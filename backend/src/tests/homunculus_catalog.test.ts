import { expect, test } from "bun:test";
import original from "../../../data/homunculi.json";
import manifest from "../../../data/static/expedition_homunculi.json";
import types from "../../../data/types.json";
import entities from "../../../data/entities.json";
import items from "../../../data/items.json";
import spells from "../../../data/spells.json";
import bosses from "../../../data/static/solo_bosses.json";
import mutations from "../../../data/static/mutations.json";
import balance from "../../../data/static/balance.json";
import { buildHomunculusCombatCatalog, homunculusCatalog, legacyHomunculusIds, expeditionHomunculusIds, ownsHomunculus, combatHomunculusAllowed, homunculusAttackMultiplier } from "../homunculus_catalog";
import { buildTrustedCombatSetup, createCombatState, resolveCombatTurn } from "../solo_hunt_combat";
import { trustedPvpSnapshot } from "../pvp/service";
import { createPvpCombatState, resolvePvpExchange } from "../pvp/combat";
import { createDungeonCombatState, resolveDungeonTurn } from "../dungeon_combat";
const catalogs = {entities:entities.entities, items:items.items, spells:spells.spells, types, mutations:mutations.mutations, balance:balance.balance, bosses:bosses.bosses, homunculi:homunculusCatalog().all};
const ids = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
const selection = {entity_id:"sulfur_01", weapon_ids:["bismuth_talisman","wind_amulet"], homunculus_id:"cinder", spell_ids:ids, mode:"attack"};
const state = {player_id:"a", state_revision:0, boss_id:"hunt_common", boss_entity_id:"sodium_01", item_progress:{}, homunculus_progress:{}, spell_progress:{}};
test("validated catalog preserves legacy and isolates balanced expedition records", () => {
 const c = homunculusCatalog(); expect(c.all).toHaveLength(22); expect(legacyHomunculusIds().size).toBe(8); expect(expeditionHomunculusIds().size).toBe(14); expect(c.originals).toEqual(original.homunculi); expect(new Set(c.all.map((h:any) => h.id)).size).toBe(22);
 for (const h of c.expedition) { expect([h.buff_hp,h.buff_atk,h.buff_def]).toEqual([1,1,1]); expect(Object.keys(h.per_type).length).toBe(6); expect(h.passive).toEqual(manifest.homunculi.find(e => e.id === h.id)!.passive); }
 c.originals[0].buff_atk=999; expect(homunculusCatalog().originals).toEqual(original.homunculi);
 const missing=structuredClone(original); missing.homunculi.pop(); expect(()=>buildHomunculusCombatCatalog(missing,manifest)).toThrow();
 const dup=structuredClone(original); dup.homunculi[1].id=dup.homunculi[0].id; expect(()=>buildHomunculusCombatCatalog(dup,manifest)).toThrow();
 const corrupt=structuredClone(original); corrupt.homunculi[0].buff_atk=NaN; expect(()=>buildHomunculusCombatCatalog(corrupt,manifest)).toThrow();
 const wrong:any=structuredClone(manifest); wrong.homunculi[0].type="missing"; expect(()=>buildHomunculusCombatCatalog(original,wrong)).toThrow(); wrong.homunculi[0].type="aether"; wrong.homunculi[0].passive.event="invalid"; expect(()=>buildHomunculusCombatCatalog(original,wrong)).toThrow();
});
test("ownership is strict for expedition selections", () => {
 expect(ownsHomunculus({},"cinder")).toBe(true); expect(ownsHomunculus({},"astralotl")).toBe(false); expect(ownsHomunculus({},"unknown")).toBe(false);
 for (const value of [null, 1, "true", {owned:1}, {owned:false}, {owned:true,xp:-1}, {owned:true,level:3,xp:0}, {owned:true,level:100}, {owned:true,mutation_id:17}, {owned:true,level:3,mutation_id:"unknown"}, {owned:true,level:0,mutation_id:"vitality"}]) expect(ownsHomunculus({astralotl:value},"astralotl")).toBe(false);
 expect(ownsHomunculus({astralotl:{owned:true, level:3, xp:550}},"astralotl")).toBe(true); expect(combatHomunculusAllowed({astralotl:{owned:true}},"astralotl")).toBe(false); expect(combatHomunculusAllowed({astralotl:{owned:true,level:0,xp:0}},"astralotl")).toBe(true); expect(combatHomunculusAllowed({cinder:{level:2}},"cinder")).toBe(true); expect(combatHomunculusAllowed({cinder:null},"cinder")).toBe(false);
});
test("trusted Hunt, Dungeon and Ranked accept only persisted ownership", () => {
 const legacy = trustedPvpSnapshot("a",selection,state,catalogs as any);
 expect(legacy).not.toBeNull(); expect(legacy!.weapon_ids).toEqual(selection.weapon_ids);
 expect(trustedPvpSnapshot("b",selection,state,catalogs as any)).toBeNull();
 for (const id of expeditionHomunculusIds()) {
  const progress = {[id]:{owned:true,level:3,xp:550}};
  const selected={...selection,homunculus_id:id};
  const owned={...state,homunculus_progress:progress};
  const hunt=buildTrustedCombatSetup(owned,selected,catalogs,{independentLoadout:true});
  expect(hunt.error).toBeUndefined();
  const dungeon=createDungeonCombatState(hunt,{floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:ids},catalogs);
  expect(dungeon.player.hom_id).toBe(id);
  const ranked=trustedPvpSnapshot("a",selected,owned,catalogs as any);
  expect(ranked?.homunculus_id).toBe(id);
  expect((createPvpCombatState(ranked!,{...legacy!,player_id:"b"},catalogs as any) as any).error).toBeUndefined();
  const locked={...state,homunculus_progress:{[id]:{owned:false,level:3,xp:550}}};
  expect(buildTrustedCombatSetup(locked,selected,catalogs,{independentLoadout:true})).toEqual({error:"UNTRUSTED_SETUP"});
  expect(trustedPvpSnapshot("a",selected,locked,catalogs as any)).toBeNull();
  expect(buildTrustedCombatSetup(state,selected,catalogs,{independentLoadout:true})).toEqual({error:"UNTRUSTED_SETUP"});
 }
 expect(trustedPvpSnapshot("a",{...selection,owned:true},state,catalogs as any)).toBeNull();
 expect(buildTrustedCombatSetup(state,{...selection,owned:true},catalogs,{independentLoadout:true})).toEqual({error:"UNTRUSTED_SETUP"});
 expect(buildTrustedCombatSetup({...state,homunculus_progress:{cinder:{level:2,xp:-1}}},selection,catalogs,{independentLoadout:true})).toEqual({error:"UNTRUSTED_SETUP"});
});
test("elemental multiplier covers six types and neutralization", () => {
 const c=homunculusCatalog(); for (const h of c.originals) expect(homunculusAttackMultiplier(h,"gold",types,[1])).toBe(1);
 for (const h of c.expedition) for (const target of types.types) { const relation=(types.effectiveness as any)[h.type][target.id]; const expected=relation>1?1.18:relation<1?0.84:1; expect(homunculusAttackMultiplier(h,target.id,types)).toBeCloseTo(expected); expect(homunculusAttackMultiplier(h,target.id,types,[0.25,0.5])).toBeCloseTo(1+(expected-1)*0.5); expect(homunculusAttackMultiplier(h,target.id,types,[1])).toBe(1); }
 expect(()=>homunculusAttackMultiplier({...c.expedition[0],type:"gold"},"gold",types)).toThrow(); expect(()=>homunculusAttackMultiplier(c.expedition[0],"gold",types,[1.1])).toThrow();
});


test("owned Astralotl triggers on an advantageous attack in each server engine", () => {
 const owned={...state,boss_entity_id:"vitriol_01",homunculus_progress:{astralotl:{owned:true,level:0,xp:0}}};
 const chosen={...selection,homunculus_id:"astralotl"};
 const setup=buildTrustedCombatSetup(owned,chosen,catalogs,{independentLoadout:true});
 const hunt=createCombatState(setup); hunt.boss.hp=hunt.boss.max_hp=10000; hunt.player.hp=hunt.player.max_hp=10000;
 const h=resolveCombatTurn(hunt,{turn:1,spell_id:ids[0],target:"boss"},()=>0.5);
 expect(h.events.some((e:any)=>e.kind==="hom_passive" && e.passive_id==="astralotl" && e.trigger==="before_attack")).toBe(true);
 const npcSpells=catalogs.spells.filter((s:any)=>s.type==="vitriol").slice(0,4).map((s:any)=>s.id);
 const dungeon=createDungeonCombatState(setup,{floor:1,entity_id:"vitriol_01",type:"vitriol",hp:10000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:npcSpells},catalogs);
 dungeon.player.hp=dungeon.player.max_hp=10000;
 const d=resolveDungeonTurn(dungeon,{turn:1,spell_id:ids[0]},()=>0.5);
 expect(d.events.some((e:any)=>e.kind==="hom_passive" && e.passive_id==="astralotl" && e.trigger==="before_attack")).toBe(true);
 const left=trustedPvpSnapshot("a",chosen,owned,catalogs as any)!;
 const right:any={...left,player_id:"b",entity_id:"vitriol_01",homunculus_id:null,homunculus_progress:{},spell_ids:npcSpells};
 const p:any=createPvpCombatState(left,right,catalogs as any);
 p.fighters.left.hp=p.fighters.left.max_hp=10000; p.fighters.right.hp=p.fighters.right.max_hp=10000;
 const result:any=resolvePvpExchange(p,{turn:1,spell_id:ids[0]},{turn:1,spell_id:npcSpells[0]},()=>0.5);
 expect(result.events.some((e:any)=>e.kind==="hom_passive" && e.passive_id==="astralotl" && e.trigger==="before_attack")).toBe(true);
});
