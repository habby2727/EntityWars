import { expect, test } from "bun:test";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { createServer } from "node:net";
import { Database } from "bun:sqlite";
import { chooseDungeonNpcSpell, dungeonLeaderboard, dungeonSeason, generateDungeonEnemy } from "../dungeon_combat";

const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", name), "utf8"));
const catalogs = { entities: read("entities.json").entities, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells };

test("dungeon enemy generation is deterministic, bounded and catalog-based", () => {
  const seed = new Uint8Array(32).fill(7);
  const before = structuredClone(catalogs);
  for (const floor of [1, 2, 3, 1000]) {
    const enemy = generateDungeonEnemy(seed, "isolated-run", floor, catalogs);
    expect(generateDungeonEnemy(seed, "isolated-run", floor, catalogs)).toEqual(enemy);
    expect(new Set(enemy.spell_ids).size).toBe(4);
    expect(enemy.spell_ids.some(id => ["hybrid", "universal"].includes(catalogs.spells.find(s => s.id === id).type))).toBe(true);
    expect(enemy.hp).toBeLessThanOrEqual(100000);
    expect(enemy.homunculus_level).toBeLessThanOrEqual(10);
  }
  expect(catalogs).toEqual(before);
  expect(() => generateDungeonEnemy(seed, "run", 0, catalogs)).toThrow();
  expect(() => generateDungeonEnemy(seed, "run", 1, catalogs, { hp: 2, attack: 0, defense: 0 })).toThrow();
});

test("dungeon storage enforces one active run and one monthly best", () => {
  const db = new Database(":memory:");
  try {
    db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite/0006_dungeon.sql"), "utf8"));
    const insert = db.query("INSERT INTO dungeon_runs (run_id,player_id,season,status,started_at,expires_at,player_snapshot_json) VALUES (?,?,?,'ACTIVE',1,100,'{}')");
    insert.run("run1", "player", "2026-01");
    expect(() => insert.run("run2", "player", "2026-01")).toThrow();
    db.query("UPDATE dungeon_runs SET status='LOSS' WHERE run_id='run1'").run();
    insert.run("run2", "player", "2026-02");
    db.query("INSERT INTO dungeon_monthly_best VALUES ('2026-01','player',3,20,5,'run1')").run();
    expect(() => db.query("INSERT INTO dungeon_monthly_best VALUES ('2026-01','player',4,19,6,'run1')").run()).toThrow();
  } finally { db.close(); }
});

test("monthly leaderboard ranks scores, turns and achievement time within UTC season", () => {
  const db = new Database(":memory:");
  try {
    db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
    db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite/0006_dungeon.sql"), "utf8"));
    const player = db.query("INSERT INTO players VALUES (?, ?)");
    const best = db.query("INSERT INTO dungeon_monthly_best VALUES (?, ?, ?, ?, ?, ?)");
    for (const [id, floor, turns, time] of [["a", 5, 20, 12], ["b", 5, 19, 13], ["c", 5, 19, 10], ["d", 4, 1, 1]] as const) {
      player.run(id, `Player ${id}`);
      best.run("2026-01", id, floor, turns, time, `run-${id}`);
    }
    best.run("2026-02", "a", 10, 12, 20, "run-other");
    const result = dungeonLeaderboard(db, "2026-01", "a");
    expect(result.leaders.map((row: any) => row.player_id)).toEqual(["c", "b", "a", "d"]);
    expect((result.player as any).rank).toBe(3);
    expect((result.player as any).display_name).toBe("Player a");
    expect(dungeonLeaderboard(db, "2026-02", "b").player).toBeNull();
    expect(dungeonSeason(Date.UTC(2026, 0, 31, 23, 59))).toBe("2026-01");
    expect(dungeonSeason(Date.UTC(2026, 1, 1))).toBe("2026-02");
    expect(() => dungeonLeaderboard(db, "2026-13", "a")).toThrow();
  } finally { db.close(); }
});

test("dungeon AI respects cooldowns and recognizes poison combinations", () => {
  const ids = ["etching_fang", "caustic_mark", "bitter_haze", "rot_harvest"];
  const npc = { type: "vitriol", hp: 100, max_hp: 100, status: {} };
  const target = { status: {} };
  expect(chooseDungeonNpcSpell(1, ids, catalogs.spells, {}, npc, target, 0)).toBe("etching_fang");
  expect(chooseDungeonNpcSpell(9, ids, catalogs.spells, {}, npc, { status: { poison: 2 } }, 0)).toBe("rot_harvest");
  expect(chooseDungeonNpcSpell(9, ids, catalogs.spells, { rot_harvest: 2 }, npc, { status: { poison: 2 } }, 0)).not.toBe("rot_harvest");
  expect(() => chooseDungeonNpcSpell(9, ids, catalogs.spells, Object.fromEntries(ids.map(id => [id, 1])), npc, target, 0)).toThrow("NO_AVAILABLE_DUNGEON_SPELL");
});

test("authenticated dungeon sessions recover, isolate owners and replay atomically", async () => {
  const port = await new Promise<number>(done => { const socket = createServer().listen(0, "127.0.0.1", () => { const p = (socket.address() as { port: number }).port; socket.close(() => done(p)); }); });
  const dir = mkdtempSync(join(tmpdir(), "entitywars-dungeon-")), dbPath = join(dir, "test.sqlite"), db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0" };
  const spawn = () => Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  let server = spawn();
  const request = async (path: string, body?: unknown, token?: string) => { const r = await fetch(`http://127.0.0.1:${port}${path}`, { method: body === undefined ? "GET" : "POST", headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) }); return { status: r.status, data: await r.json() as any }; };
  const ready = async () => { for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) return; } catch {} await Bun.sleep(100); } throw new Error("Server not ready"); };
  try {
    await ready();
    const a = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data;
    const b = (await request("/auth/dev_login", { name: "dungeon_test_b" })).data;
    expect((await request("/dungeon/start", { client_action_id: "start" })).status).toBe(401);
    expect((await request("/dungeon/start", { client_action_id: "start" }, a.token)).status).toBe(409);
    const state = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(a.player_id) as any).state_json);
    state.lab.hqLevel = 4; state.lab.buildings.sync_nexus = { level: 1 };
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), a.player_id);
    const input = { client_action_id: "start" };
    const started = await request("/dungeon/start", input, a.token);
    expect(started.status).toBe(200);
    expect((await request("/dungeon/start", input, a.token)).data).toEqual(started.data);
    expect((await request("/dungeon/start", { client_action_id: "different" }, a.token)).status).toBe(409);
    expect((await request("/dungeon/session", undefined, b.token)).data.session).toBeNull();
    expect((await request("/dungeon/abandon", { client_action_id: "foreign", run_id: started.data.run_id }, b.token)).status).toBe(404);
    server.kill(); await server.exited; server = spawn(); await ready();
    let token = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data.token;
    b.token = (await request("/auth/dev_login", { name: "dungeon_test_b" })).data.token;
    expect((await request("/dungeon/session", undefined, token)).data.session).toEqual(started.data);
    const loadout = { run_id: started.data.run_id, client_action_id: "loadout", entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", null], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" };
    expect((await request("/dungeon/loadout", loadout, b.token)).status).toBe(404);
    expect((await request("/dungeon/loadout", { ...loadout, atk: 999 }, token)).status).toBe(400);
    expect((await request("/dungeon/loadout", { ...loadout, spell_ids: ["cinder_fist", "cinder_fist", "ash_temper", "brimstone_crash"] }, token)).status).toBe(400);
    const initialized = await request("/dungeon/loadout", loadout, token);
    expect(initialized.status).toBe(200);
    expect(initialized.data.combat_ready).toBe(false);
    expect((await request("/dungeon/loadout", loadout, token)).data).toEqual(initialized.data);
    expect((await request("/dungeon/loadout", { ...loadout, client_action_id: "other" }, token)).status).toBe(409);
    expect((await request("/dungeon/session", undefined, token)).data.session.loadout).toEqual(initialized.data.loadout);
    server.kill(); await server.exited; server = spawn(); await ready();
    token = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data.token;
    expect((await request("/dungeon/session", undefined, token)).data.session.loadout).toEqual(initialized.data.loadout);
    expect((await request("/dungeon/loadout", loadout, token)).data).toEqual(initialized.data);
    const abandon = { client_action_id: "abandon", run_id: started.data.run_id };
    const closed = await request("/dungeon/abandon", abandon, token);
    expect(closed.data.status).toBe("ABANDONED");
    expect((await request("/dungeon/abandon", abandon, token)).data).toEqual(closed.data);
    expect((await request("/dungeon/session", undefined, token)).data.session).toBeNull();
  } finally {
    server.kill(); await server.exited; db.close();
    for (let i = 0; i < 10; i++) { try { rmSync(dir, { recursive: true, force: true }); break; } catch { await Bun.sleep(100); } }
  }
}, 120000);
