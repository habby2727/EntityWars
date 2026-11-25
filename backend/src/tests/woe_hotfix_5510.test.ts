import {test,expect} from 'bun:test';
import {cardById,cardCost,cards,potions,arena} from '../woe/catalog';
import {initializeMatch,applyDeployment,advanceTick,getPublicSnapshot,route,formationPoint} from '../woe/engine';
import {chooseBotDeployment} from '../woe/bot_ai';
import {initializeCoreDefense,applyCoreDefenseDeployment,advanceCoreDefenseTick,getCoreDefenseSnapshot,alliedCapacity} from '../woe/core_defense';

test('four-card decks, legal fourth slot, legacy hand and mode-specific Solcarp',()=>{
 for(const seed of ['one','two','three']) {
  const s=initializeMatch('1v1',seed,['a','b']);expect(s).toEqual(initializeMatch('1v1',seed,['a','b']));
  for(const p of s.controllers){expect(p.slots).toHaveLength(4);expect(p.queue).toHaveLength(8);expect(new Set([...p.slots,...p.queue])).toEqual(new Set([...cards,...potions].map(c=>c.id)));expect(p.slots.some(id=>cardById[id]&&cardCost(cardById[id],'woe')<=3)).toBe(true);}
  expect(getPublicSnapshot(s,'a').players[1]).not.toHaveProperty('slots');
 }
 let w=initializeMatch('1v1','slots',['a','b']);w.controllers[0].slots[3]='solcarp';w.controllers[0].zealTenths=60;
 const cmd={controllerId:'a',actionId:'four',slot:3,cardId:'solcarp',lane:'left' as const};
 expect(applyDeployment(w,cmd)).toMatchObject({accepted:false,reason:'INSUFFICIENT_ZEAL'});
 w.controllers[0].zealTenths=70;const replacement=w.controllers[0].queue[0];const deployed=applyDeployment(w,cmd);expect(deployed.accepted).toBe(true);expect(deployed.state.controllers[0].zealTenths).toBe(0);expect(deployed.state.controllers[0].slots[3]).toBe(replacement);
 expect(applyDeployment(w,{...cmd,slot:4})).toMatchObject({reason:'INVALID_CARD'});expect(applyDeployment(w,{...cmd,slot:-1})).toMatchObject({reason:'INVALID_CARD'});
 const legacy=structuredClone(w);legacy.controllers[0].queue.unshift(legacy.controllers[0].slots.pop()!);expect(applyDeployment(legacy,cmd)).toMatchObject({reason:'INVALID_CARD'});
 const c=initializeCoreDefense('solo','slots',['a']);c.controllers[0].slots[3]='solcarp';expect(applyCoreDefenseDeployment(c,cmd).accepted).toBe(true);
});

test('bot opening grace and team-wide parity are evaluated after every deployment',()=>{
 let s=initializeMatch('2v2','bots',['b1','b2','r1','r2']);s.controllers.forEach(p=>p.zealTenths=100);
 expect(chooseBotDeployment(s,'b1')).toBeNull();s.tick=50;
 let cmd=chooseBotDeployment(s,'b1')!;expect(cmd.lane).toBe('left');s=applyDeployment(s,cmd).state;expect(chooseBotDeployment(s,'b2')).toBeNull();
 cmd=chooseBotDeployment(s,'r1')!;expect(cmd.lane).toBe('left');s=applyDeployment(s,cmd).state;
 cmd=chooseBotDeployment(s,'b2')!;expect(['left','right']).toContain(cmd.lane);s=applyDeployment(s,cmd).state;expect(chooseBotDeployment(s,'b1')).toBeNull();
 const early=initializeMatch('1v1','response',['a','bot']);early.controllers[0].zealTenths=100;
 const human=applyDeployment(early,{actionId:'human',controllerId:'a',slot:0,cardId:early.controllers[0].slots[0],lane:'left'}).state;
 expect(chooseBotDeployment(human,'bot')).not.toBeNull();
 const crowded=structuredClone(s);crowded.units=Array.from({length:6},(_,i)=>({...structuredClone(s.units[0]),id:i+1,team:i<3?'blue':'red'}));expect(chooseBotDeployment(crowded,'b1')).toBeNull();
 crowded.units[5].hp=0;expect(chooseBotDeployment(crowded,'r2')).not.toBeNull();
});

test('CD shared cap thresholds freeze regeneration, deny without mutation and allow stored intermission zeal',()=>{
 let s=initializeCoreDefense('coop','cap',['a','b']);s.controllers.forEach(p=>p.zealTenths=100);
 let r=applyCoreDefenseDeployment(s,{actionId:'a',controllerId:'a',slot:0,cardId:s.controllers[0].slots[0],lane:'left'});expect(r.accepted).toBe(true);s=r.state;
 const ally=s.units[0];s.units=Array.from({length:4},(_,i)=>({...structuredClone(ally),id:i+1}));
 expect(alliedCapacity(s)).toEqual({allied_count:4,allied_cap:4});
 const command={actionId:'blocked',controllerId:'b',slot:3,cardId:s.controllers[1].slots[3],lane:'right' as const};const before=structuredClone(s);
 expect(applyCoreDefenseDeployment(s,command)).toMatchObject({accepted:false,reason:'UNIT_CAP'});expect(s).toEqual(before);
 s.controllers.forEach(p=>p.zealTenths=0);s=advanceCoreDefenseTick(s);s=advanceCoreDefenseTick(s);expect(s.controllers.map(p=>p.zealTenths)).toEqual([0,0]);
 const enemy=s.units.find(u=>u.team==='red')!;s.units.push(...Array.from({length:3},(_,i)=>({...structuredClone(enemy),id:100+i})));expect(alliedCapacity(s).allied_cap).toBe(6);
 s=advanceCoreDefenseTick(s);s=advanceCoreDefenseTick(s);expect(s.controllers.map(p=>p.zealTenths)).toEqual([0,0]);expect(s.controllers.map(p=>p.zealRegenTicks)).toEqual([2,2]);
 s.units.push(...Array.from({length:4},(_,i)=>({...structuredClone(enemy),id:200+i})));expect(alliedCapacity(s).allied_cap).toBe(8);
 s.units.push({...structuredClone(ally),id:500},{...structuredClone(ally),id:501});
 s.units=s.units.filter(u=>u.team==='blue');expect(alliedCapacity(s)).toEqual({allied_count:6,allied_cap:4});s.controllers[1].zealTenths=100;
 expect(applyCoreDefenseDeployment(s,command)).toMatchObject({accepted:false,reason:'UNIT_CAP'});
 s=advanceCoreDefenseTick(advanceCoreDefenseTick(s));expect(alliedCapacity(s).allied_count).toBe(6);expect(s.controllers[0].zealRegenTicks).toBe(2);
 s.units=s.units.filter(u=>u.team==='blue');
 s.phase='intermission';s.intermissionTicks=20;s.controllers[1].zealTenths=100;s.units.splice(3);
 r=applyCoreDefenseDeployment(s,{...command,cardId:s.controllers[1].slots[3]});expect(r.accepted).toBe(true);s=r.state;const frozen=s.controllers.map(p=>p.zealTenths);s=advanceCoreDefenseTick(s);expect(s.controllers.map(p=>p.zealTenths)).toEqual(frozen);
 expect(getCoreDefenseSnapshot(s,'a')).toMatchObject({allied_count:4,allied_cap:4,regeneration_blocked:true});
});

test('red lab strikes both lanes once without enemy kills and does not affect WOE',()=>{
 for(const lane of ['left','right'] as const){
  let s=initializeCoreDefense('solo','tower',['a']);s.controllers[0].zealTenths=100;const p=s.controllers[0];s=applyCoreDefenseDeployment(s,{actionId:'x',controllerId:'a',slot:0,cardId:p.slots[0],lane}).state;
  const unit=s.units[0],lab=s.laboratories.find(l=>l.id==='red:'+lane)!;unit.position={...lab.position};s.phase='intermission';s.intermissionTicks=20;
  s=advanceCoreDefenseTick(s);expect(s.units.some(u=>u.id===unit.id)).toBe(false);expect(s.enemiesKilled).toBe(0);expect(s.events.filter(e=>e.type==='tower_strike')).toHaveLength(1);expect(s.events.filter(e=>e.type==='death')).toHaveLength(1);expect(s.events[0].position).toEqual(lab.position);expect(advanceCoreDefenseTick(s).events).toHaveLength(0);
  let moving=initializeCoreDefense('solo','tower-move',['a']);moving.controllers[0].zealTenths=100;const player=moving.controllers[0];moving=applyCoreDefenseDeployment(moving,{actionId:'move',controllerId:'a',slot:0,cardId:player.slots[0],lane}).state;
  const mover=moving.units[0];mover.position={x:lab.position.x+101,y:lab.position.y};mover.route=[{...lab.position}];mover.waypoint=0;moving.phase='intermission';moving.intermissionTicks=20;
  moving=advanceCoreDefenseTick(moving);expect(moving.units.some(u=>u.id===mover.id)).toBe(false);expect(moving.events.filter(e=>e.type==='tower_strike')).toHaveLength(1);
  let w=initializeMatch('1v1','tower',['a','b']);w.controllers[0].zealTenths=100;w=applyDeployment(w,{actionId:'x',controllerId:'a',slot:0,cardId:w.controllers[0].slots[0],lane}).state;w.units[0].position={...arena.laboratories.red[lane]};w=advanceTick(w);expect(w.units).toHaveLength(1);
 }
});

test('natural CD waves progress with automatic legal deployments',()=>{
 let s=initializeCoreDefense('solo','natural-waves',['a']);
 while(s.wave<3 && !s.result && s.tick<5000){
  if(s.tick%10===0){const p=s.controllers[0],slot=p.slots.findIndex(id=>cardById[id]&&cardCost(cardById[id],'core_defense')*10<=p.zealTenths);if(slot>=0)s=applyCoreDefenseDeployment(s,{actionId:`${s.tick}`,controllerId:p.id,slot,cardId:p.slots[slot],lane:Math.floor(s.tick/10)%2?'left':'right'}).state;}
  s=advanceCoreDefenseTick(s);
 }
 expect(s.completedWaves).toBeGreaterThanOrEqual(2);expect(s.wave).toBeGreaterThanOrEqual(3);
});

test('zeal progress survives serialization, spending, full capacity and CD pauses',()=>{
 let s=initializeMatch('1v1','timing',['a','b']);
 for(let i=0;i<29;i++)s=advanceTick(s);
 expect(getPublicSnapshot(s,'a').players[0]).toMatchObject({zeal:5,zeal_regen_ticks:29});
 s=advanceTick(JSON.parse(JSON.stringify(s)));expect(s.controllers[0]).toMatchObject({zealTenths:60,zealRegenTicks:0});
 for(let i=0;i<17;i++)s=advanceTick(s);
 const p=s.controllers[0],slot=p.slots.findIndex(id=>cardById[id]&&cardCost(cardById[id],'woe')<=6),cost=cardCost(cardById[p.slots[slot]],'woe');
 s=applyDeployment(s,{controllerId:'a',actionId:'spend',slot,cardId:p.slots[slot],lane:'left'}).state;
 expect(s.controllers[0]).toMatchObject({zealTenths:60-cost*10,zealRegenTicks:17});
 for(let i=0;i<13;i++)s=advanceTick(s);expect(s.controllers[0]).toMatchObject({zealTenths:70-cost*10,zealRegenTicks:0});
 s.controllers[0].zealTenths=100;s.controllers[0].zealRegenTicks=29;s=advanceTick(s);expect(s.controllers[0].zealRegenTicks).toBe(0);
 s.controllers[0].zealRegenTicks=29;
 const full=s.controllers[0],next=full.slots.findIndex(id=>cardById[id]&&cardCost(cardById[id],'woe')<=10);s=applyDeployment(s,{controllerId:'a',actionId:'full',slot:next,cardId:full.slots[next],lane:'left'}).state;
 s=advanceTick(s);expect(s.controllers[0].zealRegenTicks).toBe(1);
 let legacy=initializeMatch('1v1','old',['a','b']);delete legacy.controllers[0].zealRegenTicks;legacy.controllers[0].zealTenths=57;
 expect(getPublicSnapshot(legacy,'a').players[0]).toMatchObject({zeal:5,zeal_regen_ticks:21});legacy=advanceTick(legacy);expect(legacy.controllers[0]).toMatchObject({zealTenths:50,zealRegenTicks:22});
 let cd=initializeCoreDefense('coop','pause',['a','b']);cd.controllers.forEach(c=>{c.zealTenths=50;c.zealRegenTicks=17});cd.phase='intermission';cd.intermissionTicks=5;
 for(let i=0;i<5;i++)cd=advanceCoreDefenseTick(cd);expect(cd.controllers.map(c=>c.zealRegenTicks)).toEqual([17,17]);
 for(let i=0;i<12;i++)cd=advanceCoreDefenseTick(cd);expect(cd.controllers.map(c=>c.zealTenths)).toEqual([50,50]);
 cd=advanceCoreDefenseTick(JSON.parse(JSON.stringify(cd)));expect(cd.controllers.map(c=>c.zealTenths)).toEqual([60,60]);
});

test('rerouting follows each original lane back through the plaza in WOE and CD',()=>{
 for(const mode of ['1v1','2v2'] as const)for(const team of ['blue','red'] as const)for(const lane of ['left','right'] as const)for(const waypoint of [3,5,7,9]){
  const ids=mode==='1v1'?['b','r']:['b','b2','r','r2'];let s=initializeMatch(mode,'reroute',ids);
  const p=s.controllers.find(c=>c.team===team && (mode==='1v1'||(s.controllers.filter(x=>x.team===team).indexOf(c)===(lane==='left'?0:1))))!;
  p.zealTenths=100;p.slots[0]='neon';s=applyDeployment(s,{controllerId:p.id,actionId:'u',slot:0,cardId:'neon',lane}).state;
  const u=s.units[0],original=structuredClone(u.route),a=original[waypoint-1],b=original[waypoint];u.position={x:(a.x+b.x)/2,y:(a.y+b.y)/2};u.waypoint=waypoint;u.cooldown=7;
  const before={...u.position};s.laboratories.find(l=>l.team!==team&&l.lane===lane)!.hp=0;s=advanceTick(s);
  let current=s.units[0];expect(current.hp).toBe(u.hp);expect(current.cooldown).toBe(6);expect(Math.hypot(current.position.x-before.x,current.position.y-before.y)).toBeLessThanOrEqual(cardById.neon.speed*0.85*0.1+1e-8);
  const plaza=formationPoint(arena.plaza,u.id),plazaIndex=current.route.findIndex(p=>p.x===plaza.x&&p.y===plaza.y);expect(plazaIndex).toBeGreaterThanOrEqual(0);
  const planned=JSON.stringify(current.route);let reached=current.waypoint>plazaIndex;
  for(let i=0;i<800&&!reached;i++){const previous={...current.position};s=advanceTick(s);current=s.units[0];expect(JSON.stringify(current.route)).toBe(planned);expect(Math.hypot(current.position.x-previous.x,current.position.y-previous.y)).toBeLessThanOrEqual(cardById.neon.speed*0.85*0.1+1e-7);reached=current.waypoint>plazaIndex;}
  expect(reached).toBe(true);
 }
 for(const lane of ['left','right'] as const)for(const waypoint of [3,5,7,9]){
  let s=advanceCoreDefenseTick(initializeCoreDefense('solo','reroute',['a']));const u=s.units.find(x=>x.kind==='enemy')!;u.lane=lane;u.targetLane=lane;u.route=route('red',lane,lane,u.id);u.waypoint=waypoint;const a=u.route[waypoint-1],b=u.route[waypoint];u.position={x:(a.x+b.x)/2,y:(a.y+b.y)/2};
  s.laboratories.find(l=>l.team==='blue'&&l.lane===lane)!.hp=0;const before={...u.position};s=advanceCoreDefenseTick(s);let current=s.units.find(x=>x.id===u.id)!;
  expect(Math.hypot(current.position.x-before.x,current.position.y-before.y)).toBeLessThanOrEqual(current.speed*0.1+1e-8);
  const plaza=formationPoint(arena.plaza,u.id),plazaIndex=current.route.findIndex(p=>p.x===plaza.x&&p.y===plaza.y);expect(plazaIndex).toBeGreaterThanOrEqual(0);
  const planned=JSON.stringify(current.route);let reached=current.waypoint>plazaIndex;
  for(let i=0;i<800&&!reached;i++){s=advanceCoreDefenseTick(s);current=s.units.find(x=>x.id===u.id)!;expect(JSON.stringify(current.route)).toBe(planned);reached=current.waypoint>plazaIndex;}
  expect(reached).toBe(true);
 }
});

test('a unit already at the plaza takes the surviving lane without retreating',()=>{
 for(const team of ['blue','red'] as const)for(const lane of ['left','right'] as const){
  let s=initializeMatch('1v1','plaza',['b','r']);const p=s.controllers.find(x=>x.team===team)!;p.zealTenths=100;
  const slot=p.slots.findIndex(id=>!!cardById[id]);s=applyDeployment(s,{controllerId:p.id,actionId:'plaza',slot,cardId:p.slots[slot],lane}).state;
  const u=s.units[0],target=lane==='left'?'right':'left';u.position=formationPoint(arena.plaza,u.id);u.waypoint=5;
  s.laboratories.find(l=>l.team!==team&&l.lane===lane)!.hp=0;s=advanceTick(s);
  expect(s.units[0].route[0]).toEqual(route(team,lane,target,u.id)[5]);
 }
 for(const lane of ['left','right'] as const){
  let s=advanceCoreDefenseTick(initializeCoreDefense('solo','plaza',['a']));const u=s.units.find(x=>x.kind==='enemy')!,target=lane==='left'?'right':'left';
  u.lane=lane;u.targetLane=lane;u.route=route('red',lane,lane,u.id);u.position=formationPoint(arena.plaza,u.id);u.waypoint=5;
  s.laboratories.find(l=>l.team==='blue'&&l.lane===lane)!.hp=0;s=advanceCoreDefenseTick(s);
  expect(s.units.find(x=>x.id===u.id)!.route[0]).toEqual(route('red',lane,target,u.id)[5]);
 }
});
