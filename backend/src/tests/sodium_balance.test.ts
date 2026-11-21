import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createPvpCombatState, resolvePvpExchange } from "../pvp/combat";
import { buildTrustedCombatSetup, createCombatState, resolveCombatTurn, applyTimedAwarePassive } from "../solo_hunt_combat";
import { newExpeditionPassiveState, beginPassiveExchange } from "../expedition_passive_state";
import { buildExpeditionEnemy, createExpeditionCombatState, resolveExpeditionTurn } from "../expeditions_combat";
import { homunculusCatalog } from "../homunculus_catalog";
import { createDungeonCombatState, resolveDungeonTurn } from "../dungeon_combat";
const read = (n: string) => JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data", n), "utf8"));
const c = { entities:read("entities.json").entities, items:read("items.json").items, homunculi:read("homunculi.json").homunculi, spells:read("spells.json").spells, types:read("types.json"), bosses:read("static/solo_bosses.json").bosses, mutations:read("static/mutations.json").mutations, balance:read("static/balance.json").balance };
const sodium = ["crystal_ram", "salt_barrier", "brine_mend", "bastion_return"], sulfur = ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"];
const snap = (player_id:string,entity_id:string,spell_ids:string[]) => ({player_id,entity_id,weapon_ids:[null,null],homunculus_id:null,spell_ids});
const rng=()=>0.5;
test("sodium spells expose specified values",()=>{const a=c.spells.find((s:any)=>s.id==="salt_barrier"),b=c.spells.find((s:any)=>s.id==="brine_mend");expect(a.cooldown_turns).toBe(2);expect(b.cooldown_turns).toBe(3);expect(a.effects).toEqual([{kind:"shield",value:0.24,target:"self",duration_exchanges:2},{kind:"reflect",value:0.5,target:"self",duration_exchanges:2}]);expect(b.effects).toEqual([{kind:"life_leech",value:1,max_heal:15,target:"self",health_drain:true}]);});
test("PvP drain is capped and mitigated",()=>{const s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);const a=s.fighters.left,b=s.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=a.max_hp-8;b.status.shield_pct=0.5;const o:any=resolvePvpExchange(s,{turn:1,spell_id:"brine_mend"},{turn:1,spell_id:"ash_temper"},rng);expect(o.error).toBeUndefined();expect(o.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(8);expect(o.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(8);expect(o.state.fighters.left.hp).toBe(a.max_hp);expect(o.state.fighters.right.hp).toBe(b.hp-8);});
test("PvP barrier survives repeated hits then expires",()=>{let s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);const a=s.fighters.left,b=s.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=a.max_hp=1000;b.hp=b.max_hp=1000;a.status.reflect_pct=0.18;a.spells.push({id:"fixture_wait",name:"Wait",type:"sodium",category:"support",power_mult:0,accuracy:1,cooldown_turns:0,effects:[]});a.spell_ids[0]="fixture_wait";for(let turn=1;turn<=4;turn++){const o:any=resolvePvpExchange(s,{turn,spell_id:turn===1?"salt_barrier":"fixture_wait"},{turn,spell_id:"cinder_fist"},rng);expect(o.error).toBeUndefined();expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="left").length).toBe(turn<=2?1:0);if(turn===1)expect(o.state.fighters.left.status.reflect_pct).toBe(0);s=o.state;}expect(s.fighters.left.timed_defenses).toBeUndefined();});
test("Boss Hunt and Dungeon drain real health",()=>{const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},c,{independentLoadout:true});const h:any=createCombatState(setup);h.player.hp=h.player.max_hp-10;h.boss.status.stun=1;const hr:any=resolveCombatTurn(h,{turn:1,spell_id:"brine_mend",target:"boss"},rng);expect(hr.error).toBeUndefined();expect(hr.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(10);const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};const d:any=createDungeonCombatState(setup,enemy,c);d.player.hp=d.player.max_hp-10;d.npc.status.stun=1;const dr:any=resolveDungeonTurn(d,{turn:1,spell_id:"brine_mend",hom_action:"hold"},rng);expect(dr.error).toBeUndefined();expect(dr.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(10);});

test("Dungeon NPC can drain health",()=>{
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const enemy={floor:1,entity_id:"sodium_01",type:"sodium",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sodium};
 const d:any=createDungeonCombatState(setup,enemy,c); expect(d.error).toBeUndefined();
 d.npc.hp=d.npc.max_hp-10;d.npc.tempo=1000;d.player.tempo=1;
 for(const id of sodium) if(id!=="brine_mend")d.npc.cooldowns[id]=3;
 const o:any=resolveDungeonTurn(d,{turn:1,spell_id:"ash_temper",hom_action:"hold"},rng);
 expect(o.error).toBeUndefined();
 expect(o.events.find((e:any)=>e.kind==="heal"&&e.actor==="npc"&&e.spell_id==="brine_mend").amount).toBe(10);
 expect(o.events.find((e:any)=>e.kind==="damage"&&e.actor==="npc"&&e.spell_id==="brine_mend").amount).toBe(15);
});

test("lethal drain restores only remaining enemy HP",()=>{
 const s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
 const a=s.fighters.left,b=s.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=a.max_hp-20;b.hp=5;b.status.shield_pct=0;
 const o:any=resolvePvpExchange(s,{turn:1,spell_id:"brine_mend"},{turn:1,spell_id:"ash_temper"},rng);
 expect(o.error).toBeUndefined();expect(o.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(5);
 expect(o.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").hp).toBe(0);
});

test("timed reflection triggers once for each spell and homunculus hit",()=>{
 const s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
 const a=s.fighters.left,b=s.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;
 a.hp=a.max_hp=1000;b.hp=b.max_hp=1000;b.hom_spent=false;b.hom_id="cinder";b.hom_energy=3;
 const o:any=resolvePvpExchange(s,{turn:1,spell_id:"salt_barrier"},{turn:1,spell_id:"cinder_fist",hom_action:"attack"},rng);
 expect(o.error).toBeUndefined();expect(o.events.filter((e:any)=>e.kind==="hom_attack")).toHaveLength(1);
 expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="left")).toHaveLength(2);
});

test("Boss Hunt and Dungeon expire timed defenses after the second exchange",()=>{
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},c,{independentLoadout:true});
 let h:any=createCombatState(setup);h.player.hp=h.player.max_hp=1000;h.boss.hp=h.boss.max_hp=1000;h.boss.atk=10;h.player.tempo=1000;h.boss.tempo=1;h.boss_shield_phases=["high","low"];
 let result:any=resolveCombatTurn(h,{turn:1,spell_id:"salt_barrier",target:"boss"},rng);expect(result.error).toBeUndefined();expect(result.events.filter((e:any)=>e.kind==="reflect"&&e.actor==="player")).toHaveLength(1);h=result.next_state;
 expect(h.player.timed_defenses.shield_pct.value).toBe(0.24);expect(h.player.timed_defenses.reflect_pct.value).toBe(0.5);
 h.boss_intent="Strike";result=resolveCombatTurn(h,{turn:2,spell_id:"crystal_ram",target:"boss"},rng);expect(result.error).toBeUndefined();expect(result.events.filter((e:any)=>e.kind==="reflect"&&e.actor==="player")).toHaveLength(1);h=result.next_state;expect(h.player.timed_defenses).toBeUndefined();
 result=resolveCombatTurn(h,{turn:3,spell_id:"bastion_return",target:"boss"},rng);expect(result.error).toBeUndefined();expect(result.next_state.player.timed_defenses).toBeUndefined();
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 let d:any=createDungeonCombatState(setup,enemy,c);d.player.hp=d.player.max_hp=1000;d.npc.hp=d.npc.max_hp=1000;d.player.tempo=1000;d.npc.tempo=1;
 for(const id of sulfur)if(id!=="cinder_fist")d.npc.cooldowns[id]=9;
 result=resolveDungeonTurn(d,{turn:1,spell_id:"salt_barrier",hom_action:"hold"},rng);expect(result.error).toBeUndefined();expect(result.events.filter((e:any)=>e.kind==="reflect"&&e.actor==="player")).toHaveLength(1);d=result.next_state;expect(d.player.timed_defenses.shield.value).toBe(0.24);expect(d.player.timed_defenses.reflect.value).toBe(0.5);
 result=resolveDungeonTurn(d,{turn:2,spell_id:"crystal_ram",hom_action:"hold"},rng);expect(result.error).toBeUndefined();expect(result.events.filter((e:any)=>e.kind==="reflect"&&e.actor==="player")).toHaveLength(1);d=result.next_state;expect(d.player.timed_defenses).toBeUndefined();
 result=resolveDungeonTurn(d,{turn:3,spell_id:"bastion_return",hom_action:"hold"},rng);expect(result.error).toBeUndefined();expect(result.next_state.player.timed_defenses).toBeUndefined();
});

test("ordinary reflect remains single use",()=>{
 let s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);s.fighters.left.entity.base_stats.tempo=100;s.fighters.right.entity.base_stats.tempo=1;s.fighters.left.hp=s.fighters.left.max_hp=1000;s.fighters.right.hp=s.fighters.right.max_hp=1000;
 const wait={id:"fixture_wait",name:"Wait",type:"sodium",category:"support",power_mult:0,accuracy:1,cooldown_turns:0,effects:[]};s.fighters.left.spells.push(wait);s.fighters.left.spell_ids[0]=wait.id;
 let o:any=resolvePvpExchange(s,{turn:1,spell_id:"bastion_return"},{turn:1,spell_id:"cinder_fist"},rng);expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="left")).toHaveLength(1);s=o.state;
 o=resolvePvpExchange(s,{turn:2,spell_id:"fixture_wait"},{turn:2,spell_id:"cinder_fist"},rng);expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="left")).toHaveLength(0);
});

test("ignore reflection does not consume the timed barrier",()=>{
 let s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);const a=s.fighters.left,b=s.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=a.max_hp=1000;b.hp=b.max_hp=1000;b.item_fx.ignore_reflect_chance=1;
 const wait={id:"fixture_wait",name:"Wait",type:"sodium",category:"support",power_mult:0,accuracy:1,cooldown_turns:0,effects:[]};a.spells.push(wait);a.spell_ids[0]=wait.id;
 let o:any=resolvePvpExchange(s,{turn:1,spell_id:"salt_barrier"},{turn:1,spell_id:"cinder_fist"},rng);expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="left")).toHaveLength(0);s=o.state;expect(s.fighters.left.timed_defenses.reflect_pct.value).toBe(0.5);s.fighters.right.item_fx.ignore_reflect_chance=0;
 o=resolvePvpExchange(s,{turn:2,spell_id:"fixture_wait"},{turn:2,spell_id:"cinder_fist"},rng);expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="left")).toHaveLength(1);
});


test("timed shield activates shield-dependent homunculus passives without consuming ordinary defenses",()=>{
 const f:any={hp:50,max_hp:100,type:"sodium",status:{},timed_defenses:{shield_pct:{value:0.24,expires_turn:3}},expedition_passive:beginPassiveExchange(newExpeditionPassiveState("ninux",0),1)};
 const t:any={hp:50,max_hp:100,type:"sulfur",status:{}};const events:any[]=[];
 applyTimedAwarePassive(f,t,"before_exchange",c.types,"a","b",events);
 expect(events.some((event:any)=>event.kind==="hom_passive" && event.passive_id==="ninux")).toBe(true);
 expect(f.status.shield_pct).toBeUndefined();expect(f.timed_defenses.shield_pct.value).toBe(0.24);
});


test("Dungeon reflects both an NPC spell and homunculus strike in one exchange",()=>{
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},c,{independentLoadout:true});
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:30,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const d:any=createDungeonCombatState(setup,enemy,c);d.player.hp=d.player.max_hp=1000;d.npc.hp=d.npc.max_hp=1000;d.player.tempo=1000;d.npc.tempo=1;d.npc.hom_energy=6;
 for(const id of sulfur)if(id!=="cinder_fist")d.npc.cooldowns[id]=3;
 const o:any=resolveDungeonTurn(d,{turn:1,spell_id:"salt_barrier",hom_action:"hold"},rng);
 expect(o.error).toBeUndefined();expect(o.events.filter((e:any)=>e.kind==="hom_attack"&&e.actor==="npc")).toHaveLength(1);
 expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.actor==="player")).toHaveLength(2);
});


test("Expedition player and NPC use the same sodium effects",()=>{
 const catalogs={...c,homunculi:homunculusCatalog().all};
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},catalogs,{independentLoadout:true});
 const seed=new Uint8Array(32).fill(5);let enemy:any;
 for(let i=0;i<100;i++){const candidate=buildExpeditionEnemy(seed,`sodium-${i}`,1,false,setup,catalogs);if(candidate.types.includes("sodium")){enemy=candidate;break;}}
 expect(enemy).toBeDefined();enemy.spell_ids=[...enemy.spell_ids.filter((id:string)=>id!=="brine_mend").slice(0,3),"brine_mend"];
 const state:any=createExpeditionCombatState(setup,enemy,catalogs);expect(state.error).toBeUndefined();state.player.hp=state.player.max_hp=1000;state.npc.hp=state.npc.max_hp-10;state.npc.tempo=1000;state.player.tempo=1;
 for(const id of state.npc.spell_ids)if(id!=="brine_mend")state.npc.cooldowns[id]=3;
 const o:any=resolveExpeditionTurn(state,{turn:1,spell_id:"salt_barrier",hom_action:"hold"},rng);expect(o.error).toBeUndefined();
 expect(o.events.find((event:any)=>event.kind==="heal"&&event.actor==="npc"&&event.spell_id==="brine_mend").amount).toBe(10);
 expect(o.events.find((event:any)=>event.kind==="damage"&&event.actor==="npc"&&event.spell_id==="brine_mend").amount).toBe(15);
 expect(o.next_state.player.timed_defenses.shield.value).toBe(0.24);expect(o.next_state.player.timed_defenses.reflect.value).toBe(0.5);
 const following:any=resolveExpeditionTurn(o.next_state,{turn:2,spell_id:"crystal_ram",hom_action:"hold"},rng);
 expect(following.error).toBeUndefined();expect(following.next_state.player.timed_defenses).toBeUndefined();
});

test("drain applies reflection once and keeps the timed reflection active",()=>{
 const s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);const a=s.fighters.left,b=s.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=a.max_hp-2;b.hp=b.max_hp=1000;b.status.reflect_pct=0.18;b.timed_defenses={reflect_pct:{value:0.5,expires_turn:3}};
 const o:any=resolvePvpExchange(s,{turn:1,spell_id:"brine_mend"},{turn:1,spell_id:"ash_temper"},rng);expect(o.error).toBeUndefined();
 expect(o.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(15);
 expect(o.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(2);
 expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="right")).toHaveLength(1);
 expect(o.state.fighters.left.hp).toBe(a.max_hp-8);expect(o.state.fighters.right.status.reflect_pct).toBe(0);expect(o.state.fighters.right.timed_defenses.reflect_pct.value).toBe(0.5);
});

test("sodium cooldowns prevent premature recasting",()=>{
 let s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);s.fighters.left.hp=s.fighters.left.max_hp=1000;s.fighters.right.hp=s.fighters.right.max_hp=1000;s.fighters.left.entity.base_stats.tempo=100;s.fighters.right.entity.base_stats.tempo=1;
 let o:any=resolvePvpExchange(s,{turn:1,spell_id:"salt_barrier"},{turn:1,spell_id:"ash_temper"},rng);expect(o.error).toBeUndefined();s=o.state;
 expect(resolvePvpExchange(s,{turn:2,spell_id:"salt_barrier"},{turn:2,spell_id:"cinder_fist"},rng)).toEqual({error:"INVALID_DECISION"});
 o=resolvePvpExchange(s,{turn:2,spell_id:"brine_mend"},{turn:2,spell_id:"cinder_fist"},rng);expect(o.error).toBeUndefined();s=o.state;
 expect(resolvePvpExchange(s,{turn:3,spell_id:"brine_mend"},{turn:3,spell_id:"cinder_fist"},rng)).toEqual({error:"INVALID_DECISION"});
});


test("Brine Mend separates actual damage from missing health and healing suppression",()=>{
 for (const scenario of [
  {missing:0, shield:0, suppression:false, target:100, damage:15, healed:0},
  {missing:4, shield:0, suppression:false, target:100, damage:15, healed:4},
  {missing:30, shield:0, suppression:true, target:100, damage:15, healed:7},
  {missing:4, shield:0, suppression:true, target:100, damage:15, healed:2},
  {missing:4, shield:0.5, suppression:false, target:100, damage:8, healed:4},
  {missing:30, shield:0, suppression:false, target:5, damage:5, healed:5},
 ]) {
  const state:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
  const a=state.fighters.left,b=state.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;
  a.hp=a.max_hp-scenario.missing;b.hp=b.max_hp=scenario.target;b.status.shield_pct=scenario.shield;
  if(scenario.suppression)a.strategic_heal_suppression={expires_turn:2};
  const out:any=resolvePvpExchange(state,{turn:1,spell_id:"brine_mend"},{turn:1,spell_id:"ash_temper"},rng);
  expect(out.error).toBeUndefined();
  expect(out.events.find((event:any)=>event.kind==="damage"&&event.spell_id==="brine_mend").damage).toBe(scenario.damage);
  expect(out.events.find((event:any)=>event.kind==="heal"&&event.spell_id==="brine_mend").amount).toBe(scenario.healed);
  expect(out.events.find((event:any)=>event.kind==="damage"&&event.spell_id==="brine_mend").hp).toBe(scenario.target-scenario.damage);
  expect(out.events.find((event:any)=>event.kind==="heal"&&event.spell_id==="brine_mend").hp).toBe(a.hp+scenario.healed);
 }
});

test("full-health caster damages without healing in Boss Hunt and Dungeon",()=>{
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},c,{independentLoadout:true});
 const h:any=createCombatState(setup);h.boss.status.stun=1;
 const hunt:any=resolveCombatTurn(h,{turn:1,spell_id:"brine_mend",target:"boss"},rng);
 expect(hunt.error).toBeUndefined();
 expect(hunt.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(15);
 expect(hunt.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(0);
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const d:any=createDungeonCombatState(setup,enemy,c);d.player.tempo=1000;d.npc.status.stun=1;
 const dungeon:any=resolveDungeonTurn(d,{turn:1,spell_id:"brine_mend",hom_action:"hold"},rng);
 expect(dungeon.error).toBeUndefined();
 expect(dungeon.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").amount).toBe(15);
 expect(dungeon.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(0);
});

test("full-health Dungeon NPC deals damage without healing",()=>{
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const enemy={floor:1,entity_id:"sodium_01",type:"sodium",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sodium};
 const state:any=createDungeonCombatState(setup,enemy,c);state.npc.tempo=1000;state.player.tempo=1;
 for(const id of sodium)if(id!=="brine_mend")state.npc.cooldowns[id]=3;
 const out:any=resolveDungeonTurn(state,{turn:1,spell_id:"ash_temper",hom_action:"hold"},rng);
 expect(out.error).toBeUndefined();
 expect(out.events.find((e:any)=>e.kind==="damage"&&e.actor==="npc"&&e.spell_id==="brine_mend").amount).toBe(15);
 expect(out.events.find((e:any)=>e.kind==="heal"&&e.actor==="npc"&&e.spell_id==="brine_mend").amount).toBe(0);
});

test("Expedition NPC barrier expires after the casting and following exchange",()=>{
 const catalogs={...c,homunculi:homunculusCatalog().all};
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},catalogs,{independentLoadout:true});
 const seed=new Uint8Array(32).fill(5);let enemy:any;
 for(let i=0;i<100;i++){const candidate=buildExpeditionEnemy(seed,`barrier-${i}`,1,false,setup,catalogs);if(candidate.types.includes("sodium")){enemy=candidate;break;}}
 expect(enemy).toBeDefined();enemy.spell_ids=[...enemy.spell_ids.filter((id:string)=>id!=="salt_barrier").slice(0,3),"salt_barrier"];
 const state:any=createExpeditionCombatState(setup,enemy,catalogs);expect(state.error).toBeUndefined();state.player.hp=state.player.max_hp=1000;state.npc.hp=state.npc.max_hp=1000;state.npc.tempo=1000;state.player.tempo=1;
 for(const id of state.npc.spell_ids)if(id!=="salt_barrier")state.npc.cooldowns[id]=3;
 const first:any=resolveExpeditionTurn(state,{turn:1,spell_id:"ash_temper",hom_action:"hold"},rng);expect(first.error).toBeUndefined();
 expect(first.next_state.npc.timed_defenses.shield.value).toBe(0.24);expect(first.next_state.npc.timed_defenses.reflect.value).toBe(0.5);
 const second:any=resolveExpeditionTurn(first.next_state,{turn:2,spell_id:"cinder_fist",hom_action:"hold"},rng);expect(second.error).toBeUndefined();
 expect(second.events.filter((e:any)=>e.kind==="reflect"&&e.actor==="npc")).toHaveLength(1);
 expect(second.next_state.npc.timed_defenses).toBeUndefined();
});

test("healing suppression limits healing, not damage, in Boss Hunt and Dungeon",()=>{
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},c,{independentLoadout:true});
 const hunt:any=createCombatState(setup);hunt.player.hp=hunt.player.max_hp-30;hunt.player.tempo=1000;hunt.boss.status.stun=1;hunt.player.strategic_heal_suppression={expires_turn:2};
 const h:any=resolveCombatTurn(hunt,{turn:1,spell_id:"brine_mend",target:"boss"},rng);expect(h.error).toBeUndefined();
 expect(h.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(15);expect(h.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(7);
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const dungeon:any=createDungeonCombatState(setup,enemy,c);dungeon.player.hp=dungeon.player.max_hp-30;dungeon.player.tempo=1000;dungeon.npc.status.stun=1;dungeon.player.strategic_heal_suppression={expires_turn:2};
 const d:any=resolveDungeonTurn(dungeon,{turn:1,spell_id:"brine_mend",hom_action:"hold"},rng);expect(d.error).toBeUndefined();
 expect(d.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").amount).toBe(15);expect(d.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(7);
});
