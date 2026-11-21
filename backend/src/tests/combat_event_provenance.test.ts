import { test, expect } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { recordPoisonChange, poisonTickMetadata, resolveOpponentPoisonDamage, recordInspirationActivation } from "../combat_event_provenance";
import { newExpeditionPassiveState, beginPassiveExchange, finishPassiveExchange, triggerInspirationActivation, passiveModifiers } from "../expedition_passive_state";
import { buildTrustedCombatSetup, createCombatState, resolveCombatTurn, resolveInspirationDecision } from "../solo_hunt_combat";
import { createDungeonCombatState, resolveDungeonTurn, resolveDungeonInspiration } from "../dungeon_combat";
import { createPvpCombatState, resolvePvpExchange, resolvePvpInspiration } from "../pvp/combat";
const read=(n:string)=>JSON.parse(readFileSync(resolve(import.meta.dir,"../../../data",n),"utf8"));
const c={entities:read("entities.json").entities,items:read("items.json").items,homunculi:read("homunculi.json").homunculi,spells:read("spells.json").spells,types:read("types.json"),mutations:read("static/mutations.json").mutations,balance:read("static/balance.json").balance,bosses:read("static/solo_bosses.json").bosses};
const ids=["cinder_fist","furnace_rush","ash_temper","brimstone_crash"];
const setup=()=>buildTrustedCombatSetup({player_id:"a",state_revision:0,boss_id:"hunt_common",boss_entity_id:"sodium_01",spell_progress:{}},{entity_id:"sulfur_01",weapon_ids:[null,null],homunculus_id:"cinder",spell_ids:ids,mode:"attack"},c,{independentLoadout:true});
const snap=(player_id:string,type:string)=>({player_id,entity_id:`${type}_01`,weapon_ids:[null,null],homunculus_id:null,spell_ids:c.spells.filter((s:any)=>s.type===type).slice(0,4).map((s:any)=>s.id)});

test("provenance changes only on an effective application and expires, including unknown old state",()=>{
 const victim:any={status:{poison:2}}; expect(poisonTickMetadata(victim,"boss",["player","boss"],2,1).source).toBeNull();
 victim.status.poison=3; recordPoisonChange(victim,2,"player"); expect(victim.poison_source).toBe("player");
 recordPoisonChange(victim,3,"boss"); expect(victim.poison_source).toBe("player");
 victim.status.poison=5; recordPoisonChange(victim,3,"boss"); expect(victim.poison_source).toBe("boss");
 const tick=poisonTickMetadata(victim,"player",["player","boss"],1,2); expect(resolveOpponentPoisonDamage(tick,"boss",[])).toEqual({marker:"poison:2:player",amount:1});
 expect(resolveOpponentPoisonDamage(tick,"boss",["poison:2:player"])).toBeNull(); expect(resolveOpponentPoisonDamage(tick,"player",[])).toBeNull(); expect(resolveOpponentPoisonDamage({...tick,source:"player"},"player",[])).toBeNull(); expect(resolveOpponentPoisonDamage({...tick,actual_damage:0},"boss",[])).toBeNull();
 victim.status.poison=0; recordPoisonChange(victim,0,null); expect(victim.poison_source).toBeUndefined();
});

test("Hunt, Dungeon and Ranked emit capped attributable ticks and survive JSON replay",()=>{
 const hunt=createCombatState(setup()); hunt.boss.status.poison=1; hunt.boss.poison_source="player"; hunt.boss.hp=2; hunt.boss.max_hp=1000; hunt.player.atk=0; hunt.boss_intent="Shield"; hunt.boss_shield_turns=0; hunt.boss_shield_cooldown=0; hunt.boss_shield_phases=[];
 // A support spell leaves the victim alive for the poison tick.
 hunt.spells[0].category="support"; hunt.spells[0].power_mult=0; hunt.spells[0].effects=[]; hunt.spells[0].accuracy=1;
 const h=resolveCombatTurn(hunt,{turn:1,spell_id:ids[0],target:"boss"},()=>0.5); const ht=h.events.find((e:any)=>e.status==="poison" && e.kind==="status_tick"); expect(ht).toMatchObject({source:"player",victim:"boss",actual_damage:2,exchange:1}); expect(h.next_state.boss.poison_source).toBeUndefined(); expect(resolveCombatTurn(JSON.parse(JSON.stringify(hunt)),{turn:1,spell_id:ids[0],target:"boss"},()=>0.5)).toEqual(h);
 const d=createDungeonCombatState(setup(),{floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:ids},c); d.npc.status.poison=1; d.npc.poison_source="player"; d.spells.find((s:any)=>s.id===ids[0]).category="support"; d.spells.find((s:any)=>s.id===ids[0]).power_mult=0; d.spells.find((s:any)=>s.id===ids[0]).effects=[];
 const dr=resolveDungeonTurn(d,{turn:1,spell_id:ids[0]},()=>0.5); expect(dr.events.find((e:any)=>e.kind==="poison" && e.side==="npc")).toMatchObject({source:"player",victim:"npc",actual_damage:3,exchange:1});
 const p:any=createPvpCombatState(snap("a","sulfur"),snap("b","mercury"),c); p.fighters.right.status.poison=1; p.fighters.right.poison_source="left"; const l=p.fighters.left.spell_ids[0], r=p.fighters.right.spell_ids[0];
 const pr:any=resolvePvpExchange(p,{turn:1,spell_id:l},{turn:1,spell_id:r},()=>0.5); expect(pr.events.find((e:any)=>e.kind==="poison" && e.side==="right")).toMatchObject({source:"left",victim:"right",actual_damage:3,exchange:1});
});

test("Inspiration marker maps successful choice to next exchange and rejects duplicate",()=>{
 const marker=recordInspirationActivation({},"player",3), context:any={fighter:{hp:40,max_hp:100,shielded:false,consecutive_spell_hits:0,attacks_made:0},target:{debuffed:false},type_relation:"neutral",poison_damage:0};
 let state=newExpeditionPassiveState("nebulynx",10); for(let i=1;i<=3;i++) state=beginPassiveExchange(state,i); state=finishPassiveExchange(state);
 const out=triggerInspirationActivation(state,marker,context); expect(out.activated).toBe(true); expect(triggerInspirationActivation(out.state,marker,context).activated).toBe(false);
 state=beginPassiveExchange(out.state,4); expect(passiveModifiers(state)).toEqual({power_flat:3,tempo_flat:2});
 expect(()=>triggerInspirationActivation(out.state,{...marker,activates_at:9},context)).toThrow();
});

test("each Inspiration resolver records only a validated choice, with deterministic replay",()=>{
 const hunt=createCombatState(setup()); hunt.player.inspiration_pending=true; hunt.inspiration_offers=hunt.inspiration_catalog.slice(0,3).map((s:any)=>s.id); const offer=hunt.inspiration_offers[0];
 const chosen=resolveInspirationDecision(hunt,{kind:"choose",spell_id:offer},()=>0.4); expect(chosen.next_state.player.inspiration_activation).toMatchObject({actor:"player",exchange:0,activates_at:1}); expect(resolveInspirationDecision(JSON.parse(JSON.stringify(hunt)),{kind:"choose",spell_id:offer},()=>0.4)).toEqual(chosen); expect(resolveInspirationDecision(chosen.next_state,{kind:"choose",spell_id:offer},()=>0.4).error).toBe("INVALID_DECISION");
 const declined=resolveInspirationDecision(hunt,{kind:"decline"},()=>{throw Error("unexpected draw")}); expect(declined.next_state.player.inspiration_activation).toBeUndefined(); expect(resolveInspirationDecision(hunt,{kind:"choose",spell_id:"forged"},()=>0).error).toBe("INVALID_DECISION");
 const dungeon=createDungeonCombatState(setup(),{floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:ids},c); dungeon.player.inspiration_pending=true; dungeon.player.inspiration_offers=dungeon.inspiration_catalog.player.slice(0,3).map((s:any)=>s.id); const dd={kind:"choose",spell_id:dungeon.player.inspiration_offers[0]}; const dc=resolveDungeonInspiration(dungeon,dd,()=>0.4); expect(dc.next_state.player.inspiration_activation).toMatchObject({actor:"player",exchange:0,activates_at:1}); expect(resolveDungeonInspiration(dc.next_state,dd,()=>0).error).toBe("INVALID_DECISION"); expect(resolveDungeonInspiration(dungeon,{kind:"decline"},()=>0).next_state.player.inspiration_activation).toBeUndefined();
 const p:any=createPvpCombatState(snap("a","sulfur"),snap("b","mercury"),c); const f=p.fighters.left; f.inspiration_pending=true; f.inspiration_offers=f.inspiration_catalog.slice(0,3).map((s:any)=>s.id); const pd:any={kind:"choose",spell_id:f.inspiration_offers[0]}; const pc:any=resolvePvpInspiration(p,"left",pd,()=>0.4); expect(pc.state.fighters.left.inspiration_activation).toMatchObject({actor:"left",exchange:0,activates_at:1}); expect(resolvePvpInspiration(pc.state,"left",pd,()=>0)).toEqual({error:"INVALID_DECISION"}); expect((resolvePvpInspiration(p,"left",{kind:"decline"},()=>0) as any).state.fighters.left.inspiration_activation).toBeUndefined();
});

test("ranked spell application and reflection maintain sources",()=>{
 const p:any=createPvpCombatState(snap("a","sulfur"),snap("b","mercury"),c); const a=p.fighters.left, b=p.fighters.right; const l=a.spells.find((x:any)=>x.id===a.spell_ids[0]), r=b.spells.find((x:any)=>x.id===b.spell_ids[0]);
 l.category="support"; l.power_mult=0; l.accuracy=1; l.effects=[{kind:"poison",target:"enemy",value:3}]; r.category="support"; r.power_mult=0; r.accuracy=1; r.effects=[];
 const out:any=resolvePvpExchange(p,{turn:1,spell_id:l.id},{turn:1,spell_id:r.id},()=>0.5); expect(out.events.find((e:any)=>e.kind==="poison" && e.side==="right")).toMatchObject({source:"left",actual_damage:3}); expect(out.state.fighters.right.poison_source).toBe("left");
 const q:any=createPvpCombatState(snap("a","sulfur"),snap("b","mercury"),c); q.fighters.right.status.reflect_pct=0.5; q.fighters.right.status.poison_on_reflect=3; q.fighters.right.poison_reflect_source="right"; const reflected:any=resolvePvpExchange(q,{turn:1,spell_id:q.fighters.left.spell_ids[0]},{turn:1,spell_id:q.fighters.right.spell_ids[0]},()=>0.5); expect(reflected.events.find((e:any)=>e.kind==="poison" && e.side==="left")).toMatchObject({source:"right",victim:"left"});
 const z:any=createPvpCombatState(snap("a","sulfur"),snap("b","mercury"),c); const zl=z.fighters.left, zr=z.fighters.right; zl.status.poison=4; zl.poison_source="right"; const clean=zl.spells.find((x:any)=>x.id===zl.spell_ids[0]); clean.category="support"; clean.power_mult=0; clean.effects=[{kind:"cleanse_one",target:"self",value:1}]; clean.accuracy=1; const zrSpell=zr.spells.find((x:any)=>x.id===zr.spell_ids[0]); zrSpell.category="support"; zrSpell.power_mult=0; zrSpell.effects=[]; const cleansed:any=resolvePvpExchange(z,{turn:1,spell_id:clean.id},{turn:1,spell_id:zrSpell.id},()=>0.5); expect(cleansed.state.fighters.left.status.poison).toBe(0); expect(cleansed.state.fighters.left.poison_source).toBeUndefined();
});

test("direct Hunt and Dungeon spells attribute new poison without changing duration",()=>{
 const hunt=createCombatState(setup()); const hs=hunt.spells.find((s:any)=>s.id===ids[0]); hs.category="support"; hs.power_mult=0; hs.accuracy=1; hs.effects=[{kind:"poison",target:"enemy",value:3}]; const h=resolveCombatTurn(hunt,{turn:1,spell_id:hs.id,target:"boss"},()=>0.5); expect(h.events.find((e:any)=>e.kind==="status_tick" && e.target==="boss")).toMatchObject({source:"player",actual_damage:3}); expect(h.next_state.boss.status.poison).toBe(2);
 const d=createDungeonCombatState(setup(),{floor:1,entity_id:"sulfur_01",type:"sulfur",hp:1000,attack:1,defense:1,homunculus_id:"cinder",homunculus_level:0,spell_ids:ids},c); const ds=d.spells.find((s:any)=>s.id===ids[0]); ds.category="support"; ds.power_mult=0; ds.accuracy=1; ds.effects=[{kind:"poison",target:"enemy",value:3}]; const out=resolveDungeonTurn(d,{turn:1,spell_id:ds.id},()=>0.5); expect(out.events.find((e:any)=>e.kind==="poison" && e.side==="npc")).toMatchObject({source:"player",actual_damage:3}); expect(out.next_state.npc.status.poison).toBe(2);
});
