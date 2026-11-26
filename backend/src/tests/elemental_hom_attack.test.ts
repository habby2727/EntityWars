import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { buildTrustedCombatSetup, createCombatState, resolveCombatTurn } from "../solo_hunt_combat";
import { createDungeonCombatState, resolveDungeonTurn } from "../dungeon_combat";
import { createPvpCombatState, resolvePvpExchange } from "../pvp/combat";
const read=(n:string)=>JSON.parse(readFileSync(resolve(import.meta.dir,"../../../data",n),"utf8"));
const c={entities:read("entities.json").entities,items:read("items.json").items,homunculi:read("homunculi.json").homunculi,spells:read("spells.json").spells,types:read("types.json"),mutations:read("static/mutations.json").mutations,balance:read("static/balance.json").balance,bosses:read("static/solo_bosses.json").bosses};
const ids=["cinder_fist","furnace_rush","ash_temper","brimstone_crash"];
const setup=()=>buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:"cinder",spell_ids:ids,mode:"attack"},c,{independentLoadout:true});
const snap=(player_id:string,type:string)=>({player_id,entity_id:`${type}_01`,weapon_ids:[null,null],homunculus_id:"cinder",spell_ids:c.spells.filter((s:any)=>s.type===type).slice(0,4).map((s:any)=>s.id)});

test("U3.1 legacy homunculus corrosion reports only actual applied damage",()=>{
 const hunt:any=createCombatState(setup());hunt.hom_synergy.dot_true=5;hunt.boss.hp=hunt.boss.max_hp=1000;hunt.boss.status.stun=1;
 const result:any=resolveCombatTurn(hunt,{turn:1,spell_id:"cinder_fist",target:"boss"},()=>0.5);
 expect(result.error).toBeUndefined();expect(result.events.find((event:any)=>event.kind==="hom_passive"&&event.trigger==="spell_hit")).toMatchObject({actor:"player",target:"boss",hom_id:"cinder",effects:[{kind:"dot_true",target:"boss",amount:5,unit:"hp"}]});
 const p:any=createPvpCombatState(snap("a","sulfur"),snap("b","sulfur"),c);p.fighters.left.hom_synergy.dot_true=5;p.fighters.left.entity.base_stats.tempo=100;p.fighters.right.entity.base_stats.tempo=1;p.fighters.right.hp=p.fighters.right.max_hp=1000;
 const ranked:any=resolvePvpExchange(p,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"ash_temper"},()=>0.5);
 expect(ranked.error).toBeUndefined();expect(ranked.events.find((event:any)=>event.kind==="hom_passive"&&event.trigger==="spell_hit")).toMatchObject({actor:"left",target:"right",hom_id:"cinder",effects:[{kind:"dot_true",target:"right",amount:5,unit:"hp"}]});
});

test("elemental homunculus attacks use defender type in Hunt including old minion snapshots",()=>{
 const h=createCombatState(setup()); h.hom_energy=3; h.player.atk=100; h.player.hp=h.player.max_hp=10000; h.boss.hp=h.boss.max_hp=10000; h.boss.type="sulfur"; h.boss.atk=1;
 const spell=h.spells.find((s:any)=>s.id===ids[0]); spell.category="support";spell.power_mult=0;spell.accuracy=1;spell.effects=[];
 const run=(id:string,s:any,target="boss")=>{s.hom_id=id;return resolveCombatTurn(s,{turn:1,spell_id:ids[0],target,hom_action:"attack"},()=>0.5)};
 const legacy=run("cinder",structuredClone(h)), elemental=run("astralotl",structuredClone(h));
 expect(legacy.events.find((e:any)=>e.kind==="hom_damage").damage).toBe(40);
 expect(elemental.events.find((e:any)=>e.kind==="hom_damage").damage).toBe(47);
 const weak=structuredClone(h); weak.boss.type="gold"; expect(run("astralotl",weak).events.find((e:any)=>e.kind==="hom_damage").damage).toBe(34);
 const neutral=structuredClone(h); neutral.boss.type="aether"; expect(run("astralotl",neutral).events.find((e:any)=>e.kind==="hom_damage").damage).toBe(40);
 const cancelled=structuredClone(h); cancelled.boss.spell_neutralize_pending=1; expect(run("astralotl",cancelled).events.find((e:any)=>e.kind==="hom_damage").damage).toBe(40);
 const old=structuredClone(h); old.minion_config.type="sulfur"; old.minions=[{id:"minion_0",type:"",hp:1000,max_hp:1000,atk:1,def:1,status:{}}];old.summoned=true;
 expect(run("astralotl",old,"minion_0").events.find((e:any)=>e.kind==="hom_damage").damage).toBe(47);
});

test("Dungeon and Ranked homunculus strikes apply the same factor without changing legacy",()=>{
 const d=createDungeonCombatState(setup(),{floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:ids},c);d.player.hom_energy=3;d.player.atk=100;d.player.hp=d.player.max_hp=10000;d.npc.hp=d.npc.max_hp=10000;d.npc.hom_id=null;
 const spell=d.spells.find((s:any)=>s.id===ids[0]);spell.category="support";spell.power_mult=0;spell.effects=[];spell.accuracy=1;
 const dr=(id:string)=>{const s=structuredClone(d);s.player.hom_id=id;return resolveDungeonTurn(s,{turn:1,spell_id:ids[0],hom_action:"attack"},()=>0.5).events.find((e:any)=>e.kind==="hom_attack" && e.actor==="player").amount};
 expect(dr("cinder")).toBe(40);expect(dr("astralotl")).toBe(47);
 const p:any=createPvpCombatState(snap("a","sulfur"),snap("b","sulfur"),c);p.fighters.left.hom_energy=3;p.fighters.left.atk=100;p.fighters.left.hp=p.fighters.left.max_hp=10000;p.fighters.right.hp=p.fighters.right.max_hp=10000;
 for(const side of ["left","right"]) {const f=p.fighters[side];const sp=f.spells.find((x:any)=>x.id===f.spell_ids[0]);sp.category="support";sp.power_mult=0;sp.effects=[];sp.accuracy=1;}
 const pr=(id:string)=>{const s=structuredClone(p);s.fighters.left.hom_id=id;return (resolvePvpExchange(s,{turn:1,spell_id:s.fighters.left.spell_ids[0],hom_action:"attack"},{turn:1,spell_id:s.fighters.right.spell_ids[0]},()=>0.5) as any).events.find((e:any)=>e.kind==="hom_attack" && e.side==="left").damage};
 expect(pr("cinder")).toBe(40);expect(pr("astralotl")).toBe(47);
});
