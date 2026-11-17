import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createPvpCombatState, validatePvpDecision, resolvePvpExchange, refreshPvpWeapon, resetPvpFighter, startPvpBattle, pvpInitiative } from "../pvp/combat";
const read = (n: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", n), "utf8"));
const catalogs = { entities: read("entities.json").entities, items: read("items.json").items, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
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

test("six real unarmed entities have normal base stats on either side", () => {
 const fixtures: Record<string, number[]> = {sulfur: [104,21,11], mercury: [96,18,10], sodium: [112,16,16], aether: [102,20,12], vitriol: [104,19,12], gold: [104,18,14]};
 for (const [type, expected] of Object.entries(fixtures)) for (const side of ["left", "right"] as const) {
  const a = snapshot("a", type), b = snapshot("b", type), state = createPvpCombatState(a, b, catalogs) as any;
  const f = state.fighters[side];
  expect([f.hp, f.max_hp, f.atk, f.def]).toEqual([expected[0], expected[0], expected[1], expected[2]]);
  expect(f.hom_spent).toBe(true); expect(pvpInitiative(f).initiative).toBe(10);
 }
});

test("real progression applies independently with upgrades, mutation and synergy", () => {
 const left = {...snapshot("a", "sulfur"), weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", item_progress: {bismuth_talisman: {level: 5}, wind_amulet: {level: 3}}, homunculus_progress: {cinder: {level: 5, mutation_id: "catalyst"}}};
 const right = {...snapshot("b", "mercury"), weapon_ids: ["wind_amulet", "saltstone_charm"], homunculus_id: "silphide", item_progress: {wind_amulet: {level: 3}, saltstone_charm: {level: 0}}, homunculus_progress: {silphide: {level: 3, mutation_id: "vitality"}}};
 const original = structuredClone({left, right, catalogs});
 const state = createPvpCombatState(left, right, catalogs) as any, l = state.fighters.left, r = state.fighters.right;
 expect([l.hp,l.max_hp,l.atk,l.def]).toEqual([109,109,34,13]);
 expect([r.hp,r.max_hp,r.atk,r.def]).toEqual([105,105,19,12]);
 expect([l.item_fx.true_on_hit, r.item_fx.evasion_pct]).toEqual([1,0.08]);
 expect([pvpInitiative(l).initiative,pvpInitiative(r).initiative]).toEqual([10,17]);
 const switched = refreshPvpWeapon(l, 2);
 expect([switched.hp,switched.max_hp,switched.atk,switched.def,pvpInitiative(switched).initiative]).toEqual([109,109,29,12,14]);
 expect([l.active_weapon_slot,l.atk,l.def]).toEqual([1,34,13]);
 expect(refreshPvpWeapon(switched, 1).atk).toBe(34);
 const mirror = createPvpCombatState({...right, player_id: "a"}, {...left, player_id: "b"}, catalogs) as any;
 expect([mirror.fighters.left.atk, mirror.fighters.right.atk]).toEqual([19,34]);
 expect({left, right, catalogs}).toEqual(original);
});

test("real scaled weapon and forged traits retain Godot truncation", () => {
 const l = {...snapshot("a", "sulfur"), weapon_ids: ["bismuth_talisman", null], homunculus_id: "nighty", item_progress: {bismuth_talisman: {level: 5, specialization: "aggressive", traits: [{id: "power_flat",points: 2},{id: "true_on_hit",points: 1},{id: "dot_true",points: 0}]}}, homunculus_progress: {nighty: {level: 3, mutation_id: "resonance"}}};
 const f = (createPvpCombatState(l, snapshot("b", "sulfur"), catalogs) as any).fighters.left;
 expect([f.max_hp,f.atk,f.def]).toEqual([110,29,14]);
 expect(f.active_weapon.effects.power_flat[0]).toBeCloseTo(8.4);
 expect(f.item_fx.true_on_hit).toBeCloseTo(2.1);
 expect(f.hom_bonus.favorable_type_bonus).toBe(0.03);
});

test("battle reset preserves score, equipment, sacrifice and ultra use while clearing combat state", () => {
 const s = setup(), f = s.fighters.left;
 s.turn = 8; s.battle_index = 3; s.wins = {left: 1,right: 1}; s.physical_anomaly = {id:"x"};
 Object.assign(f, {hp: 2, hom_energy: 5, ultra_used: true, inspiration: 3, inspiration_pending: true, temporary_spell_id: "temporary", temporary_replaced_slot: 0, strategic_trap: {value: 1}, spell_hit_this_exchange: true});
 f.spell_ids[0] = "temporary"; f.status.poison = 2; f.spell_cooldowns.abc = 2;
 const before = structuredClone(s), reset = startPvpBattle(s), x = reset.fighters.left;
 expect([reset.turn,reset.battle_index,reset.wins]).toEqual([0,3,{left:1,right:1}]);
 expect([x.hp,x.hom_energy,x.ultra_used,x.hom_spent,x.inspiration,x.inspiration_pending]).toEqual([x.max_hp,0,true,true,0,false]);
 expect(x.spell_ids).toEqual(f.original_spell_ids); expect(x.spell_cooldowns).toEqual({});
 expect(x.status).toEqual({poison:0,stun:0,shield_pct:0,atk_boost:0,vuln_pct:0,atk_down:0,hom_stun:0,reflect_pct:0,tempo_bonus:0});
 expect((x as any).strategic_trap).toBeUndefined(); expect(reset.physical_anomaly).toBeNull();
 expect(s).toEqual(before); expect(resetPvpFighter(f).hp).toBe(f.max_hp);
});

test("malformed selected progression and catalogs fail closed", () => {
 const left = {...snapshot("a", "sulfur"), weapon_ids: ["bismuth_talisman", null], homunculus_id: "cinder"};
 const right = snapshot("b", "mercury");
 for (const change of [{item_progress: {bismuth_talisman: {level: 11}}}, {item_progress: []}, {homunculus_progress: {cinder: {level: -1}}}, {homunculus_progress: {cinder: {mutation_id: "missing"}}}, {item_progress: {bismuth_talisman: {level: 5, specialization: "aggressive", traits: [{id: "power_flat",points: 9}]}}}]) {
  expect(createPvpCombatState({...left,...change},right,catalogs)).toEqual({error:"UNTRUSTED_SETUP"});
 }
 expect(createPvpCombatState(left,right,{...catalogs, entities: [null]})).toEqual({error:"UNTRUSTED_SETUP"});
 expect(createPvpCombatState(left,right,{...catalogs, types: {effectiveness: {}}})).toEqual({error:"UNTRUSTED_SETUP"});
});

test("empty first slot, fusion, switching defenses and initiative consumption", () => {
 const l = {...snapshot("a", "aether"), weapon_ids: [null, "bismuth_talisman"], homunculus_id: "drakon", item_progress: {bismuth_talisman: {level: 3, fusion: {donor_id: "wind_amulet"}}, wind_amulet: {level: 3}}, homunculus_progress: {drakon: {level: 0}}};
 const state = createPvpCombatState(l, snapshot("b", "sodium"), catalogs) as any, f = state.fighters.left;
 expect([f.active_weapon_slot, f.atk, f.def, f.max_hp, f.hom_synergy.type_adv_bonus]).toEqual([1,22,13,102,0.1]);
 f.status.tempo_bonus = 2; const init = pvpInitiative(f);
 expect(init.initiative).toBe(12); expect(init.fighter.status.tempo_bonus).toBe(0); expect(f.status.tempo_bonus).toBe(2);
 f.status.shield_pct = 0.4; f.weapon_shield_pct = 0.4; f.other_shield_pct = 0.2;
 const switched = refreshPvpWeapon(f, 2);
 expect([switched.atk, switched.def, switched.item_fx.true_on_hit, switched.item_fx.evasion_pct]).toEqual([26,14,1,0.02]);
 expect(switched.status.shield_pct).toBe(0.2); expect(f.status.shield_pct).toBe(0.4);
 const spent = structuredClone(switched); spent.hom_spent = true;
 const afterSacrifice = refreshPvpWeapon(spent);
 expect([afterSacrifice.max_hp,afterSacrifice.atk,afterSacrifice.def]).toEqual([102,24,13]);
 expect(resetPvpFighter(afterSacrifice).hom_spent).toBe(true);
});
