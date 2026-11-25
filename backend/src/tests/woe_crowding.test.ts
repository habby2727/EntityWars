import {test,expect} from 'bun:test';
import {arena,cardById} from '../woe/catalog';
import {initializeMatch,applyDeployment,advanceTick,formationPoint,route} from '../woe/engine';
import {initializeCoreDefense,applyCoreDefenseDeployment,advanceCoreDefenseTick,enemyStats} from '../woe/core_defense';

// Synthetic plaza populations; no health, damage, speed or range is boosted.
test('crowded opposing WOE units fight deterministically and reroute after laboratory destruction',()=>{
 let s=initializeMatch('1v1','crowd',['blue','red']);
 for(const p of s.controllers){p.zealTenths=100;const r=applyDeployment(s,{controllerId:p.id,actionId:p.id,slot:0,cardId:p.slots[0],lane:'left'});if(!r.accepted)throw Error(r.reason);s=r.state;}
 const templates=s.units;s.units=Array.from({length:100},(_,i)=>{const team=i<50?'blue':'red',id=i+1,u=structuredClone(templates.find(x=>x.team===team)!);u.id=id;u.cardId=['neon','mantillo','solcarp'][i%3];u.hp=cardById[u.cardId].hp;u.position=formationPoint({x:960,y:team==='blue'?568:512},id);u.route=route(team,'left','left',id);u.waypoint=4;return u;});
 s.nextUnitId=101;s.laboratories.find(l=>l.id==='red:left')!.hp=0;
 function run(){let state=structuredClone(s),attacks=0;for(let i=0;i<300&&!state.result;i++){state=advanceTick(state);expect(state.units.length).toBeLessThanOrEqual(100);for(const u of state.units)expect(Number.isFinite(u.position.x)&&Number.isFinite(u.position.y)).toBe(true);for(const e of state.events){if(e.type==='attack'){attacks++;expect(Math.hypot(e.position.x-e.targetPosition.x,e.position.y-e.targetPosition.y)).toBeLessThanOrEqual(cardById[e.cardId].range+0.00001)}}}return {state,attacks};}
 const a=run(),b=run();expect(a).toEqual(b);expect(a.attacks).toBeGreaterThan(0);expect(a.state.units.filter(u=>u.team==='blue').every(u=>u.targetLane==='right')).toBe(true);
});

test('crowded CD wave has finite combat, deterministic progression and bounded populations',()=>{
 let s=initializeCoreDefense('solo','crowd',['human']);s.controllers[0].zealTenths=100;
 const deployed=applyCoreDefenseDeployment(s,{controllerId:'human',actionId:'seed',slot:0,cardId:s.controllers[0].slots[0],lane:'left'});if(!deployed.accepted)throw Error(deployed.reason);s=advanceCoreDefenseTick(deployed.state);
 const ally=s.units.find(u=>u.kind==='homunculus')!,enemy=s.units.find(u=>u.kind==='enemy')!;
 s.units=Array.from({length:100},(_,i)=>{const u=structuredClone(i<50?ally:enemy),id=i+1;u.id=id;u.position=formationPoint({x:960,y:i<50?568:512},id);u.route=route(u.team,'left','left',id);u.waypoint=4;return u;});s.nextUnitId=101;s.pendingSpawns=0;s.laboratories.find(l=>l.id==='blue:left')!.hp=0;
 function run(){let state=structuredClone(s),attacks=0;for(let i=0;i<300&&!state.result;i++){const ranges=new Map(state.units.map(u=>[u.id,u.range]));state=advanceCoreDefenseTick(state);expect(state.units.length).toBeLessThanOrEqual(100);for(const u of state.units)expect(Number.isFinite(u.position.x)&&Number.isFinite(u.position.y)).toBe(true);for(const event of state.events){if(event.type==='attack'){const e=event as any;attacks++;expect(Math.hypot(e.position.x-e.targetPosition.x,e.position.y-e.targetPosition.y)).toBeLessThanOrEqual((ranges.get(e.attacker)??0)+0.00001)}}}return {state,attacks};}
 const a=run(),b=run();expect(a).toEqual(b);expect(a.attacks).toBeGreaterThan(0);expect(a.state.enemiesKilled>0||a.state.result!==null||a.state.completedWaves>0).toBe(true);
});

test('short-range WOE and CD units reach surviving laboratories after rerouting',()=>{
 for(const id of [1,5,25,26,50,75,100]) {
  for(const team of ['blue','red'] as const){
   let s=initializeMatch('1v1','redirect',['blue','red']);const p=s.controllers.find(x=>x.team===team)!;p.zealTenths=100;
   const applied=applyDeployment(s,{controllerId:p.id,actionId:'seed',slot:0,cardId:p.slots[0],lane:'left'});if(!applied.accepted)throw Error(applied.reason);s=applied.state;
   const u=s.units[0];u.id=id;u.cardId='neon';u.hp=cardById.neon.hp;u.position=formationPoint({x:960,y:team==='blue'?568:512},id);u.route=route(team,'left','left',id);u.waypoint=4;
   const target=team==='blue'?'red':'blue';s.laboratories.find(l=>l.id===`${target}:left`)!.hp=0;
   let attacked=false;for(let i=0;i<250&&!attacked;i++){s=advanceTick(s);attacked=s.events.some(e=>e.type==='attack'&&e.target===`${target}:right`)}
   expect(attacked).toBe(true);
  }
  let s=advanceCoreDefenseTick(initializeCoreDefense('solo','redirect',['human']));const u=s.units.find(x=>x.kind==='enemy')!;const stats=enemyStats('mycelion',2);
  Object.assign(u,stats,{id,cardId:stats.id,kind:'enemy',position:formationPoint({x:960,y:512},id),route:route('red','left','left',id),waypoint:4,formation:true});
  s.units=[u];s.pendingSpawns=0;s.laboratories.find(l=>l.id==='blue:left')!.hp=0;
  let attacked=false;for(let i=0;i<250&&!attacked;i++){s=advanceCoreDefenseTick(s);attacked=s.events.some(e=>e.type==='attack'&&e.target==='blue:right')}
  expect(attacked).toBe(true);
 }
});
