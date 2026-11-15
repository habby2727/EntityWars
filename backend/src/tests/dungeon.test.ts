import { expect, test } from "bun:test";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { createServer } from "node:net";
import { Database } from "bun:sqlite";
import { chooseDungeonNpcSpell, createDungeonCombatState, resolveDungeonTurn, dungeonLeaderboard, dungeonSeason, generateDungeonEnemy } from "../dungeon_combat";
import { buildTrustedCombatSetup } from "../solo_hunt_combat";
import { castPhysicalAnomaly, physicalAnomalyMultiplier, tickPhysicalAnomaly } from "../physical_anomaly";

const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", name), "utf8"));
const catalogs = { entities: read("entities.json").entities, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells };

test("all ten catalog anomalies cast in Dungeon combat", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const anomalies = catalogs.spells.filter((s: any) => s.effects.some((e: any) => e.kind === "physical_anomaly"));
  expect(anomalies).toHaveLength(10);
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] };
  for (const spell of anomalies) {
    const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: { learned_by_entity: { sulfur_01: [spell.id] } } };
    const selection = { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: [spell.id, "cinder_fist", "furnace_rush", "ash_temper"], mode: "attack" };
    const setup = buildTrustedCombatSetup(snapshot, selection, all, { independentLoadout: true });
    expect(setup.error).toBeUndefined();
    const combat = createDungeonCombatState(setup, enemy, all);
    expect(combat.error).toBeUndefined();
    const result = resolveDungeonTurn(combat, { turn: 1, spell_id: spell.id }, () => 0);
    expect(result.next_state.physical_anomaly.id).toBe(spell.id);
  }
});

test("physical anomalies affect Dungeon direct attacks and expire without stacking", () => {
  const anomaly = { id: "fixture_anomaly", name: "Fixture", type: "universal", eligible_types: ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"], category: "support", power_mult: 0, accuracy: 1, cooldown_turns: 4, effects: [{ kind: "physical_anomaly", target: "self", value: 1 }], favored_type: "sulfur", weakened_type: "sodium", outgoing_bonus: 0.15, outgoing_penalty: 0.15, duration_exchanges: 3 };
  const second = { ...anomaly, id: "fixture_second", favored_type: "gold" };
  const all = { ...catalogs, spells: [...catalogs.spells, anomaly, second], items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["fixture_anomaly", "fixture_second", "cinder_fist", "ash_temper"];
  const setup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: { learned_by_entity: { sulfur_01: ["fixture_anomaly", "fixture_second"] } } }, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: "cinder", spell_ids: ids, mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] };
  const state = createDungeonCombatState(setup, enemy, all);
  expect(state.error).toBeUndefined();
  const random = () => 0;
  const npcCaster = createDungeonCombatState(setup, { ...enemy, spell_ids: [anomaly.id, "cinder_fist", "ash_temper", "brimstone_crash"] }, all);
  const npcCast = resolveDungeonTurn(npcCaster, { turn: 1, spell_id: "ash_temper" }, random);
  expect(npcCast.events.some((event: any) => event.kind === "physical_anomaly_cast" && event.actor === "npc")).toBe(true);
  const activated = resolveDungeonTurn(state, { turn: 1, spell_id: anomaly.id }, random);
  expect(activated.next_state.physical_anomaly.remaining_exchanges).toBe(3);
  expect(resolveDungeonTurn(state, { turn: 1, spell_id: anomaly.id }, random)).toEqual(activated);
  const repeatState = structuredClone(activated.next_state); repeatState.player.cooldowns[anomaly.id] = 0;
  const repeated = resolveDungeonTurn(repeatState, { turn: 2, spell_id: anomaly.id }, random);
  expect(repeated.next_state.physical_anomaly.remaining_exchanges).toBe(3);
  expect(physicalAnomalyMultiplier(repeated.next_state.physical_anomaly, "sulfur")).toBe(1.15);
  const replaced = resolveDungeonTurn(activated.next_state, { turn: 2, spell_id: second.id }, random);
  expect([replaced.next_state.physical_anomaly.id, replaced.next_state.physical_anomaly.remaining_exchanges]).toEqual([second.id, 3]);
  const base = structuredClone(activated.next_state); base.physical_anomaly = null;
  const action = { turn: 2, spell_id: "cinder_fist" };
  const boosted = resolveDungeonTurn(activated.next_state, action, random);
  const normal = resolveDungeonTurn(base, action, random);
  const playerDamage = (r: any) => r.events.find((e: any) => e.kind === "damage" && e.actor === "player").amount;
  const npcDamage = (r: any) => r.events.find((e: any) => e.kind === "damage" && e.actor === "npc").amount;
  expect(playerDamage(boosted)).toBe(Math.round(playerDamage(normal) * 1.15));
  expect(npcDamage(boosted)).toBe(Math.round(npcDamage(normal) * 1.15));
  const weakened = structuredClone(activated.next_state); weakened.physical_anomaly = castPhysicalAnomaly({ ...anomaly, favored_type: "gold", weakened_type: "sulfur" }, 1);
  const reduced = resolveDungeonTurn(weakened, action, random);
  expect(playerDamage(reduced)).toBe(Math.round(playerDamage(normal) * 0.85));
  expect(npcDamage(reduced)).toBe(Math.round((activated.next_state.npc.atk - Math.trunc(activated.next_state.player.def * 0.5)) * 0.95 * 0.85));
  const neutral = structuredClone(activated.next_state); neutral.physical_anomaly = castPhysicalAnomaly(second, 1);
  const unchanged = resolveDungeonTurn(neutral, action, random);
  expect([playerDamage(unchanged), npcDamage(unchanged)]).toEqual([playerDamage(normal), npcDamage(normal)]);
  expect(resolveDungeonTurn(JSON.parse(JSON.stringify(activated.next_state)), action, random)).toEqual(boosted);
  const homBoosted = structuredClone(activated.next_state); homBoosted.player.hom_energy = 3;
  const homBase = structuredClone(homBoosted); homBase.physical_anomaly = null;
  const homAction = { ...action, hom_action: "attack" };
  expect(resolveDungeonTurn(homBoosted, homAction, random).events.find((e: any) => e.kind === "hom_attack" && e.actor === "player").amount).toBe(resolveDungeonTurn(homBase, homAction, random).events.find((e: any) => e.kind === "hom_attack" && e.actor === "player").amount);
  const poisonState = structuredClone(activated.next_state); poisonState.npc.status.poison = 2;
  const poisoned = resolveDungeonTurn(poisonState, action, random);
  expect(poisoned.events.find((e: any) => e.kind === "damage" && e.actor === "player").hp - poisoned.next_state.npc.hp).toBe(2);
  expect(boosted.next_state.physical_anomaly.remaining_exchanges).toBe(2);
  let next = boosted.next_state;
  for (let turn = 3; turn <= 4; turn++) next = resolveDungeonTurn(next, { turn, spell_id: "cinder_fist" }, random).next_state;
  expect(next.physical_anomaly).toBeNull();
  const value = castPhysicalAnomaly(anomaly, 1);
  expect([physicalAnomalyMultiplier(value, "sulfur"), physicalAnomalyMultiplier(value, "sodium"), physicalAnomalyMultiplier(value, "gold")]).toEqual([1.15, 0.85, 1]);
  const types = ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"];
  for (let i = 0; i < types.length; i++) {
    const entry = castPhysicalAnomaly({ ...anomaly, favored_type: types[i], weakened_type: types[(i + 1) % types.length] }, 1);
    expect(physicalAnomalyMultiplier(entry, types[i])).toBe(1.15);
    expect(physicalAnomalyMultiplier(entry, types[(i + 1) % types.length])).toBe(0.85);
    expect(physicalAnomalyMultiplier(entry, types[(i + 2) % types.length])).toBe(1);
  }
  expect(tickPhysicalAnomaly(value, 1)).toEqual(value);
  const replacement = castPhysicalAnomaly({ ...anomaly, id: "second", favored_type: "gold" }, 2);
  expect([replacement.id, replacement.remaining_exchanges]).toEqual(["second", 3]);
  expect(createDungeonCombatState(setup, enemy, { ...all, spells: [...catalogs.spells, { ...anomaly, weakened_type: "sulfur" }, second] }).error).toBe("UNSUPPORTED_MECHANIC");
});

test("pure dungeon combat resolves damage, effects, cooldowns, homunculus and terminal outcomes", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
  const setup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} }, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: "cinder", spell_ids: ids, mode: "attack" }, all);
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 104, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 5, spell_ids: ids };
  const state = createDungeonCombatState(setup, enemy, all);
  expect(state.error).toBeUndefined();
  expect(state.npc.max_hp).toBe(109);
  expect(state.player.atk).toBeGreaterThan(21);
  const original = structuredClone(state), random = () => 0;
  const action = { turn: 1, spell_id: "furnace_rush" };
  const result = resolveDungeonTurn(state, action, random);
  expect(state).toEqual(original);
  expect(resolveDungeonTurn(state, action, random)).toEqual(result);
  expect(result.next_state.npc.hp).toBeLessThan(state.npc.hp);
  expect(result.events.some((e: any) => e.kind === "spell" && e.actor === "npc")).toBe(true);
  expect(result.next_state.player.status.vuln).toBe(0.12);
  expect(resolveDungeonTurn(result.next_state, { turn: 2, spell_id: "furnace_rush" }, random).error).toBe("INVALID_DECISION");
  const strike = structuredClone(state); strike.player.hom_energy = 3;
  expect(resolveDungeonTurn(strike, { turn: 1, spell_id: "cinder_fist", hom_action: "attack" }, random).events.some((e: any) => e.kind === "hom_attack")).toBe(true);
  const nearWin = structuredClone(state); nearWin.npc.hp = 1;
  const win = resolveDungeonTurn(nearWin, { turn: 1, spell_id: "cinder_fist" }, random);
  expect(win.terminal_result).toBe("WIN");
  expect(resolveDungeonTurn(win.next_state, { turn: 2, spell_id: "cinder_fist" }, random).error).toBe("INVALID_DECISION");
  const nearLoss = structuredClone(state); nearLoss.player.hp = 1; nearLoss.npc.atk = 100;
  const loss = resolveDungeonTurn(nearLoss, { turn: 1, spell_id: "ash_temper" }, random);
  expect(loss.terminal_result).toBe("LOSS");
  expect(resolveDungeonTurn(loss.next_state, { turn: 2, spell_id: "cinder_fist" }, random).error).toBe("INVALID_DECISION");
  const fallback = structuredClone(state);
  for (const id of fallback.npc.spell_ids) fallback.npc.cooldowns[id] = 1;
  expect(resolveDungeonTurn(fallback, { turn: 1, spell_id: "cinder_fist" }, random).events.some((e: any) => e.kind === "spell" && e.actor === "npc" && e.spell_id === "basic_attack")).toBe(true);
  const poisonedIds = ["etching_fang", "caustic_mark", "bitter_haze", "rot_harvest"];
  const poisonSetup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} }, { entity_id: "vitriol_01", weapon_ids: [null, null], homunculus_id: "cinder", spell_ids: poisonedIds, mode: "attack" }, all);
  const poisonState = createDungeonCombatState(poisonSetup, enemy, all);
  const poisonResult = resolveDungeonTurn(poisonState, { turn: 1, spell_id: "caustic_mark" }, random);
  expect(poisonResult.next_state.npc.status.poison).toBe(1);
  expect(poisonResult.events.some((e: any) => e.kind === "poison" && e.target === "sulfur_01")).toBe(true);
  const sodiumIds = ["crystal_ram", "salt_barrier", "brine_mend", "bastion_return"];
  const sodiumSetup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} }, { entity_id: "sodium_01", weapon_ids: [null, null], homunculus_id: "cinder", spell_ids: sodiumIds, mode: "attack" }, all);
  expect(createDungeonCombatState(sodiumSetup, enemy, all).error).toBe("UNSUPPORTED_MECHANIC");
  const npcHom = structuredClone(state); npcHom.npc.hom_energy = 2;
  expect(resolveDungeonTurn(npcHom, { turn: 1, spell_id: "cinder_fist" }, random).events.some((e: any) => e.kind === "hom_attack" && e.actor === "npc")).toBe(true);
  const unsupported = { ...enemy, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "mercury_snare"] };
  expect(createDungeonCombatState(setup, unsupported, all).error).toBe("UNSUPPORTED_MECHANIC");
});

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
  let previous: { hp: number; attack: number; defense: number; entity_id?: string; homunculus_id?: string; spell_ids?: string[] } | undefined;
  for (let floor = 1; floor <= 25; floor++) {
    const next = generateDungeonEnemy(seed, "progression", floor, catalogs, undefined, previous);
    if (previous) for (const stat of ["hp", "attack", "defense"] as const) expect(next[stat]).toBeGreaterThan(previous[stat]);
    if (previous) {
      expect(next.entity_id).not.toBe(previous.entity_id);
      expect(next.homunculus_id).not.toBe(previous.homunculus_id);
      expect(next.spell_ids.some(id => !previous!.spell_ids!.includes(id))).toBe(true);
    }
    expect(next.spell_ids.some(id => { const spell = catalogs.spells.find(s => s.id === id); return spell.category === "attack" && spell.cooldown_turns === 0; })).toBe(true);
    previous = next;
  }
  expect(() => generateDungeonEnemy(seed, "run", 2, catalogs, undefined, { hp: 100000, attack: 1, defense: 1 })).toThrow("DUNGEON_DIFFICULTY_LIMIT");
  let longRun: { hp: number; attack: number; defense: number; entity_id?: string; homunculus_id?: string; spell_ids?: string[] } | undefined;
  for (let floor = 1; floor <= 1000; floor++) {
    const next = generateDungeonEnemy(seed, "thousand-floor-test", floor, catalogs, undefined, longRun);
    if (longRun) expect(next.hp > longRun.hp && next.attack > longRun.attack && next.defense > longRun.defense).toBe(true);
    longRun = next;
  }
  expect(() => generateDungeonEnemy(seed, "thousand-floor-test", 1001, catalogs, undefined, longRun)).toThrow();
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
    expect((await request("/dungeon/leaderboard?month=2026-01")).status).toBe(401);
    expect((await request("/dungeon/leaderboard?month=2026-13", undefined, a.token)).status).toBe(400);
    expect((await request("/dungeon/leaderboard?month=2026-01", undefined, a.token)).data.leaders).toEqual([]);
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
    const loadout = { run_id: started.data.run_id, client_action_id: "loadout", entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" };
    expect((await request("/dungeon/loadout", loadout, b.token)).status).toBe(404);
    expect((await request("/dungeon/loadout", { ...loadout, atk: 999 }, token)).status).toBe(400);
    expect((await request("/dungeon/loadout", { ...loadout, spell_ids: ["cinder_fist", "cinder_fist", "ash_temper", "brimstone_crash"] }, token)).status).toBe(400);
    const initialized = await request("/dungeon/loadout", loadout, token);
    expect(initialized.status).toBe(200);
    expect(initialized.data.combat_ready).toBe(true);
    expect((await request("/dungeon/loadout", loadout, token)).data).toEqual(initialized.data);
    expect((await request("/dungeon/loadout", { ...loadout, client_action_id: "other" }, token)).status).toBe(409);
    expect((await request("/dungeon/session", undefined, token)).data.session.loadout).toEqual(initialized.data.loadout);
    server.kill(); await server.exited; server = spawn(); await ready();
    token = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data.token;
    expect((await request("/dungeon/session", undefined, token)).data.session.loadout).toEqual(initialized.data.loadout);
    expect((await request("/dungeon/loadout", loadout, token)).data).toEqual(initialized.data);
    let revision = 1, previousNpc = initialized.data.combat_state.npc;
    expect((await request("/dungeon/next", { run_id: started.data.run_id, client_action_id: "premature-next", expected_revision: 1 }, token)).status).toBe(409);
    b.token = (await request("/auth/dev_login", { name: "dungeon_test_b" })).data.token;
    const firstTurn = { run_id: started.data.run_id, client_action_id: "real-turn", expected_revision: revision, decision: { turn: 1, spell_id: "cinder_fist" } };
    expect((await request("/dungeon/turn", firstTurn, b.token)).status).toBe(404);
    const [first, concurrentReplay] = await Promise.all([request("/dungeon/turn", firstTurn, token), request("/dungeon/turn", firstTurn, token)]);
    expect(first.status).toBe(200);
    expect(concurrentReplay.data).toEqual(first.data);
    expect(first.data.events.some((e: any) => e.kind === "spell" && e.actor === "npc")).toBe(true);
    expect((await request("/dungeon/turn", firstTurn, token)).data).toEqual(first.data);
    expect((await request("/dungeon/turn", { ...firstTurn, decision: { turn: 1, spell_id: "ash_temper" } }, token)).status).toBe(409);
    revision = first.data.combat_revision;
    for (let floor = 1; floor <= 3; floor++) {
      let won: any = null, action: any = null;
      for (let attempt = 0; attempt < 10 && !won; attempt++) {
        const saved = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(started.data.run_id) as any).combat_state_json);
        saved.npc.hp = 1; saved.player.hp = saved.player.max_hp;
        db.query("UPDATE dungeon_runs SET combat_state_json = ? WHERE run_id = ?").run(JSON.stringify(saved), started.data.run_id);
        action = { run_id: started.data.run_id, client_action_id: `win-${floor}-${attempt}`, expected_revision: revision, decision: { turn: saved.turn + 1, spell_id: "cinder_fist" } };
        const result = await request("/dungeon/turn", action, token);
        expect(result.status).toBe(200); revision = result.data.combat_revision;
        if (result.data.phase === "FLOOR_CLEARED") won = result.data;
      }
      expect(won?.cleared_floor).toBe(floor);
      expect((await request("/dungeon/turn", action, token)).data).toEqual(won);
      expect((await request(`/dungeon/leaderboard?month=${started.data.season}`, undefined, token)).data.player.cleared_floor).toBe(floor);
      if (floor < 3) {
        const next = { run_id: started.data.run_id, client_action_id: `next-${floor}`, expected_revision: revision };
        const advanced = await request("/dungeon/next", next, token);
        expect(advanced.status).toBe(200); revision = advanced.data.combat_revision;
        for (const key of ["max_hp", "atk", "def"]) expect(advanced.data.combat_state.npc[key]).toBeGreaterThan(previousNpc[key]);
        previousNpc = advanced.data.combat_state.npc;
        expect((await request("/dungeon/next", next, token)).data).toEqual(advanced.data);
        expect((await request("/dungeon/next", { ...next, client_action_id: `stale-next-${floor}` }, token)).status).toBe(409);
      }
    }
    server.kill(); await server.exited; server = spawn(); await ready();
    token = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data.token;
    expect((await request("/dungeon/session", undefined, token)).data.session.cleared_floor).toBe(3);
    expect((await request(`/dungeon/leaderboard?month=${started.data.season}`, undefined, token)).data.player.cleared_floor).toBe(3);
    const next = await request("/dungeon/next", { run_id: started.data.run_id, client_action_id: "next-after-three", expected_revision: revision }, token);
    expect(next.status).toBe(200); revision = next.data.combat_revision;
    let lost = false;
    for (let attempt = 0; attempt < 12 && !lost; attempt++) {
      const saved = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(started.data.run_id) as any).combat_state_json);
      saved.player.hp = 1; saved.npc.atk = 1000;
      db.query("UPDATE dungeon_runs SET combat_state_json = ? WHERE run_id = ?").run(JSON.stringify(saved), started.data.run_id);
      const result = await request("/dungeon/turn", { run_id: started.data.run_id, client_action_id: `loss-${attempt}`, expected_revision: revision, decision: { turn: saved.turn + 1, spell_id: "cinder_fist" } }, token);
      expect(result.status).toBe(200); revision = result.data.combat_revision; lost = result.data.status === "LOSS";
    }
    expect(lost).toBe(true);
    expect((await request(`/dungeon/leaderboard?month=${started.data.season}`, undefined, token)).data.player.cleared_floor).toBe(3);
    const another = await request("/dungeon/start", { client_action_id: "another-run" }, token);
    expect(another.status).toBe(200);
    const anotherLoadout = await request("/dungeon/loadout", { ...loadout, run_id: another.data.run_id, client_action_id: "another-loadout" }, token);
    expect(anotherLoadout.status).toBe(200);
    const persisted = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(another.data.run_id) as any).combat_state_json);
    const fixture = { id: "fixture_anomaly", name: "Fixture", type: "universal", eligible_types: ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"], category: "support", power_mult: 0, accuracy: 1, cooldown_turns: 4, effects: [{ kind: "physical_anomaly", target: "self", value: 1 }], favored_type: "sulfur", weakened_type: "sodium", outgoing_bonus: 0.15, outgoing_penalty: 0.15, duration_exchanges: 3 };
    persisted.spells.push(fixture); persisted.player.spell_ids[0] = fixture.id; persisted.player.hp = persisted.player.max_hp = 1000;
    db.query("UPDATE dungeon_runs SET combat_state_json = ? WHERE run_id = ?").run(JSON.stringify(persisted), another.data.run_id);
    const anomalyAction = { run_id: another.data.run_id, client_action_id: "fixture-anomaly", expected_revision: 1, decision: { turn: 1, spell_id: fixture.id } };
    const anomalyResponse = await request("/dungeon/turn", anomalyAction, token);
    expect(anomalyResponse.status).toBe(200);
    expect(anomalyResponse.data.combat_state.physical_anomaly.remaining_exchanges).toBe(3);
    expect(anomalyResponse.data.combat_state.rng_counter).toBeUndefined();
    server.kill(); await server.exited; server = spawn(); await ready();
    token = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data.token;
    expect((await request("/dungeon/session", undefined, token)).data.session.combat_state.physical_anomaly).toEqual(anomalyResponse.data.combat_state.physical_anomaly);
    expect((await request("/dungeon/turn", anomalyAction, token)).data).toEqual(anomalyResponse.data);
    const abandon = { client_action_id: "abandon", run_id: another.data.run_id };
    const closed = await request("/dungeon/abandon", abandon, token);
    expect(closed.data.status).toBe("ABANDONED");
    expect((await request("/dungeon/abandon", abandon, token)).data).toEqual(closed.data);
    expect((await request("/dungeon/session", undefined, token)).data.session).toBeNull();
  } finally {
    server.kill(); await server.exited; db.close();
    for (let i = 0; i < 10; i++) { try { rmSync(dir, { recursive: true, force: true }); break; } catch { await Bun.sleep(100); } }
  }
}, 120000);
