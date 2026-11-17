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
test("unsupported effects fail closed without mutation or RNG draws", () => {
 const s = setup(), before = structuredClone(s), l = {turn: 1, spell_id: s.fighters.left.spells.find((x: any) => x.effects.length > 0).id}, r = {turn: 1, spell_id: s.fighters.right.spells[0].id};
 let draws = 0; const rng = () => {draws++; return 0;};
 expect(resolvePvpExchange(s, l, r, rng)).toEqual({error: "PVP_COMBAT_PARITY_UNAVAILABLE"});
 expect(resolvePvpExchange(s, l, r, rng)).toEqual({error: "PVP_COMBAT_PARITY_UNAVAILABLE"});
 expect(draws).toBe(0); expect(s).toEqual(before);
});

test("both humans attack in order and deterministic draws preserve input", () => {
 const s = setup(), before = structuredClone(s), l = {turn:1,spell_id:"cinder_fist"}, r = {turn:1,spell_id:"silver_needle"};
 const result = resolvePvpExchange(s,l,r,()=>0.5) as any;
 expect(result).toEqual(resolvePvpExchange(s,l,r,()=>0.5)); expect(s).toEqual(before);
 expect(result.events.filter((e: any)=>e.kind === "damage").map((e: any)=>e.side)).toEqual(["left","right"]);
 expect(result.state.fighters.left.hp).toBeLessThan(104); expect(result.state.fighters.right.hp).toBeLessThan(96);
 expect(result.events.find((e: any)=>e.kind === "damage")).toMatchObject({actor_side:"player",category:"damage",spell_id:"cinder_fist",target_side:"right"});
});

test("faster human acts first, and lethal hits prevent the second action", () => {
 const s = setup(); s.fighters.right.status.tempo_bonus = 2; s.fighters.left.hp = 1;
 const result = resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(result.events.filter((e: any)=>e.kind === "spell").map((e: any)=>e.side)).toEqual(["right"]);
 expect(result.state.fighters.left.hp).toBe(0); expect(result.state.battle_result).toBe("right");
});

test("accuracy, evasion and stun resolve without spending wrong resources", () => {
 const s = setup(), l = {turn:1,spell_id:"cinder_fist"}, r = {turn:1,spell_id:"silver_needle"};
 s.fighters.right.item_fx.evasion_pct = 1;
 const evade = resolvePvpExchange(s,l,r,()=>0.5) as any;
 expect(evade.events.some((e: any)=>e.kind === "evade")).toBe(true);
 expect(evade.state.fighters.right.hp).toBe(96);
 s.fighters.right.item_fx.evasion_pct = 0; s.fighters.right.status.stun = 1;
 const miss = resolvePvpExchange(s,l,r,()=>0.999999) as any;
 expect(miss.events.some((e: any)=>e.kind === "miss")).toBe(true);
 expect(miss.events.some((e: any)=>e.kind === "stun")).toBe(true);
 expect(miss.state.fighters.right.status.stun).toBe(0);
});

test("boost, vulnerability, ward, reflection and on-hit effects are applied", () => {
 const l = {...snapshot("a","sulfur"), weapon_ids:["bismuth_talisman",null]};
 const s = createPvpCombatState(l,snapshot("b","mercury"),catalogs) as any;
 s.fighters.left.status.atk_boost = 0.2; s.fighters.right.status.vuln_pct = 0.2;
 s.fighters.right.status.shield_pct = 0.5; s.fighters.right.status.reflect_pct = 0.5;
 const result = resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(result.events.some((e: any)=>e.kind === "reflect")).toBe(true);
 expect(result.events.some((e: any)=>e.kind === "true_on_hit")).toBe(true);
 expect(result.state.fighters.left.status.atk_boost).toBe(0);
 expect(result.state.fighters.right.status.vuln_pct).toBe(0);
 expect(result.state.fighters.right.status.shield_pct).toBe(0);
 expect(result.state.fighters.right.status.reflect_pct).toBe(0);
});

test("invalid decisions and RNG fail without modifying input", () => {
 const s = setup(), before = structuredClone(s);
 expect(resolvePvpExchange(s,{turn:2,spell_id:"cinder_fist"},{turn:1,spell_id:"silver_needle"},()=>0.5)).toEqual({error:"INVALID_DECISION"});
 expect(resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"silver_needle"},()=>1)).toEqual({error:"INVALID_RNG"});
 expect(s).toEqual(before);
});

test("three headless Godot exchange fixtures match damage, cooldowns, statuses and event order", () => {
 const fixtures = [
  {left:"sulfur",right:"mercury",a:"cinder_fist",b:"silver_needle",hp:[96,81],damage:[15,8],draws:[0.5,0,0.5,0.5],proc:"atk_down"},
  {left:"aether",right:"sodium",a:"rift_touch",b:"crystal_ram",hp:[93,101],damage:[11,9],draws:[0.5,0,0.5,0.5],proc:"vuln_pct"},
  {left:"vitriol",right:"gold",a:"etching_fang",b:"aurum_edge",hp:[93,93],damage:[11,11],draws:[0.5,0.5,0.5,0.5],proc:null},
 ];
 for (const f of fixtures) {
  const s = createPvpCombatState(snapshot("a",f.left),snapshot("b",f.right),catalogs) as any;
  const out = resolvePvpExchange(s,{turn:1,spell_id:f.a},{turn:1,spell_id:f.b},(_t,i)=>f.draws[i]) as any;
  expect([out.state.fighters.left.hp,out.state.fighters.right.hp]).toEqual(f.hp);
  expect([out.state.fighters.left.spell_cooldowns,out.state.fighters.right.spell_cooldowns]).toEqual([{[f.a]:0},{[f.b]:0}]);
  expect(out.events.filter((e: any)=>e.kind === "damage").map((e: any)=>e.damage)).toEqual(f.damage);
  expect(out.events.filter((e: any)=>e.kind === "spell").map((e: any)=>e.spell_id)).toEqual([f.a,f.b]);
  expect(out.events.filter((e: any)=>e.kind === "elemental_proc").map((e: any)=>e.status)).toEqual(f.proc ? [f.proc] : []);
  expect(out.state.fighters.right.status.vuln_pct).toBe(f.proc === "vuln_pct" ? 0.12 : 0);
  expect(out.state.fighters.right.status.atk_down).toBe(0);
 }
});

test("all seven real effect-free attacks resolve on either human side", () => {
 for (const [type,id] of [["sulfur","cinder_fist"],["mercury","silver_needle"],["sodium","crystal_ram"],["aether","rift_touch"],["vitriol","etching_fang"],["gold","aurum_edge"],["sulfur","steady_script"]]) {
  const source = snapshot("a",type); if (id === "steady_script") source.spell_ids[0] = id;
  for (const side of ["left","right"]) {
   const opponent = snapshot("b","mercury"), left = side === "left" ? source : {...opponent,player_id:"b"}, right = side === "left" ? opponent : {...source,player_id:"a"};
   const state = createPvpCombatState(left,right,catalogs) as any;
   const a = {turn:1,spell_id: side === "left" ? id : "silver_needle"}, b = {turn:1,spell_id: side === "right" ? id : "silver_needle"};
   const result = resolvePvpExchange(state,a,b,()=>0.5) as any;
   expect(result.events.some((e: any)=>e.kind === "damage" && e.side === side && e.spell_id === id)).toBe(true);
  }
 }
});

test("cooldown validation and ticks apply independently to each human", () => {
 const s = setup(); s.fighters.left.spells.find((x: any)=>x.id === "cinder_fist").cooldown_turns = 2;
 s.fighters.left.spell_cooldowns.old = 2; s.fighters.right.spell_cooldowns.old = 3;
 const result = resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(result.state.fighters.left.spell_cooldowns).toEqual({old:1,cinder_fist:2});
 expect(result.state.fighters.right.spell_cooldowns).toEqual({old:2,silver_needle:0});
 expect(validatePvpDecision(result.state,"left",{turn:2,spell_id:"cinder_fist"})).toEqual({error:"INVALID_DECISION"});
});

test("elemental advantage and all six on-hit passives use the acting fighter", () => {
 for (const [type, spell, status] of [["sulfur","cinder_fist","atk_down"],["mercury","silver_needle","stun"],["sodium","crystal_ram","shield_pct"],["aether","rift_touch","vuln_pct"],["vitriol","etching_fang","poison"],["gold","aurum_edge","heal"]]) {
  const s = createPvpCombatState(snapshot("a",type),snapshot("b","mercury"),catalogs) as any;
  s.fighters.left.hp -= 5;
  const draws = [0.5,0,0.5,0.5];
  const out = resolvePvpExchange(s,{turn:1,spell_id:spell},{turn:1,spell_id:"silver_needle"},(_t,i)=>draws[i] ?? 0.5) as any;
  if (status === "heal") expect(out.events.some((e: any)=>e.kind === "elemental_heal" && e.side === "left")).toBe(true);
  else expect(out.events.some((e: any)=>e.kind === "elemental_proc" && e.side === "left" && e.status === status)).toBe(true);
 }
 const s = createPvpCombatState(snapshot("a","sulfur"),snapshot("b","vitriol"),catalogs) as any;
 const out = resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"etching_fang"},()=>0.5) as any;
 expect(out.events.find((e: any)=>e.kind === "damage" && e.side === "left").effectiveness).toBeCloseTo(1.12);
 expect(out.events.find((e: any)=>e.kind === "damage" && e.side === "right").effectiveness).toBeCloseTo(0.92);
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
