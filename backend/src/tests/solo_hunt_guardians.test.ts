import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createServer } from "node:net";
import { Database } from "bun:sqlite";
import { guardiansFor } from "../solo_guardians";

const catalog = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/static/solo_bosses.json"), "utf8")).bosses;

test("guardian groups use stable zone-specific identities and existing tier templates", () => {
  const expected: Record<string, string[]> = {
    hunt_common: [], hunt_mythic: ["common", "common"],
    hunt_rare: ["mythic", "common", "common"],
    hunt_epic: ["rare", "common", "common", "common"],
    hunt_legendary: ["epic", "common", "common", "common", "common"],
  };
  const ids = new Set<string>();
  for (const zone of ["zone_chaos", "zone_corrupted", "zone_crystal"]) {
    for (const [parent, tiers] of Object.entries(expected)) {
      const guardians = guardiansFor(zone, parent, catalog)!;
      expect(guardians.map(g => g.tier)).toEqual(tiers);
      expect(guardiansFor(zone, parent, catalog)).toEqual(guardians);
      for (const guardian of guardians) {
        expect(ids.has(guardian.guardian_id)).toBe(false);
        ids.add(guardian.guardian_id);
        expect(catalog.some((boss: any) => boss.id === guardian.template_id && boss.tier === guardian.tier)).toBe(true);
        if (guardian.tier === "common") expect(guardian.texture_id).toContain(`${zone.slice(5)}_zone_common/`);
      }
    }
  }
  expect(guardiansFor("fake", "hunt_rare", catalog)).toBeNull();
  expect(guardiansFor("zone_chaos", "fake", catalog)).toBeNull();
  expect(guardiansFor("zone_chaos", "hunt_rare", [])).toBeNull();
});

test("guardian authorization and victories use real HTTP and isolated SQLite", async () => {
  const port = await new Promise<number>(r => { const s = createServer().listen(0, "127.0.0.1", () => { const p = (s.address() as { port: number }).port; s.close(() => r(p)); }); });
  const directory = mkdtempSync(join(tmpdir(), "ew-guardian-"));
  const db = new Database(join(directory, "test.sqlite"));
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const env = { ...process.env, DB_PATH: join(directory, "test.sqlite"), NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0" };
  let server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  const request = async (path: string, body?: unknown, token?: string) => {
    const r = await fetch(`http://127.0.0.1:${port}${path}`, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: r.status, data: await r.json() as any };
  };
  const wait = async () => { for (let i = 0; i < 120; i++) { try { if ((await request("/health")).status === 200) return; } catch {} await Bun.sleep(100); } throw new Error("backend readiness timeout"); };
  try {
    await wait();
    let a = await request("/auth/dev_login", { name: "guardian_isolated_a" });
    const b = await request("/auth/dev_login", { name: "guardian_isolated_b" });
    expect([a.status, b.status]).toEqual([200, 200]);
    const wallet = (id: string) => JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(id) as any).state_json).wallet;
    const beforeA = wallet(a.data.player_id).essence;
    const beforeB = wallet(b.data.player_id).essence;
    const commonSchedule = (await request("/world/boss-hunts")).data;
    const common = await request("/world/boss-hunts/start", { client_action_id: "common-start", hunt_id: "hunt_common", rotation_key: commonSchedule.rotation_key }, b.data.token);
    expect(common.status).toBe(200);
    expect((await request("/world/boss-hunts/loadout", { session_id: common.data.session_id, client_action_id: "common-load", entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" }, b.data.token)).status).toBe(200);
    const commonState = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(common.data.session_id) as any).combat_state_json);
    commonState.boss.hp = 1; commonState.boss.status.stun = 100;
    db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(commonState), common.data.session_id);
    let commonResult: any;
    for (let turn = 1; turn <= 10; turn++) {
      const body = { session_id: common.data.session_id, client_action_id: `common-turn-${turn}`, expected_revision: turn, decision: { turn, spell_id: "cinder_fist", target: "boss", hom_action: "hold" } };
      const race = await Promise.all([request("/world/boss-hunts/turn", body, b.data.token), request("/world/boss-hunts/turn", body, b.data.token)]);
      expect(race.map(r => r.status)).toEqual([200, 200]);
      expect(race[0].data).toEqual(race[1].data);
      commonResult = race[0].data;
      if (commonResult.status === "VERIFIED_WIN") break;
    }
    expect(commonResult.status).toBe("VERIFIED_WIN");
    expect(commonResult.pve_reward).toEqual({ grants: { essence: 6 }, source: "boss", tier: "common" });
    expect(wallet(b.data.player_id).essence).toBe(beforeB + 6);
    expect(wallet(a.data.player_id).essence).toBe(beforeA);
    expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE related_id = ? AND reason = ?").get(common.data.session_id, "SOLO_HUNT_REWARD") as any).n).toBe(1);
    const balance = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/static/balance.json"), "utf8")).balance;
    const cap = balance.wallet_caps?.essence ?? balance.wallet_max_per_resource;
    for (const remaining of [0, 1]) {
      const account = await request("/auth/dev_login", { name: `guardian_cap_${remaining}` });
      const state = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(account.data.player_id) as any).state_json);
      state.wallet.essence = cap - remaining;
      db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), account.data.player_id);
      const current = (await request("/world/boss-hunts")).data;
      const hunt = await request("/world/boss-hunts/start", { client_action_id: `cap-start-${remaining}`, hunt_id: "hunt_common", rotation_key: current.rotation_key }, account.data.token);
      expect(hunt.status).toBe(200);
      expect((await request("/world/boss-hunts/loadout", { session_id: hunt.data.session_id, client_action_id: `cap-load-${remaining}`, entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" }, account.data.token)).status).toBe(200);
      const combat = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(hunt.data.session_id) as any).combat_state_json);
      combat.boss.hp = 1; combat.boss.status.stun = 100;
      db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(combat), hunt.data.session_id);
      let terminal: any;
      for (let turn = 1; turn <= 10; turn++) {
        const action = { session_id: hunt.data.session_id, client_action_id: `cap-turn-${remaining}-${turn}`, expected_revision: turn, decision: { turn, spell_id: "cinder_fist", target: "boss", hom_action: "hold" } };
        const response = await request("/world/boss-hunts/turn", action, account.data.token);
        expect(response.status).toBe(200);
        terminal = response.data;
        if (terminal.status === "VERIFIED_WIN") {
          expect((await request("/world/boss-hunts/turn", action, account.data.token)).data).toEqual(terminal);
          break;
        }
      }
      expect(terminal.status).toBe("VERIFIED_WIN");
      expect(terminal.pve_reward.grants.essence).toBe(remaining);
      expect(wallet(account.data.player_id).essence).toBe(cap);
      expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE related_id = ? AND reason = ?").get(hunt.data.session_id, "SOLO_HUNT_REWARD") as any).n).toBe(remaining);
    }
    expect((await request("/world/boss-hunts/guardians?zone_id=zone_chaos&hunt_id=hunt_rare")).status).toBe(401);
    for (const zone of ["zone_chaos", "zone_corrupted", "zone_crystal"]) {
      for (const [hunt, count] of [["hunt_common", 0], ["hunt_mythic", 2], ["hunt_rare", 3], ["hunt_epic", 4], ["hunt_legendary", 5]] as const) {
        const res = await request(`/world/boss-hunts/guardians?zone_id=${zone}&hunt_id=${hunt}`, undefined, a.data.token);
        expect(res.status).toBe(200);
        expect(res.data.total_count).toBe(count);
        expect(res.data.boss_unlocked).toBe(count === 0);
      }
    }
    expect((await request("/world/boss-hunts/guardians?zone_id=invalid&hunt_id=hunt_rare", undefined, a.data.token)).status).toBe(400);
    const schedule = (await request("/world/boss-hunts")).data;
    const special = schedule.bosses.find((x: any) => x.tier !== "common" && x.available);
    if (!special) {
      console.log("SKIP guardian combat: special appearance window is closed.");
      return;
    }
    if (schedule.special_window_ends_at - schedule.server_time_unix_ms < 120000) {
      console.log("SKIP guardian combat: appearance window too close to expiry.");
      return;
    }
    const zone = "zone_chaos";
    const listPath = `/world/boss-hunts/guardians?zone_id=${zone}&hunt_id=${special.id}`;
    const guardians = (await request(listPath, undefined, a.data.token)).data.guardians;
    const start = (id: string, guardian?: string) => request("/world/boss-hunts/start", { client_action_id: id, hunt_id: special.id, rotation_key: schedule.rotation_key, zone_id: zone, ...(guardian ? { guardian_id: guardian } : {}) }, a.data.token);
    expect((await start("locked")).status).toBe(409);
    expect((await start("forged", "not-a-guardian")).status).toBe(409);
    for (const remaining of [0, 1]) {
      const account = await request("/auth/dev_login", { name: `guardian_win_cap_${remaining}` });
      const player = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(account.data.player_id) as any).state_json);
      player.wallet.essence = cap - remaining;
      db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(player), account.data.player_id);
      const opened = await request("/world/boss-hunts/start", { client_action_id: `guardian-cap-start-${remaining}`, hunt_id: special.id, rotation_key: schedule.rotation_key, zone_id: zone, guardian_id: guardians[0].guardian_id }, account.data.token);
      expect(opened.status).toBe(200);
      const sessionId = opened.data.session_id;
      expect((await request("/world/boss-hunts/loadout", { session_id: sessionId, client_action_id: `guardian-cap-load-${remaining}`, entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" }, account.data.token)).status).toBe(200);
      const combat = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) as any).combat_state_json);
      combat.boss.hp = 1; combat.boss.status.stun = 100;
      db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(combat), sessionId);
      let terminal: any;
      for (let turn = 1; turn <= 10; turn++) {
        const action = { session_id: sessionId, client_action_id: `guardian-cap-turn-${remaining}-${turn}`, expected_revision: turn, decision: { turn, spell_id: "cinder_fist", target: "boss", hom_action: "hold" } };
        const responses = await Promise.all([request("/world/boss-hunts/turn", action, account.data.token), request("/world/boss-hunts/turn", action, account.data.token)]);
        expect(responses.map(r => r.status)).toEqual([200, 200]);
        expect(responses[0].data).toEqual(responses[1].data);
        terminal = responses[0].data;
        if (terminal.status === "VERIFIED_WIN") break;
      }
      expect(terminal.status).toBe("VERIFIED_WIN");
      expect(terminal.pve_reward.grants.essence).toBe(remaining);
      expect(wallet(account.data.player_id).essence).toBe(cap);
      expect((db.query("SELECT COUNT(*) AS n FROM solo_guardian_victories WHERE player_id = ? AND session_id = ?").get(account.data.player_id, sessionId) as any).n).toBe(1);
      expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE related_id = ? AND reason = ?").get(sessionId, "SOLO_HUNT_REWARD") as any).n).toBe(remaining);
      expect((await request(listPath, undefined, account.data.token)).data.defeated_count).toBe(1);
    }
    const forfeit = await start("forfeit-start", guardians[0].guardian_id);
    expect(forfeit.status).toBe(200);
    expect((await request("/world/boss-hunts/forfeit", { session_id: forfeit.data.session_id, client_action_id: "forfeit-guardian" }, a.data.token)).data.status).toBe("FORFEIT");
    expect((await request(listPath, undefined, a.data.token)).data.defeated_count).toBe(0);
    const expired = await start("expire-start", guardians[0].guardian_id);
    expect(expired.status).toBe(200);
    db.query("UPDATE solo_hunt_sessions SET expires_at = ? WHERE session_id = ?").run(Date.now() - 1, expired.data.session_id);
    await request("/world/boss-hunts/session", undefined, a.data.token);
    expect((db.query("SELECT status FROM solo_hunt_sessions WHERE session_id = ?").get(expired.data.session_id) as any).status).toBe("EXPIRED");
    expect((await request(listPath, undefined, a.data.token)).data.defeated_count).toBe(0);
    const loss = await start("loss-start", guardians[0].guardian_id);
    expect(loss.status).toBe(200);
    const lossId = loss.data.session_id;
    expect((await request("/world/boss-hunts/loadout", { session_id: lossId, client_action_id: "loss-load", entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" }, a.data.token)).status).toBe(200);
    const lossState = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(lossId) as any).combat_state_json);
    lossState.player.hp = 1; lossState.boss.status.tempo_bonus = 100;
    db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(lossState), lossId);
    let lossResult: any;
    for (let turn = 1; turn <= 10; turn++) {
      const response = await request("/world/boss-hunts/turn", { session_id: lossId, client_action_id: `loss-${turn}`, expected_revision: turn, decision: { turn, spell_id: "cinder_fist", target: "boss", hom_action: "hold" } }, a.data.token);
      expect(response.status).toBe(200);
      lossResult = response.data;
      if (lossResult.status === "VERIFIED_LOSS") break;
    }
    expect(lossResult.status).toBe("VERIFIED_LOSS");
    expect((await request(listPath, undefined, a.data.token)).data.defeated_count).toBe(0);
    expect(wallet(a.data.player_id).essence).toBe(beforeA);
    let expectedEssence = beforeA;
    for (let i = 0; i < guardians.length; i++) {
      const guardian = guardians[i];
      const opened = await start(`guardian-${i}`, guardian.guardian_id);
      expect(opened.status).toBe(200);
      expect(opened.data.guardian_id).toBe(guardian.guardian_id);
      expect(opened.data.boss_definition.id).toBe(guardian.template_id);
      expect(opened.data.boss_definition.tier).toBe(guardian.tier);
      expect(opened.data.boss_definition.texture_id).toBe(guardian.texture_id);
      const sessionId = opened.data.session_id;
      const load = await request("/world/boss-hunts/loadout", { session_id: sessionId, client_action_id: `load-${i}`, entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" }, a.data.token);
      expect(load.status).toBe(200);
      const row = db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) as any;
      const state = JSON.parse(row.combat_state_json);
      state.boss.hp = 1; state.boss.status.stun = 100;
      db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(state), sessionId);
      let result: any;
      for (let turn = 1; turn <= 10; turn++) {
        const body = { session_id: sessionId, client_action_id: `turn-${i}-${turn}`, expected_revision: turn, decision: { turn, spell_id: "cinder_fist", target: "boss", hom_action: "hold" } };
        const race = await Promise.all([request("/world/boss-hunts/turn", body, a.data.token), request("/world/boss-hunts/turn", body, a.data.token)]);
        expect(race.map(r => r.status)).toEqual([200, 200]);
        expect(race[0].data).toEqual(race[1].data);
        result = race[0].data;
        if (result.status === "VERIFIED_WIN") break;
      }
      expect(result.status).toBe("VERIFIED_WIN");
      const amount: Record<string, number> = { common: 3, mythic: 5, rare: 8, epic: 12 };
      expectedEssence += amount[guardian.tier];
      expect(result.pve_reward).toEqual({ grants: { essence: amount[guardian.tier] }, source: "guardian", tier: guardian.tier });
      expect(wallet(a.data.player_id).essence).toBe(expectedEssence);
      expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE related_id = ? AND reason = ?").get(sessionId, "SOLO_HUNT_REWARD") as any).n).toBe(1);
      expect((db.query("SELECT COUNT(*) AS n FROM solo_guardian_victories WHERE player_id = ? AND zone_id = ? AND parent_hunt_id = ?").get(a.data.player_id, zone, special.id) as any).n).toBe(i + 1);
      expect((await start(`repeat-${i}`, guardian.guardian_id)).status).toBe(409);
      expect((await request(listPath, undefined, b.data.token)).data.defeated_count).toBe(0);
    }
    expect((await request(listPath, undefined, a.data.token)).data.boss_unlocked).toBe(true);
    const main = await start("unlocked");
    expect(main.status).toBe(200);
    server.kill(); await server.exited;
    server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
    await wait();
    a = await request("/auth/dev_login", { name: "guardian_isolated_a" });
    expect((await request(listPath, undefined, a.data.token)).data.boss_unlocked).toBe(true);
    const restartedB = await request("/auth/dev_login", { name: "guardian_isolated_b" });
    const commonRecovered = await request(`/world/boss-hunts/session?session_id=${common.data.session_id}`, undefined, restartedB.data.token);
    expect(commonRecovered.data.session.pve_reward).toEqual(commonResult.pve_reward);
    expect(wallet(b.data.player_id).essence).toBe(beforeB + 6);
  } finally {
    server.kill(); await server.exited; db.close();
    rmSync(directory, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  }
}, 180000);
