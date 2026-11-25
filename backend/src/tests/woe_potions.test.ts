import {expect,test} from 'bun:test';
import {initializeMatch,applyDeployment,advanceTick,getPublicSnapshot} from '../woe/engine';
import {initializeCoreDefense,applyCoreDefenseDeployment,advanceCoreDefenseTick,getCoreDefenseSnapshot} from '../woe/core_defense';
import {cardById,potionById} from '../woe/catalog';
import {chooseBotDeployment} from '../woe/bot_ai';

function battlefield(){
 let s=initializeMatch('1v1','potions',['a','b']);const p=s.controllers[1];p.zealTenths=100;p.slots[0]='neon';
 s=applyDeployment(s,{controllerId:'b',actionId:'enemy',slot:0,cardId:'neon',lane:'left'}).state;
 const u=s.units[0];u.position={x:960,y:540};u.route=[{x:960,y:800}];u.waypoint=0;u.cooldown=10;u.hp=150;
 s.controllers[0].zealTenths=100;return s;
}
function cast(s:ReturnType<typeof initializeMatch>,id:string,action:string,point={x:960,y:540}){
 s.controllers[0].slots[0]=id;
 return applyDeployment(s,{controllerId:'a',actionId:action,slot:0,cardId:id,target_x:point.x,target_y:point.y});
}
test('potion validation, rotation, empty casts, immutable denial and legacy ten-card decks',()=>{
 let s=battlefield();s.controllers[0].slots[0]='thunderlock';const before=structuredClone(s),base={controllerId:'a',actionId:'p',slot:0,cardId:'thunderlock'};
 for(const bad of [{...base,lane:'left' as const,target_x:1,target_y:1},{...base,target_x:NaN,target_y:0},{...base,target_x:1921,target_y:0},{...base,target_x:1,target_y:-1},{...base,slot:9,target_x:1,target_y:1},{...base,cardId:'vitriol_potion',target_x:1,target_y:1}])expect(applyDeployment(s,bad).accepted).toBe(false);
 expect(s).toEqual(before);
 const next=s.controllers[0].queue[0],out=applyDeployment(s,{...base,target_x:0,target_y:0});expect(out.accepted).toBe(true);s=out.state;
 expect(s.controllers[0].slots[0]).toBe(next);expect(s.controllers[0].queue.at(-1)).toBe('thunderlock');expect(s.controllers[0].zealTenths).toBe(70);expect(s.units).toHaveLength(1);expect(s.units[0].paralyzedUntil).toBeUndefined();
 expect(applyDeployment(s,{...base,target_x:0,target_y:0})).toMatchObject({accepted:false,reason:'DUPLICATE_ACTION_ID'});
 const legacy=initializeMatch('1v1','legacy',['a','b']);legacy.controllers[0].slots=['neon','luny','mantillo'];legacy.controllers[0].queue=['cedix','venam','flincho','solcarp','hyrox','astralotl','nebulynx'];
 const d=applyDeployment(JSON.parse(JSON.stringify(legacy)),{controllerId:'a',actionId:'legacy',slot:0,cardId:'neon',lane:'left'});expect(d.accepted).toBe(true);expect(d.state.controllers[0].slots).toHaveLength(3);expect(d.state.controllers[0].queue).toHaveLength(7);
});
test('thunderlock freezes exactly 50 subsequent ticks without advancing cooldown and does not stack',()=>{
 let s=battlefield();s=cast(s,'thunderlock','first').state;const origin={...s.units[0].position};
 for(let i=0;i<10;i++)s=advanceTick(s);s=JSON.parse(JSON.stringify(s));s.controllers[0].zealTenths=100;s=cast(s,'thunderlock','again').state;
 expect(s.units[0].paralyzedUntil).toBe(50);
 for(let i=10;i<50;i++){s=advanceTick(s);expect(s.units[0].position).toEqual(origin);expect(s.units[0].cooldown).toBe(10);}
 expect(getPublicSnapshot(s,'a').units[0].paralyzed_until).toBeUndefined();s=advanceTick(JSON.parse(JSON.stringify(s)));
 expect(s.units[0].position).not.toEqual(origin);expect(s.units[0].cooldown).toBe(9);
});
test('casts ignore allies and capacity, including intermission and the technical unit cap',()=>{
 let s=battlefield();s.units.push({...structuredClone(s.units[0]),id:2,team:'blue'});s=cast(s,'thunderlock','friendly').state;
 expect(s.units[0].paralyzedUntil).toBe(50);expect(s.units[1].paralyzedUntil).toBeUndefined();
 let full=battlefield();full.units=Array.from({length:100},(_,i)=>({...structuredClone(full.units[0]),id:i+1}));
 expect(cast(full,'vitriol_potion','technical').accepted).toBe(true);
 let cd=initializeCoreDefense('solo','cap-potion',['a']);cd.controllers[0].slots[0]='neon';cd.controllers[0].zealTenths=100;
 cd=applyCoreDefenseDeployment(cd,{controllerId:'a',actionId:'unit',slot:0,cardId:'neon',lane:'left'}).state;
 cd.units=Array.from({length:4},(_,i)=>({...structuredClone(cd.units[0]),id:i+1}));cd.phase='intermission';cd.intermissionTicks=30;
 cd.controllers[0].slots[1]='thunderlock';cd.controllers[0].zealTenths=100;
 const out=applyCoreDefenseDeployment(cd,{controllerId:'a',actionId:'potion-at-cap',slot:1,cardId:'thunderlock',target_x:0,target_y:0});
 expect(out.accepted).toBe(true);expect(out.state.units).toHaveLength(4);expect(out.state.controllers[0].zealTenths).toBe(70);
});
test('poison ticks at 10, 20 and 30, slows exactly, does not stack and excludes later entrants',()=>{
 let s=battlefield();const other={...structuredClone(s.units[0]),id:2,position:{x:1300,y:540}};s.units.push(other);
 const labBefore=structuredClone(s.laboratories);s=cast(s,'vitriol_potion','first').state;
 expect(s.units[0].poisonUntil).toBe(30);expect(s.units[1].poisonUntil).toBeUndefined();
 for(let i=1;i<=30;i++){
  if(i===11)s.units[1].position={x:960,y:540};
  s=advanceTick(s);
  expect(s.units[0].hp).toBe(150-Math.floor(i/10)*15);
  if(i===10){expect(s.units[0].cooldown).toBe(4);s.controllers[0].zealTenths=100;s=cast(s,'vitriol_potion','again').state;expect(s.units[0].poisonUntil).toBe(30);}
 }
 expect(s.units[1].poisonUntil).toBeUndefined();expect(s.laboratories.map(l=>l.hp)).toEqual(labBefore.map(l=>l.hp));
 expect(s.units[0].position.y).toBeCloseTo(540+30*cardById.neon.speed*0.85*0.1*0.6,5);
});
test('poisoned attack cooldown advances at exactly three fifths and resumes normally',()=>{
 let s=battlefield();s.units[0].cooldown=0;s.units[0].route=[];
 s.units.push({...structuredClone(s.units[0]),id:2,team:'blue',position:{x:980,y:540},hp:10000,cooldown:1000});
 s=cast(s,'vitriol_potion','slow-attacks').state;const attacks:number[]=[];
 for(let i=0;i<35;i++){s=advanceTick(s);if(s.events.some(e=>e.type==='attack'&&e.attacker===1))attacks.push(s.tick);}
 expect(attacks).toEqual([1,18,33]);
});
test('poison continues during paralysis and status kills award CD wave progress once',()=>{
 let s=battlefield();s=cast(s,'vitriol_potion','poison').state;s.controllers[0].zealTenths=100;s=cast(s,'thunderlock','stun').state;
 for(let i=0;i<30;i++)s=advanceTick(s);expect(s.units[0].hp).toBe(105);expect(s.units[0].cooldown).toBe(10);expect(s.units[0].position).toEqual({x:960,y:540});
 let cd=advanceCoreDefenseTick(initializeCoreDefense('solo','poison',['a']));const e=cd.units.find(u=>u.kind==='enemy')!;e.hp=1;e.position={x:960,y:540};e.route=[];cd.pendingSpawns=0;cd.controllers[0].slots[0]='vitriol_potion';cd.controllers[0].zealTenths=100;
 const out=applyCoreDefenseDeployment(cd,{controllerId:'a',actionId:'poison',slot:0,cardId:'vitriol_potion',target_x:960,target_y:540});expect(out.accepted).toBe(true);cd=out.state;
 for(let i=0;i<10;i++){if(i===5)cd=JSON.parse(JSON.stringify(cd));cd=advanceCoreDefenseTick(cd);}
 expect(cd.enemiesKilled).toBe(1);expect(cd.completedWaves).toBe(1);expect(cd.events.filter(e=>e.type==='death')).toHaveLength(1);expect(cd.units.some(u=>u.id===e.id)).toBe(false);
 expect(getCoreDefenseSnapshot(cd,'a').enemiesKilled).toBe(1);
});
test('bot casts only on useful visible clusters and never while ahead',()=>{
 let s=battlefield();s.controllers[0].slots=['thunderlock','hyrox','astralotl','solcarp'];s.controllers[0].zealTenths=30;s.tick=100;
 s.units.push({...structuredClone(s.units[0]),id:2,position:{x:980,y:540}});
 expect(chooseBotDeployment(s,'a')).toMatchObject({cardId:'thunderlock',target_x:960,target_y:540});
 s.units.forEach(u=>u.paralyzedUntil=150);expect(chooseBotDeployment(s,'a')).toBeNull();
 s.units.push({...structuredClone(s.units[0]),id:3,team:'blue'},{...structuredClone(s.units[0]),id:4,team:'blue'},{...structuredClone(s.units[0]),id:5,team:'blue'});
 expect(chooseBotDeployment(s,'a')).toBeNull();
});
