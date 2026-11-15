import { expect, test } from "bun:test";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { createServer } from "node:net";
import { createHmac } from "node:crypto";
import { Database } from "bun:sqlite";
import { chooseDungeonNpcSpell, createDungeonCombatState, resolveDungeonTurn, resolveDungeonInspiration, hydrateDungeonInspiration, dungeonLeaderboard, dungeonSeason, generateDungeonEnemy, dungeonPreviousBase } from "../dungeon_combat";
import { buildTrustedCombatSetup } from "../solo_hunt_combat";
import { castPhysicalAnomaly, physicalAnomalyMultiplier, tickPhysicalAnomaly } from "../physical_anomaly";

const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", name), "utf8"));
const catalogs = { entities: read("entities.json").entities, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells };

test("Dungeon elite traits activate once using existing status rules", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
  const setup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} }, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: ids, mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 10, entity_id: "sulfur_01", type: "sulfur", hp: 1000, attack: 30, defense: 10, homunculus_id: "cinder", homunculus_level: 3, spell_ids: ids };
  const fixture = (kind: string) => {
    const s = createDungeonCombatState(setup, enemy, all); s.elites_enabled = s.elite_traits_enabled = true; s.elite = { kind, label: kind.toUpperCase(), modifiers: ({ bulwark: { hp: 1.2, attack: 1, defense: 1.12 }, reaver: { hp: 1.12, attack: 1.1, defense: 1 }, alchemist: { hp: 1.15, attack: 1.05, defense: 1.05 } } as any)[kind] }; s.elite_trait_used = false;
    s.player.hp = s.player.max_hp = 1000; s.npc.hp = s.npc.max_hp = 1000; s.player.hom_id = s.npc.hom_id = null;
    for (const id of ids) if (id !== "cinder_fist") s.npc.cooldowns[id] = 9;
    const attack = s.spells.find((x: any) => x.id === "cinder_fist"); attack.accuracy = 1; attack.effects = []; attack.cooldown_turns = 0;
    return s;
  };
  for (const [kind, hp, status, value] of [["bulwark", 700, "shield", 0.15], ["reaver", 500, "atk_boost", 0.15]] as const) {
    const s = fixture(kind); s.npc.hp = hp;
    const result = resolveDungeonTurn(s, { turn: 1, spell_id: "ash_temper" }, () => 0.5);
    expect(result.next_state.npc.status[status]).toBe(value);
    expect(result.events).toContainEqual(expect.objectContaining({ kind: "status_applied", target: "npc", status, previous: 0, value, source: "elite" }));
    expect(result.events.filter((e: any) => e.kind === "elite_trait_triggered")).toHaveLength(1);
    const next = resolveDungeonTurn(result.next_state, { turn: 2, spell_id: "cinder_fist" }, () => 0.5);
    expect(next.events.some((e: any) => e.kind === "elite_trait_triggered")).toBe(false);
    if (kind === "reaver") expect(next.events).toContainEqual(expect.objectContaining({ kind: "status_consumed", target: "npc", status: "atk_boost", previous: 0.15 }));
    const strong = fixture(kind); strong.npc.hp = hp; strong.npc.status[status] = 0.4; strong.spells.find((s: any) => s.id === "cinder_fist").accuracy = 0;
    const unchanged = resolveDungeonTurn(strong, { turn: 1, spell_id: "ash_temper" }, () => 0.5);
    if (kind === "bulwark") expect(unchanged.next_state.npc.status[status]).toBe(0.4);
    expect(unchanged.events.some((e: any) => e.kind === "elite_trait_triggered")).toBe(false);
    const above = fixture(kind); above.npc.hp = hp + 1;
    expect(resolveDungeonTurn(above, { turn: 1, spell_id: "ash_temper" }, () => 0.5).events.some((e: any) => e.kind === "elite_trait_triggered")).toBe(false);
  }
  const alchemist = fixture("alchemist");
  const hit = resolveDungeonTurn(alchemist, { turn: 1, spell_id: "ash_temper" }, () => 0.5);
  expect(hit.next_state.player.status.vuln).toBe(0.12);
  expect(hit.events).toContainEqual(expect.objectContaining({ kind: "status_applied", target: "player", status: "vuln", value: 0.12, source: "elite" }));
  const missed = fixture("alchemist"); missed.spells.find((s: any) => s.id === "cinder_fist").accuracy = 0;
  expect(resolveDungeonTurn(missed, { turn: 1, spell_id: "ash_temper" }, () => 0.5).events.some((e: any) => e.kind === "elite_trait_triggered")).toBe(false);
  const disabled = fixture("alchemist"); delete disabled.elite_traits_enabled;
  expect(resolveDungeonTurn(disabled, { turn: 1, spell_id: "ash_temper" }, () => 0.5).events.some((e: any) => e.kind === "elite_trait_triggered")).toBe(false);
});

test("Dungeon personalities are deterministic and mapped to elites", () => {
  const seed = new Uint8Array(32).fill(4), seen = new Set<string>(), eliteSeen = new Set<string>();
  const mapping: Record<string, string> = { bulwark: "DEFENSIVE", reaver: "AGGRESSIVE", alchemist: "ALCHEMIST" };
  for (let i = 0; i < 100; i++) {
    const run = `personality-${i}`;
    const normal = generateDungeonEnemy(seed, run, 9, catalogs, undefined, undefined, true, true);
    expect(generateDungeonEnemy(seed, run, 9, catalogs, undefined, undefined, true, true)).toEqual(normal);
    seen.add(normal.npc_personality!);
    const elite = generateDungeonEnemy(seed, run, 10, catalogs, undefined, undefined, true, true);
    eliteSeen.add(elite.elite!.kind); expect(elite.npc_personality).toBe(mapping[elite.elite!.kind]);
    expect(generateDungeonEnemy(seed, run, 10, catalogs, undefined, undefined, true).npc_personality).toBeUndefined();
  }
  expect([...seen].sort()).toEqual(["AGGRESSIVE", "ALCHEMIST", "DEFENSIVE", "OPPORTUNIST"]);
  expect(eliteSeen.size).toBe(3);
});

test("Dungeon tactics choose legal attacks, defense and combinations", () => {
  const make = (id: string, category: string, power: number, effects: any[] = []) => ({ id, type: "sulfur", category, power_mult: power, accuracy: 1, cooldown_turns: 0, effects });
  const spells = [make("strike", "attack", 1), make("heal", "support", 0, [{ kind: "heal", target: "self", value: 20 }]), make("poison", "support", 0, [{ kind: "poison", target: "enemy", value: 2 }]), make("finish", "attack", 0.9, [{ kind: "bonus_if_poisoned", target: "enemy", value: 0.5 }])];
  const ids = spells.map(s => s.id), npc: any = { type: "sulfur", atk: 30, hp: 50, max_hp: 100, status: {} }, target: any = { type: "sulfur", hp: 100, max_hp: 100, def: 10, status: {} };
  const choose = (personality?: string, cooldowns: any = {}) => chooseDungeonNpcSpell(8, ids, spells, cooldowns, npc, target, 0, { personality });
  expect(choose("AGGRESSIVE", { poison: 1, heal: 1 })).toBe("strike");
  expect(choose("DEFENSIVE", { poison: 1 })).toBe("heal");
  target.status.poison = 2;
  expect(choose("OPPORTUNIST")).toBe("finish");
  delete target.status.poison;
  expect(choose("ALCHEMIST", { heal: 1 })).toBe("poison");
  target.hp = 1;
  expect(choose("DEFENSIVE")).toBe("strike");
  target.hp = 100; npc.hp = 100;
  expect(choose("DEFENSIVE", { poison: 1, strike: 1, finish: 1 })).toBe("heal");
  expect(choose("DEFENSIVE", { poison: 1 })).not.toBe("heal");
  expect(choose(undefined)).toBe(choose(undefined));
  expect(chooseDungeonNpcSpell(2, ids, spells, {}, npc, target, 0.26, { personality: "AGGRESSIVE" })).toBe("heal");
});

test("Dungeon hybrid tactical estimates use weighted effectiveness", () => {
  const attack = (id: string, type: string, power: number, extra: any = {}) => ({ id, type, eligible_types: ["sulfur"], category: "attack", power_mult: power, accuracy: 1, cooldown_turns: 0, effects: [], ...extra });
  const spells = [attack("hybrid", "hybrid", 1, { primary_type: "sulfur", secondary_type: "sodium" }), attack("plain", "universal", 1.1), attack("weak1", "sulfur", 0.1), attack("weak2", "sulfur", 0.2)];
  const npc = { type: "sulfur", atk: 100, hp: 100, max_hp: 100, status: {} }, target = { type: "gold", hp: 120, max_hp: 200, def: 0, status: {} }, types = { effectiveness: { sulfur: { gold: 2 }, sodium: { gold: 2 } } };
  expect(chooseDungeonNpcSpell(8, spells.map(s => s.id), spells, {}, npc, target, 0, { types, personality: "AGGRESSIVE" })).toBe("hybrid");
  expect(chooseDungeonNpcSpell(8, spells.map(s => s.id), spells, {}, npc, target, 0, { types })).toBe("plain");
});

test("Dungeon base migration removes prior homunculus bonuses exactly once", () => {
  const hom = catalogs.homunculi[0], floor = 10, level = 3, base = { hp: 100, attack: 50, defense: 30 };
  const old = { floor, npc: { hom_id: hom.id }, npc_base_stats: { hp: base.hp + (hom.buff_hp ?? 0) + level, attack: base.attack + (hom.buff_atk ?? 0), defense: base.defense + (hom.buff_def ?? 0) + 1 } };
  expect(dungeonPreviousBase(old, catalogs.homunculi)).toEqual(base);
  expect(dungeonPreviousBase({ ...old, npc_base_stats_version: 2, npc_base_stats: base }, catalogs.homunculi)).toEqual(base);
  expect(dungeonPreviousBase({ npc: old.npc }, catalogs.homunculi)).toBeNull();
});

test("Dungeon elites are deterministic, scheduled, bounded and do not compound", () => {
  const seed = new Uint8Array(32).fill(7), seen = new Set<string>();
  for (let i = 0; i < 100; i++) {
    const run = `elite-${i}`;
    for (const floor of [9, 10, 11, 19, 20, 21]) {
      const normal = generateDungeonEnemy(seed, run, floor, catalogs);
      const enemy = generateDungeonEnemy(seed, run, floor, catalogs, undefined, undefined, true);
      expect(generateDungeonEnemy(seed, run, floor, catalogs, undefined, undefined, true)).toEqual(enemy);
      expect(enemy.base_stats).toEqual({ hp: normal.hp, attack: normal.attack, defense: normal.defense });
      if (floor % 10) expect(enemy.elite).toBeNull();
      else {
        seen.add(enemy.elite!.kind);
        for (const key of ["hp", "attack", "defense"] as const) expect(enemy[key]).toBe(Math.min(99999, Math.round(enemy.base_stats![key] * enemy.elite!.modifiers[key])));
        const previous = { ...enemy.base_stats!, entity_id: enemy.entity_id, homunculus_id: enemy.homunculus_id, spell_ids: enemy.spell_ids };
        const after = generateDungeonEnemy(seed, run, floor + 1, catalogs, undefined, previous, true);
        const expected = generateDungeonEnemy(seed, run, floor + 1, catalogs, undefined, previous);
        expect(after.base_stats).toEqual({ hp: expected.hp, attack: expected.attack, defense: expected.defense });
      }
      expect(normal).not.toHaveProperty("elite");
    }
  }
  expect([...seen].sort()).toEqual(["alchemist", "bulwark", "reaver"]);
  const capped = generateDungeonEnemy(seed, "limit", 1000, catalogs, undefined, { hp: 99998, attack: 99998, defense: 99998 }, true);
  expect([capped.hp, capped.attack, capped.defense]).toEqual([99999, 99999, 99999]);
});

test("Dungeon direct hits consume damage statuses once for both fighters", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
  const setup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} }, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: ids, mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 1000, attack: 30, defense: 10, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ids };
  const initial = () => {
    const state = createDungeonCombatState(setup, enemy, all);
    const attack = state.spells.find((s: any) => s.id === "cinder_fist");
    Object.assign(attack, { type: "universal", eligible_types: ["sulfur"], accuracy: 1, power_mult: 1, cooldown_turns: 0, effects: [] });
    for (const fighter of [state.player, state.npc]) {
      fighter.atk = 30; fighter.def = 10; fighter.hp = fighter.max_hp = 1000; fighter.hom_id = null;
      fighter.status = { atk_boost: 0.5, atk_down: 0.1, vuln: 0.2 };
      for (const id of fighter.spell_ids) if (id !== attack.id) fighter.cooldowns[id] = 9;
    }
    return state;
  };
  const hit = resolveDungeonTurn(initial(), { turn: 1, spell_id: "cinder_fist" }, () => 0.5);
  for (const id of ["player", "npc"]) {
    const damage = hit.events.find((e: any) => e.kind === "damage" && e.actor === id);
    expect(damage.amount).toBe(44);
    expect(damage.target_status.vuln).toBeUndefined();
    for (const [status, previous] of [["atk_boost", 0.5], ["atk_down", 0.1], ["vuln", 0.2]])
      expect(hit.events.filter((e: any) => e.kind === "status_consumed" && e.target === id && e.status === status)).toEqual([{ kind: "status_consumed", target: id, status, previous, remaining: 0 }]);
  }
  const second = resolveDungeonTurn(hit.next_state, { turn: 2, spell_id: "cinder_fist" }, () => 0.5);
  expect(second.events.filter((e: any) => e.kind === "damage").map((e: any) => e.amount)).toEqual([25, 25]);
  expect(second.events.some((e: any) => e.kind === "status_consumed")).toBe(false);
  const missState = initial(); missState.spells.find((s: any) => s.id === "cinder_fist").accuracy = 0;
  const miss = resolveDungeonTurn(missState, { turn: 1, spell_id: "cinder_fist" }, () => 0.5);
  expect(miss.events.some((e: any) => e.kind === "status_consumed")).toBe(false);
  for (const id of ["player", "npc"]) expect(miss.next_state[id].status).toMatchObject({ atk_boost: 0.5, atk_down: 0.1, vuln: 0.2 });
  const reapplied = initial();
  reapplied.spells.find((s: any) => s.id === "cinder_fist").effects = [{ kind: "atk_boost", target: "self", value: 0.3 }, { kind: "vuln", target: "enemy", value: 0.3 }];
  const result = resolveDungeonTurn(reapplied, { turn: 1, spell_id: "cinder_fist" }, () => 0.5);
  for (const id of ["player", "npc"]) expect(result.next_state[id].status).toMatchObject({ atk_boost: 0.3, vuln: 0.3 });
});

test("Dungeon hybrid damage uses both elements for player and NPC", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
  const setup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} }, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: ids, mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 1000, attack: 30, defense: 10, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ids };
  const spell = structuredClone(all.spells.find((s: any) => s.type === "hybrid" && s.category === "attack" && s.eligible_types.includes("sulfur")));
  spell.effects = []; spell.power_mult = 1; spell.accuracy = 1;
  for (const [primary, secondary] of [[2, 2], [0.5, 1]]) {
    const state = createDungeonCombatState(setup, enemy, all);
    state.player.atk = state.npc.atk = 30; state.player.def = state.npc.def = 10;
    state.player.hp = state.player.max_hp = state.npc.hp = state.npc.max_hp = 1000;
    state.player.hom_id = state.npc.hom_id = null;
    state.player.spell_ids[0] = state.npc.spell_ids[0] = spell.id;
    state.spells.push(spell);
    for (const id of state.npc.spell_ids.slice(1)) state.npc.cooldowns[id] = 9;
    state.types.effectiveness[spell.primary_type].sulfur = primary;
    state.types.effectiveness[spell.secondary_type].sulfur = secondary;
    const result = resolveDungeonTurn(state, { turn: 1, spell_id: spell.id }, () => 0.5);
    const damage = result.events.filter((event: any) => event.kind === "damage");
    const expected = Math.round(25 * Math.max(0.8, Math.min(1.25, Math.pow(primary > 1 ? 1.25 : 0.8, 0.65) * Math.pow(secondary > 1 ? 1.25 : 1, 0.35))));
    expect(damage.find((event: any) => event.actor === "player").amount).toBe(expected);
    expect(damage.find((event: any) => event.actor === "npc").amount).toBe(expected);
  }
});

test("all eight real Dungeon weapons are validated and defenses do not leak across switches", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ids };
  const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {}, item_progress: Object.fromEntries(all.items.filter((item: any) => item.slot === "build").map((item: any) => [item.id, { level: 10 }])) };
  const select = (weapons: any[]) => ({ entity_id: "sulfur_01", weapon_ids: weapons, homunculus_id: null, spell_ids: ids, mode: "attack" });
  for (const item of all.items.filter((entry: any) => entry.slot === "build")) {
    const setup = buildTrustedCombatSetup(snapshot, select([item.id, null]), all, { independentLoadout: true });
    expect(setup.error).toBeUndefined();
    const state = createDungeonCombatState(setup, enemy, all);
    expect(state.error).toBeUndefined();
    expect(state.item_id).toBe(item.id);
    expect(resolveDungeonTurn(state, { turn: 1, spell_id: "cinder_fist" }, () => 0).error).toBeUndefined();
  }
  const wind = createDungeonCombatState(buildTrustedCombatSetup(snapshot, select(["wind_amulet", null]), all, { independentLoadout: true }), enemy, all);
  const evasion = resolveDungeonTurn(wind, { turn: 1, spell_id: "ash_temper" }, () => 0);
  expect(evasion.events.some((event: any) => event.kind === "evade" && event.actor === "player")).toBe(true);
  const mirror = createDungeonCombatState(buildTrustedCombatSetup(snapshot, select(["mirror_sigel", "bismuth_talisman"]), all, { independentLoadout: true }), enemy, all);
  const armed = resolveDungeonTurn(mirror, { turn: 1, spell_id: "ash_temper" }, () => 0.99);
  expect(armed.next_state.weapon_defenses.shield).toBeGreaterThan(0);
  expect(armed.next_state.weapon_defenses.reflect).toBeGreaterThan(0);
  const reflectState = structuredClone(armed.next_state);
  for (const id of reflectState.npc.spell_ids) if (id !== "cinder_fist") reflectState.npc.cooldowns[id] = 9;
  const reflected = resolveDungeonTurn(reflectState, { turn: 2, spell_id: "cinder_fist" }, () => 0.5);
  expect(reflected.events.some((event: any) => event.kind === "reflect" && event.actor === "player" && event.amount > 0)).toBe(true);
  const switched = resolveDungeonTurn(armed.next_state, { turn: 2, switch_slot: 2 }, () => 0.99);
  expect(switched.next_state.weapon_defenses.shield).toBeUndefined();
  expect(switched.next_state.weapon_defenses.reflect).toBeUndefined();
  const forged = structuredClone(snapshot);
  forged.item_progress.bismuth_talisman = { level: 10, specialization: "defensive", traits: [{ id: "guard_flat", points: 2 }, { id: "ward_pct", points: 2 }, { id: "reflect_pct", points: 1 }], fusion: { donor_id: "aether_knot" } };
  const forgedSetup = buildTrustedCombatSetup(forged, select(["bismuth_talisman", null]), all, { independentLoadout: true });
  const forgedState = createDungeonCombatState(forgedSetup, enemy, all);
  expect(forgedState.error).toBeUndefined();
  expect(forgedState.item_effects.ward_pct).toBeGreaterThan(0);
  expect(forgedState.item_effects.ignore_reflect_chance).toBeGreaterThan(0);
});

test("Dungeon Inspiration offers valid temporary spells and resolves without a turn", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["etching_fang", "caustic_mark", "bitter_haze", "rot_harvest"];
  const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} };
  const setup = buildTrustedCombatSetup(snapshot, { entity_id: "vitriol_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: ids, mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] };
  const state = createDungeonCombatState(setup, enemy, all);
  const older = structuredClone(state);
  delete older.inspiration_catalog; delete older.inspiration_catalog_version;
  for (const fighter of [older.player, older.npc]) { delete fighter.inspiration; delete fighter.original_spell_ids; }
  expect(hydrateDungeonInspiration(older, all.spells)).toBe(true);
  expect(older.inspiration_catalog_version).toBe(2);
  expect(older.player.original_spell_ids).toEqual(ids);
  expect(older.inspiration_catalog.player.some((s: any) => s.id === "toxic_smog")).toBe(true);
  expect(state.inspiration_catalog.player.some((s: any) => s.id === "toxic_smog")).toBe(true);
  expect(state.inspiration_catalog.player.some((s: any) => s.id === "septic_echo")).toBe(true);
  state.player.inspiration = 2;
  const earned = resolveDungeonTurn(state, { turn: 1, spell_id: "caustic_mark" }, () => 0);
  expect(earned.next_state.player.inspiration_pending).toBe(true);
  expect(new Set(earned.next_state.player.inspiration_offers).size).toBe(3);
  expect(resolveDungeonTurn(earned.next_state, { turn: 2, spell_id: "etching_fang" }, () => 0)).toEqual({ error: "INVALID_DECISION" });
  const offer = earned.next_state.player.inspiration_offers[0];
  const chosen = resolveDungeonInspiration(earned.next_state, { kind: "choose", spell_id: offer }, () => 0);
  expect(chosen.next_state.turn).toBe(1);
  expect(chosen.next_state.player.spell_ids[0]).toBe(offer);
  expect(resolveDungeonInspiration(chosen.next_state, { kind: "decline" }, () => 0)).toEqual({ error: "INVALID_DECISION" });
  expect(resolveDungeonTurn(chosen.next_state, { turn: 2, spell_id: offer }, () => 0).error).toBeUndefined();
  const declined = resolveDungeonInspiration(earned.next_state, { kind: "decline" }, () => 0);
  expect(declined.next_state.player.spell_ids).toEqual(ids);
  expect(declined.next_state.rng_counter).toBe(earned.next_state.rng_counter);
  const winning = structuredClone(chosen.next_state); winning.npc.hp = 1;
  const won = resolveDungeonTurn(winning, { turn: 2, spell_id: "rot_harvest" }, () => 0);
  expect(won.terminal_result).toBe("WIN");
  expect(won.next_state.player.spell_ids).toEqual(ids);
  expect(won.next_state.player.temporary_spell_id).toBeNull();
  expect(won.next_state.spells.some((s: any) => s.id === offer && !winning.npc.spell_ids.includes(offer))).toBe(false);
  const losing = structuredClone(chosen.next_state); losing.player.hp = 1; losing.npc.atk = 1000;
  for (const id of losing.npc.spell_ids) if (id !== "cinder_fist") losing.npc.cooldowns[id] = 9;
  const lost = resolveDungeonTurn(losing, { turn: 2, spell_id: "bitter_haze" }, () => 0);
  expect(lost.terminal_result).toBe("LOSS");
  expect(lost.next_state.player.spell_ids).toEqual(ids);
});

test("two supported real weapons switch without stacking and consume a turn", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
  const setup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", item_progress: { bismuth_talisman: { level: 5 }, vitriol_vial: { level: 5 } }, spell_progress: {} }, { entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "vitriol_vial"], homunculus_id: null, spell_ids: ids, mode: "attack" }, all, { independentLoadout: true });
  expect(setup.error).toBeUndefined();
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ids };
  const state = createDungeonCombatState(setup, enemy, all);
  expect(state.error).toBeUndefined();
  expect(state.item_id).toBe("bismuth_talisman");
  const switched = resolveDungeonTurn(state, { turn: 1, switch_slot: 2 }, () => 0);
  expect(switched.next_state.item_id).toBe("vitriol_vial");
  expect(switched.next_state.active_weapon_slot).toBe(2);
  expect(switched.next_state.player.atk).toBe(state.player.atk - Math.trunc(state.item_effects.power_flat ?? 0) + Math.trunc(switched.next_state.item_effects.power_flat ?? 0));
  expect(switched.events.some((e: any) => e.kind === "switch" && e.slot === 2)).toBe(true);
  expect(switched.events.some((e: any) => e.kind === "spell" && e.actor === "npc")).toBe(true);
  expect(resolveDungeonTurn(state, { turn: 1, switch_slot: 2 }, () => 0)).toEqual(switched);
  expect(resolveDungeonTurn(state, { turn: 1, switch_slot: 2, spell_id: ids[0] }, () => 0).error).toBe("INVALID_DECISION");
  expect(state.active_weapon_slot).toBe(1);
  const nextFloor = createDungeonCombatState(setup, { ...enemy, floor: 2 }, all, switched.next_state.active_weapon_slot);
  expect(nextFloor.active_weapon_slot).toBe(2);
  expect(nextFloor.item_id).toBe("vitriol_vial");
  expect(nextFloor.player.atk).toBe(switched.next_state.player.atk);
});

test("generated advanced floors select legal two-step combinations deterministically", () => {
  const seed = new Uint8Array(32).fill(7);
  for (let floor = 8; floor <= 16; floor++) {
    const enemy = generateDungeonEnemy(seed, "combo-test", floor, catalogs);
    expect(generateDungeonEnemy(seed, "combo-test", floor, catalogs)).toEqual(enemy);
    expect(new Set(enemy.spell_ids).size).toBe(4);
    const spells = enemy.spell_ids.map((id: string) => catalogs.spells.find((s: any) => s.id === id));
    expect(spells.every((s: any) => s.type === enemy.type || s.eligible_types?.includes(enemy.type))).toBe(true);
    expect(spells.some((s: any) => s.category === "attack" && s.cooldown_turns === 0)).toBe(true);
    const has = (kind: string, target?: string) => spells.some((s: any) => s.effects.some((e: any) => e.kind === kind && (!target || e.target === target)));
    if (enemy.type !== "mercury") expect((has("poison", "enemy") && has("bonus_if_poisoned")) || (has("shield", "self") && has("ward_convert")) || (has("vuln", "enemy") && spells.some((s: any) => s.category === "attack" && s.power_mult >= 0.9))).toBe(true);
  }
});

test("NPC executes poison then Pyrolytic Fuse as an authoritative two-turn combo", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const setup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} }, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 8, entity_id: "vitriol_01", type: "vitriol", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["etching_fang", "caustic_mark", "pyrolytic_fuse", "bitter_haze"] };
  const initial = createDungeonCombatState(setup, enemy, all); initial.player.hp = initial.player.max_hp = 1000;
  const first = resolveDungeonTurn(initial, { turn: 1, spell_id: "ash_temper" }, () => 0);
  expect(first.events.find((e: any) => e.kind === "spell" && e.actor === "npc").spell_id).toBe("caustic_mark");
  expect(first.next_state.player.status.poison).toBe(1);
  const second = resolveDungeonTurn(first.next_state, { turn: 2, spell_id: "cinder_fist" }, () => 0);
  expect(second.events.find((e: any) => e.kind === "spell" && e.actor === "npc").spell_id).toBe("pyrolytic_fuse");
  expect(second.events.find((e: any) => e.kind === "combo_trigger")).toMatchObject({ actor: "npc", target: "player", source_spell_id: "pyrolytic_fuse", prerequisite: "poison" });
  expect(second.events.find((e: any) => e.kind === "combo_trigger").actual_bonus_damage).toBeGreaterThan(0);
  expect(resolveDungeonTurn(first.next_state, { turn: 2, spell_id: "cinder_fist" }, () => 0)).toEqual(second);
});

test("all twenty strategic catalog spells resolve in Dungeon", () => {
  const ids = ["septic_echo", "void_purge", "paradox_ledger", "sovereign_hack", "signal_jam", "echo_ambush", "crystal_dividend", "null_quarantine", "gilded_lien", "auric_retort", "caustic_quarantine", "osmotic_rebound", "catalytic_mirror", "toxic_extraction", "pyrolytic_fuse", "scorched_antidote", "overclock_drain", "reactor_feedback", "ashen_patent", "debt_bomb"];
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] };
  for (const id of ids) {
    const spell = catalogs.spells.find((s: any) => s.id === id);
    const entity = catalogs.entities.find((e: any) => e.type === spell.primary_type);
    const native = catalogs.spells.find((s: any) => s.type === spell.primary_type && s.effects.length === 0).id;
    const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: { learned_by_entity: { [entity.id]: [id, "steady_script", "ward_glyph"] } } };
    const selected = { entity_id: entity.id, weapon_ids: [null, null], homunculus_id: null, spell_ids: [id, native, "steady_script", "ward_glyph"], mode: "attack" };
    const setup = buildTrustedCombatSetup(snapshot, selected, all, { independentLoadout: true });
    expect(setup.error).toBeUndefined();
    const combat = createDungeonCombatState(setup, enemy, all);
    expect(combat.error).toBeUndefined();
    const result = resolveDungeonTurn(combat, { turn: 1, spell_id: id }, () => 0);
    expect(result.error).toBeUndefined();
    expect(result.events.some((e: any) => e.kind === "spell" && e.actor === "player" && e.spell_id === id && e.hit)).toBe(true);
  }
});

test("Dungeon delayed damage, trap, ward conversion and healing suppression affect combat", () => {
  const make = (id: string, kind: string, value: number, attack: boolean) => ({ id, name: id, type: "universal", eligible_types: ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"], category: attack ? "attack" : "support", power_mult: attack ? 1 : 0, accuracy: 1, cooldown_turns: 1, effects: [{ kind, target: kind === "counter_trap" ? "self" : "enemy", value }] });
  const spells = [make("d_delay", "delayed_damage", 0.5, true), make("d_ward", "ward_convert", 1, true), make("d_trap", "counter_trap", 0.5, false), make("d_suppress", "heal_suppression", 0.5, false)];
  const heal = { ...make("d_heal", "heal", 20, false), effects: [{ kind: "heal", target: "self", value: 20 }] };
  const all = { ...catalogs, spells: [...catalogs.spells, ...spells, heal], items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const setup = buildTrustedCombatSetup({ player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: { learned_by_entity: { sulfur_01: spells.map(s => s.id) } } }, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: spells.map(s => s.id), mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] };
  const initial = () => { const state = createDungeonCombatState(setup, enemy, all); state.player.hp = state.player.max_hp = 1000; return state; };
  const delayed = resolveDungeonTurn(initial(), { turn: 1, spell_id: "d_delay" }, () => 0);
  const queued = delayed.events.find((e: any) => e.kind === "delayed_damage_queued");
  expect(queued.amount).toBeGreaterThan(0);
  const resumed = JSON.parse(JSON.stringify(delayed.next_state));
  const tick = resolveDungeonTurn(resumed, { turn: 2, spell_id: "d_trap" }, () => 0);
  expect(tick.events.filter((e: any) => e.kind === "delayed_damage")).toHaveLength(1);
  expect(tick.events.find((e: any) => e.kind === "delayed_damage").amount).toBe(queued.amount);
  expect(resolveDungeonTurn(JSON.parse(JSON.stringify(delayed.next_state)), { turn: 2, spell_id: "d_trap" }, () => 0)).toEqual(tick);
  const armed = resolveDungeonTurn(initial(), { turn: 1, spell_id: "d_trap" }, () => 0);
  expect(armed.events.some((e: any) => e.kind === "counter_trap_triggered")).toBe(false);
  const retaliation = resolveDungeonTurn(armed.next_state, { turn: 2, spell_id: "d_suppress" }, () => 0);
  expect(retaliation.events.filter((e: any) => e.kind === "counter_trap_triggered")).toHaveLength(1);
  const ward = initial(); ward.player.status.shield = 0.5;
  const converted = resolveDungeonTurn(ward, { turn: 1, spell_id: "d_ward" }, () => 0);
  expect(converted.events.find((e: any) => e.kind === "ward_convert").amount).toBe(Math.floor(ward.npc.max_hp * 0.2));
  expect(resolveDungeonTurn(initial(), { turn: 1, spell_id: "d_ward" }, () => 0).events.some((e: any) => e.kind === "ward_convert")).toBe(false);
  const healed = createDungeonCombatState(setup, { ...enemy, spell_ids: ["d_heal", "furnace_rush", "ash_temper", "brimstone_crash"] }, all); healed.npc.hp -= 50;
  for (const id of ["furnace_rush", "ash_temper", "brimstone_crash"]) healed.npc.cooldowns[id] = 5;
  const suppressed = resolveDungeonTurn(healed, { turn: 1, spell_id: "d_suppress" }, () => 0);
  expect(suppressed.next_state.npc.hp).toBe(healed.npc.hp + 10);
  expect(suppressed.next_state.npc.strategic_heal_suppression.expires_turn).toBe(3);
  const second = resolveDungeonTurn(suppressed.next_state, { turn: 2, spell_id: "d_delay" }, () => 0);
  const third = resolveDungeonTurn(second.next_state, { turn: 3, spell_id: "d_ward" }, () => 0);
  expect(third.next_state.npc.strategic_heal_suppression).toBeUndefined();
  expect(third.events.filter((e: any) => e.kind === "heal_suppression_expired")).toHaveLength(1);
  const invalid = initial(); invalid.spells.find((s: any) => s.id === "d_trap").effects[0].value = 0.6;
  const original = structuredClone(invalid);
  expect(resolveDungeonTurn(invalid, { turn: 1, spell_id: "d_trap" }, () => 0)).toEqual({ error: "UNSUPPORTED_MECHANIC" });
  expect(invalid).toEqual(original);
});

test("Dungeon transfers debuffs and steals bounded buffs", () => {
  const fixture = (id: string, kind: string, value: number) => ({ id, name: id, type: "universal", eligible_types: ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"], category: "support", power_mult: 0, accuracy: 1, cooldown_turns: 4, effects: [{ kind, target: "enemy", value }] });
  const transfer = fixture("transfer_fixture", "debuff_transfer", 1), steal = fixture("steal_fixture", "buff_steal", 0.5);
  const all = { ...catalogs, spells: [...catalogs.spells, transfer, steal], items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: { learned_by_entity: { sulfur_01: [transfer.id, steal.id] } } };
  const setup = buildTrustedCombatSetup(snapshot, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: [transfer.id, steal.id, "cinder_fist", "ash_temper"], mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] };
  const state = createDungeonCombatState(setup, enemy, all);
  state.player.status.poison = 2;
  const result = resolveDungeonTurn(state, { turn: 1, spell_id: transfer.id }, () => 0);
  expect(result.events.find((e: any) => e.kind === "debuff_transfer")).toMatchObject({ source: "player", target: "npc", status: "poison", value: 2 });
  const state2 = createDungeonCombatState(setup, enemy, all);
  state2.npc.status.atk_boost = 0.8;
  const result2 = resolveDungeonTurn(state2, { turn: 1, spell_id: steal.id }, () => 0);
  expect(result2.events.find((e: any) => e.kind === "buff_steal")).toMatchObject({ source: "npc", target: "player", status: "atk_boost", value: 0.2 });
  const empty = createDungeonCombatState(setup, enemy, all);
  expect(resolveDungeonTurn(empty, { turn: 1, spell_id: transfer.id }, () => 0).events.some((e: any) => e.kind === "debuff_transfer")).toBe(false);
});

test("Dungeon jams an eligible spell and siphons bounded homunculus energy", () => {
  const fixture = (id: string, kind: string, value: number) => ({ id, name: id, type: "universal", eligible_types: ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"], category: "support", power_mult: 0, accuracy: 1, cooldown_turns: 4, effects: [{ kind, target: "enemy", value }] });
  const jam = fixture("jam_fixture", "cooldown_jam", 1), siphon = fixture("siphon_fixture", "hom_energy_siphon", 2);
  const all = { ...catalogs, spells: [...catalogs.spells, jam, siphon], items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: { learned_by_entity: { sulfur_01: [jam.id, siphon.id] } } };
  const setup = buildTrustedCombatSetup(snapshot, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: "cinder", spell_ids: [jam.id, siphon.id, "cinder_fist", "ash_temper"], mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 500, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] };
  const state = createDungeonCombatState(setup, enemy, all);
  const jammed = resolveDungeonTurn(state, { turn: 1, spell_id: jam.id }, () => 0);
  expect(jammed.events.find((e: any) => e.kind === "cooldown_jam")).toMatchObject({ actor: "player", target: "npc", value: 1 });
  const energy = createDungeonCombatState(setup, enemy, all);
  energy.player.hom_energy = 5; energy.npc.hom_energy = 2;
  const stolen = resolveDungeonTurn(energy, { turn: 1, spell_id: siphon.id }, () => 0);
  expect(stolen.events.find((e: any) => e.kind === "hom_energy_siphon")).toMatchObject({ amount: 1, actor_energy: 6, target_energy: 1 });
});

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
  expect(result.events).toContainEqual({ kind: "status_consumed", target: "player", status: "vuln", previous: 0.12, remaining: 0 });
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
  const sodiumState = createDungeonCombatState(sodiumSetup, enemy, all);
  expect(sodiumState.error).toBeUndefined();
  for (const id of sodiumState.npc.spell_ids) if (id !== "cinder_fist") sodiumState.npc.cooldowns[id] = 9;
  const reflection = resolveDungeonTurn(sodiumState, { turn: 1, spell_id: "bastion_return" }, () => 0.5);
  expect(reflection.events.some((event: any) => event.kind === "reflect" && event.actor === "player" && event.amount > 0)).toBe(true);
  const npcHom = structuredClone(state); npcHom.npc.hom_energy = 2;
  expect(resolveDungeonTurn(npcHom, { turn: 1, spell_id: "cinder_fist" }, random).events.some((e: any) => e.kind === "hom_attack" && e.actor === "npc")).toBe(true);
  const unsupported = { ...enemy, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "mercury_snare"] };
  expect(createDungeonCombatState(setup, unsupported, all).error).toBe("UNTRUSTED_SETUP");
});

test("every catalog spell can be offered and cast as temporary Dungeon Inspiration", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  expect(all.spells.length).toBe(94);
  const types = ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"];
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 1000, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] };
  for (const spell of all.spells) {
    const type = types.find(t => spell.type === t || (["universal", "hybrid"].includes(spell.type) && spell.eligible_types?.includes(t)))!;
    const ids = all.spells.filter((s: any) => s.type === type).slice(0, 4).map((s: any) => s.id);
    const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} };
    const setup = buildTrustedCombatSetup(snapshot, { entity_id: `${type}_01`, weapon_ids: [null, null], homunculus_id: null, spell_ids: ids, mode: "attack" }, all, { independentLoadout: true });
    const state = createDungeonCombatState(setup, enemy, all);
    expect(state.error).toBeUndefined();
    if (!ids.includes(spell.id)) {
      const options = state.inspiration_catalog.player.map((s: any) => s.id);
      expect(options).toContain(spell.id);
      state.player.inspiration = 3; state.player.inspiration_pending = true;
      state.player.inspiration_offers = [spell.id, ...options.filter((id: string) => id !== spell.id).slice(0, 2)];
      const choice = resolveDungeonInspiration(state, { kind: "choose", spell_id: spell.id }, () => 0);
      expect(choice.error).toBeUndefined();
      Object.assign(state, choice.next_state);
    }
    const result = resolveDungeonTurn(state, { turn: 1, spell_id: spell.id }, () => 0);
    expect(result.error).toBeUndefined();
    expect(result.events.some((event: any) => event.kind === "spell" && event.actor === "player" && event.spell_id === spell.id && event.hit)).toBe(true);
  }
});

test("Dungeon Inspiration effects change real combat state and consume the correct statuses", () => {
  const all = { ...catalogs, items: read("items.json").items, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
  const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
  const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} };
  const setup = buildTrustedCombatSetup(snapshot, { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: ids, mode: "attack" }, all, { independentLoadout: true });
  const enemy = { floor: 1, entity_id: "sulfur_01", type: "sulfur", hp: 1000, attack: 21, defense: 11, homunculus_id: "cinder", homunculus_level: 0, spell_ids: ids };
  const base = createDungeonCombatState(setup, enemy, all);
  const cast = (id: string, configure: (state: any) => void = () => {}) => {
    const state = structuredClone(base);
    const spell = all.spells.find((s: any) => s.id === id);
    state.player.spell_ids[0] = id; state.spells.push(spell);
    for (const npcId of state.npc.spell_ids) state.npc.cooldowns[npcId] = 9;
    configure(state);
    return resolveDungeonTurn(state, { turn: 1, spell_id: id }, () => 0);
  };
  const focus = cast("quiet_focus");
  expect(focus.next_state.player.status.focus_next).toBe(0.12);
  const missState = structuredClone(focus.next_state);
  const afterFocus = resolveDungeonTurn(missState, { turn: 2, spell_id: "brimstone_crash" }, () => 0.999);
  expect(afterFocus.next_state.player.status.focus_next).toBeUndefined();
  const cleanse = cast("clear_thread", s => { s.player.status.poison = 2; s.player.status.atk_down = 0.1; });
  expect(cleanse.next_state.player.status.poison).toBeUndefined();
  expect(cleanse.next_state.player.status.atk_down).toBe(0.1);
  const pierced = cast("needle_etch", s => { s.npc.status.shield = 0.5; });
  expect(pierced.events.find((e: any) => e.kind === "damage" && e.actor === "player").target_status.shield).toBeUndefined();
  const ordinary = cast("cinder_fist", s => { s.npc.status.shield = 0.5; });
  expect(pierced.events.find((e: any) => e.kind === "damage" && e.actor === "player").amount).toBeGreaterThan(ordinary.events.find((e: any) => e.kind === "damage" && e.actor === "player").amount);
  const leech = cast("echo_siphon", s => { s.player.hp = 30; });
  expect(leech.events.some((e: any) => e.kind === "heal" && e.actor === "player" && e.amount > 0)).toBe(true);
  const tempo = cast("salt_circuit");
  expect(tempo.next_state.npc.status.tempo_bonus).toBe(-2);
  expect(tempo.next_state.player.inspiration).toBe(1);
  const mark = cast("paradox_edict");
  expect(mark.next_state.npc.status.hybrid_mark).toEqual({ owner: "player", remaining: 2 });
  expect(mark.next_state.player.inspiration).toBe(1);
  const neutralize = cast("paradox_fold");
  expect(neutralize.next_state.player.spell_neutralize_pending).toBe(0.5);
  expect(neutralize.next_state.player.spell_neutralize_active).toBe(0);
  const stun = cast("mercury_snare", s => { s.npc.hom_energy = 2; });
  expect(stun.events.some((e: any) => e.kind === "status_consumed" && e.target === "npc" && e.status === "hom_stun")).toBe(true);
  expect(stun.events.some((e: any) => e.kind === "hom_attack" && e.actor === "npc")).toBe(false);
  expect(stun.next_state.player.inspiration).toBe(1);
  expect(cast("crooked_rune").next_state.player.inspiration).toBe(1);
  expect(cast("brimstone_crash").next_state.player.inspiration).toBe(1);
  expect(cast("caustic_mark").next_state.player.inspiration).toBe(1);
  expect(cast("caustic_mark", s => { s.npc.status.poison = 5; }).next_state.player.inspiration).toBe(0);
  expect(cast("brimstone_crash", s => { s.npc.status.atk_down = 0.9; }).next_state.player.inspiration).toBe(0);
  expect(cast("furnace_rush").next_state.player.inspiration).toBe(0);
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

test("Dungeon anomaly choice considers the proposed types and lethal attacks", () => {
  const ids = ["aurum_edge", "quicksilver_tempest", "toxic_smog", "ward_glyph"];
  const npc = { type: "gold", hp: 100, max_hp: 100, atk: 20, status: {} };
  const target = { type: "mercury", hp: 100, max_hp: 100, def: 5, status: {} };
  const bad = catalogs.spells.find((s: any) => s.id === "quicksilver_tempest");
  const selected = chooseDungeonNpcSpell(15, ids, catalogs.spells, {}, npc, target, 0, { anomaly: { id: "old", favored_type: "mercury", weakened_type: "sodium" } });
  expect(selected).not.toBe(bad.id);
  const lethal = chooseDungeonNpcSpell(15, ids, catalogs.spells, {}, npc, { ...target, hp: 1 }, 0, { anomaly: { id: "old", favored_type: "mercury", weakened_type: "sodium" } });
  expect(lethal).toBe("aurum_edge");
  const alreadyFavored = chooseDungeonNpcSpell(15, ids, catalogs.spells, {}, npc, target, 0, { anomaly: { id: "different", favored_type: "gold", weakened_type: "mercury" } });
  expect(["quicksilver_tempest", "toxic_smog"]).not.toContain(alreadyFavored);
});

test("floor 8 and 1000 change repeated NPC spell sets without breaking the selected pair", () => {
  const seed = new Uint8Array(32).fill(7);
  for (const floor of [8, 1000]) {
    const original = generateDungeonEnemy(seed, "same-spells", floor, catalogs);
    const previous = { hp: 0, attack: 0, defense: 0, spell_ids: [...original.spell_ids] };
    const varied = generateDungeonEnemy(seed, "same-spells", floor, catalogs, undefined, previous);
    expect(varied.spell_ids.some((id: string) => !previous.spell_ids.includes(id))).toBe(true);
    expect(varied.spell_ids.slice(0, 3)).toEqual(original.spell_ids.slice(0, 3));
    expect(new Set(varied.spell_ids).size).toBe(4);
    expect(generateDungeonEnemy(seed, "same-spells", floor, catalogs, undefined, previous)).toEqual(varied);
  }
});

test("local Dungeon preparation is guarded and supports a real authenticated run", async () => {
  const port = await new Promise<number>(done => { const socket = createServer().listen(0, "127.0.0.1", () => { const p = (socket.address() as { port: number }).port; socket.close(() => done(p)); }); });
  const dir = mkdtempSync(join(tmpdir(), "entitywars-dungeon-debug-")), dbPath = join(dir, "test.sqlite"), db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const secrets = { TOKEN_SIGNING_SECRET: "test-signing-secret-01234567890123456789", EXPERIMENT_SECRET: "test-experiment-secret-0123456789012345", TRADE_SECRET: "test-trade-secret-01234567890123456789", WORLD_SECRET: "test-world-secret-01234567890123456789" };
  const env = { ...process.env, ...secrets, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0", DEV_DOCKER_LOCAL_LOGIN: "1", DUNGEON_DEBUG_PREPARE: "1" };
  const spawn = (extra: Record<string, string> = {}) => Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env: { ...env, ...extra }, stdout: "ignore", stderr: "ignore" });
  let server = spawn();
  const request = async (path: string, body?: unknown, token?: string, origin?: string) => { const r = await fetch(`http://127.0.0.1:${port}${path}`, { method: body === undefined ? "GET" : "POST", headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}), ...(origin ? { origin } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) }); return { status: r.status, data: await r.json() as any }; };
  const ready = async () => { for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) return; } catch {} await Bun.sleep(100); } throw new Error("Server not ready"); };
  try {
    await ready();
    const normal = (await request("/auth/dev_login", { name: "normal_dungeon_player" })).data;
    const debug = (await request("/auth/dev_login", { name: "dungeon_debug_local" })).data;
    expect((await request("/debug/dungeons/prepare", {})).status).toBe(401);
    expect((await request("/debug/dungeons/prepare", {}, normal.token)).status).toBe(403);
    expect((await request("/debug/dungeons/prepare", {}, debug.token, "https://example.com")).status).toBe(404);
    expect((await request("/debug/dungeons/prepare", { floor: 1000 }, debug.token)).status).toBe(400);
    const prepared = await request("/debug/dungeons/prepare", {}, debug.token);
    expect(prepared.status).toBe(200);
    const state = prepared.data.updated_player_state;
    expect(state.lab.hqLevel).toBeGreaterThanOrEqual(4);
    expect(state.lab.buildings.sync_nexus.level).toBeGreaterThanOrEqual(1);
    expect(state.spell_progress.learned_by_entity.sulfur_01).toContain("nuclear_fallout");
    expect(state.spell_progress.learned_by_entity.sulfur_01).toContain("pyrolytic_fuse");
    expect(state.homunculus_progress.cinder.level).toBe(10);
    expect((await request("/debug/dungeons/prepare", {}, debug.token)).data.updated_player_state).toEqual(state);
    const started = await request("/dungeon/start", { client_action_id: "debug-start" }, debug.token);
    expect(started.status).toBe(200);
    const selected = { run_id: started.data.run_id, client_action_id: "debug-loadout", entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "vitriol_vial"], homunculus_id: "cinder", spell_ids: ["nuclear_fallout", "cinder_fist", "ash_temper", "brimstone_crash"], mode: "attack" };
    const initialized = await request("/dungeon/loadout", selected, debug.token);
    expect(initialized.status).toBe(200);
    expect(initialized.data.combat_ready).toBe(true);
    expect((await request("/debug/dungeons/prepare", {}, debug.token)).status).toBe(200);
    expect((await request("/dungeon/session", undefined, debug.token)).data.session.run_id).toBe(started.data.run_id);
    expect(initialized.data.combat_state.item_id).toBe("bismuth_talisman");
    const swap = { run_id: started.data.run_id, client_action_id: "debug-swap", expected_revision: 1, decision: { turn: 1, switch_slot: 2 } };
    const switched = await request("/dungeon/turn", swap, debug.token);
    expect(switched.status).toBe(200);
    expect(switched.data.combat_state.item_id).toBe("vitriol_vial");
    expect(switched.data.combat_state.active_weapon_slot).toBe(2);
    expect(switched.data.combat_state.player.atk).toBe(initialized.data.combat_state.player.atk - Math.trunc(initialized.data.combat_state.item_effects.power_flat ?? 0) + Math.trunc(switched.data.combat_state.item_effects.power_flat ?? 0));
    expect(switched.data.combat_state.turn).toBe(1);
    expect(switched.data.events.some((event: any) => event.kind === "spell" && event.actor === "npc")).toBe(true);
    expect((await request("/dungeon/turn", swap, debug.token)).data).toEqual(switched.data);
    expect((await request("/dungeon/session", undefined, debug.token)).data.session.combat_state.item_id).toBe("vitriol_vial");
    const turn = await request("/dungeon/turn", { run_id: started.data.run_id, client_action_id: "debug-turn", expected_revision: 2, decision: { turn: 2, spell_id: "nuclear_fallout" } }, debug.token);
    expect(turn.status).toBe(200);
    expect(turn.data.events.some((event: any) => event.kind === "physical_anomaly_cast" && event.actor === "player" && event.anomaly.id === "nuclear_fallout")).toBe(true);
    const fixture = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id=?").get(started.data.run_id) as any).combat_state_json);
    fixture.player.inspiration = 2; fixture.player.hp = fixture.player.max_hp = 1000; fixture.npc.hp = fixture.npc.max_hp = 1000; fixture.npc.status.atk_down = 0;
    fixture.spells.find((s: any) => s.id === "brimstone_crash").accuracy = 1;
    db.query("UPDATE dungeon_runs SET combat_state_json=? WHERE run_id=?").run(JSON.stringify(fixture), started.data.run_id);
    const earn = await request("/dungeon/turn", { run_id: started.data.run_id, client_action_id: "earn-inspiration", expected_revision: 3, decision: { turn: 3, spell_id: "brimstone_crash" } }, debug.token);
    expect(earn.status).toBe(200);
    expect(earn.data.combat_state.player.inspiration_pending).toBe(true);
    const offers = earn.data.combat_state.player.inspiration_offers;
    expect(new Set(offers).size).toBe(3);
    expect((await request("/dungeon/turn", { run_id: started.data.run_id, client_action_id: "blocked-turn", expected_revision: 4, decision: { turn: 4, spell_id: "cinder_fist" } }, debug.token)).status).toBe(400);
    const choice = { run_id: started.data.run_id, client_action_id: "choose-inspiration", expected_revision: 4, decision: { kind: "choose", spell_id: offers[0] } };
    expect((await request("/dungeon/inspiration", { ...choice, decision: { kind: "choose", spell_id: "forged" } }, debug.token)).status).toBe(400);
    expect((await request("/dungeon/inspiration", choice, normal.token)).status).toBe(404);
    const [chosen, duplicateChoice] = await Promise.all([request("/dungeon/inspiration", choice, debug.token), request("/dungeon/inspiration", choice, debug.token)]);
    expect(chosen.status).toBe(200);
    expect(duplicateChoice.data).toEqual(chosen.data);
    expect(chosen.data.combat_state.turn).toBe(3);
    expect(chosen.data.combat_state.player.spell_ids).toContain(offers[0]);
    expect((await request("/dungeon/inspiration", choice, debug.token)).data).toEqual(chosen.data);
    server.kill(); await server.exited; server = spawn(); await ready();
    const recovered = (await request("/auth/dev_login", { name: "dungeon_debug_local" })).data.token;
    expect((await request("/dungeon/session", undefined, recovered)).data.session.combat_state.player.spell_ids).toEqual(chosen.data.combat_state.player.spell_ids);
    expect((await request("/dungeon/inspiration", choice, recovered)).data).toEqual(chosen.data);
    const temporary = await request("/dungeon/turn", { run_id: started.data.run_id, client_action_id: "temporary-spell", expected_revision: 5, decision: { turn: 4, spell_id: offers[0] } }, recovered);
    expect(temporary.status).toBe(200);
    const ending = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id=?").get(started.data.run_id) as any).combat_state_json);
    const finisher = ending.player.spell_ids.find((id: string) => ending.spells.some((s: any) => s.id === id && s.category === "attack"));
    expect(finisher).toBeDefined();
    ending.spells.find((s: any) => s.id === finisher).accuracy = 1; ending.player.cooldowns[finisher] = 0;
    ending.player.hp = ending.player.max_hp = 1000; ending.npc.hp = 1; ending.npc.status = {};
    db.query("UPDATE dungeon_runs SET combat_state_json=? WHERE run_id=?").run(JSON.stringify(ending), started.data.run_id);
    const win = await request("/dungeon/turn", { run_id: started.data.run_id, client_action_id: "finish-inspiration-floor", expected_revision: 6, decision: { turn: 5, spell_id: finisher } }, recovered);
    expect(win.status).toBe(200);
    expect(win.data.phase).toBe("FLOOR_CLEARED");
    expect(win.data.combat_state.player.spell_ids).toEqual(selected.spell_ids);
    expect(win.data.combat_state.player.temporary_spell_id).toBeNull();
    expect((await request("/player/state", undefined, recovered)).data.updated_player_state.spell_progress).toEqual(state.spell_progress);
    server.kill(); await server.exited;
    server = spawn({ NODE_ENV: "production", BUN_ENV: "development" });
    await ready();
    expect((await request("/debug/dungeons/prepare", {}, debug.token)).status).toBe(404);
    server.kill(); await server.exited;
    server = spawn({ DUNGEON_DEBUG_PREPARE: "0", DEBUG_BYPASS: "1" });
    await ready();
    const bypass = await fetch(`http://127.0.0.1:${port}/debug/dungeons/prepare`, { method: "POST", headers: { "content-type": "application/json", "x-debug-bypass": "1", authorization: `Bearer ${debug.token}` }, body: "{}" });
    expect(bypass.status).toBe(404);
  } finally {
    server.kill(); await server.exited; db.close();
    for (let i = 0; i < 10; i++) { try { rmSync(dir, { recursive: true, force: true }); break; } catch { await Bun.sleep(100); } }
  }
}, 60000);

test("authenticated dungeon sessions recover, isolate owners and replay atomically", async () => {
  const port = await new Promise<number>(done => { const socket = createServer().listen(0, "127.0.0.1", () => { const p = (socket.address() as { port: number }).port; socket.close(() => done(p)); }); });
  const dir = mkdtempSync(join(tmpdir(), "entitywars-dungeon-")), dbPath = join(dir, "test.sqlite"), db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0", DUNGEON_ELITES_ENABLED: "0", DUNGEON_TACTICS_ENABLED: "0", DUNGEON_ELITE_TRAITS_ENABLED: "0", WORLD_SECRET: "dev_world_secret" };
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
    const legacy = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(started.data.run_id) as any).combat_state_json);
    delete legacy.elites_enabled; delete legacy.npc_base_stats; delete legacy.tactics_enabled;
    db.query("UPDATE dungeon_runs SET combat_state_json = ? WHERE run_id = ?").run(JSON.stringify(legacy), started.data.run_id);
    env.DUNGEON_ELITES_ENABLED = "1";
    env.DUNGEON_TACTICS_ENABLED = "1";
    env.DUNGEON_ELITE_TRAITS_ENABLED = "1";
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
        expect(advanced.data.combat_state.elite).toBeUndefined();
        expect(advanced.data.combat_state.npc_personality).toBeUndefined();
        expect(JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(started.data.run_id) as any).combat_state_json).elites_enabled).toBe(false);
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
    const delayedFixture = { id: "fixture_delay", name: "Delayed", type: "universal", eligible_types: fixture.eligible_types, category: "attack", power_mult: 1, accuracy: 1, cooldown_turns: 1, effects: [{ kind: "delayed_damage", target: "enemy", value: 0.5 }] };
    const delayedState = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(another.data.run_id) as any).combat_state_json);
    delayedState.spells.push(delayedFixture); delayedState.player.spell_ids[0] = delayedFixture.id; delayedState.npc.hp = delayedState.npc.max_hp = 1000;
    db.query("UPDATE dungeon_runs SET combat_state_json = ? WHERE run_id = ?").run(JSON.stringify(delayedState), another.data.run_id);
    const delayAction = { run_id: another.data.run_id, client_action_id: "fixture-delay", expected_revision: 2, decision: { turn: 2, spell_id: delayedFixture.id } };
    const delayResponse = await request("/dungeon/turn", delayAction, token);
    expect(delayResponse.status).toBe(200);
    expect(delayResponse.data.combat_state.strategic_delayed).toHaveLength(1);
    server.kill(); await server.exited; server = spawn(); await ready();
    token = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data.token;
    expect((await request("/dungeon/session", undefined, token)).data.session.combat_state.strategic_delayed).toEqual(delayResponse.data.combat_state.strategic_delayed);
    expect((await request("/dungeon/turn", delayAction, token)).data).toEqual(delayResponse.data);
    const tickAction = { run_id: another.data.run_id, client_action_id: "fixture-delay-tick", expected_revision: 3, decision: { turn: 3, spell_id: "furnace_rush" } };
    const tickResponse = await request("/dungeon/turn", tickAction, token);
    expect(tickResponse.status).toBe(200);
    expect(tickResponse.data.events.filter((e: any) => e.kind === "delayed_damage" && e.actor === "player")).toHaveLength(1);
    expect(tickResponse.data.combat_state.strategic_delayed.filter((entry: any) => entry.actor === "player")).toEqual([]);
    expect((await request("/dungeon/turn", tickAction, token)).data).toEqual(tickResponse.data);
    const comboState = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(another.data.run_id) as any).combat_state_json);
    const poisonSpell = structuredClone(catalogs.spells.find((s: any) => s.id === "caustic_mark")); poisonSpell.accuracy = 1;
    const comboSpell = structuredClone(catalogs.spells.find((s: any) => s.id === "pyrolytic_fuse")); comboSpell.accuracy = 1;
    comboState.player.type = "vitriol"; comboState.player.hp = comboState.player.max_hp = 1000;
    comboState.npc.hp = comboState.npc.max_hp = 1000; comboState.npc.status = {};
    comboState.player.spell_ids[0] = poisonSpell.id; comboState.player.spell_ids[1] = comboSpell.id;
    comboState.spells.push(poisonSpell, comboSpell);
    db.query("UPDATE dungeon_runs SET combat_state_json = ? WHERE run_id = ?").run(JSON.stringify(comboState), another.data.run_id);
    const poisonAction = { run_id: another.data.run_id, client_action_id: "fixture-poison", expected_revision: 4, decision: { turn: 4, spell_id: poisonSpell.id } };
    expect((await request("/dungeon/turn", poisonAction, token)).status).toBe(200);
    const comboAction = { run_id: another.data.run_id, client_action_id: "fixture-combo", expected_revision: 5, decision: { turn: 5, spell_id: comboSpell.id } };
    const comboResponse = await request("/dungeon/turn", comboAction, token);
    expect(comboResponse.status).toBe(200);
    expect(comboResponse.data.events.find((e: any) => e.kind === "combo_trigger")).toMatchObject({ actor: "player", target: "npc", source_spell_id: "pyrolytic_fuse", prerequisite: "poison" });
    expect(comboResponse.data.events.find((e: any) => e.kind === "combo_trigger").actual_bonus_damage).toBeGreaterThan(0);
    expect((await request("/dungeon/turn", comboAction, token)).data).toEqual(comboResponse.data);
    const abandon = { client_action_id: "abandon", run_id: another.data.run_id };
    const closed = await request("/dungeon/abandon", abandon, token);
    expect(closed.data.status).toBe("ABANDONED");
    expect((await request("/dungeon/abandon", abandon, token)).data).toEqual(closed.data);
    expect((await request("/dungeon/session", undefined, token)).data.session).toBeNull();
    const eliteRun = await request("/dungeon/start", { client_action_id: "elite-start" }, token);
    const eliteLoadout = await request("/dungeon/loadout", { ...loadout, run_id: eliteRun.data.run_id, client_action_id: "elite-loadout" }, token);
    expect(eliteLoadout.status).toBe(200);
    const savedElite = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(eliteRun.data.run_id) as any).combat_state_json);
    expect(savedElite.elites_enabled).toBe(true);
    expect(savedElite.tactics_enabled).toBe(true);
    expect(savedElite.elite_traits_enabled).toBe(true);
    savedElite.floor = 9; savedElite.terminal_result = "WIN";
    db.query("UPDATE dungeon_runs SET combat_state_json = ?, cleared_floor = 9 WHERE run_id = ?").run(JSON.stringify(savedElite), eliteRun.data.run_id);
    env.DUNGEON_ELITES_ENABLED = "0";
    env.DUNGEON_TACTICS_ENABLED = "0";
    env.DUNGEON_ELITE_TRAITS_ENABLED = "0";
    server.kill(); await server.exited; server = spawn(); await ready();
    token = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data.token;
    const eliteNext = { run_id: eliteRun.data.run_id, client_action_id: "elite-next", expected_revision: 1 };
    const eliteFloor = await request("/dungeon/next", eliteNext, token);
    expect(eliteFloor.status).toBe(200);
    expect(eliteFloor.data.combat_state.elite.label).toMatch(/^(BULWARK|REAVER|ALCHEMIST)$/);
    expect(eliteFloor.data.combat_state.elite_trait.used).toBe(false);
    expect(eliteFloor.data.combat_state.npc_personality).toBe(({ BULWARK: "DEFENSIVE", REAVER: "AGGRESSIVE", ALCHEMIST: "ALCHEMIST" } as any)[eliteFloor.data.combat_state.elite.label]);
    expect((await request("/dungeon/next", eliteNext, token)).data).toEqual(eliteFloor.data);
    server.kill(); await server.exited; server = spawn(); await ready();
    token = (await request("/auth/dev_login", { name: "dungeon_test_a" })).data.token;
    expect((await request("/dungeon/session", undefined, token)).data.session.combat_state.elite).toEqual(eliteFloor.data.combat_state.elite);
    expect((await request("/dungeon/session", undefined, token)).data.session.combat_state.elite_trait).toEqual(eliteFloor.data.combat_state.elite_trait);
    expect((await request("/dungeon/session", undefined, token)).data.session.combat_state.npc_personality).toBe(eliteFloor.data.combat_state.npc_personality);
    expect((await request("/dungeon/next", eliteNext, token)).data).toEqual(eliteFloor.data);
    const floorTen = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(eliteRun.data.run_id) as any).combat_state_json);
    const seed = createHmac("sha256", env.WORLD_SECRET).update("dungeon:" + eliteRun.data.run_id).digest();
    const expectedEleven = generateDungeonEnemy(seed, eliteRun.data.run_id, 11, catalogs, undefined, { ...floorTen.npc_base_stats, entity_id: floorTen.npc.id, homunculus_id: floorTen.npc.hom_id, spell_ids: floorTen.npc.spell_ids }, true);
    floorTen.terminal_result = "WIN";
    db.query("UPDATE dungeon_runs SET combat_state_json = ?, cleared_floor = 10 WHERE run_id = ?").run(JSON.stringify(floorTen), eliteRun.data.run_id);
    const floorEleven = await request("/dungeon/next", { run_id: eliteRun.data.run_id, client_action_id: "after-elite", expected_revision: 2 }, token);
    expect(floorEleven.status).toBe(200);
    expect(floorEleven.data.combat_state.elite).toBeUndefined();
    const hom = catalogs.homunculi.find((h: any) => h.id === expectedEleven.homunculus_id);
    expect(floorEleven.data.combat_state.npc.max_hp).toBe(expectedEleven.hp + (hom.buff_hp ?? 0) + expectedEleven.homunculus_level);
    expect(floorEleven.data.combat_state.npc.atk).toBe(expectedEleven.attack + (hom.buff_atk ?? 0) + Math.floor(expectedEleven.homunculus_level / 5));
    expect(floorEleven.data.combat_state.npc.def).toBe(expectedEleven.defense + (hom.buff_def ?? 0) + Math.floor(expectedEleven.homunculus_level / 3));
  } finally {
    server.kill(); await server.exited; db.close();
    for (let i = 0; i < 10; i++) { try { rmSync(dir, { recursive: true, force: true }); break; } catch { await Bun.sleep(100); } }
  }
}, 120000);
