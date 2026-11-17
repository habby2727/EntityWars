import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createPvpCombatState, validatePvpDecision, resolvePvpExchange, refreshPvpWeapon, resetPvpFighter, startPvpBattle, pvpInitiative } from "../pvp/combat";
const read = (n: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", n), "utf8"));
const catalogs = { entities: read("entities.json").entities, items: read("items.json").items, homunculi: read("homunculi.json").homunculi, spells: read("spells.json").spells, types: read("types.json"), mutations: read("static/mutations.json").mutations, balance: read("static/balance.json").balance };
const snapshot = (player_id: string, type: string) => ({ player_id, entity_id: `${type}_01`, weapon_ids: [null, null], homunculus_id: null, spell_ids: catalogs.spells.filter((s: any) => s.type === type).slice(0, 4).map((s: any) => s.id) });
const setup = () => createPvpCombatState(snapshot("a", "sulfur"), snapshot("b", "mercury"), catalogs) as any;
const equip = (fighter: any, id: string) => { const spell = catalogs.spells.find((s: any) => s.id === id); fighter.spells = fighter.spells.filter((s: any) => s.id !== id); fighter.spells.push(structuredClone(spell)); fighter.spell_ids[0] = id; };
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
 const s = setup(), spell = catalogs.spells.find((x: any) => x.id === "pyrolytic_fuse");
 s.fighters.left.spells.push(structuredClone(spell)); s.fighters.left.spell_ids[0] = spell.id;
 const before = structuredClone(s), l = {turn: 1, spell_id: spell.id}, r = {turn: 1, spell_id: s.fighters.right.spells[0].id};
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

test("three Godot support and attack-effect fixtures match HP, status, cooldown and event categories", () => {
 const fixtures = [
  {left:"sulfur",right:"mercury",a:"ash_temper",b:"silver_needle",hp:[94,96],damage:[10],draws:[0.775193333625793,0.54944521188736,0.714087608503178],categories:["buff","buff","buff","damage","damage"],status:"atk_boost",value:0.2,recipient:"left",cd:2,inspiration:0},
  {left:"sodium",right:"aether",a:"brine_mend",b:"rift_touch",hp:[101,102],damage:[11],draws:[0.0138160288333893,0.28386664390564,0.93741182051599],categories:["buff","buff","heal","damage","damage","debuff"],status:"vuln_pct",value:0.12,recipient:"left",cd:3,inspiration:0},
  {left:"vitriol",right:"gold",a:"caustic_mark",b:"aurum_edge",hp:[93,94],damage:[8,11],draws:[0.801872670650482,0.909451206680387,0.222710683941841,0.41610933537595],categories:["damage","damage","debuff","inspiration","damage","damage","debuff"],status:"poison",value:1,recipient:"right",cd:2,inspiration:1},
 ];
 for (const f of fixtures) {
  const s = createPvpCombatState(snapshot("a",f.left),snapshot("b",f.right),catalogs) as any;
  if (f.a === "brine_mend") s.fighters.left.hp = 105;
  const used: number[] = [];
  const out = resolvePvpExchange(s,{turn:1,spell_id:f.a},{turn:1,spell_id:f.b},(_t,i)=>{used.push(i); return f.draws[i];}) as any;
  expect(used).toEqual(f.draws.map((_v,i)=>i));
  expect([out.state.fighters.left.hp,out.state.fighters.right.hp]).toEqual(f.hp);
  expect(out.state.fighters[f.recipient].status[f.status]).toBe(f.value);
  expect(out.state.fighters.left.spell_cooldowns[f.a]).toBe(f.cd);
  expect(out.state.fighters.right.spell_cooldowns[f.b]).toBe(0);
  expect(out.state.fighters.left.inspiration).toBe(f.inspiration);
  expect(out.events.filter((e: any)=>e.kind === "damage").map((e: any)=>e.damage)).toEqual(f.damage);
  expect(out.events.map((e: any)=>e.category)).toEqual(f.categories);
  expect(out.events[0]).toMatchObject({spell_meta:{id:f.a,context:{spell:{id:f.a}}},spell_id:f.a,category:f.categories[0]});
 }
});

test("shield provenance, neutralization, cleanse priority and toxic reflection", () => {
 const s = setup(); equip(s.fighters.left,"clear_thread"); equip(s.fighters.right,"liquid_decoy");
 s.fighters.left.status.poison = 2; s.fighters.left.status.vuln_pct = 0.4; s.fighters.left.status.atk_down = 0.3;
 let out = resolvePvpExchange(s,{turn:1,spell_id:"clear_thread"},{turn:1,spell_id:"liquid_decoy"},()=>0.5) as any;
 expect(out.state.fighters.left.status.poison).toBe(0); expect(out.state.fighters.left.status.vuln_pct).toBe(0.4);
 expect(out.state.fighters.right.status.shield_pct).toBe(0.18); expect((out.state.fighters.right as any).spell_ward).toBe(0.18);
 equip(out.state.fighters.left,"cinder_fist"); equip(out.state.fighters.right,"silver_needle");
 out = resolvePvpExchange(out.state,{turn:2,spell_id:"cinder_fist"},{turn:2,spell_id:"silver_needle"},()=>0.5) as any;
 expect(out.state.fighters.right.status.shield_pct).toBe(0); expect((out.state.fighters.right as any).spell_ward).toBeUndefined();
 const t = createPvpCombatState(snapshot("a","aether"),snapshot("b","sulfur"),catalogs) as any;
 out = resolvePvpExchange(t,{turn:1,spell_id:"paradox_fold"},{turn:1,spell_id:"cinder_fist"},()=>0.5) as any;
 expect(out.state.fighters.left.spell_neutralize_pending).toBe(0.5);
 const t2 = out.state; equip(t2.fighters.left,"rift_touch");
 out = resolvePvpExchange(t2,{turn:2,spell_id:"rift_touch"},{turn:2,spell_id:"cinder_fist"},()=>0.5) as any;
 expect(out.events.find((e: any)=>e.kind === "damage" && e.side === "left").effectiveness).toBeCloseTo(1.06);
 expect(out.state.fighters.left.spell_neutralize_pending).toBe(0);
 const m = createPvpCombatState(snapshot("a","mercury"),snapshot("b","sulfur"),catalogs) as any; equip(m.fighters.left,"toxic_mirror");
 out = resolvePvpExchange(m,{turn:1,spell_id:"toxic_mirror"},{turn:1,spell_id:"cinder_fist"},()=>0.5) as any;
 expect(out.events.some((e: any)=>e.kind === "reflect")).toBe(true);
 expect(out.events.some((e: any)=>e.kind === "poison" && e.side === "right" && e.damage === 2)).toBe(true);
 expect(out.state.fighters.right.status.poison).toBe(0);
 expect(out.state.fighters.right.hp).toBeLessThan(104);
});

test("inspiration increases only on stronger opposing debuffs and blocks the next exchange at three", () => {
 let state = createPvpCombatState(snapshot("a","vitriol"),snapshot("b","gold"),catalogs) as any;
 state.fighters.left.inspiration = 2; state.fighters.right.status.poison = 0;
 const out = resolvePvpExchange(state,{turn:1,spell_id:"caustic_mark"},{turn:1,spell_id:"aurum_edge"},()=>0.5) as any;
 expect(out.state.fighters.left.inspiration).toBe(3); expect(out.state.fighters.left.inspiration_pending).toBe(true);
 expect(out.events.find((e: any)=>e.kind === "inspiration")).toMatchObject({side:"left",value:3,source:"poison"});
 const before = structuredClone(out.state); let draws = 0;
 expect(resolvePvpExchange(out.state,{turn:2,spell_id:"etching_fang"},{turn:2,spell_id:"aurum_edge"},()=>{draws++;return 0.5;})).toEqual({error:"PVP_COMBAT_PARITY_UNAVAILABLE"});
 expect(draws).toBe(0); expect(out.state).toEqual(before);
 state.fighters.right.status.poison = 3;
 const unchanged = resolvePvpExchange(state,{turn:1,spell_id:"caustic_mark"},{turn:1,spell_id:"aurum_edge"},()=>0.5) as any;
 expect(unchanged.state.fighters.left.inspiration).toBe(2);
 state.fighters.right.status.poison = 0;
 const values = [0.5,0,0.5,0.5];
 const passiveFirst = resolvePvpExchange(state,{turn:1,spell_id:"caustic_mark"},{turn:1,spell_id:"aurum_edge"},(_t,i)=>values[i]) as any;
 expect(passiveFirst.state.fighters.left.inspiration).toBe(2);
});

test("three successive different debuffs accrue inspiration from zero", () => {
 let state = setup();
 for (const [index,id] of ["brimstone_crash","crooked_rune","fuming_distillate"].entries()) {
  equip(state.fighters.left,id);
  const out = resolvePvpExchange(state,{turn:index+1,spell_id:id},{turn:index+1,spell_id:"silver_needle"},()=>0.5) as any;
  expect(out.state.fighters.left.inspiration).toBe(index+1);
  expect(out.events.find((e: any)=>e.kind === "inspiration").value).toBe(index+1);
  state = out.state;
 }
 expect(state.fighters.left.inspiration_pending).toBe(true);
});

test("all catalog spells restricted to the fourteen supported effect kinds resolve", () => {
 const supported = new Set(["heal","shield","reflect","atk_boost","atk_down","vuln","poison","hom_stun","type_neutralize","focus_next","misalign_next","tempo_shift","cleanse_one","poison_on_reflect"]);
 const spells = catalogs.spells.filter((s: any)=>s.effects.every((e: any)=>supported.has(e.kind)));
 expect(spells).toHaveLength(45);
 for (const spell of spells) {
  const type = ["universal","hybrid"].includes(spell.type) ? spell.eligible_types[0] : spell.type;
  for (const side of ["left","right"] as const) {
   const a = snapshot("a",type), b = snapshot("b","gold"), state = createPvpCombatState(side === "left" ? a : b, side === "left" ? b : a, catalogs) as any;
   equip(state.fighters[side],spell.id);
   const selected = {turn:1,spell_id:spell.id}, other = {turn:1,spell_id:"aurum_edge"};
   const out = resolvePvpExchange(state,side === "left" ? selected : other,side === "left" ? other : selected,()=>0.5) as any;
   expect(out.error).toBeUndefined(); expect(out.events.some((e: any)=>e.kind === "spell" && e.side === side && e.spell_id === spell.id)).toBe(true);
  }
 }
});

test("all 66 supported catalog spells resolve on both human sides", () => {
 const kinds = new Set(["heal","shield","reflect","atk_boost","atk_down","vuln","poison","hom_stun","type_neutralize","focus_next","misalign_next","tempo_shift","cleanse_one","poison_on_reflect","bonus_if_poisoned","bonus_if_hit_last_exchange","bonus_if_low_hp","bonus_if_marked","bonus_power_if_poisoned","bonus_if_shielded","bonus_power_if_hit_last_exchange","pierce_ward","ward_dispel","recoil","life_leech","consume_poison","hybrid_mark","shield_by_order","ward_convert"]);
 const spells = catalogs.spells.filter((s: any)=>s.effects.every((e: any)=>kinds.has(e.kind)));
 expect(spells).toHaveLength(66);
 for (const spell of spells) {
  const type = ["universal","hybrid"].includes(spell.type) ? spell.eligible_types[0] : spell.type;
  for (const side of ["left","right"] as const) {
   const a = snapshot("a",type), b = snapshot("b","gold"), state = createPvpCombatState(side === "left" ? a : b, side === "left" ? b : a, catalogs) as any;
   equip(state.fighters[side],spell.id);
   const selected = {turn:1,spell_id:spell.id}, other = {turn:1,spell_id:"aurum_edge"};
   const out = resolvePvpExchange(state,side === "left" ? selected : other,side === "left" ? other : selected,()=>0.5) as any;
   expect(out.error).toBeUndefined();
   expect(out.events.some((e: any)=>e.kind === "spell" && e.side === side && e.spell_id === spell.id)).toBe(true);
   expect(out.events.some((e: any)=>e.kind === "miss" && e.side === side && e.spell_id === spell.id)).toBe(false);
   expect(out.events.some((e: any)=>e.kind === (spell.category === "attack" ? "damage" : "support_hit") && e.side === side && e.spell_id === spell.id)).toBe(true);
  }
 }
});

test("four headless Godot advanced fixtures match HP, cooldowns, statuses and draw order", () => {
 const common = [0.0973597019910812,0.519018752966076,0.342859894037247,0.339055563090369];
 const fixtures = [
  {left:"gold",right:"sodium",a:"gilded_exception",b:"crystal_ram",mode:"mark",hp:[96,97],damage:[15,8],draws:common,cd:3},
  {left:"aether",right:"sodium",a:"crystal_dividend",b:"crystal_ram",mode:"ward",hp:[102,81],damage:[13],draws:[0.167608201503754,0.540733559522778,0.988577008247375],cd:3},
  {left:"sulfur",right:"mercury",a:"last_axiom",b:"silver_needle",mode:"recoil",hp:[0,72],damage:[24],draws:common.slice(0,2),cd:3},
  {left:"sulfur",right:"mercury",a:"echo_siphon",b:"silver_needle",mode:"leech",hp:[52,85],damage:[11,10],draws:common,cd:2},
 ];
 for (const f of fixtures) {
  const s = createPvpCombatState(snapshot("a",f.left),snapshot("b",f.right),catalogs) as any; equip(s.fighters.left,f.a);
  if (f.mode === "mark") s.fighters.right.status.hybrid_mark = {owner:"left",remaining:2};
  if (f.mode === "ward") Object.assign(s.fighters.left,{spell_ward:0.3,spell_ward_baseline:0.1,weapon_shield_pct:0.2,other_shield_pct:0.35}), s.fighters.left.status.shield_pct=0.35;
  if (f.mode === "recoil") s.fighters.left.hp=4;
  if (f.mode === "leech") s.fighters.left.hp=60;
  const seen: number[] = [];
  const out = resolvePvpExchange(s,{turn:1,spell_id:f.a},{turn:1,spell_id:f.b},(_t,i)=>{seen.push(i);return f.draws[i];}) as any;
  expect(seen).toEqual(f.draws.map((_v,i)=>i));
  expect([out.state.fighters.left.hp,out.state.fighters.right.hp]).toEqual(f.hp);
  expect(out.state.fighters.left.spell_cooldowns[f.a]).toBe(f.cd);
  expect(out.events.filter((e: any)=>e.kind === "damage").map((e: any)=>e.damage)).toEqual(f.damage);
  if (f.mode === "mark") { expect(out.state.fighters.right.status.hybrid_mark).toBeUndefined(); expect(out.events.map((e: any)=>e.kind)).toEqual(["mark_tick","spell","damage","mark_consumed","spell","damage"]); }
  if (f.mode === "ward") { expect(out.state.fighters.left.status.shield_pct).toBe(0.2); expect(out.state.fighters.left.other_shield_pct).toBe(0.1); expect(out.state.fighters.left.spell_ward).toBeUndefined(); expect(out.events.find((e: any)=>e.kind === "ward_convert").damage).toBe(18); }
  if (f.mode === "recoil") { expect(out.state.battle_result).toBe("right"); expect(out.state.fighters.right.spell_cooldowns).toEqual({}); expect(out.events.some((e: any)=>e.kind === "recoil")).toBe(true); }
  if (f.mode === "leech") expect(out.events.find((e: any)=>e.kind === "life_leech_heal").amount).toBe(2);
 }
});

test("conditional modifiers use poison, prior hits, marks and HP before the hit", () => {
 const attack = (type: string, id: string, change: (s: any)=>void) => {
  const s = createPvpCombatState(snapshot("a",type),snapshot("b","gold"),catalogs) as any; equip(s.fighters.left,id); change(s);
  const out = resolvePvpExchange(s,{turn:1,spell_id:id},{turn:1,spell_id:"aurum_edge"},()=>0.5) as any;
  return out.events.find((e: any)=>e.kind === "damage" && e.side === "left").damage;
 };
 for (const [type,id,boost] of [
  ["vitriol","rot_harvest",(s: any)=>{s.fighters.right.status.poison=2;}],
  ["gold","tribunal_strike",(s: any)=>{s.fighters.left.spell_hit_this_exchange=true;}],
  ["gold","silver_debt",(s: any)=>{s.fighters.left.spell_hit_this_exchange=true;}],
  ["gold","gilded_exception",(s: any)=>{s.fighters.right.status.hybrid_mark={owner:"left",remaining:2};}],
  ["vitriol","caustic_paradox",(s: any)=>{s.fighters.right.status.poison=2;}],
  ["vitriol","corrosive_tribute",(s: any)=>{s.fighters.right.status.poison=2;}],
  ["sulfur","last_axiom",(s: any)=>{s.fighters.left.hp=30;}],
 ] as [string,string,(s: any)=>void][]) {
  expect(attack(type,id,boost)).toBeGreaterThan(attack(type,id,()=>{}));
 }
 const s = createPvpCombatState(snapshot("a","vitriol"),snapshot("b","gold"),catalogs) as any; equip(s.fighters.left,"corrosive_tribute");
 const draws = [0.5,0,0.5,0.5];
 const out = resolvePvpExchange(s,{turn:1,spell_id:"corrosive_tribute"},{turn:1,spell_id:"aurum_edge"},(_t,i)=>draws[i]) as any;
 const noProc = resolvePvpExchange(s,{turn:1,spell_id:"corrosive_tribute"},{turn:1,spell_id:"aurum_edge"},()=>0.5) as any;
 expect(out.events.find((e: any)=>e.kind === "damage" && e.side === "left").damage).toBe(noProc.events.find((e: any)=>e.kind === "damage" && e.side === "left").damage);
 expect(out.state.fighters.right.status.poison).toBe(1);
 expect(out.events.some((e: any)=>e.kind === "consume_poison")).toBe(false);
});

test("ward pierce, dispel, initiative shields and conversion preserve defenses", () => {
 for (const [type,id,expected] of [["sulfur","needle_etch",9],["mercury","quicksilver_solvent",7]] as const) {
  const s = createPvpCombatState(snapshot("a",type),snapshot("b",type === "sulfur" ? "gold" : "sulfur"),catalogs) as any;
  equip(s.fighters.left,id); s.fighters.right.status.shield_pct=0.5;
  const right = type === "sulfur" ? "aurum_edge" : "cinder_fist";
  const out = resolvePvpExchange(s,{turn:1,spell_id:id},{turn:1,spell_id:right},()=>0.5) as any;
  expect(out.events.find((e: any)=>e.kind === "damage" && e.side === "left").damage).toBe(expected);
  expect(out.state.fighters.right.status.shield_pct).toBe(0);
 }
 for (const second of [false,true]) {
  const s = createPvpCombatState(snapshot("a","mercury"),snapshot("b","sulfur"),catalogs) as any; equip(s.fighters.left,"fluid_anchor");
  if (second) s.fighters.right.status.tempo_bonus=1;
  const out = resolvePvpExchange(s,{turn:1,spell_id:"fluid_anchor"},{turn:1,spell_id:"ash_temper"},()=>0.5) as any;
  expect(out.state.fighters.left.status.shield_pct).toBe(second ? 0.18 : 0.08);
 }
 const s = createPvpCombatState(snapshot("a","gold"),snapshot("b","sodium"),catalogs) as any; equip(s.fighters.left,"gilded_lien");
 Object.assign(s.fighters.left,{spell_ward:0.3,spell_ward_baseline:0.1}); s.fighters.left.status.shield_pct=0.3;
 const out = resolvePvpExchange(s,{turn:1,spell_id:"gilded_lien"},{turn:1,spell_id:"brine_mend"},()=>0.5) as any;
 expect(out.events.find((e: any)=>e.kind === "ward_convert").damage).toBe(14);
 expect(out.state.fighters.left.status.shield_pct).toBe(0.1); expect(out.state.fighters.left.spell_ward).toBe(0.08);
});

test("hybrid mark belongs to its caster, expires on their actions and consumes only on hybrid hit", () => {
 const s = createPvpCombatState(snapshot("a","aether"),snapshot("b","gold"),catalogs) as any; equip(s.fighters.left,"paradox_edict");
 let out = resolvePvpExchange(s,{turn:1,spell_id:"paradox_edict"},{turn:1,spell_id:"aurum_edge"},()=>0.5) as any;
 expect(out.state.fighters.right.status.hybrid_mark).toEqual({owner:"left",remaining:2}); expect(out.state.fighters.left.inspiration).toBe(1);
 equip(out.state.fighters.left,"rift_touch");
 out = resolvePvpExchange(out.state,{turn:2,spell_id:"rift_touch"},{turn:2,spell_id:"aurum_edge"},()=>0.5) as any;
 expect(out.state.fighters.right.status.hybrid_mark).toEqual({owner:"left",remaining:1});
 const miss = resolvePvpExchange(out.state,{turn:3,spell_id:"rift_touch"},{turn:3,spell_id:"aurum_edge"},()=>0.999) as any;
 expect(miss.state.fighters.right.status.hybrid_mark).toBeUndefined();
 const s2 = createPvpCombatState(snapshot("a","gold"),snapshot("b","sodium"),catalogs) as any; equip(s2.fighters.left,"gilded_exception");
 s2.fighters.right.status.hybrid_mark={owner:"right",remaining:2};
 const opposite = resolvePvpExchange(s2,{turn:1,spell_id:"gilded_exception"},{turn:1,spell_id:"crystal_ram"},()=>0.5) as any;
 expect(opposite.state.fighters.right.status.hybrid_mark).toEqual({owner:"right",remaining:2});
 s2.fighters.right.status.hybrid_mark={owner:"left",remaining:2};
 const missed = resolvePvpExchange(s2,{turn:1,spell_id:"gilded_exception"},{turn:1,spell_id:"crystal_ram"},()=>0.999) as any;
 expect(missed.state.fighters.right.status.hybrid_mark).toEqual({owner:"left",remaining:1});
 expect(missed.events.some((e: any)=>e.kind === "mark_consumed")).toBe(false);
 s2.fighters.left.status.stun=1;
 const stunned = resolvePvpExchange(s2,{turn:1,spell_id:"gilded_exception"},{turn:1,spell_id:"crystal_ram"},()=>0.5) as any;
 expect(stunned.state.fighters.right.status.hybrid_mark).toEqual({owner:"left",remaining:1});
 expect(stunned.events.some((e: any)=>e.kind === "mark_consumed")).toBe(false);
});

test("ultra scales recoil, marks, order shields and leech caps but not conversion rate", () => {
 for (const ultra of [false,true]) {
  let s = createPvpCombatState(snapshot("a","sulfur"),snapshot("b","sodium"),catalogs) as any;
  s.battle_index=3; s.wins={left:1,right:1}; equip(s.fighters.left,"echo_siphon");
  s.fighters.left.atk=100; s.fighters.left.hp=30; s.fighters.right.hp=s.fighters.right.max_hp=300;
  let out = resolvePvpExchange(s,{turn:1,spell_id:"echo_siphon",ultra},{turn:1,spell_id:"brine_mend"},()=>0.5) as any;
  expect(out.events.find((e: any)=>e.kind === "life_leech_heal").amount).toBe(ultra ? 10 : 5);
  s = createPvpCombatState(snapshot("a","aether"),snapshot("b","sodium"),catalogs) as any;
  s.battle_index=3; s.wins={left:1,right:1}; equip(s.fighters.left,"paradox_edict");
  out = resolvePvpExchange(s,{turn:1,spell_id:"paradox_edict",ultra},{turn:1,spell_id:"brine_mend"},()=>0.5) as any;
  expect(out.state.fighters.right.status.hybrid_mark.remaining).toBe(ultra ? 4 : 2);
  s = createPvpCombatState(snapshot("a","mercury"),snapshot("b","sulfur"),catalogs) as any;
  s.battle_index=3; s.wins={left:1,right:1}; equip(s.fighters.left,"fluid_anchor"); s.fighters.right.status.tempo_bonus=1;
  out = resolvePvpExchange(s,{turn:1,spell_id:"fluid_anchor",ultra},{turn:1,spell_id:"ash_temper"},()=>0.5) as any;
  expect(out.state.fighters.left.status.shield_pct).toBe(ultra ? 0.36 : 0.18);
  s = createPvpCombatState(snapshot("a","gold"),snapshot("b","sodium"),catalogs) as any;
  s.battle_index=3; s.wins={left:1,right:1}; equip(s.fighters.left,"gilded_lien");
  Object.assign(s.fighters.left,{spell_ward:0.3,spell_ward_baseline:0.1}); s.fighters.left.status.shield_pct=0.3;
  out = resolvePvpExchange(s,{turn:1,spell_id:"gilded_lien",ultra},{turn:1,spell_id:"brine_mend"},()=>0.5) as any;
  expect(out.events.find((e: any)=>e.kind === "ward_convert").damage).toBe(14);
 }
 const s = setup(); s.battle_index=3; s.wins={left:1,right:1}; equip(s.fighters.left,"last_axiom"); s.fighters.left.hp=6;
 const lethal = resolvePvpExchange(s,{turn:1,spell_id:"last_axiom",ultra:true},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(lethal.state.fighters.left.hp).toBe(0); expect(lethal.events.find((e: any)=>e.kind === "recoil").damage).toBe(8);
 const capped = setup(); equip(capped.fighters.left,"echo_siphon"); capped.fighters.left.hp=50; capped.fighters.right.hp=3;
 const hit = resolvePvpExchange(capped,{turn:1,spell_id:"echo_siphon"},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(hit.events.find((e: any)=>e.kind === "spell").spell_meta.context.actual_damage).toBe(3);
 expect(hit.events.find((e: any)=>e.kind === "life_leech_heal").amount).toBe(0);
 const poison = createPvpCombatState(snapshot("a","vitriol"),snapshot("b","gold"),catalogs) as any;
 poison.battle_index=3; poison.wins={left:1,right:1}; equip(poison.fighters.left,"corrosive_tribute"); poison.fighters.right.status.poison=3;
 const tribute = resolvePvpExchange(poison,{turn:1,spell_id:"corrosive_tribute",ultra:true},{turn:1,spell_id:"aurum_edge"},()=>0.5) as any;
 expect(tribute.state.fighters.right.status.poison).toBe(1);
});

test("malformed advanced fields and marks fail before RNG without mutating either side", () => {
 for (const [id,field,value] of [["last_axiom","threshold",1.1],["echo_siphon","max_heal",-1],["fluid_anchor","second_value",null],["paradox_edict","value",0]] as const) {
  const type = id === "fluid_anchor" ? "mercury" : id === "paradox_edict" ? "aether" : "sulfur";
  const state = createPvpCombatState(snapshot("a",type),snapshot("b","gold"),catalogs) as any; equip(state.fighters.left,id);
  state.fighters.left.spells.find((s: any)=>s.id === id).effects[0][field]=value;
  const before = structuredClone(state); let draws=0;
  expect(resolvePvpExchange(state,{turn:1,spell_id:id},{turn:1,spell_id:"aurum_edge"},()=>{draws++;return 0.5;})).toEqual({error:"PVP_COMBAT_PARITY_UNAVAILABLE"});
  expect(draws).toBe(0); expect(state).toEqual(before);
 }
 const state = setup(); state.fighters.right.status.hybrid_mark={owner:"unknown",remaining:1}; let draws=0;
 expect(resolvePvpExchange(state,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"silver_needle"},()=>{draws++;return 0.5;})).toEqual({error:"PVP_COMBAT_PARITY_UNAVAILABLE"});
 expect(draws).toBe(0);
});

test("ultra scales support effects; stun and misses prevent effects", () => {
 const s = setup(); s.battle_index = 3; s.wins = {left:1,right:1};
 let out = resolvePvpExchange(s,{turn:1,spell_id:"ash_temper",ultra:true},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(out.state.fighters.left.status.atk_boost).toBe(0.4); expect(out.state.fighters.left.ultra_used).toBe(true);
 const stunned = setup(); stunned.fighters.left.status.stun = 1;
 out = resolvePvpExchange(stunned,{turn:1,spell_id:"ash_temper"},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(out.state.fighters.left.status.atk_boost).toBe(0); expect(out.state.fighters.left.spell_cooldowns.ash_temper).toBe(2);
 const miss = setup(); equip(miss.fighters.left,"crooked_rune");
 out = resolvePvpExchange(miss,{turn:1,spell_id:"crooked_rune"},{turn:1,spell_id:"silver_needle"},()=>0.999) as any;
 expect(out.state.fighters.right.status.misalign_next).toBeUndefined(); expect(out.state.fighters.left.inspiration).toBe(0);
});

test("focus, misalignment, tempo and homunculus stun affect their recipient independently", () => {
 let s = setup(); equip(s.fighters.left,"quiet_focus"); equip(s.fighters.right,"crooked_rune");
 let out = resolvePvpExchange(s,{turn:1,spell_id:"quiet_focus"},{turn:1,spell_id:"crooked_rune"},()=>0.5) as any;
 expect(out.state.fighters.left.status.focus_next).toBe(0.12);
 expect(out.state.fighters.left.status.misalign_next).toBe(0.10);
 expect(out.state.fighters.right.inspiration).toBe(1);
 equip(out.state.fighters.left,"cinder_fist"); equip(out.state.fighters.right,"silver_needle");
 out = resolvePvpExchange(out.state,{turn:2,spell_id:"cinder_fist"},{turn:2,spell_id:"silver_needle"},()=>0.5) as any;
 expect(out.state.fighters.left.status.focus_next).toBeUndefined(); expect(out.state.fighters.left.status.misalign_next).toBeUndefined();
 s = createPvpCombatState(snapshot("a","aether"),snapshot("b","mercury"),catalogs) as any;
 out = resolvePvpExchange(s,{turn:1,spell_id:"null_stitch"},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(out.state.fighters.right.status.hom_stun).toBe(1); expect(out.state.fighters.left.inspiration).toBe(1);
 s = setup(); equip(s.fighters.left,"second_measure");
 out = resolvePvpExchange(s,{turn:1,spell_id:"second_measure"},{turn:1,spell_id:"silver_needle"},()=>0.5) as any;
 expect(out.state.fighters.left.status.tempo_bonus).toBe(2);
 equip(out.state.fighters.left,"cinder_fist");
 const later = resolvePvpExchange(out.state,{turn:2,spell_id:"cinder_fist"},{turn:2,spell_id:"silver_needle"},()=>0.5) as any;
 expect(later.events.find((e: any)=>e.kind === "spell").side).toBe("left");
 expect(later.state.fighters.left.status.tempo_bonus).toBe(0);
});

test("effect preflight rejects either unsupported decision before RNG and ultra clamps shields", () => {
 const s = setup(); equip(s.fighters.right,"pyrolytic_fuse");
 const saved = structuredClone(s); let count = 0;
 expect(resolvePvpExchange(s,{turn:1,spell_id:"ash_temper"},{turn:1,spell_id:"pyrolytic_fuse"},()=>{count++;return 0.5;})).toEqual({error:"PVP_COMBAT_PARITY_UNAVAILABLE"});
 expect(count).toBe(0); expect(s).toEqual(saved);
 const t = setup(); t.battle_index = 3; t.wins = {left:1,right:1};
 const shield = t.fighters.right.spells.find((x: any)=>x.id === "liquid_decoy"); shield.effects[0].value = 0.8;
 const out = resolvePvpExchange(t,{turn:1,spell_id:"ash_temper"},{turn:1,spell_id:"liquid_decoy",ultra:true},()=>0.5) as any;
 expect(out.state.fighters.right.status.shield_pct).toBe(0.95);
 const p = createPvpCombatState(snapshot("a","vitriol"),snapshot("b","gold"),catalogs) as any;
 p.battle_index = 3; p.wins = {left:1,right:1};
 const poisoned = resolvePvpExchange(p,{turn:1,spell_id:"caustic_mark",ultra:true},{turn:1,spell_id:"aurum_edge"},()=>0.5) as any;
 expect(poisoned.state.fighters.right.status.poison).toBe(3);
 const n = createPvpCombatState(snapshot("a","aether"),snapshot("b","sulfur"),catalogs) as any;
 n.battle_index = 3; n.wins = {left:1,right:1};
 const neutral = resolvePvpExchange(n,{turn:1,spell_id:"paradox_fold",ultra:true},{turn:1,spell_id:"cinder_fist"},()=>0.5) as any;
 expect(neutral.state.fighters.left.spell_neutralize_pending).toBe(1);
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
