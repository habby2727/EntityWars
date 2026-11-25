import { test, expect } from "bun:test";
import { arena, cards, cardById, cardCost, potions, potionById, elementalMultiplier, attackDamage, ATTACK_INTERVAL_MS } from "../woe/catalog";
import { initializeMatch, applyDeployment, advanceTick, getPublicSnapshot, formationPoint, route, move, WOE_MOVEMENT_MULTIPLIER, type MatchState } from "../woe/engine";
const make = () => initializeMatch("1v1", "seed", ["b", "r"]);
function deploy(s: MatchState, i: number, slot=0, lane: "left"|"right"="left") { const p=s.controllers[i]; if(!cardById[p.slots[slot]])slot=p.slots.findIndex(id=>!!cardById[id]); const r=applyDeployment(s,{actionId:`${s.nextUnitId}`,controllerId:p.id,slot,cardId:p.slots[slot],lane}); expect(r.accepted).toBe(true); return r.state; }
function ticks(s: MatchState, n: number) { for(let i=0;i<n;i++) s=advanceTick(s); return s; }
test("catalog and elemental damage",()=>{
 expect(cards.map(c=>[c.id,c.cost])).toEqual([["neon",2],["luny",3],["mantillo",3],["nebulynx",4],["venam",4],["cedix",4],["flincho",5],["solcarp",5],["hyrox",6],["astralotl",6]]);
 expect(cardById.cedix.element).toBe("sulfur"); expect(elementalMultiplier("sulfur","vitriol")).toBe(1.18); expect(elementalMultiplier("sulfur","aether")).toBe(0.84); expect(elementalMultiplier("aether","sulfur")).toBe(1.18);
 expect(elementalMultiplier("mercury","gold")).toBe(1.18); expect(elementalMultiplier("gold","mercury")).toBe(0.84); expect(elementalMultiplier("gold","sodium")).toBe(1);
 expect(attackDamage(100,0,1.18)).toBe(118); expect(attackDamage(100,0,0.84)).toBe(84); expect(attackDamage(1,20)).toBe(0); expect(attackDamage(20000,0)).toBe(10000);
});
test('all four laboratories attack one nearest living enemy with stable ties and neutral defense',()=>{
 expect(arena.laboratory_defense).toEqual({range:120,damage:30,interval_ms:1000});
 for(const mode of ['1v1','2v2'] as const) for(const team of ['blue','red'] as const) for(const lane of ['left','right'] as const){
  let s=mode==='1v1'?make():initializeMatch('2v2','defense',['b','b2','r','r2']);const lab=s.laboratories.find(l=>l.team===team&&l.lane===lane)!;
  const opponent=mode==='1v1'?(team==='blue'?1:0):(team==='blue'?2:0)+(lane==='right'?1:0);s.controllers[opponent].zealTenths=100;s=deploy(s,opponent,0,lane);
  const base=s.units[0],sign=team==='blue'?-1:1;
  s.units=[
   {...structuredClone(base),id:9,cardId:'mantillo',position:{x:lab.position.x+20,y:lab.position.y+sign*80},hp:1000,cooldown:1000,route:[]},
   {...structuredClone(base),id:3,cardId:'mantillo',position:{x:lab.position.x-20,y:lab.position.y+sign*80},hp:1000,cooldown:1000,route:[]},
   {...structuredClone(base),id:5,cardId:'mantillo',position:{x:lab.position.x,y:lab.position.y+sign*120},hp:1000,cooldown:1000,route:[]},
   {...structuredClone(base),id:6,cardId:'mantillo',position:{x:lab.position.x,y:lab.position.y+sign*121},hp:1000,cooldown:1000,route:[]},
   {...structuredClone(base),id:7,team,cardId:'mantillo',position:{...lab.position},hp:1000,cooldown:1000,route:[]},
   {...structuredClone(base),id:1,cardId:'mantillo',position:{...lab.position},hp:0,cooldown:1000,route:[]},
  ];
  s=advanceTick(s);const attacks=s.events.filter(e=>e.type==='lab_attack');expect(attacks).toHaveLength(1);
  expect(attacks[0]).toMatchObject({labId:lab.id,team,target:3,damage:attackDamage(30,cardById.mantillo.defense),position:lab.position});
  expect(s.units.find(u=>u.id===3)!.hp).toBe(1000-attackDamage(30,cardById.mantillo.defense));
  expect(s.units.find(u=>u.id===9)!.hp).toBe(1000);expect(s.units.find(u=>u.id===7)!.hp).toBe(1000);
  for(let i=0;i<9;i++){s=advanceTick(s);expect(s.events.some(e=>e.type==='lab_attack')).toBe(false);}
  s=advanceTick(JSON.parse(JSON.stringify(s)));expect(s.events.filter(e=>e.type==='lab_attack')).toHaveLength(1);
 }
});
test('laboratory range is inclusive, old states are ready, dead labs never fire and deaths are unique',()=>{
 let s=make();s.controllers[1].zealTenths=100;s=deploy(s,1);const lab=s.laboratories.find(l=>l.id==='blue:left')!;
 const u=s.units[0];u.cardId='neon';u.position={x:lab.position.x,y:lab.position.y-121};u.route=[];u.cooldown=1000;u.hp=1000;
 delete lab.defenseCooldown;s=advanceTick(s);expect(s.events.some(e=>e.type==='lab_attack')).toBe(false);
 s.units[0].position.y=lab.position.y-120;s.units[0].hp=1;s=advanceTick(JSON.parse(JSON.stringify(s)));
 expect(s.events.filter(e=>e.type==='lab_attack')).toHaveLength(1);expect(s.events.filter(e=>e.type==='death'&&e.target===u.id)).toHaveLength(1);
 expect(s.events.find(e=>e.type==='death')).toMatchObject({attackerKind:'laboratory',labId:'blue:left',targetKind:'unit',victimCardId:'neon',victimTeam:'red'});
 expect(s.units).toHaveLength(0);expect(advanceTick(s).events).toHaveLength(0);
 s=make();s.controllers[1].zealTenths=100;s=deploy(s,1);s.units[0].position={...s.laboratories[0].position};s.units[0].route=[];s.units[0].cooldown=1000;
 s.laboratories[0].hp=0;s=advanceTick(s);expect(s.events.some(e=>e.type==='lab_attack')).toBe(false);
});
test('laboratory fires on entry and cannot act after being destroyed in the same tick',()=>{
 let s=make();s.controllers[1].zealTenths=100;s=deploy(s,1);let lab=s.laboratories.find(l=>l.id==='blue:left')!,u=s.units[0];
 u.cardId='neon';u.position={x:lab.position.x,y:lab.position.y-126};u.route=[{...lab.position}];u.waypoint=0;u.cooldown=1000;
 s=advanceTick(s);expect(s.events.find(e=>e.type==='lab_attack')).toMatchObject({labId:lab.id,target:u.id});
 s=make();s.controllers[1].zealTenths=100;s=deploy(s,1);lab=s.laboratories.find(l=>l.id==='blue:left')!;u=s.units[0];
 lab.hp=1;u.cardId='neon';u.position={...lab.position};u.cooldown=0;s=advanceTick(s);
 expect(s.laboratories.find(l=>l.id===lab.id)!.hp).toBe(0);expect(s.events.some(e=>e.type==='lab_attack'&&e.labId===lab.id)).toBe(false);
});
test('laboratories do not attack units killed earlier in the same tick',()=>{
 let s=make();s.controllers.forEach(p=>p.zealTenths=100);s=deploy(s,0);s=deploy(s,1);
 const lab=s.laboratories.find(l=>l.id==='blue:left')!,attacker=s.units[0],victim=s.units[1];
 attacker.cardId='neon';attacker.position={...lab.position};attacker.cooldown=0;
 victim.cardId='mantillo';victim.position={x:lab.position.x,y:lab.position.y-20};victim.hp=1;victim.cooldown=1000;
 s=advanceTick(s);expect(s.events.filter(e=>e.type==='death'&&e.target===victim.id)).toHaveLength(1);
 expect(s.events.some(e=>e.type==='lab_attack'&&e.target===victim.id)).toBe(false);
});
test("twelve-card rotation cycles units and potions through four slots",()=>{
 let s=make(); const initial=[...s.controllers[0].slots], deployed:string[]=[];
 expect(s.controllers[0].queue.length).toBe(8);
 for(let i=0;i<16;i++) {
   s.controllers[0].zealTenths=100;
   const slot=i%4, card=s.controllers[0].slots[slot]; deployed.push(card);
   const command={actionId:`rotation-${i}`,controllerId:s.controllers[0].id,slot,cardId:card,...(potionById[card]?{target_x:0,target_y:0}:{lane:'left' as const})};
   const result=applyDeployment(s,command);expect(result.accepted).toBe(true);s=result.state;
   expect(s.controllers[0].zealTenths).toBe(100-(potionById[card]?.cost??cardCost(cardById[card],'woe'))*10);
   expect(s.controllers[0].slots.length).toBe(4);
 }
 expect(new Set(deployed.slice(0,12))).toEqual(new Set([...cards,...potions].map(c=>c.id)));
 expect(deployed.slice(12)).toEqual(initial);
});
test("Cedix attacks use sulfur effectiveness once",()=>{
 for(const [defender,multiplier] of [["venam",1.18],["luny",0.84]] as const) {
   let s=make(); s.controllers.forEach(p=>p.zealTenths=100); s=deploy(s,0); s=deploy(s,1);
   s.units[0].cardId="cedix"; s.units[1].cardId=defender; s.units.forEach(u=>u.position={x:960,y:540});
   s=advanceTick(s);
   expect(s.events[0]).toMatchObject({type:"attack",attacker:1,target:2,damage:attackDamage(cardById.cedix.damage,cardById[defender].defense,multiplier)});
 }
});
test("all cards wait ten ticks between attacks even after their target dies",()=>{
 expect(ATTACK_INTERVAL_MS).toBe(1000);
 for(const card of cards) {
   let s=make(); s.controllers.forEach(p=>p.zealTenths=100); s=deploy(s,0); s=deploy(s,1); s.controllers[1].zealTenths=100; s=deploy(s,1);
   s.units[0].cardId=card.id; s.units[1].hp=1; s.units[2].hp=10000;
   s.units.forEach(u=>u.position={x:960,y:540}); s.units[1].cooldown=100; s.units[2].cooldown=100;
   s=advanceTick(s); expect(s.events.some(e=>e.type==="death"&&e.target===2)).toBe(true);
   for(let i=0;i<9;i++) { s=advanceTick(s); expect(s.events.some(e=>e.type==="attack" && e.attacker===1)).toBe(false); }
   s=advanceTick(s); expect(s.events.some(e=>e.type==="attack" && e.attacker===1 && e.target===3)).toBe(true);
 }
});
test("snapshots expose only the viewer's hand and zeal",()=>{
 const s=initializeMatch("2v2","private",["b","b2","r","r2"]);
 for(const viewer of [undefined,"unknown","b","b2","r","r2"]) {
   const snapshot=getPublicSnapshot(s,viewer);
   for(const p of snapshot.players) {
     const source=s.controllers.find(c=>c.id===p.id)!;
     if(p.id===viewer) { expect(p).toEqual({id:p.id,team:p.team,zeal:source.zealTenths/10,zeal_regen_ticks:0,slots:source.slots,allowedDeploymentLanes:['left','right']}); }
     else { expect(p).toEqual({id:p.id,team:p.team}); }
     expect(p).not.toHaveProperty("queue"); expect(p).not.toHaveProperty("actionIds");
   }
 }
});
test("2v2 both teammates can use either surviving laboratory after recovery",()=>{
 for (const i of [0,1,2,3]) for (const lane of ['left','right'] as const) {
  const s=JSON.parse(JSON.stringify(initializeMatch('2v2','seats',['blue','bot-blue','red','bot-red'])));
  const p=s.controllers[i];p.zealTenths=100;const slot=p.slots.findIndex((id:string)=>!!cardById[id]);
  const cmd={actionId:`seat-${i}`,controllerId:p.id,slot,cardId:p.slots[slot],lane};
  expect(getPublicSnapshot(s,p.id).players.find((x:any)=>x.id===p.id)!.allowedDeploymentLanes).toEqual(['left','right']);
  expect(applyDeployment(s,{...cmd,lane:'invalid' as any})).toMatchObject({accepted:false,reason:'INVALID_LANE'});
  const deployed=applyDeployment(s,cmd);expect(deployed.accepted).toBe(true);
  expect(deployed.state.units[0]).toMatchObject({controllerId:p.id,team:p.team,lane});
  s.laboratories.find((l:any)=>l.team===p.team&&l.lane===lane).hp=0;
  expect(applyDeployment(s,cmd)).toMatchObject({accepted:false,reason:'LANE_DESTROYED'});
  const other=lane==='left'?'right':'left';
  expect(getPublicSnapshot(s,p.id).players.find((x:any)=>x.id===p.id)!.allowedDeploymentLanes).toEqual([other]);
  expect(applyDeployment(s,{...cmd,lane:other}).accepted).toBe(true);
  s.laboratories.find((l:any)=>l.team!==p.team&&l.lane===other).hp=0;
  expect(applyDeployment(s,{...cmd,lane:other}).accepted).toBe(true);
 }
});
test("rerouting beyond the plaza returns to the plaza before switching lanes",()=>{
 for(const team of ["blue","red"] as const) for(const lane of ["left","right"] as const) {
   let s=make(); const controller=team==="blue"?0:1; s.controllers[controller].zealTenths=100; s=deploy(s,controller,0,lane);
   const u=s.units[0], enemyTeam=team==="blue"?"red":"blue";
   u.position={x:lane==="left"?600:1320,y:team==="blue"?438:642}; u.waypoint=7;
   s.laboratories.find(l=>l.team===enemyTeam && l.lane===lane)!.hp=0;
   const startY=u.position.y; s=advanceTick(s);
   expect(s.units[0].targetLane).toBe(lane==="left"?"right":"left");
   expect(team==="blue" ? s.units[0].position.y>startY : s.units[0].position.y<startY).toBe(true);
   expect(s.units[0].route).toContainEqual(formationPoint(arena.plaza,u.id));
   for(let i=0;i<1000 && !s.events.some(e=>e.type==="attack" && typeof e.target==="string");i++) s=advanceTick(s);
   expect(s.events.some(e=>e.type==="attack" && typeof e.target==="string")).toBe(true);
 }
});
test("modes, seeded openings, rotation and independent zeal",()=>{
 for(const mode of ["1v1","2v2"] as const) for(let i=0;i<20;i++){const s=initializeMatch(mode,String(i),mode==="1v1"?["b","r"]:["b","b2","r","r2"]); expect(s.laboratories.length).toBe(4); expect(s.controllers.every(p=>p.slots.some(id=>cardById[id] && cardById[id].cost<=3))).toBe(true);}
 let s=make(); const p=s.controllers[0], slot=p.slots.findIndex(id=>cardById[id] && cardById[id].cost<=3), card=p.slots[slot], replacement=p.queue[0]; s=deploy(s,0,slot);
 expect(s.controllers[0].slots[slot]).toBe(replacement); expect(s.controllers[0].queue.at(-1)).toBe(card); expect(s.controllers[0].zealTenths).toBe(50-cardById[card].cost*10);
 s=ticks(s,30); expect(s.controllers[0].zealTenths).toBe(60-cardById[card].cost*10); expect(s.controllers[1].zealTenths).toBe(60); s=ticks(s,240); expect(s.controllers.every(p=>p.zealTenths===100)).toBe(true);
});
test("invalid and duplicate actions do not mutate or charge",()=>{
 let s=make(); const p=s.controllers[0], slot=p.slots.findIndex(id=>cardById[id] && cardById[id].cost<=3); const cmd={actionId:"x",controllerId:p.id,slot,cardId:p.slots[slot],lane:"left" as const};
 const original=structuredClone(s); expect(applyDeployment(s,{...cmd,slot:9}).accepted).toBe(false); expect(s).toEqual(original); s=applyDeployment(s,cmd).state;
 const before=structuredClone(s); expect(applyDeployment(s,cmd)).toMatchObject({accepted:false,reason:"DUPLICATE_ACTION_ID"}); expect(s).toEqual(before);
 const fresh={...cmd,actionId:"y",cardId:s.controllers[0].slots[slot]}; s.laboratories[0].hp=0; expect(applyDeployment(s,fresh)).toMatchObject({reason:"LANE_DESTROYED"}); s.laboratories[0].hp=1000; s.controllers[0].zealTenths=0; expect(applyDeployment(s,fresh)).toMatchObject({reason:"INSUFFICIENT_ZEAL"});
});
test("bounded spawns and movement",()=>{
 let s=make(); s.controllers.forEach(p=>p.zealTenths=100); s=deploy(s,0); s=deploy(s,1); expect(Math.abs(s.units[0].position.x-s.units[1].position.x)).toBeLessThanOrEqual(48); expect(s.units[0].position.y+s.units[1].position.y).toBe(1080); expect(arena.spawns.blue.left.x+arena.spawns.blue.right.x).toBe(1920); const pos=structuredClone(s.units[0].position); s=advanceTick(s); expect(s.units[0].position).not.toEqual(pos);
});
test('WOE generates one zeal in three seconds and slows every card equally',()=>{
 let s=make();s.controllers.forEach(p=>p.zealTenths=0);
 s=ticks(s,29);expect(s.controllers.map(p=>p.zealTenths)).toEqual([0,0]);
 s=advanceTick(s);expect(s.controllers.map(p=>p.zealTenths)).toEqual([10,10]);
 for(const card of cards){
  let sample=make();sample.controllers[0].slots[0]=card.id;sample.controllers[0].zealTenths=100;sample=deploy(sample,0);
  const before=sample.units[0].position;sample=advanceTick(sample);const after=sample.units[0].position;
  expect(Math.hypot(after.x-before.x,after.y-before.y)).toBeCloseTo(card.speed*WOE_MOVEMENT_MULTIPLIER*arena.tick_ms/1000,8);
 }
});
test('formation slots remain bounded, advance and reach short-range laboratories in both directions',()=>{
 for(const team of ['blue','red'] as const) for(const lane of ['left','right'] as const) {
  const opponent=team==='blue'?'red':'blue';
  const positions=new Set<string>();
  for(let id=1;id<=100;id++) {
   const spawn=formationPoint(arena.spawns[team][lane],id);
   positions.add(JSON.stringify(spawn));
   expect(Math.abs(spawn.x-arena.spawns[team][lane].x)).toBeLessThanOrEqual(30);
   expect(Math.abs(spawn.y-arena.spawns[team][lane].y)).toBeLessThanOrEqual(20);
   const u:any={position:spawn,route:route(team,lane,lane,id),waypoint:0};
   for(let tick=0;tick<500;tick++) {const before={...u.position};move(u,6.5);expect(Math.hypot(u.position.x-before.x,u.position.y-before.y)).toBeLessThanOrEqual(6.500001);}
   expect(u.waypoint).toBe(u.route.length);
   expect(Math.hypot(u.position.x-arena.laboratories[opponent][lane].x,u.position.y-arena.laboratories[opponent][lane].y)).toBeLessThanOrEqual(65);
  }
  expect(positions.size).toBe(100);
 }
});
test('100 mixed-speed WOE units make deterministic progress without blocking',()=>{
 for(const team of ['blue','red'] as const){
  let s=make();const index=team==='blue'?0:1;s.controllers[index].zealTenths=100;s=deploy(s,index);const original=s.units[0];
  s.units=Array.from({length:100},(_,i)=>({...structuredClone(original),id:i+1,cardId:['neon','mantillo','solcarp'][i%3],position:formationPoint(arena.spawns[team].left,i+1),route:route(team,'left','left',i+1),waypoint:0}));
  s.nextUnitId=101;const a=ticks(s,40),b=ticks(JSON.parse(JSON.stringify(s)),40);
  expect(a).toEqual(b);expect(a.units.length).toBe(100);
  expect(a.units.every(u=>team==='blue'?u.position.y<arena.spawns.blue.left.y:u.position.y>arena.spawns.red.left.y)).toBe(true);
  expect(new Set(a.units.map(u=>`${u.position.x.toFixed(2)}:${u.position.y.toFixed(2)}`)).size).toBeGreaterThanOrEqual(25);
 }
});
test("group combat, deterministic targets, multiplier and death",()=>{
 let s=make(); s.controllers.forEach(p=>p.zealTenths=100); s=deploy(s,0); s=deploy(s,1); s.controllers[1].zealTenths=100; s=deploy(s,1);
 s.units[0].cardId="neon"; s.units[1].cardId="solcarp"; s.units[2].cardId="solcarp"; s.units.forEach(u=>u.position={x:960,y:540}); s.units[1].hp=1;
 s=advanceTick(s); expect(s.events[0]).toMatchObject({type:"attack",attacker:1,target:2,damage:1}); expect(s.events.find(e=>e.type==="death"&&e.target===2)).toMatchObject({victimCardId:"solcarp",victimTeam:"red",victimPosition:{x:960,y:540},targetKind:"unit"}); expect(s.units.some(u=>u.id===2)).toBe(false); expect(s.events.some(e=>e.type==="attack"&&e.attacker===3)).toBe(true);
 s=make(); s.controllers.forEach(p=>p.zealTenths=100); s=deploy(s,0); s=deploy(s,1); s.units[0].cardId="neon"; s.units[1].cardId="solcarp"; s.units.forEach(u=>u.position={x:960,y:540}); s=advanceTick(s); expect(s.events[0]).toMatchObject({damage:attackDamage(cardById.neon.damage,cardById.solcarp.defense,1.18)});
});
test("laboratory redirection and immediate victory",()=>{
 let s=make(); s.controllers[0].zealTenths=100; s=deploy(s,0); s.laboratories.find(l=>l.id==="red:left")!.hp=0; s=advanceTick(s); expect(s.units[0].targetLane).toBe("right"); const lab=s.laboratories.find(l=>l.id==="red:right")!; lab.hp=1; s.units[0].position={...lab.position}; s=advanceTick(s); expect(s.result).toEqual({winner:"blue",reason:"laboratories"}); expect(s.events.find(e=>e.type==="death"&&e.target==="red:right")).toMatchObject({victimCardId:null,victimTeam:"red",targetKind:"laboratory"}); expect(advanceTick(s)).toBe(s);
});
test("timeout compares lab count then health and permits draw",()=>{
 let s=make(); s.tick=1799; expect(advanceTick(s).result?.winner).toBe(null); s=make(); s.tick=1799; s.laboratories[0].hp=1; s.laboratories[1].hp=1; s.laboratories[2].hp=0; expect(advanceTick(s).result?.winner).toBe("blue"); s=make(); s.tick=1799; s.laboratories[0].hp--; expect(advanceTick(s).result?.winner).toBe("red");
});
test("unit cap rejects without mutation",()=>{
 let s=make(); s.controllers[0].zealTenths=100; s=deploy(s,0); s.units=Array.from({length:arena.unit_cap},(_,i)=>({...structuredClone(s.units[0]),id:i+1})); s.controllers[0].zealTenths=100; const p=s.controllers[0], before=structuredClone(s); expect(applyDeployment(s,{actionId:"cap",controllerId:p.id,slot:0,cardId:p.slots[0],lane:"left"})).toMatchObject({reason:"UNIT_CAP"}); expect(s).toEqual(before);
});
test("seeded automated matches terminate and replay identically",()=>{
 function play(seed:string,mode:"1v1"|"2v2") { let s=initializeMatch(mode,seed,mode==="1v1"?["b","r"]:["b","b2","r","r2"]); while(!s.result && s.tick<1800){ if(s.tick%10===0) for(let i=0;i<s.controllers.length;i++){const p=s.controllers[i], slot=p.slots.findIndex(id=>cardById[id] && cardCost(cardById[id],'woe')*10<=p.zealTenths); if(slot>=0) s=applyDeployment(s,{actionId:`${s.tick}:${i}`,controllerId:p.id,slot,cardId:p.slots[slot],lane:(Math.floor(s.tick/100)+i)%2?"right":"left"}).state;} s=advanceTick(s); } expect(s.result).not.toBeNull(); return getPublicSnapshot(s); }
 for(const mode of ["1v1","2v2"] as const) for(let i=0;i<3;i++) expect(play(String(i),mode)).toEqual(play(String(i),mode));
});
