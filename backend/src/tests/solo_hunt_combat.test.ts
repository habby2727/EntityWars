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
