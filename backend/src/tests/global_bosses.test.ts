import { test, expect } from "bun:test";
import { createHmac } from "node:crypto";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { globalBossRoll, globalBossTier } from "../global_boss_rotation";

test("global rotation uses configured weighted boundaries and zone-specific HMAC", () => {
  const weights = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/static/solo_bosses.json"), "utf8")).rotation.weights;
  expect([0, 0.349999, 0.35, 0.649999, 0.65, 0.849999, 0.85, 0.999999].map(roll => globalBossTier(roll, weights))).toEqual(["mythic", "mythic", "rare", "rare", "epic", "epic", "legendary", "legendary"]);
  expect(globalBossRoll("test", "zone_chaos", 123)).toEqual(globalBossRoll("test", "zone_chaos", 123));
  expect(globalBossRoll("test", "zone_chaos", 123)).not.toEqual(globalBossRoll("test", "zone_crystal", 123));
});

test("global bosses persist per zone and use trusted sessions", async () => {
  const port = await new Promise<number>(done => { const socket = createServer().listen(0, "127.0.0.1", () => { const value = (socket.address() as {port: number}).port; socket.close(() => done(value)); }); });
  const directory = mkdtempSync(join(tmpdir(), "entitywars-global-"));
  const dbPath = join(directory, "test.sqlite");
  const db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0", WORLD_SECRET: "global-test-secret" };
  const spawn = () => Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  let server = spawn();
  const request = async (path: string, body?: unknown, token?: string) => {
    const response = await fetch(`http://127.0.0.1:${port}${path}`, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, data: await response.json() as any };
  };
  const ready = async () => { for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) return; } catch {} await Bun.sleep(100); } throw new Error("server unavailable"); };
  try {
    await ready();
    const a = (await request("/auth/dev_login", {name: "global_test_a"})).data;
    const b = (await request("/auth/dev_login", {name: "global_test_b"})).data;
    expect((await request("/world/global-bosses")).status).toBe(401);
    const events = (await request("/world/global-bosses", undefined, a.token)).data.events;
    expect(events.map((e: any) => e.zone_id)).toEqual(["zone_chaos", "zone_corrupted", "zone_crystal"]);
    expect(events.every((e: any) => e.status === "ACTIVE" && e.tier !== "common" && e.winner_count === 0)).toBe(true);
    expect((await request("/world/global-bosses", undefined, b.token)).data.events).toEqual(events);
    const event = events[0];
    expect((await request("/world/boss-hunts/start", {client_action_id: "forged", global_event_id: "global_fake"}, a.token)).status).toBe(409);
    const start = await request("/world/boss-hunts/start", {client_action_id: "global-start", global_event_id: event.event_id, hunt_id: "forged", rotation_key: -1}, a.token);
    expect(start.status).toBe(200);
    expect(start.data.hunt_id).toBe(event.boss.id);
    expect(start.data.global_event_id).toBe(event.event_id);
    expect(start.data.global_status.zone_id).toBe(event.zone_id);
    expect(start.data.boss_definition.texture_id).toBe(event.boss.texture_id);
    const storedStart = db.query("SELECT guardian_id, guardian_zone_id FROM solo_hunt_sessions WHERE session_id = ?").get(start.data.session_id) as any;
    expect(storedStart).toEqual({guardian_id: null, guardian_zone_id: null});
    expect((await request(`/world/boss-hunts/session?session_id=${start.data.session_id}`, undefined, b.token)).status).toBe(404);
    const forfeit = {client_action_id: "forfeit", session_id: start.data.session_id};
    expect((await request("/world/boss-hunts/forfeit", forfeit, a.token)).data.status).toBe("FORFEIT");
    expect((await request("/world/boss-hunts/forfeit", forfeit, a.token)).data.status).toBe("FORFEIT");
    expect((await request("/world/boss-hunts/session", undefined, a.token)).data.session).toBeNull();
    const retry = await request("/world/boss-hunts/start", {client_action_id: "retry", global_event_id: event.event_id}, a.token);
    expect(retry.status).toBe(200);
    server.kill(); await server.exited; server = spawn(); await ready();
    a.token = (await request("/auth/dev_login", {name: "global_test_a"})).data.token;
    b.token = (await request("/auth/dev_login", {name: "global_test_b"})).data.token;
    expect((await request("/world/global-bosses", undefined, a.token)).data.events).toEqual(events);
    const players = [a, b];
    for (let i = 2; i < 6; i++) players.push((await request("/auth/dev_login", {name: `global_test_${i}`})).data);
    const sessions = [retry.data.session_id];
    for (let i = 1; i < 6; i++) {
      const response = await request("/world/boss-hunts/start", {client_action_id: `start-${i}`, global_event_id: event.event_id}, players[i].token);
      expect(response.status).toBe(200);
      sessions.push(response.data.session_id);
    }
    const wallet = (i: number) => JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(players[i].player_id) as any).state_json).wallet;
    const before = players.map((_, i) => wallet(i));
    const grants = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/static/balance.json"), "utf8")).balance.solo_hunt_rewards.boss[event.tier];
    for (let i = 0; i < 4; i++) {
      const loadout = { session_id: sessions[i], client_action_id: `load-${i}`, entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: i === 0 ? null : "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" };
      expect((await request("/world/boss-hunts/loadout", loadout, players[i].token)).status).toBe(200);
      if (i === 0) {
        const forgedTurn = {session_id: sessions[i], client_action_id: "forged-turn", expected_revision: 1, decision: {turn: 1, spell_id: "fake", target: "boss"}};
        expect((await request("/world/boss-hunts/turn", forgedTurn, players[i].token)).status).toBe(400);
        expect((await request("/world/boss-hunts/turn", {...forgedTurn, client_action_id: "stale-turn", expected_revision: 2}, players[i].token)).status).toBe(409);
        expect((await request("/world/boss-hunts/turn", {...forgedTurn, client_action_id: "other-user"}, b.token)).status).toBe(404);
        expect((await request("/world/global-bosses", undefined, players[i].token)).data.events[0].winner_count).toBe(0);
      }
      const state = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessions[i]) as any).combat_state_json);
      state.boss.hp = 1;
      state.boss_shield_turns = 0;
      for (const minion of state.minions) minion.hp = 0;
      db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(state), sessions[i]);
      let final: any;
      for (let n = 0; n < 10; n++) {
        const current = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessions[i]) as any).combat_state_json);
        const spell = current.spell_ids.find((id: string) => !(current.cooldowns[id] > 0));
        const turn = {session_id: sessions[i], client_action_id: `turn-${i}-${n}`, expected_revision: n + 1, decision: {turn: current.turn + 1, spell_id: spell, target: "boss"}};
        const result = await request("/world/boss-hunts/turn", turn, players[i].token);
        expect(result.status).toBe(200);
        if (result.data.status !== "ACTIVE") {
          final = result.data;
          expect((await request("/world/boss-hunts/turn", turn, players[i].token)).data).toEqual(final);
          break;
        }
      }
      expect(final?.status).toBe("VERIFIED_WIN");
      expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id=?").get(players[i].player_id) as any).state_json).homunculus_progress?.cinder?.xp ?? 0).toBe(i === 0 ? 0 : 20);
      const after = (await request("/world/global-bosses", undefined, players[i].token)).data.events[0];
      expect(after.winner_count).toBe(i + 1);
      expect(after.reward_status).toBe("WAITING");
      expect(wallet(i)).toEqual(before[i]);
      if (i === 0) {
        expect((await request("/world/boss-hunts/start", {client_action_id: "again", global_event_id: event.event_id}, a.token)).status).toBe(409);
        expect((await request("/world/global-bosses", undefined, b.token)).data.events[0].reward_status).toBeNull();
      }
    }
    for (const i of [4, 5]) {
      const loadout = { session_id: sessions[i], client_action_id: `load-${i}`, entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" };
      expect((await request("/world/boss-hunts/loadout", loadout, players[i].token)).status).toBe(200);
      const state = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessions[i]) as any).combat_state_json);
      state.boss.hp = 1; state.boss_shield_turns = 0;
      for (const minion of state.minions) minion.hp = 0;
      db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(state), sessions[i]);
    }
    const finished = new Set<number>();
    const terminalTurns = new Map<number, {turn: any; response: any}>();
    for (let n = 0; n < 10 && finished.size < 2; n++) {
      const pending = [4, 5].filter(i => !finished.has(i));
      const turns = pending.map(i => {
        const row = db.query("SELECT combat_state_json, combat_revision FROM solo_hunt_sessions WHERE session_id = ?").get(sessions[i]) as any;
        const state = JSON.parse(row.combat_state_json);
        const spell = state.spell_ids.find((id: string) => !(state.cooldowns[id] > 0));
        return {session_id: sessions[i], client_action_id: `race-${i}-${n}`, expected_revision: row.combat_revision, decision: {turn: state.turn + 1, spell_id: spell, target: "boss"}};
      });
      const results = await Promise.all(pending.map((i, j) => request("/world/boss-hunts/turn", turns[j], players[i].token)));
      for (let j = 0; j < pending.length; j++) {
        expect(results[j].status).toBe(200);
        if (results[j].data.status === "VERIFIED_WIN") {
          finished.add(pending[j]);
          terminalTurns.set(pending[j], {turn: turns[j], response: results[j].data});
          expect((await request("/world/boss-hunts/turn", turns[j], players[pending[j]].token)).data).toEqual(results[j].data);
          expect((await request("/world/boss-hunts/turn", {...turns[j], client_action_id: `closed-${pending[j]}`}, players[pending[j]].token)).status).toBe(409);
        }
      }
    }
    expect(finished.size).toBe(2);
    for (const i of [4, 5]) expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id=?").get(players[i].player_id) as any).state_json).homunculus_progress.cinder.xp).toBe(20);
    const raceWinners = db.query("SELECT player_id FROM global_boss_winners WHERE event_id = ? AND player_id IN (?, ?)").all(event.event_id, players[4].player_id, players[5].player_id) as {player_id: string}[];
    expect(raceWinners).toHaveLength(1);
    const fifth = players.findIndex(p => p.player_id === raceWinners[0].player_id);
    const sixth = fifth === 4 ? 5 : 4;
    expect((await request("/world/global-bosses", undefined, players[fifth].token)).data.events[0].reward_status).toBe("PAID");
    expect((await request("/world/global-bosses", undefined, players[sixth].token)).data.events[0].reward_status).toBeNull();
    for (const i of [0, 1, 2, 3, fifth]) {
      expect(wallet(i).essence - before[i].essence).toBe(({ common: 18, mythic: 36, rare: 54, epic: 72, legendary: 96 } as Record<string, number>)[event.tier]);
      const bonus = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/static/balance.json"), "utf8")).balance.solo_hunt_bonus_loot[event.tier];
      const expected = { ...grants };
      for (const id of ["core", "arcane_shard"]) {
        const roll = createHmac("sha256", env.WORLD_SECRET).update(`solo-hunt-bonus:${id}:${sessions[i]}`).digest().readUInt32BE(0) / 0x100000000;
        if (roll < bonus[id].chance) expected[id] = bonus[id].quantity;
        expect((wallet(i)[id] ?? 0) - (before[i][id] ?? 0)).toBe(expected[id] ?? 0);
      }
      const paid = db.query("SELECT reward_json FROM global_boss_winners WHERE event_id = ? AND player_id = ?").get(event.event_id, players[i].player_id) as any;
      expect(JSON.parse(paid.reward_json)).toEqual(expected);
      for (const [id, amount] of Object.entries(grants)) expect(wallet(i)[id] - (before[i][id] ?? 0)).toBe(Number(amount));
      expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE related_id = ? AND reason = 'GLOBAL_BOSS_REWARD'").get(sessions[i]) as any).n).toBe(1);
    }
    expect(wallet(sixth)).toEqual(before[sixth]);
    const paidWallets = players.map((_, i) => wallet(i));
    server.kill(); await server.exited; server = spawn(); await ready();
    a.token = (await request("/auth/dev_login", {name: "global_test_a"})).data.token;
    b.token = (await request("/auth/dev_login", {name: "global_test_b"})).data.token;
    expect((await request("/world/global-bosses", undefined, a.token)).data.events[0].reward_status).toBe("PAID");
    players[fifth].token = (await request("/auth/dev_login", {name: `global_test_${fifth}`})).data.token;
    const replay = terminalTurns.get(fifth)!;
    expect((await request("/world/boss-hunts/turn", replay.turn, players[fifth].token)).data).toEqual(replay.response);
    for (let i = 0; i < players.length; i++) expect(wallet(i)).toEqual(paidWallets[i]);
    expect((await request("/world/boss-hunts/start", {client_action_id: "completed", global_event_id: event.event_id}, b.token)).status).toBe(409);
    expect((await request("/world/global-bosses", undefined, a.token)).data.events[0].event_id).toBe(event.event_id);
    const completedAt = Date.now() - 13 * 3600000;
    db.query("UPDATE global_boss_events SET spawned_at = ?, completed_at = ? WHERE event_id = ?").run(completedAt - 1000, completedAt, event.event_id);
    const replacement = (await request("/world/global-bosses", undefined, a.token)).data.events[0];
    expect(replacement.event_id).not.toBe(event.event_id);
    expect(replacement.winner_count).toBe(0);
    expect(replacement.spawned_at).toBe(Math.ceil((completedAt + 12 * 3600000) / 900000) * 900000);
  } finally { server.kill(); await server.exited; db.close(); rmSync(directory, {recursive: true, force: true, maxRetries: 5, retryDelay: 100}); }
}, 240000);
