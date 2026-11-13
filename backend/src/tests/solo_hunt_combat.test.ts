import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { buildTrustedCombatSetup, createCombatState, resolveCombatTurn, deterministicDraw } from "../solo_hunt_combat";

const read = (name: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", name), "utf8"));
const catalogs = { entities: read("entities.json").entities, items: read("items.json").items, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells, bosses: read("static/solo_bosses.json").bosses, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
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
  const mismatched = { ...selection, spell_ids: ["null_lattice", ...selection.spell_ids.slice(1)] };
  const progress = { learned_by_entity: { sulfur_01: ["null_lattice"] }, equipped_by_mode: { attack: { sulfur_01: mismatched.spell_ids } } };
  expect(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, mismatched, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  const equipped = createCombatState(buildTrustedCombatSetup(snapshot, selection, catalogs));
  expect(resolveCombatTurn(equipped, { turn: 1, spell_id: "steady_script", target: "boss" }, rng)).toEqual({ error: "INVALID_DECISION" });
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
  const unsupported = new Set<string>();
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
  expect(counts).toEqual({ universal: 10, hybrid: 30 });
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

test("catalog sweep includes all 64 equipped spells", () => {
  let passed = 0;
  for (const spell of catalogs.spells) {
    const entity = catalogs.entities.find((e: any) => spell.type === e.type || spell.eligible_types?.includes(e.type));
    const defaults = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
    const equipped = [spell.id, ...defaults.filter((id: string) => id !== spell.id).slice(0, 3)];
    const progress = { learned_by_entity: { [entity.id]: [spell.id] }, equipped_by_mode: { attack: { [entity.id]: equipped } } };
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: entity.id, spell_ids: equipped }, catalogs));
    state.boss.status.stun = 1;
    const result = resolveCombatTurn(state, { turn: 1, spell_id: spell.id, target: "boss" }, rng);
    expect(result.error).toBeUndefined();
    expect(result.next_state.turn).toBe(1);
    passed++;
  }
  expect(passed).toBe(64);
});

test("precision, shields, leech and initiative have observable effects", () => {
  const fixture = (id: string, entity = "sulfur_01") => {
    const ids = [id, ...catalogs.spells.filter((s: any) => s.type === catalogs.entities.find((e: any) => e.id === entity).type).map((s: any) => s.id).filter((x: string) => x !== id).slice(0, 3)];
    const progress = { learned_by_entity: { [entity]: [id] }, equipped_by_mode: { attack: { [entity]: ids } } };
    return createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: entity, spell_ids: ids }, catalogs));
  };
  const cast = (state: any, spell_id: string, random = rng) => resolveCombatTurn(state, { turn: state.turn + 1, spell_id, target: "boss" }, random);
  const pierce = fixture("needle_etch"); pierce.boss.status.shield_pct = 0.5; pierce.boss.status.stun = 1;
  expect(cast(pierce, "needle_etch").next_state.boss.hp).toBe(104);
  const dispel = fixture("quicksilver_solvent", "mercury_01"); dispel.boss.status.shield_pct = 0.5; dispel.boss.status.stun = 1;
  expect(cast(dispel, "quicksilver_solvent").next_state.boss.hp).toBe(106);
  const leech = fixture("echo_siphon"); leech.player.hp = 80; leech.boss.status.stun = 1;
  expect(cast(leech, "echo_siphon").next_state.player.hp).toBe(81);
  const overkill = fixture("echo_siphon"); overkill.player.hp = 80; overkill.boss.hp = 1; overkill.boss.max_hp = 2;
  expect(cast(overkill, "echo_siphon").next_state.player.hp).toBe(80);
  const focus = fixture("quiet_focus"); focus.boss.status.stun = 1;
  const focused = cast(focus, "quiet_focus").next_state;
  expect(focused.player.status.focus_next).toBe(0.12);
  focused.boss.status.stun = 1;
  expect(cast(focused, "furnace_rush", () => 0.99).next_state.player.status.focus_next).toBeUndefined();
  const crooked = fixture("crooked_rune"); crooked.boss.status.stun = 1;
  expect(cast(crooked, "crooked_rune").next_state.boss.status.misalign_next).toBe(0.1);
  const misaligned = cast(fixture("crooked_rune"), "crooked_rune", (_turn, draw) => [0, 0.99, 0.84][draw % 3]);
  expect(misaligned.events.some((e: any) => e.actor === "boss" && e.kind === "damage")).toBe(true);
  expect(misaligned.next_state.boss.status.misalign_next).toBe(0.1);
  const tempo = fixture("second_measure"); tempo.boss.status.stun = 1;
  expect(cast(tempo, "second_measure").next_state.player.status.tempo_bonus).toBe(2);
  const recoil = fixture("last_axiom"); recoil.player.hp = 2; recoil.boss.status.stun = 1;
  expect(cast(recoil, "last_axiom").terminal_result).toBe("LOSS");
  const second = fixture("fluid_anchor", "mercury_01"); second.player.status.tempo_bonus = -2;
  const result = cast(second, "fluid_anchor");
  expect(result.events[0].actor).toBe("boss");
  expect(result.next_state.player.status.shield_pct).toBe(0.18);
  const first = fixture("fluid_anchor", "mercury_01"); first.boss.status.stun = 1;
  expect(cast(first, "fluid_anchor").next_state.player.status.shield_pct).toBe(0.08);
  const killed = fixture("fluid_anchor", "mercury_01"); killed.player.status.tempo_bonus = -2; killed.player.hp = 1;
  expect(cast(killed, "fluid_anchor").events.some((e: any) => e.actor === "player")).toBe(false);
  const toxic = fixture("toxic_mirror", "mercury_01");
  const reflected = cast(toxic, "toxic_mirror", rng);
  expect(reflected.events.some((e: any) => e.kind === "reflect")).toBe(true);
  expect(reflected.next_state.boss.status.poison).toBe(0);
  expect(reflected.next_state.player.status.poison_on_reflect).toBeUndefined();
  const miss = fixture("toxic_mirror", "mercury_01"); miss.boss.status.stun = 1;
  const saved = cast(miss, "toxic_mirror", rng).next_state;
  expect(saved.player.status.poison_on_reflect).toBe(1);
  expect(saved.boss.status.poison ?? 0).toBe(0);
});

test("server Bismuth and Cinder progression applies without trusting client stats", () => {
  const selected = { ...selection, weapon_ids: ["bismuth_talisman", null], homunculus_id: "cinder" };
  const progress = { ...snapshot, item_progress: { bismuth_talisman: { level: 5 } }, homunculus_progress: { cinder: { level: 5 } } };
  const state = createCombatState(buildTrustedCombatSetup(progress, selected, catalogs));
  expect([state.player.hp, state.player.atk, state.player.def]).toEqual([109, 33, 13]);
  const base = createCombatState(buildTrustedCombatSetup(snapshot, selected, catalogs));
  expect([base.player.hp, base.player.atk, base.player.def]).toEqual([104, 27, 12]);
  state.boss.status.stun = 1;
  const before = structuredClone(state);
  const result = resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "hold" }, rng);
  expect(result.error).toBeUndefined();
  expect(result.events.find((e: any) => e.kind === "true_damage").damage).toBe(1);
  expect(result.next_state.hom_energy).toBe(1);
  const ready = structuredClone(state); ready.hom_energy = 3;
  const hom = resolveCombatTurn(ready, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, rng);
  expect(hom.events.find((e: any) => e.kind === "hom_damage").damage).toBe(13);
  expect(hom.next_state.hom_energy).toBe(1);
  const stunned = structuredClone(ready); stunned.player.status.hom_stun = 1;
  const nullified = resolveCombatTurn(stunned, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, rng);
  expect(nullified.events.some((e: any) => e.kind === "hom_damage")).toBe(false);
  expect([nullified.next_state.player.status.hom_stun, nullified.next_state.hom_energy]).toEqual([0, 1]);
  ready.hom_energy = 6;
  expect(resolveCombatTurn(ready, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, rng).events.find((e: any) => e.kind === "hom_damage").damage).toBe(20);
  ready.hom_energy = 3; ready.player.hp = 50;
  const sacrificed = resolveCombatTurn(ready, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "sacrifice" }, rng).next_state;
  expect([sacrificed.player.hp, sacrificed.player.max_hp, sacrificed.player.atk, sacrificed.player.def, sacrificed.hom_spent]).toEqual([80, 104, 27, 12, true]);
  expect(state).toEqual(before);
  expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, rng)).toEqual({ error: "INVALID_DECISION" });
  let draws = 0;
  expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "attack" }, () => { draws++; return 0; })).toEqual({ error: "INVALID_DECISION" });
  expect(draws).toBe(0);
  expect(buildTrustedCombatSetup(progress, { ...selected, weapon_ids: ["bismuth_talisman", "bismuth_talisman"] }, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  expect(buildTrustedCombatSetup({ ...progress, item_progress: { bismuth_talisman: { level: 5, specialization: "aggressive" } } }, selected, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
});

test("catalog homunculi and validated flat Forge traits use server progression", () => {
  const selected = { ...selection, weapon_ids: ["bismuth_talisman", null], homunculus_id: "cinder" };
  const progress = { ...snapshot, item_progress: { bismuth_talisman: { level: 5, specialization: "aggressive", traits: [{ id: "power_flat", points: 2 }, { id: "true_on_hit", points: 1 }, { id: "dot_true", points: 0 }] } }, homunculus_progress: { cinder: { level: 5, mutation_id: "vitality" } } };
  const enhanced = createCombatState(buildTrustedCombatSetup(progress, selected, catalogs));
  expect([enhanced.player.hp, enhanced.player.atk, enhanced.item_effects.true_on_hit]).toEqual([114, 35, 2]);
  enhanced.boss.status.stun = 1;
  expect(resolveCombatTurn(enhanced, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp).toBe(86);
  const supported = structuredClone(progress); supported.item_progress.bismuth_talisman.specialization = "technical";
  supported.item_progress.bismuth_talisman.traits = [{ id: "guard_flat", points: 2 }, { id: "power_flat", points: 1 }, { id: "tempo_flat", points: 0 }];
  expect(buildTrustedCombatSetup(supported, selected, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
  const vitality = { ...snapshot, homunculus_progress: { cinder: { level: 5, mutation_id: "vitality" } } };
  const state = createCombatState(buildTrustedCombatSetup(vitality, selected, catalogs));
  expect([state.player.hp, state.player.atk]).toEqual([114, 28]);
  const sodium = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, homunculus_id: "sodium" }, catalogs));
  expect(sodium.hom_id).toBe("sodium");
  sodium.boss.status.stun = 1;
  expect(resolveCombatTurn(sodium, { turn: 1, spell_id: "cinder_fist", target: "boss", hom_action: "hold" }, rng).next_state.hom_energy).toBe(1);
  const silphide = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, homunculus_id: "silphide" }, catalogs));
  silphide.boss.status.tempo_bonus = 1;
  expect(resolveCombatTurn(silphide, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).events[0].actor).toBe("player");
  const catalyst = { ...snapshot, homunculus_progress: { cinder: { level: 5, mutation_id: "catalyst" } } };
  expect(createCombatState(buildTrustedCombatSetup(catalyst, selected, catalogs)).player.atk).toBe(29);
  expect(buildTrustedCombatSetup({ ...snapshot, homunculus_progress: { cinder: { level: 99 } } }, selected, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
});

test("all 48 catalog entity and homunculus combinations resolve", () => {
  let count = 0;
  for (const entity of catalogs.entities) for (const hom of catalogs.homunculi) {
    const spells = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
    const state = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, entity_id: entity.id, spell_ids: spells, homunculus_id: hom.id }, catalogs));
    expect(state.hom_id).toBe(hom.id);
    state.boss.status.stun = 1;
    const result = resolveCombatTurn(state, { turn: 1, spell_id: spells[0], target: "boss", hom_action: "hold" }, rng);
    expect(result.error).toBeUndefined();
    expect(result.next_state.hom_energy).toBe(1);
    count++;
  }
  expect(count).toBe(48);
});

test("homunculus levels and mutations are server-derived", () => {
  for (const hom of catalogs.homunculi) for (const level of [0, 5, 10]) for (const mutation_id of ["catalyst", "vitality", "resonance"]) {
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, homunculus_progress: { [hom.id]: { level, mutation_id } } }, { ...selection, homunculus_id: hom.id }, catalogs));
    expect(state.player.max_hp).toBe(104 + hom.buff_hp + level + (mutation_id === "vitality" ? 5 : 0));
    expect(state.hom_advantage).toBeCloseTo(Math.min(0.5, (hom.per_type.sulfur.type_adv_bonus ?? 0) + (mutation_id === "resonance" ? 0.03 : 0)));
    state.boss.status.stun = 1;
    expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).error).toBeUndefined();
  }
  expect(buildTrustedCombatSetup({ ...snapshot, homunculus_progress: { cinder: { mutation_id: "forged" } } }, { ...selection, homunculus_id: "cinder" }, catalogs)).toEqual({ error: "UNTRUSTED_SETUP" });
});

test("synergy damage, neutralization, corrosion and incoming reduction", () => {
  const fixture = (entity_id: string, homunculus_id: string, boss_entity_id: string, mutation_id?: string) => {
    const entity = catalogs.entities.find((e: any) => e.id === entity_id);
    const spell_ids = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
    const homunculus_progress = mutation_id ? { [homunculus_id]: { mutation_id } } : {};
    return createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id, homunculus_progress }, { ...selection, entity_id, spell_ids, homunculus_id }, catalogs));
  };
  const drakon = fixture("sulfur_01", "drakon", "vitriol_01", "resonance");
  drakon.boss.status.stun = 1;
  const d = resolveCombatTurn(drakon, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng);
  expect(d.events.find((e: any) => e.kind === "damage").damage).toBe(19);
  expect(drakon.hom_advantage).toBeCloseTo(0.08);
  const unfavorable = fixture("sulfur_01", "drakon", "sodium_01", "resonance"); unfavorable.boss.status.stun = 1;
  const withoutBonus = structuredClone(unfavorable); withoutBonus.hom_advantage = 0;
  expect(resolveCombatTurn(unfavorable, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp).toBe(resolveCombatTurn(withoutBonus, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp);
  const universalIds = ["steady_script", "furnace_rush", "ash_temper", "brimstone_crash"];
  const spell_progress = { learned_by_entity: { sulfur_01: ["steady_script"] }, equipped_by_mode: { attack: { sulfur_01: universalIds } } };
  const universal = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id: "vitriol_01", spell_progress, homunculus_progress: { drakon: { mutation_id: "resonance" } } }, { ...selection, spell_ids: universalIds, homunculus_id: "drakon" }, catalogs));
  universal.boss.status.stun = 1;
  expect(resolveCombatTurn(universal, { turn: 1, spell_id: "steady_script", target: "boss" }, rng).events.find((e: any) => e.kind === "damage").damage).toBe(14);
  const hybridIds = ["golden_crucible", "furnace_rush", "ash_temper", "brimstone_crash"];
  const hybridProgress = { learned_by_entity: { sulfur_01: ["golden_crucible"] }, equipped_by_mode: { attack: { sulfur_01: hybridIds } } };
  const hybrid = createCombatState(buildTrustedCombatSetup({ ...snapshot, boss_entity_id: "aether_01", spell_progress: hybridProgress, homunculus_progress: { drakon: { mutation_id: "resonance" } } }, { ...selection, spell_ids: hybridIds, homunculus_id: "drakon" }, catalogs));
  hybrid.boss.status.stun = 1;
  expect(resolveCombatTurn(hybrid, { turn: 1, spell_id: "golden_crucible", target: "boss" }, rng).events.find((e: any) => e.kind === "damage").damage).toBe(20);
  const mothy = fixture("sulfur_01", "mothy", "sodium_01"); mothy.player.spell_neutralize_pending = 0.5; mothy.boss.status.stun = 1;
  const m = resolveCombatTurn(mothy, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng);
  expect(m.events.find((e: any) => e.kind === "damage").damage).toBe(14);
  const pyritc = fixture("vitriol_01", "pyritc", "sodium_01"); pyritc.boss.status.stun = 1;
  const p = resolveCombatTurn(pyritc, { turn: 1, spell_id: "etching_fang", target: "boss" }, rng);
  expect(p.events.find((e: any) => e.kind === "hom_corrosion").damage).toBe(3);
  expect(resolveCombatTurn(pyritc, { turn: 1, spell_id: "etching_fang", target: "boss" }, () => 0.99).events.some((e: any) => e.kind === "hom_corrosion")).toBe(false);
  const silk = fixture("sodium_01", "silphide", "sodium_01");
  const reduced = resolveCombatTurn(silk, { turn: 1, spell_id: "salt_barrier", target: "boss" }, (_t, i) => [0, 0, 0.99][i % 3]);
  expect(reduced.next_state.player.hp).toBe(107);
});

test("Nighty scaling and Chimera reflection are removed safely on sacrifice", () => {
  const weapons = ["bismuth_talisman", "wind_amulet"];
  const item_progress = { bismuth_talisman: { level: 5, fusion: { donor_id: "wind_amulet" } }, wind_amulet: { level: 3 } };
  const night = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress }, { ...selection, weapon_ids: weapons, homunculus_id: "nighty" }, catalogs));
  expect(night.item_effects.power_flat).toBeCloseTo(6.3);
  expect(night.item_effects.evasion_pct).toBeCloseTo(0.021);
  night.hom_energy = 3; night.boss.status.stun = 1;
  const sacrificed = resolveCombatTurn(night, { turn: 1, switch_slot: 2, hom_action: "sacrifice" }, rng).next_state;
  expect(sacrificed.item_effects.tempo_flat).toBe(4);
  expect(sacrificed.hom_spent).toBe(true);
  sacrificed.boss.status.stun = 1;
  const back = resolveCombatTurn(sacrificed, { turn: 2, switch_slot: 1 }, rng).next_state;
  expect(back.item_effects.power_flat).toBe(6);
  expect(back.item_effects.evasion_pct).toBe(0.02);
  const chimera = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: ["mirror_sigel", "bismuth_talisman"], homunculus_id: "chimera" }, catalogs));
  chimera.hom_energy = 3; chimera.boss.status.stun = 1;
  const active = resolveCombatTurn(chimera, { turn: 1, spell_id: "ash_temper", target: "boss" }, rng).next_state;
  expect(active.player.status.reflect_pct).toBe(0.02);
  active.boss.status.stun = 1;
  const removed = resolveCombatTurn(active, { turn: 2, switch_slot: 2, hom_action: "sacrifice" }, rng).next_state;
  expect(removed.player.status.reflect_pct ?? 0).toBe(0);
  const ids = ["reverse_quill", "furnace_rush", "ash_temper", "brimstone_crash"];
  const spell_progress = { learned_by_entity: { sulfur_01: ["reverse_quill"] }, equipped_by_mode: { attack: { sulfur_01: ids } } };
  const combined = createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress }, { ...selection, spell_ids: ids, weapon_ids: ["mirror_sigel", "bismuth_talisman"], homunculus_id: "chimera" }, catalogs));
  combined.hom_energy = 3; combined.boss.status.stun = 1;
  const defended = resolveCombatTurn(combined, { turn: 1, spell_id: "reverse_quill", target: "boss" }, rng).next_state;
  expect(defended.player.status.reflect_pct).toBe(0.13);
  defended.boss.status.stun = 1;
  const preserved = resolveCombatTurn(defended, { turn: 2, switch_slot: 2, hom_action: "sacrifice" }, rng).next_state;
  expect(preserved.player.status.reflect_pct).toBe(0.13);
});

test("all eight catalog weapons resolve at Forge levels 0, 5 and 10", () => {
  for (const item of catalogs.items) for (const level of [0, 5, 10]) {
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [item.id]: { level } } }, { ...selection, weapon_ids: [item.id, null] }, catalogs));
    expect(state.item_id).toBe(item.id);
    for (const [key, values] of Object.entries(item.effects) as [string, number[]][]) {
      const expected = level === 0 && values.length === 10 && key in (item.base_effects ?? {}) ? item.base_effects[key] : values[Math.min(values.length - 1, Math.max(0, level - 1))];
      expect(state.item_effects[key]).toBe(expected);
    }
    state.boss.status.stun = 1;
    expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp).toBeLessThan(112);
  }
});

test("Forge paths and all donor imprints derive from official balance", () => {
  for (const path of ["aggressive", "defensive", "technical"]) {
    const pool = catalogs.balance.forge_trait_pool[path];
    const traits = Object.keys(pool).slice(0, 3).map((id, i) => ({ id, points: i === 0 ? 2 : 0 }));
    const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { bismuth_talisman: { level: 5, specialization: path, traits } } }, { ...selection, weapon_ids: ["bismuth_talisman", null] }, catalogs));
    const base = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { bismuth_talisman: { level: 5 } } }, { ...selection, weapon_ids: ["bismuth_talisman", null] }, catalogs));
    expect(state.item_effects[traits[0].id]).toBe((base.item_effects[traits[0].id] ?? 0) + pool[traits[0].id] * 2);
    state.boss.status.stun = 1;
    expect(resolveCombatTurn(state, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).next_state.boss.hp).toBeLessThan(112);
  }
  for (const donor of catalogs.items) {
    const target = donor.id === "bismuth_talisman" ? "wind_amulet" : "bismuth_talisman";
    const base = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [target]: { level: 3 } } }, { ...selection, weapon_ids: [target, null] }, catalogs));
    const fused = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [target]: { level: 3, fusion: { donor_id: donor.id } }, [donor.id]: { level: 3 } } }, { ...selection, weapon_ids: [target, null] }, catalogs));
    const [key, amount] = Object.entries(catalogs.balance.forge_fusion_imprints[donor.id])[0] as [string, number];
    expect(fused.item_effects[key]).toBeCloseTo((base.item_effects[key] ?? 0) + amount);
  }
});

test("weapon evasion, ward, corrosion and reflection prevention activate", () => {
  const fixture = (id: string, level = 0) => createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [id]: { level } } }, { ...selection, weapon_ids: [id, null] }, catalogs));
  const action = (spell_id: string) => ({ turn: 1, spell_id, target: "boss" });
  const dodge = resolveCombatTurn(fixture("wind_amulet"), action("ash_temper"), () => 0);
  expect(dodge.next_state.player.hp).toBe(104);
  expect(dodge.events.some((event: any) => event.kind === "evade")).toBe(true);
  const ward = fixture("saltstone_charm"); ward.boss.status.stun = 1;
  expect(resolveCombatTurn(ward, action("ash_temper"), rng).next_state.player.status.shield_pct).toBe(0.12);
  const mirror = fixture("mirror_sigel", 5); mirror.boss.status.stun = 1;
  const guarded = resolveCombatTurn(mirror, action("ash_temper"), rng).next_state;
  expect([guarded.player.status.shield_pct, guarded.player.status.reflect_pct]).toEqual([0.08, 0.07]);
  const returned = resolveCombatTurn(guarded, { turn: 2, spell_id: "cinder_fist", target: "boss" }, rng);
  expect(returned.events.find((event: any) => event.kind === "reflect").damage).toBe(1);
  expect(returned.next_state.player.status.reflect_pct).toBeUndefined();
  const corrosion = fixture("vitriol_vial", 5); corrosion.boss.status.stun = 1;
  const corroded = resolveCombatTurn(corrosion, action("cinder_fist"), rng);
  expect(corroded.events.find((event: any) => event.kind === "corrosion").damage).toBe(3);
  expect(corroded.next_state.boss.status.vuln_pct).toBe(0.1);
  const protectedPlayer = fixture("aether_knot", 10); protectedPlayer.boss.status.reflect_pct = 1; protectedPlayer.boss.status.stun = 1;
  const ignored = resolveCombatTurn(protectedPlayer, action("cinder_fist"), () => 0);
  expect(ignored.next_state.player.hp).toBe(104);
  const suffered = resolveCombatTurn(protectedPlayer, action("cinder_fist"), (_turn, draw) => [0, 0.99, 0.99][draw % 3]);
  expect(suffered.next_state.player.hp).toBeLessThan(104);
});

test("both slots validate and each weapon switches into real combat at every Forge level", () => {
  for (const item of catalogs.items) for (const level of [0, 5, 10]) {
    const other = item.id === "bismuth_talisman" ? "wind_amulet" : "bismuth_talisman";
    for (const ids of [[item.id, other], [other, item.id]]) {
      const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [item.id]: { level } } }, { ...selection, weapon_ids: ids }, catalogs));
      expect(state.weapons[ids.indexOf(item.id)].id).toBe(item.id);
      for (const [key, values] of Object.entries(item.effects) as [string, number[]][]) {
        const expected = level === 0 && values.length === 10 && key in (item.base_effects ?? {}) ? item.base_effects[key] : values[Math.min(values.length - 1, Math.max(0, level - 1))];
        expect(state.weapons[ids.indexOf(item.id)].effects[key]).toBe(expected);
      }
      state.boss.status.stun = 1;
      const destination = ids.indexOf(item.id) + 1;
      const initial = destination === 1 ? 2 : 1;
      if (destination === 1) {
        const swapped = resolveCombatTurn(state, { turn: 1, switch_slot: initial }, rng);
        expect(swapped.next_state.active_weapon_slot).toBe(2);
        swapped.next_state.boss.status.stun = 1;
        const returned = resolveCombatTurn(swapped.next_state, { turn: 2, switch_slot: destination }, rng);
        expect(returned.next_state.item_id).toBe(item.id);
      } else {
        const switched = resolveCombatTurn(state, { turn: 1, switch_slot: destination }, rng);
        expect(switched.next_state.item_id).toBe(item.id);
      }
    }
    const onlySecond = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress: { [item.id]: { level } } }, { ...selection, weapon_ids: [null, item.id] }, catalogs));
    expect([onlySecond.active_weapon_slot, onlySecond.item_id]).toEqual([2, item.id]);
  }
});

test("switch consumes action, preserves independent defenses and recalculates stats", () => {
  const state = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: ["bismuth_talisman", "mirror_sigel"] }, catalogs));
  expect([state.player.hp, state.player.atk, state.player.def, state.active_weapon_slot]).toEqual([104, 22, 12, 1]);
  state.cooldowns.ash_temper = 2;
  state.boss.status.stun = 1;
  const switched = resolveCombatTurn(state, { turn: 1, switch_slot: 2 }, rng);
  expect([switched.next_state.player.hp, switched.next_state.player.atk, switched.next_state.player.def, switched.next_state.active_weapon_slot, switched.next_state.cooldowns.ash_temper]).toEqual([104, 21, 12, 2, 1]);
  expect(switched.events.some((event: any) => event.kind === "switch")).toBe(true);
  expect(switched.next_state.player.status.shield_pct).toBe(0.08);
  const next = switched.next_state;
  next.other_defenses.shield_pct = 0.05;
  next.other_defenses.reflect_pct = 0.01;
  next.player.status.poison = 1;
  next.boss.status.stun = 1;
  const back = resolveCombatTurn(next, { turn: 2, switch_slot: 1 }, rng);
  expect([back.next_state.player.atk, back.next_state.player.def, back.next_state.player.status.shield_pct, back.next_state.player.status.reflect_pct]).toEqual([22, 12, 0.05, 0.01]);
  expect(back.next_state.player.hp).toBe(102);
  expect(resolveCombatTurn(next, { turn: 2, switch_slot: 1 }, rng)).toEqual(back);
  let draws = 0;
  expect(resolveCombatTurn(state, { turn: 1, switch_slot: 2, spell_id: "cinder_fist" }, () => { draws++; return 0; })).toEqual({ error: "INVALID_DECISION" });
  expect(draws).toBe(0);
  expect(resolveCombatTurn(state, { turn: 1, switch_slot: 1 }, rng)).toEqual({ error: "INVALID_DECISION" });
  expect(resolveCombatTurn(state, { turn: 1, switch_slot: 3 }, rng)).toEqual({ error: "INVALID_DECISION" });
  const stunned = structuredClone(state); stunned.player.status.stun = 1;
  expect(resolveCombatTurn(stunned, { turn: 1, switch_slot: 2 }, rng).next_state.active_weapon_slot).toBe(1);
  const defeated = structuredClone(state); defeated.player.hp = 1; defeated.boss.status.stun = 0; defeated.boss.status.tempo_bonus = 100;
  const killed = resolveCombatTurn(defeated, { turn: 1, switch_slot: 2 }, () => 0);
  expect([killed.terminal_result, killed.next_state.active_weapon_slot]).toEqual(["LOSS", 1]);
  const activeBoss = structuredClone(state); activeBoss.boss.status.stun = 0;
  const bossTurn = resolveCombatTurn(activeBoss, { turn: 1, switch_slot: 2 }, rng);
  expect(bossTurn.events.some((event: any) => event.actor === "player" && event.kind === "damage")).toBe(false);
  expect(bossTurn.events.some((event: any) => event.actor === "boss" && event.kind === "damage")).toBe(true);
  const sodium = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, entity_id: "sodium_01", spell_ids: ["crystal_ram", "salt_barrier", "brine_mend", "bastion_return"], weapon_ids: ["mirror_sigel", "bismuth_talisman"] }, catalogs));
  sodium.boss.status.stun = 1;
  const protectedState = resolveCombatTurn(sodium, { turn: 1, spell_id: "salt_barrier", target: "boss" }, rng).next_state;
  expect([protectedState.player.status.shield_pct, protectedState.weapon_defenses.shield_pct, protectedState.other_defenses.shield_pct]).toEqual([0.24, 0.08, 0.24]);
  protectedState.boss.status.stun = 1;
  const preserved = resolveCombatTurn(protectedState, { turn: 2, switch_slot: 2 }, rng).next_state;
  expect(preserved.player.status.shield_pct).toBe(0.24);
  const withoutTempo = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: ["bismuth_talisman", "wind_amulet"] }, catalogs));
  const withTempo = createCombatState(buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: ["wind_amulet", "bismuth_talisman"] }, catalogs));
  withoutTempo.boss.status.tempo_bonus = 1; withTempo.boss.status.tempo_bonus = 1;
  expect(resolveCombatTurn(withoutTempo, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).events[0].actor).toBe("boss");
  expect(resolveCombatTurn(withTempo, { turn: 1, spell_id: "cinder_fist", target: "boss" }, rng).events[0].actor).toBe("player");
});

test("each slot retains its own Forge traits and fusion through switching", () => {
  const item_progress = {
    bismuth_talisman: { level: 5, specialization: "aggressive", traits: [{ id: "power_flat", points: 2 }, { id: "true_on_hit", points: 1 }, { id: "dot_true", points: 0 }], fusion: { donor_id: "wind_amulet" } },
    wind_amulet: { level: 5, specialization: "defensive", traits: [{ id: "guard_flat", points: 2 }, { id: "ward_pct", points: 1 }, { id: "reflect_pct", points: 0 }], fusion: { donor_id: "mirror_sigel" } },
    mirror_sigel: { level: 3 },
  };
  const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, item_progress }, { ...selection, weapon_ids: ["bismuth_talisman", "wind_amulet"] }, catalogs));
  expect([state.player.atk, state.item_effects.true_on_hit, state.item_effects.evasion_pct]).toEqual([29, 2, 0.02]);
  expect(state.item_effects.ward_pct).toBeUndefined();
  state.boss.status.stun = 1;
  const switched = resolveCombatTurn(state, { turn: 1, switch_slot: 2 }, rng).next_state;
  expect([switched.player.atk, switched.player.def, switched.item_effects.ward_pct, switched.item_effects.reflect_pct]).toEqual([22, 13, 0.02, 0.02]);
  expect(switched.item_effects.true_on_hit).toBeUndefined();
  expect(switched.player.status.shield_pct).toBe(0.02);
});

test("switch and sacrifice preserve recalculated stats on subsequent switches", () => {
  const selected = { ...selection, weapon_ids: ["bismuth_talisman", "mirror_sigel"], homunculus_id: "cinder" };
  const state = createCombatState(buildTrustedCombatSetup({ ...snapshot, homunculus_progress: { cinder: { level: 5 } } }, selected, catalogs));
  state.hom_energy = 3; state.player.hp = 50; state.boss.status.stun = 1;
  const switched = resolveCombatTurn(state, { turn: 1, switch_slot: 2, hom_action: "sacrifice" }, rng).next_state;
  expect([switched.player.hp, switched.player.max_hp, switched.player.atk, switched.player.def, switched.hom_spent]).toEqual([80, 104, 21, 12, true]);
  switched.boss.status.stun = 1;
  const back = resolveCombatTurn(switched, { turn: 2, switch_slot: 1 }, rng).next_state;
  expect([back.player.hp, back.player.atk, back.player.def, back.hom_spent]).toEqual([80, 22, 12, true]);
});

test("marks are owned, expire on actions and are consumed on hybrid hit", () => {
  const ids = ["paradox_edict", "gilded_exception", "rift_touch", "paradox_fold"];
  const progress = { learned_by_entity: { aether_01: ids.slice(0, 2) }, equipped_by_mode: { attack: { aether_01: ids } } };
  const make = () => createCombatState(buildTrustedCombatSetup({ ...snapshot, spell_progress: progress }, { ...selection, entity_id: "aether_01", spell_ids: ids }, catalogs));
  const state = make(); state.boss.status.stun = 1;
  const marked = resolveCombatTurn(state, { turn: 1, spell_id: "paradox_edict", target: "boss" }, rng).next_state;
  expect(marked.boss.status.hybrid_mark).toEqual({ owner: "player", remaining: 2 });
  marked.boss.status.stun = 1;
  const consumed = resolveCombatTurn(marked, { turn: 2, spell_id: "gilded_exception", target: "boss" }, rng).next_state;
  expect(consumed.boss.status.hybrid_mark).toBeUndefined();
  const foreign = make(); foreign.boss.status.stun = 1; foreign.boss.status.hybrid_mark = { owner: "enemy", remaining: 2 };
  const other = resolveCombatTurn(foreign, { turn: 1, spell_id: "gilded_exception", target: "boss" }, rng).next_state;
  expect(other.boss.status.hybrid_mark).toEqual({ owner: "enemy", remaining: 2 });
  const expiring = make(); expiring.boss.status.stun = 1; expiring.boss.status.hybrid_mark = { owner: "player", remaining: 1 };
  const expired = resolveCombatTurn(expiring, { turn: 1, spell_id: "rift_touch", target: "boss" }, rng).next_state;
  expect(expired.boss.status.hybrid_mark).toBeUndefined();
});
