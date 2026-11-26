import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createPvpCombatState, resolvePvpExchange, resolvePvpInspiration, startPvpBattle } from "../pvp/combat";
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
test("sodium spells expose specified values",()=>{const a=c.spells.find((s:any)=>s.id==="salt_barrier"),b=c.spells.find((s:any)=>s.id==="brine_mend");expect(a.cooldown_turns).toBe(2);expect(b.cooldown_turns).toBe(4);expect(a.effects).toEqual([{kind:"shield",value:0.24,target:"self",duration_exchanges:2},{kind:"reflect",value:0.5,target:"self",duration_exchanges:2}]);expect(b.effects).toEqual([{kind:"life_leech",value:1,max_heal:15,target:"self",health_drain:true}]);});
test("PvP drain is capped and mitigated",()=>{const s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);const a=s.fighters.left,b=s.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=a.max_hp-8;b.status.shield_pct=0.5;const o:any=resolvePvpExchange(s,{turn:1,spell_id:"brine_mend"},{turn:1,spell_id:"ash_temper"},rng);const expected=Math.round(Math.round(b.hp*0.06)*0.5);expect(o.error).toBeUndefined();expect(o.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(expected);expect(o.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(expected);expect(o.state.fighters.left.hp).toBe(a.hp+expected);expect(o.state.fighters.right.hp).toBe(b.hp-expected);});
test("PvP barrier survives repeated hits then expires",()=>{let s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);const a=s.fighters.left,b=s.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=a.max_hp=1000;b.hp=b.max_hp=1000;a.status.reflect_pct=0.18;a.spells.push({id:"fixture_wait",name:"Wait",type:"sodium",category:"support",power_mult:0,accuracy:1,cooldown_turns:0,effects:[]});a.spell_ids[0]="fixture_wait";for(let turn=1;turn<=4;turn++){const o:any=resolvePvpExchange(s,{turn,spell_id:turn===1?"salt_barrier":"fixture_wait"},{turn,spell_id:"cinder_fist"},rng);expect(o.error).toBeUndefined();expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="left").length).toBe(turn<=2?1:0);if(turn===1)expect(o.state.fighters.left.status.reflect_pct).toBe(0);s=o.state;}expect(s.fighters.left.timed_defenses).toBeUndefined();});
test("Boss Hunt and Dungeon drain real health",()=>{const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},c,{independentLoadout:true});const h:any=createCombatState(setup);h.player.hp=h.player.max_hp-10;h.boss.status.stun=1;const hr:any=resolveCombatTurn(h,{turn:1,spell_id:"brine_mend",target:"boss"},rng);expect(hr.error).toBeUndefined();expect(hr.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(Math.min(10,Math.round(h.boss.hp*0.06)));const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};const d:any=createDungeonCombatState(setup,enemy,c);d.player.hp=d.player.max_hp-10;d.npc.status.stun=1;const dr:any=resolveDungeonTurn(d,{turn:1,spell_id:"brine_mend",hom_action:"hold"},rng);expect(dr.error).toBeUndefined();expect(dr.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(10);});

test("Dungeon NPC can drain health",()=>{
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const enemy={floor:1,entity_id:"sodium_01",type:"sodium",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sodium};
 const d:any=createDungeonCombatState(setup,enemy,c); expect(d.error).toBeUndefined();
 d.npc.hp=d.npc.max_hp-10;d.npc.tempo=1000;d.player.tempo=1;
 for(const id of sodium) if(id!=="brine_mend")d.npc.cooldowns[id]=3;
 const o:any=resolveDungeonTurn(d,{turn:1,spell_id:"ash_temper",hom_action:"hold"},rng);
 expect(o.error).toBeUndefined();
 expect(o.events.find((e:any)=>e.kind==="heal"&&e.actor==="npc"&&e.spell_id==="brine_mend").amount).toBe(Math.min(10,Math.round(d.player.hp*0.06)));
 expect(o.events.find((e:any)=>e.kind==="damage"&&e.actor==="npc"&&e.spell_id==="brine_mend").amount).toBe(Math.round(d.player.hp*0.06));
});

test("lethal drain restores only remaining enemy HP",()=>{
 const s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
 delete s.combat_rules_version; // Frozen sessions retain the original fixed drain.
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
 expect(o.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(60);
 expect(o.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(2);
 expect(o.events.filter((e:any)=>e.kind==="reflect"&&e.side==="right")).toHaveLength(1);
 expect(o.state.fighters.left.hp).toBe(a.max_hp-30);expect(o.state.fighters.right.status.reflect_pct).toBe(0);expect(o.state.fighters.right.timed_defenses.reflect_pct.value).toBe(0.5);
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
  {missing:0, shield:0, suppression:false, target:100, damage:6, healed:0},
  {missing:4, shield:0, suppression:false, target:100, damage:6, healed:4},
  {missing:30, shield:0, suppression:true, target:100, damage:6, healed:3},
  {missing:4, shield:0, suppression:true, target:100, damage:6, healed:2},
  {missing:4, shield:0.5, suppression:false, target:100, damage:3, healed:3},
  {missing:30, shield:0, suppression:false, target:5, damage:0, healed:0},
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
 expect(hunt.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(Math.round(h.boss.hp*0.06));
 expect(hunt.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(0);
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const d:any=createDungeonCombatState(setup,enemy,c);d.player.tempo=1000;d.npc.status.stun=1;
 const dungeon:any=resolveDungeonTurn(d,{turn:1,spell_id:"brine_mend",hom_action:"hold"},rng);
 expect(dungeon.error).toBeUndefined();
 expect(dungeon.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").amount).toBe(Math.round(d.npc.hp*0.06));
 expect(dungeon.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(0);
});

test("full-health Dungeon NPC deals damage without healing",()=>{
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const enemy={floor:1,entity_id:"sodium_01",type:"sodium",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sodium};
 const state:any=createDungeonCombatState(setup,enemy,c);state.npc.tempo=1000;state.player.tempo=1;
 for(const id of sodium)if(id!=="brine_mend")state.npc.cooldowns[id]=3;
 const out:any=resolveDungeonTurn(state,{turn:1,spell_id:"ash_temper",hom_action:"hold"},rng);
 expect(out.error).toBeUndefined();
 expect(out.events.find((e:any)=>e.kind==="damage"&&e.actor==="npc"&&e.spell_id==="brine_mend").amount).toBe(Math.round(state.player.hp*0.06));
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
 expect(h.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(Math.round(hunt.boss.hp*0.06));expect(h.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(Math.floor(Math.min(30,Math.round(hunt.boss.hp*0.06))/2));
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const dungeon:any=createDungeonCombatState(setup,enemy,c);dungeon.player.hp=dungeon.player.max_hp-30;dungeon.player.tempo=1000;dungeon.npc.status.stun=1;dungeon.player.strategic_heal_suppression={expires_turn:2};
 const d:any=resolveDungeonTurn(dungeon,{turn:1,spell_id:"brine_mend",hom_action:"hold"},rng);expect(d.error).toBeUndefined();
 expect(d.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").amount).toBe(Math.round(dungeon.npc.hp*0.06));expect(d.events.find((e:any)=>e.kind==="heal"&&e.spell_id==="brine_mend").amount).toBe(Math.floor(Math.min(30,Math.round(dungeon.npc.hp*0.06))/2));
});


test("U3.1 poison stages and legacy snapshots remain deterministic", () => {
 const s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
 const wait={id:"fixture_wait",name:"Wait",type:"sodium",category:"support",power_mult:0,accuracy:1,cooldown_turns:0,effects:[]};
 for (const [side,hp,type] of [["left",100,"sodium"],["right",200,"sulfur"]] as const) { const f=s.fighters[side]; f.hp=f.max_hp=hp; f.status.poison=3; f.spells.push({...wait,type}); f.spell_ids[0]=wait.id; }
 const legacy=structuredClone(s); delete legacy.combat_rules_version;
 const action=(turn:number)=>({turn,spell_id:wait.id});
 let result:any=resolvePvpExchange(legacy,action(1),action(1),rng); expect(result.error).toBeUndefined(); expect(result.events.filter((e:any)=>e.kind==="poison").map((e:any)=>e.damage)).toEqual([3,3]);
 let current=s;
 for (const [turn,expected] of [[1,[3,5]],[2,[5,10]],[3,[6,12]]] as const) { result=resolvePvpExchange(current,action(turn),action(turn),rng); expect(result.error).toBeUndefined(); expect(result.events.filter((e:any)=>e.kind==="poison").map((e:any)=>e.damage)).toEqual(expected); current=result.state; }
 expect(current.fighters.left.status.poison).toBe(0); expect(current.fighters.right.status.poison).toBe(0);
});

test("U3.1 brine drain recalculates current HP next exchange", () => {
 const s:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
 const a=s.fighters.left,b=s.fighters.right; a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1; a.hp=a.max_hp-50;b.hp=b.max_hp=1000;
 b.spells.push({id:"fixture_wait",name:"Wait",type:"sulfur",category:"support",power_mult:0,accuracy:1,cooldown_turns:0,effects:[]}); b.spell_ids[0]="fixture_wait";
 const first:any=resolvePvpExchange(s,{turn:1,spell_id:"brine_mend"},{turn:1,spell_id:"fixture_wait"},rng);
 expect(first.error).toBeUndefined(); expect(first.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(60); expect(first.state.pending_drains).toHaveLength(1);
 const second:any=resolvePvpExchange(first.state,{turn:2,spell_id:"bastion_return"},{turn:2,spell_id:"fixture_wait"},rng);
 expect(second.error).toBeUndefined(); expect(second.events.find((e:any)=>e.source==="pending_drain"&&e.kind==="damage").damage).toBe(56); expect(second.state.pending_drains).toHaveLength(0);
});

test("U3.1 delayed brine uses the target's current shield and reflection", () => {
 const state:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
 const a=state.fighters.left,b=state.fighters.right;a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=200;a.max_hp=500;b.hp=b.max_hp=1000;
 b.spells.push({id:"fixture_wait",name:"Wait",type:"sulfur",category:"support",power_mult:0,accuracy:1,cooldown_turns:0,effects:[]});b.spell_ids[0]="fixture_wait";
 const first:any=resolvePvpExchange(state,{turn:1,spell_id:"brine_mend"},{turn:1,spell_id:"fixture_wait"},rng);expect(first.error).toBeUndefined();
 first.state.fighters.right.status.shield_pct=0.5;first.state.fighters.right.status.reflect_pct=0.5;
 const second:any=resolvePvpExchange(first.state,{turn:2,spell_id:"bastion_return"},{turn:2,spell_id:"fixture_wait"},rng);expect(second.error).toBeUndefined();
 expect(second.events.find((event:any)=>event.source==="pending_drain"&&event.kind==="damage").damage).toBe(28);
 expect(second.events.find((event:any)=>event.source==="pending_drain"&&event.kind==="heal").amount).toBe(28);
 expect(second.events.find((event:any)=>event.kind==="reflect"&&event.side==="right").damage).toBe(14);
});

test("U3.1 Hunt and Dungeon persist and recalculate the second brine tick", () => {
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},c,{independentLoadout:true});
 const hunt:any=createCombatState(setup);hunt.player.hp=500;hunt.player.max_hp=1000;hunt.boss.hp=hunt.boss.max_hp=1000;hunt.boss.status.stun=100;
 const h1:any=resolveCombatTurn(hunt,{turn:1,spell_id:"brine_mend",target:"boss"},rng);expect(h1.error).toBeUndefined();expect(h1.next_state.pending_drains).toHaveLength(1);
 const h2:any=resolveCombatTurn(h1.next_state,{turn:2,spell_id:"salt_barrier",target:"boss"},rng);expect(h2.error).toBeUndefined();expect(h2.events.find((e:any)=>e.kind==="damage"&&e.source==="pending_drain").damage).toBe(56);expect(h2.next_state.pending_drains).toHaveLength(0);
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const dungeon:any=createDungeonCombatState(setup,enemy,c);dungeon.player.hp=500;dungeon.player.max_hp=1000;dungeon.npc.hp=dungeon.npc.max_hp=1000;dungeon.npc.status.stun=100;
 const d1:any=resolveDungeonTurn(dungeon,{turn:1,spell_id:"brine_mend"},rng);expect(d1.error).toBeUndefined();expect(d1.next_state.pending_drains).toHaveLength(1);
 const d2:any=resolveDungeonTurn(d1.next_state,{turn:2,spell_id:"salt_barrier"},rng);expect(d2.error).toBeUndefined();expect(d2.events.find((e:any)=>e.kind==="damage"&&e.source==="pending_drain").amount).toBe(56);expect(d2.next_state.pending_drains).toHaveLength(0);
});

test("U3.1 Dungeon NPC retains its own pending brine target", () => {
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const enemy={floor:1,entity_id:"sodium_01",type:"sodium",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sodium};
 const state:any=createDungeonCombatState(setup,enemy,c);state.player.hp=state.player.max_hp=1000;state.npc.hp=500;state.npc.max_hp=1000;state.npc.tempo=1000;state.player.tempo=1;
 for(const id of sodium) if(id!=="brine_mend") state.npc.cooldowns[id]=5;
 const first:any=resolveDungeonTurn(state,{turn:1,spell_id:"ash_temper"},rng);expect(first.error).toBeUndefined();expect(first.next_state.pending_drains).toMatchObject([{source:"npc",target:"player",due_exchange:2}]);
 first.next_state.npc.status.stun=1;
 const second:any=resolveDungeonTurn(first.next_state,{turn:2,spell_id:"cinder_fist"},rng);expect(second.error).toBeUndefined();
 expect(second.events.find((event:any)=>event.kind==="damage"&&event.source==="pending_drain")).toMatchObject({actor:"npc",target:"player",amount:56});
});


test("U3.1 poison ticks in Hunt and Dungeon while old states stay legacy", () => {
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const hunt:any=createCombatState(setup); hunt.player.hp=hunt.player.max_hp=100; hunt.boss.hp=hunt.boss.max_hp=200; hunt.player.status.poison=3;hunt.boss.status.poison=3;hunt.boss.status.stun=100;
 const legacy=structuredClone(hunt);delete legacy.combat_rules_version;
 const action={turn:1,spell_id:"ash_temper",target:"boss"};
 const old:any=resolveCombatTurn(legacy,action,rng);expect(old.error).toBeUndefined();expect(old.events.filter((e:any)=>e.kind==="status_tick").map((e:any)=>e.damage)).toEqual([3,3]);
 const fresh:any=resolveCombatTurn(hunt,action,rng);expect(fresh.error).toBeUndefined();expect(fresh.events.filter((e:any)=>e.kind==="status_tick").map((e:any)=>e.damage)).toEqual([3,5]);
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:200,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const dungeon:any=createDungeonCombatState(setup,enemy,c);dungeon.player.hp=dungeon.player.max_hp=100;dungeon.npc.hp=dungeon.npc.max_hp=200;dungeon.player.status.poison=3;dungeon.npc.status.poison=3;dungeon.npc.status.stun=100;
 const result:any=resolveDungeonTurn(dungeon,{turn:1,spell_id:"ash_temper"},rng);expect(result.error).toBeUndefined();expect(result.events.filter((e:any)=>e.kind==="poison").map((e:any)=>e.amount)).toEqual([3,5]);
});

test("U3.1 burn suppresses defenses for two exchanges without consuming them", () => {
 const s:any=createPvpCombatState(snap("a","sulfur_01",sulfur),snap("b","sodium_01",sodium),c);
 const a=s.fighters.left,b=s.fighters.right; a.entity.base_stats.tempo=100;b.entity.base_stats.tempo=1;a.hp=a.max_hp=b.hp=b.max_hp=1000;
 const spell=structuredClone(c.spells.find((entry:any)=>entry.id==="flash_brine"));a.spells.push(spell);a.spell_ids[1]=spell.id;
 b.spells.push({id:"fixture_wait",name:"Wait",type:"sodium",category:"support",power_mult:0,accuracy:1,cooldown_turns:0,effects:[]});b.spell_ids[0]="fixture_wait";
 const first:any=resolvePvpExchange(s,{turn:1,spell_id:spell.id},{turn:1,spell_id:"fixture_wait"},()=>0);
 expect(first.error).toBeUndefined();expect(first.state.fighters.right.burn_effect).toMatchObject({applied_exchange:1,expires_exchange:3});
 const burned=first.state; burned.fighters.right.status.shield_pct=0.5;burned.fighters.right.status.reflect_pct=0.5;
 const normal=structuredClone(burned);delete normal.fighters.right.burn_effect;
 const attack={turn:2,spell_id:"cinder_fist"},wait={turn:2,spell_id:"fixture_wait"};
 const affected:any=resolvePvpExchange(burned,attack,wait,()=>0.5),plain:any=resolvePvpExchange(normal,attack,wait,()=>0.5);
 expect(affected.error).toBeUndefined();expect(plain.error).toBeUndefined();
 expect(affected.events.find((e:any)=>e.kind==="damage"&&e.side==="left").damage).toBeGreaterThan(plain.events.find((e:any)=>e.kind==="damage"&&e.side==="left").damage);
 expect(affected.events.some((e:any)=>e.kind==="reflect")).toBe(false);expect(affected.state.fighters.right.status.shield_pct).toBe(0.5);expect(affected.state.fighters.right.status.reflect_pct).toBe(0.5);
 const third:any=resolvePvpExchange(affected.state,{turn:3,spell_id:"cinder_fist"},{turn:3,spell_id:"fixture_wait"},()=>0.5);
 expect(third.error).toBeUndefined();expect(third.state.fighters.right.burn_effect).toBeUndefined();expect(third.state.fighters.right.status.shield_pct).toBe(0.5);
});

test("U3.1 status chance is rolled only after a successful hit", () => {
 const state:any=createPvpCombatState(snap("a","sulfur_01",sulfur),snap("b","sodium_01",sodium),c);
 const spell=structuredClone(c.spells.find((entry:any)=>entry.id==="flash_brine"));state.fighters.left.spells.push(spell);state.fighters.left.spell_ids[1]=spell.id;
 state.fighters.left.entity.base_stats.tempo=100;state.fighters.right.entity.base_stats.tempo=1;state.fighters.left.hp=state.fighters.left.max_hp=1000;state.fighters.right.hp=state.fighters.right.max_hp=1000;
 const left={turn:1,spell_id:spell.id},right={turn:1,spell_id:"bastion_return"};
 const success:any=resolvePvpExchange(state,left,right,()=>0.1),failedProc:any=resolvePvpExchange(state,left,right,()=>0.5),miss:any=resolvePvpExchange(state,left,right,()=>0.99);
 expect(success.error).toBeUndefined();expect(success.state.fighters.right.burn_effect).toBeDefined();
 expect(failedProc.error).toBeUndefined();expect(failedProc.state.fighters.right.burn_effect).toBeUndefined();
 expect(miss.error).toBeUndefined();expect(miss.events.some((event:any)=>event.kind==="miss"&&event.side==="left")).toBe(true);expect(miss.state.fighters.right.burn_effect).toBeUndefined();
});

test("U3.1 lethargy lowers spell accuracy and expires on schedule", () => {
 const s:any=createPvpCombatState(snap("a","sulfur_01",sulfur),snap("b","sodium_01",sodium),c);
 const spell=structuredClone(c.spells.find((entry:any)=>entry.id==="salt_rift")); s.fighters.right.spells.push(spell);s.fighters.right.spell_ids[1]=spell.id;
 s.fighters.left.hp=s.fighters.left.max_hp=s.fighters.right.hp=s.fighters.right.max_hp=1000;
 const first:any=resolvePvpExchange(s,{turn:1,spell_id:"ash_temper"},{turn:1,spell_id:spell.id},()=>0);
 expect(first.error).toBeUndefined();expect(first.state.fighters.left.lethargy_effect).toMatchObject({applied_exchange:1,expires_exchange:3});
 const affected:any=resolvePvpExchange(first.state,{turn:2,spell_id:"cinder_fist"},{turn:2,spell_id:"crystal_ram"},()=>0.9);
 expect(affected.error).toBeUndefined();expect(affected.events.some((e:any)=>e.kind==="miss"&&e.side==="left")).toBe(true);
});

test("U3.1 Hunt and Dungeon apply and validate chance-based statuses", () => {
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const effect={kind:"burn",value:1,target:"enemy",chance:0.35};
 const hunt:any=createCombatState(setup);hunt.boss.hp=hunt.boss.max_hp=1000;hunt.boss.status.stun=100;hunt.spells.find((s:any)=>s.id==="cinder_fist").effects.push(effect);
 const h:any=resolveCombatTurn(hunt,{turn:1,spell_id:"cinder_fist",target:"boss"},()=>0);expect(h.error).toBeUndefined();expect(h.next_state.boss.burn_effect).toMatchObject({source:"player",applied_exchange:1,expires_exchange:3});
 const invalid=structuredClone(hunt);invalid.spells.find((s:any)=>s.id==="cinder_fist").effects[0].chance=2;expect(resolveCombatTurn(invalid,{turn:1,spell_id:"cinder_fist",target:"boss"},()=>0).error).toBe("UNSUPPORTED_MECHANIC");
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const dungeon:any=createDungeonCombatState(setup,enemy,c);dungeon.npc.status.stun=100;dungeon.spells.find((s:any)=>s.id==="cinder_fist").effects.push({kind:"lethargy",value:1,target:"enemy",chance:0.3});
 const d:any=resolveDungeonTurn(dungeon,{turn:1,spell_id:"cinder_fist"},()=>0);expect(d.error).toBeUndefined();expect(d.next_state.npc.lethargy_effect).toMatchObject({source:"player",applied_exchange:1,expires_exchange:3});
 const malformed=structuredClone(dungeon);malformed.spells.find((s:any)=>s.id==="cinder_fist").effects[0].chance=-0.1;expect(resolveDungeonTurn(malformed,{turn:1,spell_id:"cinder_fist"},()=>0).error).toBe("UNSUPPORTED_MECHANIC");
});

test("U3.1 Hunt and Dungeon honor burn and lethargy during resolution", () => {
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const hunt:any=createCombatState(setup);hunt.player.hp=hunt.player.max_hp=1000;hunt.boss.hp=hunt.boss.max_hp=1000;hunt.boss.status={stun:100,shield_pct:0.5,reflect_pct:0.5};hunt.boss.burn_effect={source:"player",applied_exchange:0,expires_exchange:2};
 const clearHunt=structuredClone(hunt);delete clearHunt.boss.burn_effect;
 const burnedHunt:any=resolveCombatTurn(hunt,{turn:1,spell_id:"cinder_fist",target:"boss"},rng),plainHunt:any=resolveCombatTurn(clearHunt,{turn:1,spell_id:"cinder_fist",target:"boss"},rng);
 expect(burnedHunt.error).toBeUndefined();expect(plainHunt.error).toBeUndefined();
 expect(burnedHunt.events.find((e:any)=>e.kind==="damage"&&e.actor==="player").damage).toBeGreaterThan(plainHunt.events.find((e:any)=>e.kind==="damage"&&e.actor==="player").damage);expect(burnedHunt.next_state.boss.status.shield_pct).toBe(0.5);
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const dungeon:any=createDungeonCombatState(setup,enemy,c);dungeon.player.hp=dungeon.player.max_hp=1000;dungeon.npc.status={stun:100,shield:0.5,reflect:0.5};dungeon.npc.burn_effect={source:"player",applied_exchange:0,expires_exchange:2};
 const clearDungeon=structuredClone(dungeon);delete clearDungeon.npc.burn_effect;
 const burnedDungeon:any=resolveDungeonTurn(dungeon,{turn:1,spell_id:"cinder_fist"},rng),plainDungeon:any=resolveDungeonTurn(clearDungeon,{turn:1,spell_id:"cinder_fist"},rng);
 expect(burnedDungeon.error).toBeUndefined();expect(plainDungeon.error).toBeUndefined();
 expect(burnedDungeon.events.find((e:any)=>e.kind==="damage"&&e.actor==="player").amount).toBeGreaterThan(plainDungeon.events.find((e:any)=>e.kind==="damage"&&e.actor==="player").amount);expect(burnedDungeon.next_state.npc.status.shield).toBe(0.5);
 const lethargicHunt=structuredClone(hunt);lethargicHunt.player.lethargy_effect={source:"boss",applied_exchange:0,expires_exchange:2};
 expect(resolveCombatTurn(lethargicHunt,{turn:1,spell_id:"cinder_fist",target:"boss"},()=>0.9).events.some((e:any)=>e.kind==="miss"&&e.actor==="player")).toBe(true);
 const lethargicDungeon=structuredClone(dungeon);lethargicDungeon.player.lethargy_effect={source:"npc",applied_exchange:0,expires_exchange:2};
 expect(resolveDungeonTurn(lethargicDungeon,{turn:1,spell_id:"cinder_fist"},()=>0.9).events.some((e:any)=>e.kind==="spell"&&e.actor==="player"&&e.hit===false)).toBe(true);
});

test("U3.1 catalog chances and poison cooldowns remain valid", () => {
 expect(c.spells).toHaveLength(94);
 for (const spell of c.spells) if (spell.effects.some((effect:any)=>["poison","poison_on_reflect"].includes(effect.kind))) expect(spell.cooldown_turns).toBe(4);
 for (const [id,kind,chance] of [["quicksilver_solvent","poison",0.3],["crooked_rune","poison",0.25],["volatile_current","burn",0.35],["flash_brine","burn",0.25],["ember_anomaly","burn",0.2],["phase_quicksilver","lethargy",0.3],["paradox_edict","lethargy",0.25],["salt_rift","lethargy",0.2]] as const) {
  const spell=c.spells.find((entry:any)=>entry.id===id);expect(spell.effects.find((effect:any)=>effect.kind===kind)).toMatchObject({target:"enemy",chance});
  expect(spell.effects.filter((effect:any)=>["poison","burn","lethargy"].includes(effect.kind))).toHaveLength(1);
 }
});

test("U3.1 affected spells are eligible in Hunt Dungeon and PvP", () => {
 for (const id of ["quicksilver_solvent","crooked_rune","volatile_current","flash_brine","ember_anomaly","phase_quicksilver","paradox_edict","salt_rift"]) {
  const spell=c.spells.find((entry:any)=>entry.id===id), type=spell.eligible_types[0], entity_id=`${type}_01`;
  const native=c.spells.filter((entry:any)=>entry.type===type).slice(0,3).map((entry:any)=>entry.id), equipped=[id,...native];
  const progress={learned_by_entity:{[entity_id]:[id]}};
  const trusted=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:progress},{entity_id,weapon_ids:[null,null],homunculus_id:null,spell_ids:equipped,mode:"attack"},c,{independentLoadout:true});
  expect((trusted as any).error).toBeUndefined();expect(createCombatState(trusted).error).toBeUndefined();
  const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
  expect(createDungeonCombatState(trusted,enemy,c).error).toBeUndefined();
  expect((createPvpCombatState(snap("a",entity_id,equipped),snap("b","sulfur_01",sulfur),c) as any).error).toBeUndefined();
 }
});

test("U3.1 malformed persisted effects are rejected before consuming RNG", () => {
 const s:any=createPvpCombatState(snap("a","sulfur_01",sulfur),snap("b","sodium_01",sodium),c);
 s.fighters.left.burn_effect={source:"right",applied_exchange:0,expires_exchange:10};let draws=0;
 expect(resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"crystal_ram"},()=>{draws++;return 0.5;})).toEqual({error:"PVP_COMBAT_PARITY_UNAVAILABLE"});expect(draws).toBe(0);
 delete s.fighters.left.burn_effect;s.pending_drains=[{source:"left",target:"right",due_exchange:0}];
 expect(resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"crystal_ram"},()=>{draws++;return 0.5;})).toEqual({error:"PVP_COMBAT_PARITY_UNAVAILABLE"});expect(draws).toBe(0);
 delete s.pending_drains;s.fighters.left.status.poison=4;
 expect(resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"crystal_ram"},()=>{draws++;return 0.5;})).toEqual({error:"PVP_COMBAT_PARITY_UNAVAILABLE"});expect(draws).toBe(0);
 s.fighters.left.status.poison=2;s.fighters.left.poison_effect={stage:4,applied_exchange:0,expires_exchange:2,source:"right"};
 expect(resolvePvpExchange(s,{turn:1,spell_id:"cinder_fist"},{turn:1,spell_id:"crystal_ram"},()=>{draws++;return 0.5;})).toEqual({error:"PVP_COMBAT_PARITY_UNAVAILABLE"});expect(draws).toBe(0);
});

test("U3.1 toxin ward scales against the percentage tick", () => {
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sulfur,mode:"attack"},c,{independentLoadout:true});
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const state:any=createDungeonCombatState(setup,enemy,c);state.player.hp=state.player.max_hp=200;state.player.status.poison=3;state.npc.status.stun=100;
 state.blessing={selected:"toxin_ward",tier:1,poison_remainder:0};
 const result:any=resolveDungeonTurn(state,{turn:1,spell_id:"ash_temper"},()=>0.5);
 expect(result.error).toBeUndefined();expect(result.events.find((event:any)=>event.kind==="poison"&&event.side==="player").amount).toBe(4);
});

test("U3.1 inspiration does not resolve a pending poison or drain tick", () => {
 const state:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
 state.turn=1;state.fighters.left.inspiration_pending=true;state.fighters.left.status.poison=2;
 state.fighters.left.inspiration_offers=state.fighters.left.inspiration_catalog.slice(0,3).map((spell:any)=>spell.id);
 state.fighters.left.poison_effect={stage:1,applied_exchange:1,source:"right"};
 state.pending_drains=[{source:"left",target:"right",due_exchange:2}];
 const before=structuredClone(state);
 const result:any=resolvePvpInspiration(state,"left",{kind:"decline"},rng);
 expect(result.error).toBeUndefined();expect(result.state.fighters.left.hp).toBe(before.fighters.left.hp);
 expect(result.state.fighters.left.poison_effect).toEqual(before.fighters.left.poison_effect);expect(result.state.pending_drains).toEqual(before.pending_drains);
});

test("U3.1 ultra does not double brine and a new battle clears pending effects", () => {
 const state:any=createPvpCombatState(snap("a","sodium_01",sodium),snap("b","sulfur_01",sulfur),c);
 state.battle_index=3;state.wins={left:1,right:1};state.fighters.left.entity.base_stats.tempo=100;state.fighters.right.entity.base_stats.tempo=1;
 state.fighters.right.hp=state.fighters.right.max_hp=1000;
 const result:any=resolvePvpExchange(state,{turn:1,spell_id:"brine_mend",ultra:true},{turn:1,spell_id:"ash_temper"},()=>0.5);
 expect(result.error).toBeUndefined();expect(result.events.find((e:any)=>e.kind==="damage"&&e.spell_id==="brine_mend").damage).toBe(60);
 result.state.fighters.left.burn_effect={source:"right",applied_exchange:1,expires_exchange:3};
 const reset:any=startPvpBattle(result.state);expect(reset.pending_drains).toEqual([]);expect(reset.fighters.left.burn_effect).toBeUndefined();expect(reset.fighters.left.poison_effect).toBeUndefined();
});

test("U3.1 pending brine expires if its original caster has fallen", () => {
 const setup=buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sodium_01",weapon_ids:[null,null],homunculus_id:null,spell_ids:sodium,mode:"attack"},c,{independentLoadout:true});
 const enemy={floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1000,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:sulfur};
 const state:any=createDungeonCombatState(setup,enemy,c);state.player.hp=1;state.npc.tempo=1000;state.player.tempo=1;
 state.pending_drains=[{source:"player",target:"npc",due_exchange:1}];
 for(const id of sulfur) if(id!=="cinder_fist") state.npc.cooldowns[id]=2;
 const result:any=resolveDungeonTurn(state,{turn:1,spell_id:"crystal_ram"},()=>0.5);
 expect(result.error).toBeUndefined();expect(result.next_state.player.hp).toBe(0);
 expect(result.events.some((event:any)=>event.source==="pending_drain")).toBe(false);expect(result.next_state.pending_drains).toHaveLength(0);
});
