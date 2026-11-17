import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createPvpCombatState, validatePvpDecision, resolvePvpExchange } from "../pvp/combat";
const read = (n: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", n), "utf8"));
const catalogs = { entities: read("entities.json").entities, items: read("items.json").items, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells, types: read("types.json") };
const snapshot = (player_id: string, type: string) => ({ player_id, entity_id: `${type}_01`, weapon_ids: [null, null], homunculus_id: null, spell_ids: catalogs.spells.filter((s: any) => s.type === type).slice(0, 4).map((s: any) => s.id) });
const setup = () => createPvpCombatState(snapshot("a", "sulfur"), snapshot("b", "mercury"), catalogs) as any;
test("real loadouts are independent and cloned", () => {
 const l = snapshot("a", "sulfur"), r = snapshot("b", "mercury"), before = structuredClone({l, r, catalogs});
 const state = createPvpCombatState(l, r, catalogs) as any;
 expect(state.fighters.left.spells.map((s: any) => s.id)).toEqual(l.spell_ids);
 expect(state.fighters.right.spells.map((s: any) => s.id)).toEqual(r.spell_ids);
 state.fighters.left.entity.name = "changed"; expect({l, r, catalogs}).toEqual(before);
});
test("each side selects only its own available action", () => {
 const s = setup(), l = s.fighters.left.spells[0].id, r = s.fighters.right.spells[0].id;
 expect(validatePvpDecision(s, "left", {turn: 1, spell_id: l})).toEqual({ok: true});
 expect(validatePvpDecision(s, "right", {turn: 1, spell_id: r})).toEqual({ok: true});
 expect(validatePvpDecision(s, "left", {turn: 1, spell_id: r})).toEqual({error: "INVALID_DECISION"});
 expect(validatePvpDecision(s, "left", {turn: 1, spell_id: l, target: "left"} as any)).toEqual({error: "INVALID_DECISION"});
 s.fighters.right.spell_cooldowns[r] = 1;
 expect(validatePvpDecision(s, "right", {turn: 1, spell_id: r})).toEqual({error: "INVALID_DECISION"});
 expect(validatePvpDecision(s, "left", {turn: 1, spell_id: l, hom_action: "attack"})).toEqual({error: "INVALID_DECISION"});
});
test("ultra validation follows deciding-round conditions", () => {
 const s = setup(), d = {turn: 1, spell_id: s.fighters.left.spells[0].id, ultra: true};
 expect(validatePvpDecision(s, "left", d)).toEqual({error: "INVALID_DECISION"});
 s.battle_index = 3; s.wins = {left: 1, right: 1};
 expect(validatePvpDecision(s, "left", d)).toEqual({ok: true});
 s.fighters.left.ultra_used = true; expect(validatePvpDecision(s, "left", d)).toEqual({error: "INVALID_DECISION"});
});
test("resolution fails closed without mutation or RNG draws", () => {
 const s = setup(), before = structuredClone(s), l = {turn: 1, spell_id: s.fighters.left.spells[0].id}, r = {turn: 1, spell_id: s.fighters.right.spells[0].id};
 let draws = 0; const rng = () => {draws++; return 0;};
 expect(resolvePvpExchange(s, l, r, rng)).toEqual({error: "PVP_COMBAT_PARITY_UNAVAILABLE"});
 expect(resolvePvpExchange(s, l, r, rng)).toEqual({error: "PVP_COMBAT_PARITY_UNAVAILABLE"});
 expect(draws).toBe(0); expect(s).toEqual(before);
});
test("bad setups and duplicate equipment are rejected", () => {
 const l = snapshot("a", "sulfur"), r = snapshot("b", "mercury"), item = catalogs.items.find((i: any) => i.slot === "build");
 expect(createPvpCombatState(l, {...r, player_id: "a"}, catalogs)).toEqual({error: "UNTRUSTED_SETUP"});
 expect(createPvpCombatState({...l, weapon_ids: [item.id, item.id]}, r, catalogs)).toEqual({error: "UNTRUSTED_SETUP"});
});

test("normal reference initiative and battle-end scoring", async () => {
 const { normalBattleOutcome, normalInitiativeOrder } = await import("../pvp/combat");
 expect(normalInitiativeOrder(10, 10)).toEqual(["left", "right"]);
 expect(normalInitiativeOrder(10, 11)).toEqual(["right", "left"]);
 expect(normalInitiativeOrder(11, 10)).toEqual(["left", "right"]);
 const score = {left: 1, right: 1, battle_index: 3, sudden_death: false};
 const saved = structuredClone(score);
 expect(normalBattleOutcome(score, {left: true, right: false})).toEqual({wins: {left: 1, right: 2}, battle_index: 3, sudden_death: false, result: "right"});
 expect(normalBattleOutcome(score, {left: true, right: true})).toEqual({wins: {left: 1, right: 1}, battle_index: 4, sudden_death: true, result: null});
 expect(normalBattleOutcome({left: 1, right: 1, battle_index: 4, sudden_death: true}, {left: true, right: true}).result).toBe("draw");
 expect(normalBattleOutcome({left: 1, right: 0, battle_index: 3, sudden_death: false}, {left: true, right: true}).result).toBe("left");
 expect(score).toEqual(saved);
 expect(() => normalBattleOutcome(score, {left: false, right: false})).toThrow("INVALID_BATTLE_OUTCOME");
});

test("normal spell multipliers follow catalog relationships and hybrid weights", async () => {
 const { normalSpellMultiplier } = await import("../pvp/combat");
 const matrix = catalogs.types.effectiveness;
 const entries = Object.entries(matrix).flatMap(([a, row]: [string, any]) => Object.entries(row).map(([d, value]) => ({a, d, value: value as number})));
 const strong = entries.find(x => x.value > 1)!, weak = entries.find(x => x.value < 1)!;
 const input = (a: string, d: string, spell_type = a) => ({attacker_type: a, defender_type: d, spell_type, effectiveness: matrix});
 expect(normalSpellMultiplier(input(strong.a, strong.d))).toBeCloseTo(1.12);
 expect(normalSpellMultiplier(input(weak.a, weak.d))).toBeCloseTo(0.92);
 expect(normalSpellMultiplier({...input(weak.a, weak.d), disadvantage_reduction: 0.04})).toBeCloseTo(0.96);
 expect(normalSpellMultiplier({...input(strong.a, strong.d), advantage_bonus: 0.1})).toBeCloseTo(1.22);
 expect(normalSpellMultiplier({...input(strong.a, strong.d), defender_neutralize: 1})).toBe(1);
 expect(normalSpellMultiplier(input(strong.a, strong.d, "universal"))).toBe(1);
 const h = {...input(strong.a, strong.d, "hybrid"), primary_type: strong.a, secondary_type: strong.d};
 const secondary = matrix[strong.d]?.[strong.d] ?? 1;
 const factor = secondary > 1 ? 1.25 : secondary < 1 ? 0.8 : 1;
 expect(normalSpellMultiplier(h)).toBeCloseTo(Math.pow(1.25, 0.65) * Math.pow(factor, 0.35));
});

test("normal direct damage applies rounding, status, wards and ultra in reference order", async () => {
 const { normalDirectDamage } = await import("../pvp/combat");
 const base = {attack: 21, defense: 11, power: 1, type_multiplier: 1};
 expect(normalDirectDamage(base)).toBe(16);
 expect(normalDirectDamage({...base, attack_down: 0.15, attack_boost: 0.2})).toBe(17);
 expect(normalDirectDamage({...base, incoming_multiplier: 0.5, vulnerability: 0.25, shield: 0.5, ultra: true})).toBe(10);
 expect(normalDirectDamage({...base, shield: 0.5, dispel: 0.5, pierce: 0.5})).toBe(14);
 expect(normalDirectDamage({...base, shield: 1})).toBe(0);
});

test("normal action cooldowns decrement before the chosen spell cooldown is set", async () => {
 const { normalActionCooldowns } = await import("../pvp/combat");
 const cooldowns = {a: 0, b: 2}, before = structuredClone(cooldowns);
 expect(normalActionCooldowns(cooldowns, {id: "a", cooldown_turns: 3})).toEqual({a: 3, b: 1});
 expect(normalActionCooldowns(cooldowns)).toEqual({a: 0, b: 1});
 expect(() => normalActionCooldowns(cooldowns, {id: "b", cooldown_turns: 2})).toThrow("INVALID_COOLDOWN");
 expect(cooldowns).toEqual(before);
});
