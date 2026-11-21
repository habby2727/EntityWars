import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { homunculusCatalog } from "../homunculus_catalog";
import { buildTrustedCombatSetup, createCombatState, resolveCombatTurn } from "../solo_hunt_combat";
import { createDungeonCombatState, resolveDungeonTurn } from "../dungeon_combat";
import { trustedPvpSnapshot } from "../pvp/service";
import { createPvpCombatState, resolvePvpExchange } from "../pvp/combat";
const read=(n:string)=>JSON.parse(readFileSync(resolve(import.meta.dir,"../../../data",n),"utf8"));
const c={entities:read("entities.json").entities,items:read("items.json").items,homunculi:homunculusCatalog().all,spells:read("spells.json").spells,types:read("types.json"),mutations:read("static/mutations.json").mutations,balance:read("static/balance.json").balance,bosses:read("static/solo_bosses.json").bosses};
const ids=["cinder_fist","furnace_rush","ash_temper","brimstone_crash"], progress={luny:{owned:true,level:3,xp:550}};
const selection={entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:"luny",spell_ids:ids,mode:"attack"};
const snapshot={player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",homunculus_progress:progress,spell_progress:{}};
const setup=()=>buildTrustedCombatSetup(snapshot,selection,c,{independentLoadout:true});

test("Luny changes Hunt action order only for an eligible attack",()=>{
 const h=createCombatState(setup()); h.player.tempo=10;h.boss.tempo=11;h.player.hp=h.player.max_hp=10000;h.boss.hp=h.boss.max_hp=10000;h.player.expedition_passive.consecutive_spell_hits=2;
 const run=(s:any)=>resolveCombatTurn(s,{turn:1,spell_id:ids[0],target:"boss"},()=>0.5);
 const result=run(structuredClone(h));const player=result.events.findIndex((e:any)=>e.kind==="damage"&&e.actor==="player"),boss=result.events.findIndex((e:any)=>e.kind==="boss_action");expect(player).toBeLessThan(boss);expect(result.events.filter((e:any)=>e.kind==="hom_passive")).toHaveLength(1);
 const no=structuredClone(h);no.player.expedition_passive.consecutive_spell_hits=1;const r=run(no);expect(r.events.findIndex((e:any)=>e.kind==="boss_action")).toBeLessThan(r.events.findIndex((e:any)=>e.kind==="damage"&&e.actor==="player"));
});
test("Luny changes Dungeon action order",()=>{
 const d=createDungeonCombatState(setup(),{floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:ids},c);d.player.tempo=10;d.npc.tempo=11;d.player.hp=d.player.max_hp=10000;d.npc.hp=d.npc.max_hp=10000;d.player.expedition_passive.consecutive_spell_hits=2;
 const result=resolveDungeonTurn(d,{turn:1,spell_id:ids[0]},()=>0.5);expect(result.events.find((e:any)=>e.kind==="spell").actor).toBe("player");expect(result.events.filter((e:any)=>e.kind==="hom_passive")).toHaveLength(1);
 const no=structuredClone(d);no.player.expedition_passive.consecutive_spell_hits=1;expect(resolveDungeonTurn(no,{turn:1,spell_id:ids[0]},()=>0.5).events.find((e:any)=>e.kind==="spell").actor).toBe("npc");
});
test("Luny changes Ranked action order",()=>{
 const left=trustedPvpSnapshot("a",selection,snapshot,c as any)!;const right={...left,player_id:"b",homunculus_id:null,homunculus_progress:{}};const p:any=createPvpCombatState(left,right,c as any);p.fighters.left.entity.base_stats.tempo=10;p.fighters.right.entity.base_stats.tempo=11;p.fighters.left.expedition_passive.consecutive_spell_hits=2;
 const run=(s:any)=>resolvePvpExchange(s,{turn:1,spell_id:ids[0]},{turn:1,spell_id:ids[0]},()=>0.5) as any;
 const result=run(structuredClone(p));expect(result.events.find((e:any)=>e.kind==="spell").side).toBe("left");expect(result.events.filter((e:any)=>e.kind==="hom_passive")).toHaveLength(1);
 const no=structuredClone(p);no.fighters.left.expedition_passive.consecutive_spell_hits=1;expect(run(no).events.find((e:any)=>e.kind==="spell").side).toBe("right");
});
