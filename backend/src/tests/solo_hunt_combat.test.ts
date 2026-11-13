import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { buildTrustedCombatSetup, createCombatState, resolveCombatTurn, deterministicDraw } from "../solo_hunt_combat";

const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", name), "utf8"));
const catalogs = { entities: read("entities.json").entities, items: read("items.json").items, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells, bosses: read("static/solo_bosses.json").bosses, types: read("types.json") };
const snapshot = { player_id: "test", state_revision: 1, boss_id: "hunt_common", boss_entity_id: "sodium_01", spell_progress: {} };
const selection = { entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: null, spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" };
const rng = (_turn: number, draw: number) => draw % 2 === 0 ? 0 : 0.99;

test("validated setup and deterministic direct exchange", () => {
  const setup = buildTrustedCombatSetup(snapshot, selection, catalogs);
  expect(setup.error).toBeUndefined();
  const state = createCombatState(setup);
  expect([state.player.hp, state.player.atk, state.player.def]).toEqual([104, 21, 11]);
  expect([state.boss.hp, state.boss.atk, state.boss.def]).toEqual([112, 16, 16]);
  const before = structuredClone(state);
  const decision = { turn: 1, spell_id: "cinder_fist", target: "boss" };
  const result = resolveCombatTurn(state, decision, rng);
  expect(result.error).toBeUndefined();
  expect([result.next_state.player.hp, result.next_state.boss.hp]).toEqual([93, 101]);
  expect(result.next_state.turn).toBe(1);
  expect(resolveCombatTurn(state, decision, rng)).toEqual(result);
  const missed = resolveCombatTurn(state, decision, () => 0.99);
  expect([missed.next_state.player.hp, missed.next_state.boss.hp, missed.next_state.rng_counter]).toEqual([104, 112, 2]);
  expect(resolveCombatTurn({ ...state, terminal_result: "WIN" }, decision, rng)).toEqual({ error: "INVALID_DECISION" });
  expect(state).toEqual(before);
  expect(resolveCombatTurn(state, { ...decision, hp: 999 }, rng)).toEqual({ error: "INVALID_DECISION" });
  const proc = resolveCombatTurn(state, decision, () => 0);
  expect(proc.next_state.boss.status.atk_down ?? 0).toBe(0);
  expect(proc.events.some((e: any) => e.kind === "elemental_proc" && e.type === "sulfur")).toBe(true);
  const support = resolveCombatTurn(state, { ...decision, spell_id: "ash_temper" }, rng);
  expect(support.next_state.player.status.atk_boost).toBe(0.2);
  expect(support.next_state.cooldowns.ash_temper).toBe(2);
  const rush = resolveCombatTurn(state, { ...decision, spell_id: "furnace_rush" }, rng);
  expect(rush.next_state.player.hp).toBeLessThan(104);
  expect(rush.next_state.cooldowns.furnace_rush).toBe(2);
  expect(rush.next_state.player.status.vuln_pct ?? 0).toBe(0);
  const crash = resolveCombatTurn(state, { ...decision, spell_id: "brimstone_crash" }, rng);
  expect(crash.next_state.boss.status.atk_down ?? 0).toBe(0);
  expect(crash.next_state.player.hp).toBeGreaterThan(93);
  expect(resolveCombatTurn(support.next_state, { turn: 2, spell_id: "ash_temper", target: "boss" }, rng)).toEqual({ error: "INVALID_DECISION" });
});

test("trust, spell and deterministic RNG boundaries", () => {
  expect(createCombatState({ selection_authority: "SERVER_VALIDATED" })).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup(snapshot, { ...selection, state_revision: 50 }, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup(snapshot, { ...selection, spell_ids: ["steady_script", ...selection.spell_ids.slice(1)] }, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  const secret = new Uint8Array(32).fill(42);
  expect(deterministicDraw(secret, "session", 1, 0)).toBe(deterministicDraw(secret, "session", 1, 0));
});

test("six elemental procs resolve and update combat state", () => {
  for (const type of ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"]) {
    const state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
    state.player.type = type;
    state.spells.find((s: any) => s.id === "cinder_fist").type = type;
    state.boss.type = "unknown";
    state.player.hp = 90;
    const result = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0);
    expect(result.events.some((e: any) => e.kind === "elemental_proc" && e.type === type)).toBe(true);
    if (type === "mercury") expect(result.next_state.player.hp).toBe(90);
    if (type === "aether") expect(result.next_state.boss.status.vuln_pct).toBe(0.12);
    if (type === "vitriol") expect(result.next_state.boss.status.poison).toBe(1);
    if (type === "gold") expect(result.next_state.player.hp).toBeGreaterThan(79);
    if (type === "sodium") expect(result.next_state.player.hp).toBeGreaterThan(79);
    if (type === "sulfur") expect(result.next_state.player.hp).toBeGreaterThan(79);
  }
  const capped = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  capped.player.type = "gold";
  capped.spells.find((s: any) => s.id === "cinder_fist").type = "gold";
  capped.player.hp = 103;
  capped.boss.status.stun = 1;
  const result = resolveCombatTurn(capped, { turn: 1, spell_id: "cinder_fist", target: "boss" }, () => 0);
  expect(result.next_state.player.hp).toBe(104);
});

test("validated Mercury and Sodium defensive spells", () => {
  const fixture = (type: string, spells: string[]) => createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, entity_id: type + "_01", spell_ids: spells }, catalogs));
  const mercury = () => fixture("mercury", ["silver_needle", "false_signal", "liquid_decoy", "mercury_snare"]);
  const sodium = () => fixture("sodium", ["crystal_ram", "salt_barrier", "brine_mend", "bastion_return"]);
  const hit = (_turn: number, draw: number) => [0, 0, 0.99][draw % 3];
  const cast = (state: any, spell_id: string, random = hit) => resolveCombatTurn(state, { turn: 1, spell_id, target: "boss" }, random);
  const decoy = cast(mercury(), "liquid_decoy");
  expect(decoy.next_state.player.hp).toBe(86);
  expect(decoy.next_state.player.status.shield_pct ?? 0).toBe(0);
  const stronger = mercury(); stronger.player.status.shield_pct = 0.3;
  expect(cast(stronger, "liquid_decoy").next_state.player.hp).toBe(88);
  const barrier = cast(sodium(), "salt_barrier");
  expect(barrier.next_state.player.hp).toBe(106);
  const barrierProc = cast(sodium(), "salt_barrier", () => 0);
  expect(barrierProc.next_state.player.hp).toBe(106);
  expect(barrierProc.next_state.boss.status.shield_pct).toBe(0.12);
  const injured = sodium(); injured.player.hp = 50;
  const healed = cast(injured, "brine_mend");
  expect(healed.next_state.player.hp).toBe(53);
  const full = sodium(); full.boss.status.stun = 1;
  expect(cast(full, "brine_mend").next_state.player.hp).toBe(112);
  const reflected = cast(sodium(), "bastion_return");
  expect(reflected.events.find((e: any) => e.kind === "reflect").damage).toBe(1);
  expect(reflected.next_state.boss.hp).toBe(111);
  expect(reflected.next_state.player.status.reflect_pct ?? 0).toBe(0);
  const snare = cast(mercury(), "mercury_snare", () => 0);
  expect(snare.next_state.boss.status.hom_stun).toBe(1);
  const miss = cast(mercury(), "mercury_snare", () => 0.99);
  expect(miss.next_state.boss.hp).toBe(112);
  expect(miss.next_state.cooldowns.mercury_snare).toBe(3);
  expect(cast(sodium(), "bastion_return")).toEqual(reflected);
  for (const [state, id] of [[mercury(), "silver_needle"], [mercury(), "false_signal"], [sodium(), "crystal_ram"]] as const) {
    expect(cast(state, id, () => 0).next_state.boss.hp).toBeLessThan(112);
  }
});

test("native Aether and Vitriol spells, delayed neutralization and poison", () => {
  const aether = ["rift_touch", "null_stitch", "veil_rupture", "paradox_fold"];
  const vitriol = ["etching_fang", "caustic_mark", "bitter_haze", "rot_harvest"];
  const fixture = (type: string, spells: string[], bossId: string) => createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id: bossId }, { ...selection, entity_id: type + "_01", spell_ids: spells }, catalogs));
  const draws = (_turn: number, counter: number) => counter % 2 === 0 ? 0 : 0.99;
  for (const [type, spells, bossId] of [["aether", aether, "sulfur_01"], ["vitriol", vitriol, "sodium_01"]] as const) {
    for (const spell_id of spells) {
      const state = fixture(type, spells, bossId); state.boss.status.stun = 1;
      const before = structuredClone(state);
      const decision = { turn: 1, spell_id, target: "boss" };
      const result = resolveCombatTurn(state, decision, draws);
      expect(result.error).toBeUndefined();
      expect(result.next_state.cooldowns[spell_id]).toBe(state.spells.find((s: any) => s.id === spell_id).cooldown_turns);
      expect(resolveCombatTurn(state, decision, draws)).toEqual(result);
      expect(state).toEqual(before);
    }
  }
  const base = fixture("aether", aether, "sulfur_01"); base.boss.status.stun = 1;
  expect(resolveCombatTurn(base, { turn: 1, spell_id: "rift_touch", target: "boss" }, draws).next_state.boss.hp).toBe(88);
  const fold = resolveCombatTurn(base, { turn: 1, spell_id: "paradox_fold", target: "boss" }, draws).next_state;
  expect(fold.player.spell_neutralize_pending).toBe(0.5);
  expect(fold.player.spell_neutralize_active).toBe(0);
  fold.boss.status.stun = 1;
  const follow = resolveCombatTurn(fold, { turn: 2, spell_id: "rift_touch", target: "boss" }, () => 0.1).next_state;
  expect(follow.boss.hp).toBe(89);
  expect([follow.player.spell_neutralize_pending, follow.player.spell_neutralize_active]).toEqual([0, 0]);
  const plain = fixture("vitriol", vitriol, "sodium_01"); plain.boss.status.stun = 1;
  const poisoned = structuredClone(plain); poisoned.boss.status.poison = 2;
  const action = { turn: 1, spell_id: "rot_harvest", target: "boss" };
  expect(resolveCombatTurn(plain, action, draws).next_state.boss.hp).toBe(98);
  const harvest = resolveCombatTurn(poisoned, action, draws).next_state;
  expect([harvest.boss.hp, harvest.boss.status.poison]).toEqual([91, 1]);
  const marked = resolveCombatTurn(plain, { turn: 1, spell_id: "caustic_mark", target: "boss" }, draws).next_state;
  expect(marked.boss.status.poison).toBe(1);
});

test("reflection uses calculated damage even when the target has little HP", () => {
  const state = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  state.player.hp = 1;
  state.player.status.reflect_pct = 0.5;
  const result = resolveCombatTurn(state, { turn: 1, spell_id: "ash_temper", target: "boss" }, () => 0.1);
  expect([result.next_state.player.hp, result.next_state.boss.hp]).toEqual([0, 106]);
  expect(result.events.find((event: any) => event.kind === "reflect").damage).toBe(6);
});

test("Gold spells and received-hit tracking across exchanges", () => {
  const spells = ["aurum_edge", "gilded_reprisal", "debt_seal", "tribunal_strike"];
  const fixture = () => createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, entity_id: "gold_01", spell_ids: spells }, catalogs));
  const action = (turn: number, spell_id: string) => ({ turn, spell_id, target: "boss" });
  const state = fixture();
  expect([state.player.hp, state.player.atk, state.player.def]).toEqual([104, 18, 14]);
  for (const spell of spells) {
    const result = resolveCombatTurn(fixture(), action(1, spell), rng);
    expect(result.error).toBeUndefined();
    expect(result.next_state.cooldowns[spell]).toBe(state.spells.find((s: any) => s.id === spell).cooldown_turns);
  }
  const normal = resolveCombatTurn(fixture(), action(1, "tribunal_strike"), rng);
  expect(normal.next_state.boss.hp).toBe(99);
  const first = resolveCombatTurn(fixture(), action(1, "aurum_edge"), rng).next_state;
  expect(first.player.spell_hit_this_exchange).toBe(true);
  const boosted = resolveCombatTurn(first, action(2, "tribunal_strike"), rng);
  expect(boosted.events.find((e: any) => e.actor === "player" && e.kind === "damage").damage).toBe(16);
  expect(boosted).toEqual(resolveCombatTurn(first, action(2, "tribunal_strike"), rng));
  const outgoing = fixture(); outgoing.boss.status.stun = 1;
  const onlyHit = resolveCombatTurn(outgoing, action(1, "aurum_edge"), rng).next_state;
  expect(onlyHit.player.spell_hit_this_exchange).toBe(false);
  expect(resolveCombatTurn(onlyHit, action(2, "tribunal_strike"), rng).events[0].damage).toBe(13);
  const missed = resolveCombatTurn(fixture(), action(1, "aurum_edge"), () => 0.99).next_state;
  expect(missed.player.spell_hit_this_exchange).toBe(false);
  const blocked = fixture(); blocked.player.status.shield_pct = 1;
  expect(resolveCombatTurn(blocked, action(1, "aurum_edge"), rng).next_state.player.spell_hit_this_exchange).toBe(false);
  const reflection = fixture(); reflection.boss.status.reflect_pct = 0.5; reflection.boss.status.stun = 1;
  expect(resolveCombatTurn(reflection, action(1, "aurum_edge"), rng).next_state.player.spell_hit_this_exchange).toBe(true);
  const poison = fixture(); poison.player.status.poison = 1; poison.boss.status.stun = 1;
  const poisoned = resolveCombatTurn(poison, action(1, "aurum_edge"), rng).next_state;
  expect(poisoned.player.hp).toBe(102);
  expect(poisoned.player.spell_hit_this_exchange).toBe(true);
  const healing = fixture(); healing.player.hp = 103; healing.boss.status.stun = 1;
  expect(resolveCombatTurn(healing, action(1, "aurum_edge"), () => 0).next_state.player.hp).toBe(104);
});

test("researchable catalog spells resolve or fail closed", () => {
  const unsupported = new Set(["pierce_ward", "focus_next", "life_leech", "misalign_next", "tempo_shift", "hybrid_mark", "bonus_if_marked", "shield_by_order", "ward_dispel", "poison_on_reflect"]);
  const counts = { universal: 0, hybrid: 0 };
  for (const spell of catalogs.spells.filter((s: any) => ["universal", "hybrid"].includes(s.type))) {
    const entity = catalogs.entities.find((e: any) => spell.eligible_types.includes(e.type));
    const defaults = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id).slice(0, 4);
    const equipped = [spell.id, ...defaults.slice(1)];
    const progress = { learned_by_entity: { [entity.id]: [spell.id] }, equipped_by_mode: { attack: { [entity.id]: equipped } } };
    const setup = buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: entity.id, spell_ids: equipped }, catalogs);
    const state = createCombatState(setup);
    state.boss.status.stun = 1;
    const decision = { turn: 1, spell_id: spell.id, target: "boss" };
    const before = structuredClone(state);
    const result = resolveCombatTurn(state, decision, rng);
    if (spell.effects.some((effect: any) => unsupported.has(effect.kind))) expect(result).toEqual({ error: "UNSUPPORTED_MECHANIC" });
    else { expect(result.error).toBeUndefined(); counts[spell.type as "universal" | "hybrid"]++; }
    expect(state).toEqual(before);
  }
  console.log("Researchable spells supported:", JSON.stringify(counts));
});

test("universal is neutral and hybrid uses both catalog types", () => {
  const setupFor = (id: string) => {
    const ids = [id, "null_stitch", "veil_rupture", "paradox_fold"];
    const progress = { learned_by_entity: { aether_01: [id] }, equipped_by_mode: { attack: { aether_01: ids } } };
    return createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id: "sulfur_01", spell_progress: progress }, { ...selection, entity_id: "aether_01", spell_ids: ids }, catalogs));
  };
  const neutral = setupFor("steady_script"); neutral.boss.status.stun = 1;
  expect(resolveCombatTurn(neutral, { turn: 1, spell_id: "steady_script", target: "boss" }, rng).next_state.boss.hp).toBe(92);
  const hybrid = setupFor("void_etching"); hybrid.boss.status.stun = 1;
  expect(resolveCombatTurn(hybrid, { turn: 1, spell_id: "void_etching", target: "boss" }, rng).next_state.boss.hp).toBe(91);
});
