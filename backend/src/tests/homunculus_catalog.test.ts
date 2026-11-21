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
import { buildTrustedCombatSetup } from "../solo_hunt_combat";
import { trustedPvpSnapshot } from "../pvp/service";
import { createPvpCombatState } from "../pvp/combat";
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
test("ownership is strict and the phase gate blocks owned expedition selections", () => {
 expect(ownsHomunculus({},"cinder")).toBe(true); expect(ownsHomunculus({},"astralotl")).toBe(false); expect(ownsHomunculus({},"unknown")).toBe(false);
 for (const value of [null, 1, "true", {owned:1}, {owned:false}, {owned:true,xp:-1}, {owned:true,level:3,xp:0}, {owned:true,level:100}, {owned:true,mutation_id:17}, {owned:true,level:3,mutation_id:"unknown"}, {owned:true,level:0,mutation_id:"vitality"}]) expect(ownsHomunculus({astralotl:value},"astralotl")).toBe(false);
 expect(ownsHomunculus({astralotl:{owned:true, level:3, xp:550}},"astralotl")).toBe(true); expect(combatHomunculusAllowed({astralotl:{owned:true}},"astralotl")).toBe(false); expect(combatHomunculusAllowed({cinder:{level:2}},"cinder")).toBe(true); expect(combatHomunculusAllowed({cinder:null},"cinder")).toBe(false);
});
test("trusted PvE and ranked reject forged ownership, account mismatch and expedition IDs", () => {
 expect(buildTrustedCombatSetup(state,selection,catalogs,{independentLoadout:true}).error).toBeUndefined();
 const pvp = trustedPvpSnapshot("a",selection,state,catalogs as any); expect(pvp).not.toBeNull(); expect(pvp!.weapon_ids).toEqual(selection.weapon_ids); expect(trustedPvpSnapshot("b",selection,state,catalogs as any)).toBeNull(); expect(trustedPvpSnapshot("a",{...selection,homunculus_progress:{astralotl:{owned:true}}},state,catalogs as any)).toBeNull();
 const other = {...pvp!,player_id:"b"};
 for (const id of expeditionHomunculusIds()) { const progress = {[id]:{owned:true,level:3,xp:550}}; const selected={...selection,homunculus_id:id}; expect(buildTrustedCombatSetup({...state,homunculus_progress:progress},selected,catalogs,{independentLoadout:true})).toEqual({error:"UNTRUSTED_SETUP"}); expect(trustedPvpSnapshot("a",selected,{...state,homunculus_progress:progress},catalogs as any)).toBeNull(); expect(createPvpCombatState({...pvp!,homunculus_id:id,homunculus_progress:progress},other,catalogs as any)).toEqual({error:"UNTRUSTED_SETUP"}); }
 expect(buildTrustedCombatSetup(state,{...selection,owned:true},catalogs,{independentLoadout:true})).toEqual({error:"UNTRUSTED_SETUP"}); expect(buildTrustedCombatSetup({...state,homunculus_progress:{cinder:{level:2,xp:-1}}},selection,catalogs,{independentLoadout:true})).toEqual({error:"UNTRUSTED_SETUP"});
});
test("elemental multiplier covers six types and neutralization", () => {
 const c=homunculusCatalog(); for (const h of c.originals) expect(homunculusAttackMultiplier(h,"gold",types,[1])).toBe(1);
 for (const h of c.expedition) for (const target of types.types) { const relation=(types.effectiveness as any)[h.type][target.id]; const expected=relation>1?1.18:relation<1?0.84:1; expect(homunculusAttackMultiplier(h,target.id,types)).toBeCloseTo(expected); expect(homunculusAttackMultiplier(h,target.id,types,[0.25,0.5])).toBeCloseTo(1+(expected-1)*0.5); expect(homunculusAttackMultiplier(h,target.id,types,[1])).toBe(1); }
 expect(()=>homunculusAttackMultiplier({...c.expedition[0],type:"gold"},"gold",types)).toThrow(); expect(()=>homunculusAttackMultiplier(c.expedition[0],"gold",types,[1.1])).toThrow();
});
