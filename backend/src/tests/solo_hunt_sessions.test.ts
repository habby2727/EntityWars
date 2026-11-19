import { test, expect } from "bun:test";
import { createHmac } from "node:crypto";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { commonAppearance } from "../solo_guardians";
import { maintainSoloHunts } from "../solo_hunt_retention";

test("all zone common appearances are strictly whitelisted", () => {
  const zones: Record<string, string[]> = {
    zone_chaos: ["chaos_astral_alchemist", "chaos_astral_alchemist_variant", "chaos_astral_eagle", "chaos_cyber_warrior", "chaos_lion_warrior"],
    zone_corrupted: ["corrupted_cocodragon", "corrupted_cybermantis", "corrupted_doctor", "corrupted_hipovenom", "corrupted_medusa", "corrupted_sphinx"],
    zone_crystal: ["crystal_bear", "crystal_golem", "crystal_hydra", "crystal_mage", "crystal_sentinel", "crystal_wolf"],
  };
  expect(Object.values(zones).flat()).toHaveLength(17);
  for (const [zone, ids] of Object.entries(zones)) for (const id of ids) {
    const appearance = commonAppearance(zone, id)!;
    expect(appearance.appearance_id).toBe(id);
    expect(appearance.name.length).toBeGreaterThan(0);
    expect(appearance.texture_id).toBe(`res://assets/lab/bosses/${zone.slice(5)}_zone_common/${id}.png`);
    expect(commonAppearance(zone === "zone_chaos" ? "zone_crystal" : "zone_chaos", id)).toBeNull();
  }
  expect(commonAppearance("__proto__", "x")).toBeNull();
  expect(commonAppearance("zone_chaos", "../x")).toBeNull();
});

test("solo hunts are isolated, persistent and idempotent without wallet changes", async () => {
  const port = await new Promise<number>((resolvePort) => {
    const socket = createServer().listen(0, "127.0.0.1", () => { const port = (socket.address() as { port: number }).port; socket.close(() => resolvePort(port)); });
  });
  const directory = mkdtempSync(join(tmpdir(), "entitywars-hunts-"));
  const dbPath = join(directory, "test.sqlite");
  const db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(name => name.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const clockOffset = Math.floor(Date.now() / 900000) * 900000 + 120000 - Date.now();
  const testNow = () => Date.now() + clockOffset;
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0", WORLD_SECRET: "test-hunt-world-secret", TEST_CLOCK_OFFSET: String(clockOffset) };
  const spawnServer = () => Bun.spawn([process.execPath, "-e", "const realNow = Date.now.bind(Date); Date.now = () => realNow() + Number(process.env.TEST_CLOCK_OFFSET); await import('./src/index.ts');"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  let server = spawnServer();
  const request = async (path: string, body?: unknown, token?: string) => {
    const response = await fetch(`http://127.0.0.1:${port}${path}`, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, data: await response.json() as any };
  };
  try {
    let ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    const a = await request("/auth/dev_login", { name: "hunt_test_a" });
    const b = await request("/auth/dev_login", { name: "hunt_test_b" });
    expect([a.status, b.status]).toEqual([200, 200]);
    const reroll = { client_action_id: "reroll-a", zone_id: "zone_chaos" };
    const simultaneous = await Promise.all([request("/world/reroll", reroll, a.data.token), request("/world/reroll", reroll, a.data.token)]);
    expect(simultaneous.map(r => r.status)).toEqual([200, 200]);
    expect(simultaneous.filter(r => r.data.duplicate).length).toBe(1);
    expect((await request("/world/reroll", { client_action_id: "reroll-b" }, a.data.token)).status).toBe(429);
    const worldA = await request("/world/state", undefined, a.data.token);
    const worldB = await request("/world/state", undefined, b.data.token);
    expect(worldA.data.player_world.reroll_count).toBe(1);
    expect(worldA.data.player_world.reroll_seeds.zone_chaos).toBeGreaterThan(0);
    expect((await request("/world/state", undefined, a.data.token)).data.player_world.reroll_seeds).toEqual(worldA.data.player_world.reroll_seeds);
    expect(worldB.data.player_world.reroll_count).toBe(0);
    expect((await request("/world/reroll", { client_action_id: "reroll-other" }, b.data.token)).status).toBe(200);
    const worldRow = db.query("SELECT state_json FROM players WHERE player_id = ?").get(a.data.player_id) as any;
    const worldFixture = JSON.parse(worldRow.state_json);
    worldFixture.world.sessions["loot-fixture"] = { session_id: "loot-fixture", zone_id: "zone_chaos", started_at: testNow(), last_farm_at: 0, pending_loot: { essence: 7 }, blocks_farmed: 0, modifiers: [] };
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(worldFixture), a.data.player_id);
    expect((await request("/world/claim", { client_action_id: "loot-other", session_id: "loot-fixture" }, b.data.token)).status).toBe(400);
    const lootBefore = worldFixture.wallet.essence;
    const claims = await Promise.all([request("/world/claim", { client_action_id: "loot-claim", session_id: "loot-fixture" }, a.data.token), request("/world/claim", { client_action_id: "loot-claim", session_id: "loot-fixture" }, a.data.token)]);
    expect(claims.map(c => c.status)).toEqual([200, 200]);
    expect((await request("/world/claim", { client_action_id: "loot-again", session_id: "loot-fixture" }, a.data.token)).data.claimed).toEqual({});
    expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(a.data.player_id) as any).state_json).wallet.essence).toBe(lootBefore + 7);
    const wallet = (id: string) => JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(id) as any).state_json).wallet;
    const beforeA = wallet(a.data.player_id), beforeB = wallet(b.data.player_id);
    const balance = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/static/balance.json"), "utf8")).balance;
    const commonReward = { ...balance.solo_hunt_rewards.boss.common };
    const fixture = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(a.data.player_id) as any).state_json);
    fixture.spell_progress = { learned_by_entity: { sulfur_01: ["steady_script"] }, active_research: null, equipped_by_mode: { attack: { sulfur_01: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] }, defense: {} } };
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(fixture), a.data.player_id);
    const schedule = (await request("/world/boss-hunts")).data;
    const key = schedule.rotation_key;
    const start = (id: string, hunt = "hunt_common", rotation = key, token = a.data.token) => request("/world/boss-hunts/start", { client_action_id: id, hunt_id: hunt, rotation_key: rotation, ...(hunt === "hunt_common" ? { zone_id: "zone_chaos", appearance_id: id.includes("LOSS") ? "chaos_cyber_warrior" : "chaos_astral_eagle" } : {}) }, token);
    expect((await request("/world/boss-hunts/start", { client_action_id: "anonymous", hunt_id: "hunt_common", rotation_key: key })).status).toBe(401);
    expect((await start("bad-id", "fake_boss")).status).toBe(409);
    expect((await start("bad-key", "hunt_common", key - 1)).status).toBe(409);
    const unavailable = schedule.bosses.find((boss: any) => boss.tier !== "common" && !boss.available);
    expect((await start("unavailable", unavailable.id)).status).toBe(409);
    const visualStart = { client_action_id: "visual", hunt_id: "hunt_common", rotation_key: key, zone_id: "zone_chaos", appearance_id: "chaos_astral_alchemist_variant" };
    expect((await request("/world/boss-hunts/start", { ...visualStart, appearance_id: "crystal_bear" }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/start", { ...visualStart, zone_id: undefined }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/start", { ...visualStart, guardian_id: "fake" }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/start", { ...visualStart, global_event_id: "fake" }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/start", { ...visualStart, hunt_id: "hunt_mythic" }, a.data.token)).status).toBe(400);
    const concurrent = await Promise.all([request("/world/boss-hunts/start", visualStart, a.data.token), request("/world/boss-hunts/start", visualStart, a.data.token)]);
    expect(concurrent.map(result => result.status)).toEqual([200, 200]);
    const session = concurrent[0].data;
    expect(concurrent[1].data.session_id).toBe(session.session_id);
    expect(session.boss_definition.name).toBe("Astral Alchemist Ascendant");
    expect(session.boss_definition.texture_id).toBe("res://assets/lab/bosses/chaos_zone_common/chaos_astral_alchemist_variant.png");
    expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.session.boss_definition).toEqual(session.boss_definition);
    expect((await request("/world/boss-hunts/start", { ...visualStart, appearance_id: "chaos_astral_eagle" }, a.data.token)).status).toBe(409);
    expect(session.expires_at - session.started_at).toBe(2700000);
    expect((await start("concurrent", "hunt_common", key - 1)).status).toBe(409);
    expect((await request("/world/boss-hunts/start", { ...visualStart, client_action_id: "invalid-second", appearance_id: "invalid" }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/session", undefined, b.data.token)).data.session).toBeNull();
    expect((await request("/world/boss-hunts/forfeit", { session_id: session.session_id, client_action_id: "other-player" }, b.data.token)).status).toBe(404);
    const snapshot = db.query("SELECT * FROM solo_hunt_sessions WHERE session_id = ?").get(session.session_id) as any;
    expect(JSON.parse(snapshot.player_snapshot_json).loadout_verification).toBe("UNVERIFIED");
    const loadout = { session_id: session.session_id, client_action_id: "hunt-loadout", entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["steady_script", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" };
    expect((await request("/world/boss-hunts/loadout", loadout)).status).toBe(401);
    expect((await request("/world/boss-hunts/loadout", loadout, b.data.token)).status).toBe(404);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, atk: 999 }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, level: 10 }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, entity_id: "fake_entity" }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, spell_ids: ["needle_etch", ...loadout.spell_ids.slice(1)] }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, homunculus_id: "unknown" }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, weapon_ids: ["fake", null] }, a.data.token)).status).toBe(400);
    expect((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(session.session_id) as any).combat_state_json).toBeNull();
    const initialized = await Promise.all([request("/world/boss-hunts/loadout", loadout, a.data.token), request("/world/boss-hunts/loadout", loadout, a.data.token)]);
    expect(initialized.map(r => r.status)).toEqual([200, 200]);
    expect(initialized[0].data.combat_state).toEqual(initialized[1].data.combat_state);
    expect(initialized[0].data.combat_revision).toBe(1);
    expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(a.data.player_id) as any).state_json).spell_progress).toEqual(fixture.spell_progress);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, entity_id: "gold_01" }, a.data.token)).status).toBe(409);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, client_action_id: "different" }, a.data.token)).status).toBe(409);
    const savedCombat = initialized[0].data.combat_state;
    const fullStateBefore = (db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(session.session_id) as any).combat_state_json;
    const privateKeys = new Set(["rng_counter", "boss_signature", "selected_signature", "inspiration_catalog", "hom_synergy", "item_effects", "boss_cooldowns", "boss_shield_phases", "power_turn_eligible", "original_spell_ids", "weapons", "types"]);
    const assertPublic = (value: any) => {
      if (!value || typeof value !== "object") return;
      for (const [key, child] of Object.entries(value)) { expect(privateKeys.has(key)).toBe(false); assertPublic(child); }
    };
    expect(JSON.parse(fullStateBefore).rng_counter).toBe(1);
    assertPublic(initialized[0].data);
    expect(savedCombat.player.hp).toBeGreaterThan(0);
    expect(savedCombat.moves).toHaveLength(4);
    const upgraded = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(a.data.player_id) as any).state_json);
    const originalProgress = upgraded.item_progress;
    upgraded.item_progress = { ...upgraded.item_progress, bismuth_talisman: { level: 10 } };
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(upgraded), a.data.player_id);
    server.kill();
    await server.exited;
    server = spawnServer();
    ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    const relogin = await request("/auth/dev_login", { name: "hunt_test_a" });
    expect(relogin.status).toBe(200);
    a.data.token = relogin.data.token;
    const reloginB = await request("/auth/dev_login", { name: "hunt_test_b" });
    expect(reloginB.status).toBe(200);
    b.data.token = reloginB.data.token;
    const recovered = (await request("/world/boss-hunts/session", undefined, a.data.token)).data.session;
    expect(recovered.session_id).toBe(session.session_id);
    expect(recovered.combat_state).toEqual(savedCombat);
    expect(recovered.combat_revision).toBe(1);
    expect((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(session.session_id) as any).combat_state_json).toBe(fullStateBefore);
    const restoredPlayer = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(a.data.player_id) as any).state_json);
    restoredPlayer.item_progress = originalProgress;
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(restoredPlayer), a.data.player_id);
    assertPublic(recovered);
    const repeatedAfterRestart = await request("/world/boss-hunts/loadout", loadout, a.data.token);
    expect(repeatedAfterRestart.data.duplicate).toBe(true);
    expect(repeatedAfterRestart.data.combat_state).toEqual(savedCombat);
    assertPublic(repeatedAfterRestart.data);
    const turn = { session_id: session.session_id, client_action_id: "turn-1", expected_revision: 1, decision: { turn: 1, spell_id: "steady_script", target: "boss" } };
    expect((await request("/world/boss-hunts/turn", turn)).status).toBe(401);
    expect((await request("/world/boss-hunts/turn", turn, b.data.token)).status).toBe(404);
    const beforeInvalidTurn = (db.query("SELECT combat_state_json, combat_revision FROM solo_hunt_sessions WHERE session_id = ?").get(session.session_id) as any);
    expect((await request("/world/boss-hunts/turn", { ...turn, decision: { ...turn.decision, spell_id: "forged" } }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/turn", { ...turn, decision: { ...turn.decision, target: "minion_9" } }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/turn", { ...turn, decision: { ...turn.decision, damage: 999 } }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/turn", { ...turn, expected_revision: 2 }, a.data.token)).status).toBe(409);
    expect((await request("/world/boss-hunts/turn", { ...turn, decision: { ...turn.decision, turn: 2 } }, a.data.token)).status).toBe(400);
    expect(db.query("SELECT combat_state_json, combat_revision FROM solo_hunt_sessions WHERE session_id = ?").get(session.session_id)).toEqual(beforeInvalidTurn);
    const firstTurn = await request("/world/boss-hunts/turn", turn, a.data.token);
    expect(firstTurn.status).toBe(200);
    expect(firstTurn.data.combat_revision).toBe(2);
    expect(firstTurn.data.combat_state.turn).toBe(1);
    expect(Array.isArray(firstTurn.data.events)).toBe(true);
    assertPublic(firstTurn.data);
    const turnTwo = { session_id: session.session_id, expected_revision: 2, decision: { turn: 2, spell_id: "furnace_rush", target: "boss" } };
    const turnRace = await Promise.all(["turn-2a", "turn-2b"].map(client_action_id => request("/world/boss-hunts/turn", { ...turnTwo, client_action_id }, a.data.token)));
    expect(turnRace.map(r => r.status).sort()).toEqual([200, 409]);
    expect(turnRace.find(r => r.status === 200)!.data.combat_revision).toBe(3);
    expect((await request("/world/boss-hunts/turn", turn, a.data.token)).data).toEqual(firstTurn.data);
    expect((await request("/world/boss-hunts/turn", { ...turn, decision: { ...turn.decision, spell_id: "ash_temper" } }, a.data.token)).status).toBe(409);
    expect((await request(`/world/boss-hunts/session?session_id=${session.session_id}`, undefined, a.data.token)).data.session.combat_revision).toBe(3);
    expect((await request(`/world/boss-hunts/session?session_id=${session.session_id}`, undefined, b.data.token)).status).toBe(404);
    const afterTwo = turnRace.find(r => r.status === 200)!.data.combat_state;
    server.kill();
    await server.exited;
    server = spawnServer();
    ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    const tokenAfterTurns = await request("/auth/dev_login", { name: "hunt_test_a" });
    expect(tokenAfterTurns.status).toBe(200);
    a.data.token = tokenAfterTurns.data.token;
    b.data.token = (await request("/auth/dev_login", { name: "hunt_test_b" })).data.token;
    const afterRestart = (await request(`/world/boss-hunts/session?session_id=${session.session_id}`, undefined, a.data.token)).data.session;
    expect(afterRestart.combat_revision).toBe(3);
    expect(afterRestart.combat_state).toEqual(afterTwo);
    expect((await request("/world/boss-hunts/turn", turn, a.data.token)).data).toEqual(firstTurn.data);
    const forfeit = () => request("/world/boss-hunts/forfeit", { session_id: session.session_id, client_action_id: "forfeit" }, a.data.token);
    expect((await forfeit()).data.status).toBe("FORFEIT");
    expect((await request("/world/boss-hunts/turn", { ...turn, client_action_id: "closed-turn", expected_revision: 3, decision: { ...turn.decision, turn: 3 } }, a.data.token)).status).toBe(409);
    expect((await request("/world/boss-hunts/turn", turn, a.data.token)).data).toEqual(firstTurn.data);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, client_action_id: "after-forfeit" }, a.data.token)).status).toBe(409);
    expect((await forfeit()).data.duplicate).toBe(true);
    expect((await request("/world/boss-hunts/start", visualStart, a.data.token)).data.status).toBe("FORFEIT");
    db.query("UPDATE solo_hunt_sessions SET finished_at = ? WHERE session_id = ?").run(testNow() - 7200000, session.session_id);
    const beforeCompact = (await request(`/world/boss-hunts/session?session_id=${session.session_id}`, undefined, a.data.token)).data.session;
    expect(maintainSoloHunts(db, testNow()).compacted).toBeGreaterThan(0);
    expect((await request(`/world/boss-hunts/session?session_id=${session.session_id}`, undefined, a.data.token)).data.session).toEqual(beforeCompact);
    expect((await forfeit()).data.combat_state).toEqual(beforeCompact.combat_state);
    expect((await request("/world/boss-hunts/start", visualStart, a.data.token)).data.combat_state).toEqual(beforeCompact.combat_state);
    expect((await request("/world/boss-hunts/loadout", loadout, a.data.token)).data.combat_state).toEqual(beforeCompact.combat_state);
    expect((await request("/world/boss-hunts/turn", turn, a.data.token)).data).toEqual(firstTurn.data);
    expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.session).toBeNull();
    const cooldown = await start("cooldown-after-forfeit");
    expect(cooldown.status).toBe(200);
    const duringCooldown = (await request("/world/boss-hunts")).data;
    const activeSpecial = duringCooldown.bosses.find((boss: any) => boss.tier !== "common" && boss.available);
    expect(activeSpecial).toBeDefined();
    if (activeSpecial) {
      const group = (await request(`/world/boss-hunts/guardians?zone_id=zone_chaos&hunt_id=${activeSpecial.id}`, undefined, a.data.token)).data.guardians;
      const guardian = group.find((entry: any) => entry.tier === "common") ?? group[0];
      const guardianStart = await request("/world/boss-hunts/start", { client_action_id: "guardian-during-common-cooldown", hunt_id: activeSpecial.id, rotation_key: duringCooldown.rotation_key, zone_id: "zone_chaos", guardian_id: guardian.guardian_id }, a.data.token);
      expect(guardianStart.status).toBe(200);
      expect((await request("/world/boss-hunts/forfeit", { client_action_id: "guardian-cooldown-forfeit", session_id: guardianStart.data.session_id }, a.data.token)).status).toBe(200);
      const bGuardian = await request("/world/boss-hunts/start", { client_action_id: "guardian-only-b", hunt_id: activeSpecial.id, rotation_key: duringCooldown.rotation_key, zone_id: "zone_chaos", guardian_id: guardian.guardian_id }, b.data.token);
      expect(bGuardian.status).toBe(200);
      expect((await request("/world/boss-hunts/forfeit", { client_action_id: "guardian-only-b-end", session_id: bGuardian.data.session_id }, b.data.token)).status).toBe(200);
      const bCommon = await start("common-after-guardian-b", "hunt_common", duringCooldown.rotation_key, b.data.token);
      expect(bCommon.status).toBe(200);
      expect((await request("/world/boss-hunts/forfeit", { client_action_id: "common-b-end", session_id: bCommon.data.session_id }, b.data.token)).status).toBe(200);
      for (const entry of group) db.query("INSERT INTO solo_guardian_victories (player_id, zone_id, parent_hunt_id, guardian_id, session_id, defeated_at) VALUES (?, ?, ?, ?, ?, ?)").run(b.data.player_id, "zone_chaos", activeSpecial.id, entry.guardian_id, `fixture-${entry.guardian_id}`, testNow());
      const specialWhileCooling = await request("/world/boss-hunts/start", { client_action_id: "special-during-common-cooldown", hunt_id: activeSpecial.id, rotation_key: duringCooldown.rotation_key, zone_id: "zone_chaos" }, b.data.token);
      expect(specialWhileCooling.status).toBe(200);
      expect((await request("/world/boss-hunts/forfeit", { client_action_id: "special-b-end", session_id: specialWhileCooling.data.session_id }, b.data.token)).status).toBe(200);
    }
    server.kill(); await server.exited;
    server = spawnServer();
    ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    a.data.token = (await request("/auth/dev_login", { name: "hunt_test_a" })).data.token;
    b.data.token = (await request("/auth/dev_login", { name: "hunt_test_b" })).data.token;
    expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.common_cooldown_until).toBe(0);
    expect((await request("/world/boss-hunts/start", visualStart, a.data.token)).data.session_id).toBe(session.session_id);
    expect((await request(`/world/boss-hunts/session?session_id=${session.session_id}`, undefined, a.data.token)).data.session).toEqual(beforeCompact);
    db.query("UPDATE solo_hunt_sessions SET finished_at = ? WHERE session_id = ?").run(testNow() - 61000, session.session_id);
    const competing = await Promise.all([start("next-a"), start("next-b")]);
    expect(competing.map(result => result.status)).toEqual([200, 200]);
    const activeId = (await request("/world/boss-hunts/session", undefined, a.data.token)).data.session.session_id;
    const next = competing.find(result => result.data.session_id === activeId)!;
    const competingLoads = await Promise.all(["init-a", "init-b"].map(client_action_id => request("/world/boss-hunts/loadout", { ...loadout, session_id: next.data.session_id, client_action_id }, a.data.token)));
    expect(competingLoads.map(result => result.status).sort()).toEqual([200, 409]);
    const pendingRow = db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any;
    const pendingState = JSON.parse(pendingRow.combat_state_json);
    pendingState.player.inspiration_pending = true;
    pendingState.player.inspiration = 3;
    pendingState.inspiration_offers = pendingState.inspiration_catalog.filter((spell: any) => !pendingState.spell_ids.includes(spell.id)).slice(0, 3).map((spell: any) => spell.id);
    expect(new Set(pendingState.inspiration_offers).size).toBe(3);
    db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(pendingState), next.data.session_id);
    server.kill();
    await server.exited;
    server = spawnServer();
    ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    a.data.token = (await request("/auth/dev_login", { name: "hunt_test_a" })).data.token;
    b.data.token = (await request("/auth/dev_login", { name: "hunt_test_b" })).data.token;
    expect(JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_state_json)).toEqual(pendingState);
    expect((await request("/world/boss-hunts/turn", { session_id: next.data.session_id, client_action_id: "pending-inspiration", expected_revision: 1, decision: { turn: 1, spell_id: "steady_script", target: "boss" } }, a.data.token)).status).toBe(409);
    expect((db.query("SELECT combat_revision FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_revision).toBe(1);
    const choice = { session_id: next.data.session_id, client_action_id: "inspiration-choice", expected_revision: 1, decision: { kind: "choose", spell_id: pendingState.inspiration_offers[0] } };
    expect((await request("/world/boss-hunts/inspiration", choice)).status).toBe(401);
    expect((await request("/world/boss-hunts/inspiration", choice, b.data.token)).status).toBe(404);
    expect((await request("/world/boss-hunts/inspiration", { ...choice, decision: { kind: "choose", spell_id: "forged" } }, a.data.token)).status).toBe(400);
    expect((await request("/world/boss-hunts/inspiration", { ...choice, decision: { ...choice.decision, slot: 0 } }, a.data.token)).status).toBe(400);
    expect(JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_state_json)).toEqual(pendingState);
    const chosen = await request("/world/boss-hunts/inspiration", choice, a.data.token);
    expect(chosen.status).toBe(200);
    expect(chosen.data.combat_revision).toBe(2);
    const afterChoice = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_state_json);
    expect(afterChoice.turn).toBe(pendingState.turn);
    expect(afterChoice.rng_counter).toBe(pendingState.rng_counter + 1);
    expect(afterChoice.spell_ids.filter((id: string, i: number) => id !== pendingState.spell_ids[i])).toEqual([choice.decision.spell_id]);
    server.kill();
    await server.exited;
    server = spawnServer();
    ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    a.data.token = (await request("/auth/dev_login", { name: "hunt_test_a" })).data.token;
    const recoveredChoice = (await request(`/world/boss-hunts/session?session_id=${next.data.session_id}`, undefined, a.data.token)).data.session;
    expect(recoveredChoice.combat_revision).toBe(2);
    expect(recoveredChoice.combat_state).toEqual(chosen.data.combat_state);
    expect(recoveredChoice.combat_state.turn).toBe(pendingState.turn);
    expect(JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_state_json)).toEqual(afterChoice);
    expect((await request("/world/boss-hunts/inspiration", choice, a.data.token)).data).toEqual(chosen.data);
    expect(JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_state_json).rng_counter).toBe(afterChoice.rng_counter);
    expect((await request("/world/boss-hunts/inspiration", { ...choice, decision: { kind: "decline" } }, a.data.token)).status).toBe(409);
    const tempCast = await request("/world/boss-hunts/turn", { session_id: next.data.session_id, client_action_id: "inspiration-temp-cast", expected_revision: 2, decision: { turn: 1, spell_id: choice.decision.spell_id, target: "boss" } }, a.data.token);
    expect(tempCast.status).toBe(200);
    expect(tempCast.data.combat_revision).toBe(3);
    const afterTemporaryCast = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_state_json);
    db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(pendingState), next.data.session_id);
    const decline = { session_id: next.data.session_id, client_action_id: "inspiration-decline", expected_revision: 3, decision: { kind: "decline" } };
    const race = await Promise.all([decline, { ...decline, client_action_id: "inspiration-race", decision: { kind: "choose", spell_id: pendingState.inspiration_offers[1] } }].map(input => request("/world/boss-hunts/inspiration", input, a.data.token)));
    expect(race.map(r => r.status).sort()).toEqual([200, 409]);
    const winner = race.findIndex(r => r.status === 200);
    const afterRace = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_state_json);
    expect(afterRace.turn).toBe(pendingState.turn);
    expect(afterRace.rng_counter).toBe(pendingState.rng_counter + (winner === 0 ? 0 : 1));
    if (winner === 0) expect(afterRace.spell_ids).toEqual(pendingState.spell_ids);
    expect((await request("/world/boss-hunts/inspiration", { ...decline, client_action_id: "stale-choice" }, a.data.token)).status).toBe(409);
    db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(pendingState), next.data.session_id);
    const declined = await request("/world/boss-hunts/inspiration", { ...decline, client_action_id: "inspiration-decline-explicit", expected_revision: 4 }, a.data.token);
    expect(declined.status).toBe(200);
    const afterDecline = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).combat_state_json);
    expect(afterDecline.spell_ids).toEqual(pendingState.spell_ids);
    expect(afterDecline.turn).toBe(pendingState.turn);
    expect(afterDecline.rng_counter).toBe(pendingState.rng_counter);
    expect(afterDecline.player.inspiration_used_this_battle).toBe(true);
    db.query("UPDATE solo_hunt_sessions SET expires_at = ? WHERE session_id = ?").run(testNow() - 1, next.data.session_id);
    expect((await request("/world/boss-hunts/inspiration", choice, a.data.token)).data).toEqual(chosen.data);
    expect((await request("/world/boss-hunts/inspiration", { ...decline, client_action_id: "expired-choice", expected_revision: 4 }, a.data.token)).status).toBe(409);
    expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.session).toBeNull();
    expect((db.query("SELECT status FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).status).toBe("EXPIRED");
    expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.common_cooldown_until).toBe(0);
    expect((await request("/world/boss-hunts/forfeit", { session_id: next.data.session_id, client_action_id: "expired-forfeit" }, a.data.token)).status).toBe(409);
    expect((await request("/world/boss-hunts/loadout", { ...loadout, session_id: next.data.session_id, client_action_id: "expired-loadout" }, a.data.token)).status).toBe(409);
    expect((await request("/world/boss-hunts/turn", { session_id: next.data.session_id, client_action_id: "expired-turn", expected_revision: 1, decision: { turn: 1, spell_id: "steady_script", target: "boss" } }, a.data.token)).status).toBe(409);
    db.query("UPDATE solo_hunt_sessions SET expires_at = ? WHERE session_id = ?").run(testNow() - 61000, next.data.session_id);
    for (const outcome of ["WIN", "LOSS"]) {
      const walletBeforeBattle = wallet(a.data.player_id);
      const current = (await request("/world/boss-hunts")).data;
      const hunt = await start(`terminal-start-${outcome}`, "hunt_common", current.rotation_key);
      expect(hunt.status).toBe(200);
      const sessionId = hunt.data.session_id;
      expect((await request("/world/boss-hunts/loadout", { ...loadout, session_id: sessionId, client_action_id: `terminal-loadout-${outcome}` }, a.data.token)).status).toBe(200);
      const stored = db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) as any;
      const fixtureState = outcome === "LOSS" ? structuredClone(afterTemporaryCast) : JSON.parse(stored.combat_state_json);
      if (outcome === "WIN") fixtureState.boss.hp = 1;
      else { fixtureState.player.hp = 1; fixtureState.boss.status.tempo_bonus = 100; }
      db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(fixtureState), sessionId);
      let revision = 1, finalResponse: any = null, finalRequest: any = null;
      for (let i = 1; i <= 10 && !finalResponse; i++) {
        const spellId = fixtureState.spell_ids.find((id: string) => !(fixtureState.cooldowns[id] > 0));
        const input = { session_id: sessionId, client_action_id: `terminal-turn-${outcome}-${i}`, expected_revision: revision, decision: { turn: fixtureState.turn + i, spell_id: spellId, target: "boss" } };
        const response = await request("/world/boss-hunts/turn", input, a.data.token);
        expect(response.status).toBe(200);
        revision = response.data.combat_revision;
        if (response.data.status !== "ACTIVE") { finalResponse = response.data; finalRequest = input; }
      }
      expect(finalResponse?.status).toBe(`VERIFIED_${outcome}`);
      expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.common_cooldown_until).toBe(0);
      const expectedWallet = { ...walletBeforeBattle };
      if (outcome === "WIN") {
        for (const id of ["core", "arcane_shard"]) {
          const drop = balance.solo_hunt_bonus_loot.common[id];
          const roll = createHmac("sha256", env.WORLD_SECRET || "dev_world_secret").update(`solo-hunt-bonus:${id}:${sessionId}`).digest().readUInt32BE(0) / 0x100000000;
          if (roll < drop.chance) commonReward[id] = drop.quantity;
        }
        for (const [resource, amount] of Object.entries(commonReward)) expectedWallet[resource] = (expectedWallet[resource] ?? 0) + Number(amount);
        expect(finalResponse.pve_reward).toEqual({ grants: commonReward, source: "boss", tier: "common" });
      } else expect(finalResponse.pve_reward).toBeUndefined();
      expect(wallet(a.data.player_id)).toEqual(expectedWallet);
      if (outcome === "WIN") {
        expect((await request("/world/claim", { client_action_id: "loot-after-boss", session_id: "loot-fixture" }, a.data.token)).data.claimed).toEqual({});
        expect(wallet(a.data.player_id)).toEqual(expectedWallet);
      }
      expect(finalResponse.events.filter((e: any) => e.kind === "combat_terminal")).toHaveLength(1);
      const missionsBeforeRetry = (await request("/world/missions", undefined, a.data.token)).data;
      if (outcome === "WIN") {
        expect(missionsBeforeRetry.daily.missions.find((m: any) => m.id === "daily_boss").progress).toBe(1);
        expect(missionsBeforeRetry.daily.missions.find((m: any) => m.id === "daily_damage").progress).toBeGreaterThan(0);
      }
      expect((await request("/world/boss-hunts/turn", finalRequest, a.data.token)).data).toEqual(finalResponse);
      expect((await request("/world/missions", undefined, a.data.token)).data.daily).toEqual(missionsBeforeRetry.daily);
      expect(wallet(a.data.player_id)).toEqual(expectedWallet);
      expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE related_id = ? AND reason = ?").get(sessionId, "SOLO_HUNT_REWARD") as any).n).toBe(outcome === "WIN" ? 1 : 0);
      expect((await request("/world/boss-hunts/turn", { ...finalRequest, client_action_id: `closed-${outcome}` }, a.data.token)).status).toBe(409);
      const terminal = (await request(`/world/boss-hunts/session?session_id=${sessionId}`, undefined, a.data.token)).data.session;
      expect(terminal.status).toBe(`VERIFIED_${outcome}`);
      expect(terminal.combat_revision).toBe(revision);
      if (outcome === "LOSS") {
        const finalState = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) as any).combat_state_json);
        expect(finalState.spell_ids).toEqual(pendingState.spell_ids);
        expect(finalState.temporary_spell_id).toBeNull();
        expect(finalState.spells.some((spell: any) => spell.id === choice.decision.spell_id)).toBe(false);
        server.kill();
        await server.exited;
        server = spawnServer();
        ready = false;
        for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
        expect(ready).toBe(true);
        a.data.token = (await request("/auth/dev_login", { name: "hunt_test_a" })).data.token;
        expect((await request(`/world/boss-hunts/session?session_id=${sessionId}`, undefined, a.data.token)).data.session).toEqual(terminal);
        expect((await request("/world/boss-hunts/turn", finalRequest, a.data.token)).data).toEqual(finalResponse);
      }
      db.query("UPDATE solo_hunt_sessions SET finished_at = ? WHERE session_id = ?").run(testNow() - 61000, sessionId);
    }
    const fresh = (await request("/world/boss-hunts")).data;
    const special = fresh.bosses.find((boss: any) => boss.tier !== "common" && boss.available);
    if (special) {
      expect((await start("special-without-zone", special.id, fresh.rotation_key)).status).toBe(409);
      expect((await request("/world/boss-hunts/start", { client_action_id: "special-locked", hunt_id: special.id, rotation_key: fresh.rotation_key, zone_id: "zone_chaos" }, a.data.token)).status).toBe(409);
    } else console.log("Special authorization not tested: outside appearance window.");
    const expectedFinalWallet = { ...beforeA };
    for (const [resource, amount] of Object.entries(commonReward)) expectedFinalWallet[resource] = (expectedFinalWallet[resource] ?? 0) + Number(amount);
    expect(wallet(a.data.player_id)).toEqual(expectedFinalWallet);
    expect(wallet(b.data.player_id)).toEqual(beforeB);
    expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(a.data.player_id) as any).state_json).spell_progress).toEqual(fixture.spell_progress);
  } finally {
    server.kill();
    await server.exited;
    db.close();
    rmSync(directory, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  }
}, 240000);
