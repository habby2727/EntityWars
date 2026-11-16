import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";

test("common cycles, guardian roster and atomic hunt replacement", async () => {
  const port = await new Promise<number>(done => { const s = createServer().listen(0, "127.0.0.1", () => { const p = (s.address() as {port: number}).port; s.close(() => done(p)); }); });
  const dir = mkdtempSync(join(tmpdir(), "world-gate-"));
  const path = join(dir, "test.sqlite"), db = new Database(path);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const env = { ...process.env, DB_PATH: path, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0" };
  const spawn = () => Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  let server = spawn();
  let token = "";
  const req = async (url: string, body?: unknown) => { const response = await fetch(`http://127.0.0.1:${port}${url}`, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) }); return { status: response.status, data: await response.json() as any }; };
  const ready = async () => { for (let i = 0; i < 200; i++) { try { if ((await req("/health")).status === 200) return; } catch {} await Bun.sleep(100); } throw new Error("server did not start"); };
  try {
    await ready();
    const login = await req("/auth/dev_login", { name: "progression_test" }); token = login.data.token;
    const zone = "zone_chaos", base = "/world/boss-hunts";
    const progress = await req(`${base}/commons?zone_id=${zone}`);
    expect(progress.data.commons).toHaveLength(5);
    expect((await req(`${base}/commons?zone_id=zone_corrupted`)).data.commons).toHaveLength(6);
    expect((await req(`${base}/commons?zone_id=zone_crystal`)).data.commons).toHaveLength(6);
    expect((await req(`${base}/commons/restart`, { zone_id: zone, client_action_id: "early" })).status).toBe(409);
    const schedule = (await req(base)).data;
    const payload = { hunt_id: "hunt_common", rotation_key: schedule.rotation_key, zone_id: zone, appearance_id: progress.data.commons[0].appearance_id };
    const first = await req(`${base}/start`, { ...payload, client_action_id: "one" });
    expect(first.status).toBe(200);
    expect((await req(`${base}/start`, { ...payload, appearance_id: "invalid", client_action_id: "bad" })).status).toBe(400);
    expect((await req(`${base}/session`)).data.session.session_id).toBe(first.data.session_id);
    const nextPayload = { ...payload, appearance_id: progress.data.commons[1].appearance_id, client_action_id: "two" };
    const [next, retry] = await Promise.all([req(`${base}/start`, nextPayload), req(`${base}/start`, nextPayload)]);
    expect(next.status).toBe(200); expect(next.data.session_id).toBe(retry.data.session_id);
    expect(next.data.replaced_session_id).toBe(first.data.session_id);
    expect((await req(`${base}/session?session_id=${first.data.session_id}`)).data.session.status).toBe("FORFEIT");
    expect((await req(`${base}/turn`, { session_id: first.data.session_id, client_action_id: "late", expected_revision: 1, decision: {} })).status).toBe(409);
    const player = login.data.player_id;
    expect((await req(`${base}/commons?zone_id=zone_corrupted`)).data.commons.every((c: any) => !c.defeated)).toBe(true);
    const unavailable = schedule.bosses.find((b: any) => b.tier !== "common" && !b.available);
    if (unavailable) {
      const url = `${base}/guardians?zone_id=${zone}&hunt_id=${unavailable.id}`;
      const before = (await req(url)).data.guardians;
      expect((await req(`${base}/start`, { client_action_id: "guardian", hunt_id: unavailable.id, rotation_key: schedule.rotation_key, zone_id: zone, guardian_id: before[0].guardian_id })).status).toBe(200);
      expect((await req(`${base}/start`, { client_action_id: "parent", hunt_id: unavailable.id, rotation_key: schedule.rotation_key, zone_id: zone })).status).toBe(409);
      await req("/world/reroll", { client_action_id: "reroll", zone_id: zone });
      expect((await req(url)).data.guardians).toEqual(before);
    }
    const concurrent = await Promise.all([2, 3].map(i => req(`${base}/start`, { ...payload, appearance_id: progress.data.commons[i].appearance_id, client_action_id: `race-${i}` })));
    expect(concurrent.map(r => r.status)).toEqual([200, 200]);
    expect((db.query("SELECT COUNT(*) AS n FROM solo_hunt_sessions WHERE player_id = ? AND status = 'ACTIVE'").get(player) as { n: number }).n).toBe(1);
    const playerRow = db.query("SELECT state_json FROM players WHERE player_id = ?").get(player) as {state_json: string};
    const state = JSON.parse(playerRow.state_json);
    state.spell_progress = { learned_by_entity: { sulfur_01: ["steady_script"] }, active_research: null, equipped_by_mode: { attack: { sulfur_01: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] }, defense: {} } };
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), player);
    const combatStart = await req(`${base}/start`, { ...payload, appearance_id: progress.data.commons[4].appearance_id, client_action_id: "victory" });
    const sessionId = combatStart.data.session_id;
    const loadout = await req(`${base}/loadout`, { session_id: sessionId, client_action_id: "loadout", entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["steady_script", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" });
    expect(loadout.status).toBe(200);
    const combat = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) as {combat_state_json: string}).combat_state_json);
    combat.boss.hp = 1;
    db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(combat), sessionId);
    const turn = { session_id: sessionId, client_action_id: "victory-turn", expected_revision: 1, decision: { turn: 1, spell_id: "steady_script", target: "boss" } };
    const victory = await req(`${base}/turn`, turn);
    expect(victory.data.status).toBe("VERIFIED_WIN");
    const walletAfter = (db.query("SELECT state_json FROM players WHERE player_id = ?").get(player) as {state_json: string}).state_json;
    expect((await req(`${base}/turn`, turn)).data.status).toBe("VERIFIED_WIN");
    expect((db.query("SELECT state_json FROM players WHERE player_id = ?").get(player) as {state_json: string}).state_json).toBe(walletAfter);
    expect((await req(`${base}/commons?zone_id=${zone}`)).data.commons[4].defeated).toBe(true);
    expect((await req(`${base}/start`, { ...payload, appearance_id: progress.data.commons[4].appearance_id, client_action_id: "defeated" })).status).toBe(409);
    server.kill(); await server.exited; server = spawn(); await ready();
    token = (await req("/auth/dev_login", { name: "progression_test" })).data.token;
    expect((await req(`${base}/session?session_id=${sessionId}`)).data.session.status).toBe("VERIFIED_WIN");
    const recovered = (await req(`${base}/commons?zone_id=${zone}`)).data;
    expect(recovered.cycle).toBe(1); expect(recovered.commons[4].defeated).toBe(true);
    // Every remaining victory goes through loadout, combat and server settlement.
    const fight = async (zoneId: string, appearance: string, id: string, accelerated = true) => {
      const rotation = (await req(base)).data.rotation_key;
      const started = await req(`${base}/start`, { hunt_id: "hunt_common", rotation_key: rotation, zone_id: zoneId, appearance_id: appearance, client_action_id: `start-${id}` });
      expect(started.status).toBe(200);
      const sid = started.data.session_id;
      expect((await req(`${base}/loadout`, { session_id: sid, client_action_id: `load-${id}`, entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["steady_script", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" })).status).toBe(200);
      const battle = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sid) as {combat_state_json: string}).combat_state_json);
      if (accelerated) {
        battle.boss.hp = 1; // Speed up cycle coverage; settlement remains server-authoritative.
        db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(battle), sid);
      }
      let result: any;
      for (let i = 0; i < 80; i++) {
        const row = db.query("SELECT combat_state_json, combat_revision FROM solo_hunt_sessions WHERE session_id = ?").get(sid) as {combat_state_json: string; combat_revision: number};
        const current = JSON.parse(row.combat_state_json);
        if (current.player.inspiration_pending) {
          expect((await req(`${base}/inspiration`, { session_id: sid, client_action_id: `decline-${id}-${i}`, expected_revision: row.combat_revision, decision: { kind: "decline" } })).status).toBe(200);
          continue;
        }
        const spell = ["steady_script", "furnace_rush", "brimstone_crash"].find((spellId: string) => !(current.cooldowns[spellId] > 0));
        result = await req(`${base}/turn`, { session_id: sid, client_action_id: `turn-${id}-${i}`, expected_revision: row.combat_revision, decision: { turn: current.turn + 1, spell_id: spell, target: "boss" } });
        expect(result.status).toBe(200);
        if (result.data.status !== "ACTIVE") break;
      }
      expect(result.data.status).toBe("VERIFIED_WIN");
      expect(result.data.pve_reward).toBeDefined();
    };
    for (const [index, common] of recovered.commons.filter((c: any) => !c.defeated).entries()) await fight(zone, common.appearance_id, `chaos-${index}`);
    const corrupted = (await req(`${base}/commons?zone_id=zone_corrupted`)).data.commons[0];
    await fight("zone_corrupted", corrupted.appearance_id, "corrupted", false);
    expect((await req(`${base}/commons?zone_id=${zone}`)).data.complete).toBe(true);
    expect((await req(`${base}/commons?zone_id=zone_corrupted`)).data.commons[0].defeated).toBe(true);
    const reset = { zone_id: zone, client_action_id: "reset" };
    expect((await req(`${base}/commons/restart`, reset)).data.cycle).toBe(2);
    expect((await req(`${base}/commons/restart`, reset)).data.cycle).toBe(2);
    expect((await req(`${base}/commons?zone_id=${zone}`)).data.commons.every((c: any) => !c.defeated)).toBe(true);
    expect((await req(`${base}/commons?zone_id=zone_corrupted`)).data.commons[0].defeated).toBe(true);
  } finally { server.kill(); await server.exited; db.close(); rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }); }
}, 120000);
