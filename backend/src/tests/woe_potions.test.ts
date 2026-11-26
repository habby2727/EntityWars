import {expect,test} from 'bun:test';
import {initializeMatch,applyDeployment,advanceTick,getPublicSnapshot,replaceCard} from '../woe/engine';
import {initializeCoreDefense,applyCoreDefenseDeployment,advanceCoreDefenseTick,getCoreDefenseSnapshot} from '../woe/core_defense';
import {cardById,potionById,attackDamage} from '../woe/catalog';
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
test('both modes charge the canonical potion cost and reject insufficient zeal',()=>{
 for(const [id,cost] of [['thunderlock',2],['vitriol_potion',3],['blood_potion',4],['aether_potion',2]] as const){
  expect(potionById[id].cost).toBe(cost);
  for(const mode of ['woe','core_defense'] as const){
   let s:any=mode==='woe'?initializeMatch('1v1','potion-cost',['a','b']):initializeCoreDefense('solo','potion-cost',['a']);
   s.controllers[0].slots[0]=id;s.controllers[0].zealTenths=(cost-1)*10;
   const cmd={controllerId:'a',actionId:`cost-${mode}-${id}`,slot:0,cardId:id,target_x:0,target_y:0};
   const apply=mode==='woe'?applyDeployment:applyCoreDefenseDeployment;
   expect(apply(s,cmd).reason).toBe('INSUFFICIENT_ZEAL');
   s.controllers[0].zealTenths=cost*10;const result=apply(s,cmd);
   expect(result.accepted).toBe(true);expect(result.state.controllers[0].zealTenths).toBe(0);
  }
 }
});
test('held potions keep queued potions in order and legacy multiple-potion hands drain',()=>{
 const s=initializeMatch('1v1','rotation',['a','b']),p=s.controllers[0];
 p.slots=['thunderlock','neon','luny','mantillo'];p.queue=['vitriol_potion','blood_potion','cedix','aether_potion','venam'];
 replaceCard(p,1);expect(p.slots).toEqual(['thunderlock','cedix','luny','mantillo']);expect(p.queue).toEqual(['vitriol_potion','blood_potion','aether_potion','venam','neon']);
 replaceCard(p,0);expect(p.slots[0]).toBe('vitriol_potion');expect(p.queue).toEqual(['blood_potion','aether_potion','venam','neon','thunderlock']);
 p.slots=['thunderlock','vitriol_potion','neon'];p.queue=['blood_potion','aether_potion','cedix','luny'];replaceCard(p,0);
 expect(p.slots).toEqual(['cedix','vitriol_potion','neon']);expect(p.queue).toEqual(['blood_potion','aether_potion','luny','thunderlock']);
 const legacy=initializeMatch('1v1','old-twelve',['a','b']);const old=legacy.controllers[0];
 old.slots=['thunderlock','vitriol_potion','neon','luny'];old.queue=['mantillo','nebulynx','venam','cedix','flincho','solcarp','hyrox','astralotl'];old.zealTenths=100;
 const applied=applyDeployment(JSON.parse(JSON.stringify(legacy)),{controllerId:'a',actionId:'old-deck',slot:0,cardId:'thunderlock',target_x:0,target_y:0});
 expect(applied.accepted).toBe(true);expect(applied.state.controllers[0].slots).toEqual(['mantillo','vitriol_potion','neon','luny']);
 expect([...applied.state.controllers[0].slots,...applied.state.controllers[0].queue]).toHaveLength(12);
 expect([...applied.state.controllers[0].slots,...applied.state.controllers[0].queue]).not.toContain('blood_potion');
});
test('blood heals friendly units four times, caps HP and cannot revive poison victims',()=>{
 for(const mode of ['woe','core_defense'] as const){
  let s:any=mode==='woe'?initializeMatch('2v2','blood',['a','ally','r','r2']):initializeCoreDefense('coop','blood',['a','ally']);
  const ally=s.controllers[1];ally.slots[0]='neon';ally.zealTenths=100;
  const deploy={controllerId:'ally',actionId:'unit',slot:0,cardId:'neon',lane:'left' as const};
  s=(mode==='woe'?applyDeployment(s,deploy):applyCoreDefenseDeployment(s,deploy)).state;
  s.units[0].position={x:960,y:540};s.units[0].route=[];s.units[0].hp=50;s.units[0].cooldown=1000;
  if(mode==='core_defense'){s.phase='intermission';s.intermissionTicks=100;}
  s.controllers[0].slots[0]='blood_potion';s.controllers[0].zealTenths=100;
  const cmd={controllerId:'a',actionId:'heal',slot:0,cardId:'blood_potion',target_x:960,target_y:540};
  s=(mode==='woe'?applyDeployment(s,cmd):applyCoreDefenseDeployment(s,cmd)).state;
  expect(s.units[0].bloodUntil).toBe(40);const heals:number[]=[];
  for(let i=1;i<=40;i++){
   if(i===15){s=JSON.parse(JSON.stringify(s));s.controllers[0].slots[0]='blood_potion';s.controllers[0].zealTenths=100;const repeat={...cmd,actionId:'heal-again'};s=(mode==='woe'?applyDeployment(s,repeat):applyCoreDefenseDeployment(s,repeat)).state;expect(s.units[0].bloodUntil).toBe(40);expect(s.units[0].bloodNextTick).toBe(20);}
   s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));if(s.events.some((e:any)=>e.type==='potion_heal'))heals.push(i);
  }
  expect(heals).toEqual([10,20,30,40]);expect(s.units[0].hp).toBe(110);
  s.units[0].hp=145;s.units[0].bloodUntil=s.tick+10;s.units[0].bloodNextTick=s.tick+10;
  for(let i=0;i<10;i++)s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));expect(s.units[0].hp).toBe(150);expect(s.events.find((e:any)=>e.type==='potion_heal').healing).toBe(5);
  s.units[0].hp=75;s.units[0].bloodUntil=s.tick+10;s.units[0].bloodNextTick=s.tick+10;s.units[0].poisonUntil=s.tick+10;s.units[0].poisonNextTick=s.tick+10;s.units[0].poisonTeam='red';
  for(let i=0;i<10;i++)s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));expect(s.units[0].hp).toBe(75);expect(s.events.filter((e:any)=>['potion_damage','potion_heal'].includes(e.type)).map((e:any)=>e.type)).toEqual(['potion_damage','potion_heal']);
  s.units[0].hp=1;s.units[0].bloodUntil=s.tick+10;s.units[0].bloodNextTick=s.tick+10;s.units[0].poisonUntil=s.tick+10;s.units[0].poisonNextTick=s.tick+10;s.units[0].poisonTeam='red';
  for(let i=0;i<10;i++)s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));
  expect(s.units).toHaveLength(0);expect(s.events.filter((e:any)=>e.type==='death')).toHaveLength(1);expect(s.events.some((e:any)=>e.type==='potion_heal')).toBe(false);
 }
});
test('aether boosts friendly attacks for 40 ticks without changing cooldown',()=>{
 for(const mode of ['woe','core_defense'] as const){
  let s:any=mode==='woe'?initializeMatch('1v1','buff',['a','b']):initializeCoreDefense('solo','buff',['a']);
  s.controllers[0].slots[0]='neon';s.controllers[0].zealTenths=100;
  const deploy={controllerId:'a',actionId:'unit',slot:0,cardId:'neon',lane:'left' as const};s=(mode==='woe'?applyDeployment(s,deploy):applyCoreDefenseDeployment(s,deploy)).state;
  const u=s.units[0];u.position={x:960,y:540};u.route=[];u.cooldown=0;
  s.units.push({...structuredClone(u),id:2,team:'red',hp:10000,position:{x:990,y:540},cooldown:1000});
  if(mode==='core_defense'){s.phase='intermission';s.intermissionTicks=100;}
  s.controllers[0].slots[0]='aether_potion';s.controllers[0].zealTenths=100;
  const cmd={controllerId:'a',actionId:'buff',slot:0,cardId:'aether_potion',target_x:960,target_y:540};s=(mode==='woe'?applyDeployment(s,cmd):applyCoreDefenseDeployment(s,cmd)).state;
  expect(s.units[0].aetherUntil).toBe(40);expect(s.units[1].aetherUntil).toBeUndefined();const attacks:any[]=[];
  for(let i=1;i<=41;i++){s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));attacks.push(...s.events.filter((e:any)=>e.type==='attack'&&e.attacker===1));}
  expect(attacks.map(e=>e.tick)).toEqual([1,11,21,31,41]);const base=attackDamage(cardById.neon.damage,cardById.neon.defense,1);
  expect(attacks.map(e=>e.damage)).toEqual([Math.round(base*1.2),Math.round(base*1.2),Math.round(base*1.2),Math.round(base*1.2),base]);
 }
});
test('aether speed combines with poison and paralysis without stacking or catch-up',()=>{
 for(const mode of ['woe','core_defense'] as const){
  let s:any=mode==='woe'?initializeMatch('1v1','speed',['a','b']):initializeCoreDefense('solo','speed',['a']);
  s.controllers[0].slots[0]='neon';s.controllers[0].zealTenths=100;
  const deploy={controllerId:'a',actionId:'unit',slot:0,cardId:'neon',lane:'left' as const};s=(mode==='woe'?applyDeployment(s,deploy):applyCoreDefenseDeployment(s,deploy)).state;
  const u=s.units[0];u.position={x:960,y:540};u.route=[{x:960,y:1000}];u.waypoint=0;u.cooldown=1000;u.poisonUntil=30;u.poisonNextTick=10;u.poisonTeam='red';
  if(mode==='core_defense'){s.phase='intermission';s.intermissionTicks=100;}
  s.controllers[0].slots[0]='aether_potion';s.controllers[0].zealTenths=100;
  const cmd={controllerId:'a',actionId:'buff',slot:0,cardId:'aether_potion',target_x:960,target_y:540};s=(mode==='woe'?applyDeployment(s,cmd):applyCoreDefenseDeployment(s,cmd)).state;
  const speed=cardById.neon.speed*(mode==='woe'?0.85:1)*0.1;
  for(let i=1;i<=10;i++)s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));
  expect(s.units[0].position.y).toBeCloseTo(540+10*speed*0.6*1.15,6);
  s.controllers[0].slots[0]='aether_potion';s.controllers[0].zealTenths=100;
  s=(mode==='woe'?applyDeployment(s,{...cmd,actionId:'again',target_y:s.units[0].position.y}):applyCoreDefenseDeployment(s,{...cmd,actionId:'again',target_y:s.units[0].position.y})).state;
  expect(s.units[0].aetherUntil).toBe(40);s.units[0].paralyzedUntil=20;
  const frozen=s.units[0].position.y;for(let i=11;i<=20;i++)s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));expect(s.units[0].position.y).toBe(frozen);
  for(let i=21;i<=40;i++)s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));
  expect(s.units[0].position.y).toBeCloseTo(frozen+10*speed*0.6*1.15+10*speed*1.15,6);
  const before=s.units[0].position.y;s=(mode==='woe'?advanceTick(s):advanceCoreDefenseTick(s));expect(s.units[0].position.y-before).toBeCloseTo(speed,6);
 }
});
test('friendly potion radius excludes enemies, laboratories and late entrants',()=>{
 for(const id of ['blood_potion','aether_potion']){
  let s=battlefield();const enemy=s.units[0];enemy.hp=60;
  s.units.push({...structuredClone(enemy),id:2,team:'blue',position:{x:960,y:540}},{...structuredClone(enemy),id:3,team:'blue',position:{x:1400,y:540}});
  const labs=structuredClone(s.laboratories);s=cast(s,id,'friendly-range').state;
  const field=id==='blood_potion'?'bloodUntil':'aetherUntil';expect((s.units[0] as any)[field]).toBeUndefined();expect((s.units[1] as any)[field]).toBe(40);expect((s.units[2] as any)[field]).toBeUndefined();
  s.units[2].position={x:960,y:540};s=advanceTick(s);expect((s.units[2] as any)[field]).toBeUndefined();expect(s.laboratories.map(l=>l.hp)).toEqual(labs.map(l=>l.hp));
 }
});
test('aether buffs unit attacks on enemy laboratories without buffing laboratory defense',()=>{
 let s=initializeMatch('1v1','buff-labs',['a','b']);const p=s.controllers[0];p.slots[0]='neon';p.zealTenths=100;
 s=applyDeployment(s,{controllerId:'a',actionId:'unit',slot:0,cardId:'neon',lane:'left'}).state;
 const lab=s.laboratories.find(l=>l.id==='red:left')!;s.units[0].position={...lab.position};s.units[0].route=[];s.units[0].hp=1000;
 s.controllers[0].slots[0]='aether_potion';s.controllers[0].zealTenths=100;s=applyDeployment(s,{controllerId:'a',actionId:'buff',slot:0,cardId:'aether_potion',target_x:lab.position.x,target_y:lab.position.y}).state;
 s=advanceTick(s);expect(s.events.find(e=>e.type==='attack')?.damage).toBe(Math.round(attackDamage(cardById.neon.damage,0)*1.2));
 expect(s.events.find(e=>e.type==='lab_attack')?.damage).toBe(attackDamage(30,cardById.neon.defense));
});
test('bot uses nonredundant friendly potions only for useful visible allies',()=>{
 let s=battlefield();const enemy=s.units[0];enemy.position={x:980,y:540};
 const ally={...structuredClone(enemy),id:2,team:'blue',hp:40,position:{x:960,y:540}};s.units.push(ally);s.tick=100;
 const p=s.controllers[0];p.slots=['blood_potion','hyrox','astralotl','solcarp'];p.zealTenths=40;
 expect(chooseBotDeployment(s,'a')).toMatchObject({cardId:'blood_potion',target_x:960,target_y:540});
 ally.bloodUntil=140;expect(chooseBotDeployment(s,'a')?.cardId).not.toBe('blood_potion');
 p.slots[0]='aether_potion';p.zealTenths=20;expect(chooseBotDeployment(s,'a')).toMatchObject({cardId:'aether_potion'});
 ally.aetherUntil=140;expect(chooseBotDeployment(s,'a')).toBeNull();
});
test('potion validation, rotation, empty casts, immutable denial and legacy ten-card decks',()=>{
 let s=battlefield();s.controllers[0].slots[0]='thunderlock';const before=structuredClone(s),base={controllerId:'a',actionId:'p',slot:0,cardId:'thunderlock'};
 for(const bad of [{...base,lane:'left' as const,target_x:1,target_y:1},{...base,target_x:NaN,target_y:0},{...base,target_x:1921,target_y:0},{...base,target_x:1,target_y:-1},{...base,slot:9,target_x:1,target_y:1},{...base,cardId:'vitriol_potion',target_x:1,target_y:1}])expect(applyDeployment(s,bad).accepted).toBe(false);
 expect(s).toEqual(before);
 const next=s.controllers[0].queue[0],out=applyDeployment(s,{...base,target_x:0,target_y:0});expect(out.accepted).toBe(true);s=out.state;
 expect(s.controllers[0].slots[0]).toBe(next);expect(s.controllers[0].queue.at(-1)).toBe('thunderlock');expect(s.controllers[0].zealTenths).toBe(80);expect(s.units).toHaveLength(1);expect(s.units[0].paralyzedUntil).toBeUndefined();
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
 expect(out.accepted).toBe(true);expect(out.state.units).toHaveLength(4);expect(out.state.controllers[0].zealTenths).toBe(80);
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
 let s=battlefield();s.controllers[0].slots=['thunderlock','hyrox','astralotl','solcarp'];s.controllers[0].zealTenths=10;s.tick=100;
 s.units.push({...structuredClone(s.units[0]),id:2,position:{x:980,y:540}});
 expect(chooseBotDeployment(s,'a')).toBeNull();s.controllers[0].zealTenths=20;
 expect(chooseBotDeployment(s,'a')).toMatchObject({cardId:'thunderlock',target_x:960,target_y:540});
 s.units.forEach(u=>u.paralyzedUntil=150);expect(chooseBotDeployment(s,'a')).toBeNull();
 s.units.push({...structuredClone(s.units[0]),id:3,team:'blue'},{...structuredClone(s.units[0]),id:4,team:'blue'},{...structuredClone(s.units[0]),id:5,team:'blue'});
 expect(chooseBotDeployment(s,'a')).toBeNull();
});
