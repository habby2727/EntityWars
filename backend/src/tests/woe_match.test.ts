import {test,expect} from 'bun:test';
import {Database} from 'bun:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {createWoeLobby} from '../woe/lobby';
import {createWoeMatchService} from '../woe/match_service';
import {activeWoe} from '../woe/busy';
import {initializeMatch} from '../woe/engine';
import {cardById} from '../woe/catalog';
function setup(mode='1v1',players=['a']) {
 const db=new Database(':memory:');db.exec('PRAGMA foreign_keys=ON');const dir=resolve(import.meta.dir,'../../migrations/sqlite');for(const f of readdirSync(dir).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(dir,f),'utf8'));
 for(const id of ['a','b','c','d','e'])db.query('INSERT INTO players VALUES (?,?,?,0)').run(id,id,'{}');
 let now=1000000,enabled=true;const lobby=createWoeLobby(db,()=> 'duel_clearing',()=>enabled,()=>now),service=createWoeMatchService(db,()=>enabled,()=>now);
 let r=lobby.create(players[0],{mode,client_action_id:'create'}).data;const room=r.room_id;
 for(const id of players.slice(1))r=lobby.join(id,{room_id_or_code:room,client_action_id:'join'}).data;
 const seats=mode==='1v1'?['blue:left','red:left']:['blue:left','blue:right','red:left','red:right'];
 for(let i=0;i<players.length;i++)r=lobby.seat(players[i],{room_id:room,seat:seats[i],expected_revision:r.revision,client_action_id:'seat'}).data;
 const start=lobby.start(players[0],{room_id:room,fill_bots:true,expected_revision:r.revision,client_action_id:'start'});expect(start.status).toBe(200);
 return {db,lobby,service,id:start.data.match_id,room,advance:(ms:number)=>now+=ms,disable:()=>enabled=false,enable:()=>enabled=true,now:()=>now};
}
test('ticks, bots, restart, lease fence and bounded catch-up',()=>{
 const h=setup();h.service.pulse();const a=h.service.state('a',h.id,'0').data;expect(a.tick).toBe(1);expect(a.events.some((e:any)=>e.type==='spawn')).toBe(true);expect(a.snapshot.players.find((p:any)=>p.id!=='a').slots).toBeUndefined();h.advance(3600_000);const replacement=createWoeMatchService(h.db,()=>true,h.now);replacement.pulse();expect(replacement.state('a',h.id,'0').data.tick).toBe(2);h.disable();h.service.pulse();expect(h.service.state('a',h.id,'0').status).toBe(503);h.enable();expect(h.service.state('a',h.id,'0').data.tick).toBe(2);h.db.close();
});
test('deploy is private, validated, idempotent and journaled',()=>{
 const h=setup('1v1',['a','b']);const initial=h.service.state('a',h.id,'0').data,slots=initial.snapshot.players.find((p:any)=>p.id==='a').slots,slot=slots.findIndex((id:string)=>cardById[id].cost<=5),card=slots[slot];const body={match_id:h.id,client_action_id:'one',slot,card_id:card,lane:'left'};const first=h.service.deploy('a',body);expect(first.status).toBe(200);expect(h.service.deploy('a',body)).toEqual(first);expect(h.service.deploy('a',{...body,lane:'right'}).status).toBe(409);expect(h.service.deploy('a',{...body,client_action_id:'stale'}).status).toBe(409);expect(h.service.deploy('b',{...body,client_action_id:'forge',controller_id:'a'}).status).toBe(400);expect(h.service.state('c',h.id,'0').status).toBe(403);h.service.pulse();const page=h.service.state('a',h.id,'0').data;expect(page.events[0]).toMatchObject({seq:1,type:'spawn',card_id:card,controller_id:'a'});expect(h.service.state('a',h.id,'1').data.events.every((x:any)=>x.seq>1)).toBe(true);expect(page.snapshot.units[0].maxHp).toBeGreaterThan(0);h.db.close();
});
test('leave preserves match, forfeit releases reservation and retains result',()=>{
 const h=setup('1v1',['a','b']);expect(h.lobby.leave('a',{room_id:h.room,client_action_id:'leave'}).status).toBe(200);expect(activeWoe(h.db,'a',h.now())).toBe(true);const result=h.service.forfeit('a',{match_id:h.id,client_action_id:'f'});expect(result.data.snapshot.result).toEqual({winner:'red',reason:'forfeit'});expect(activeWoe(h.db,'a',h.now())).toBe(false);expect(h.service.current('a').data.match_id).toBe(h.id);expect(h.service.state('b',h.id,'0').data.events.at(-1).type).toBe('result');h.db.close();
});
test('2v2 forfeit enables bot takeover',()=>{
 const h=setup('2v2',['a','b','c']);expect(h.service.forfeit('a',{match_id:h.id,client_action_id:'f'}).status).toBe(200);expect(h.service.state('b',h.id,'0').data.status).toBe('RUNNING');h.service.pulse();const s=h.service.state('b',h.id,'0').data;expect(s.snapshot.units.some((u:any)=>u.controllerId==='a')).toBe(true);expect(h.service.deploy('a',{match_id:h.id,client_action_id:'d',slot:0,card_id:'neon',lane:'left'}).data.error).toBe('FORFEITED');h.db.close();
});
test('2v2 bot takeover and reconnect retain seat lane ownership',()=>{
 const h=setup('2v2',['a','b','c']);
 const a=h.service.state('a',h.id,'0').data.snapshot.players.find((p:any)=>p.id==='a');
 expect(a.allowedDeploymentLanes).toEqual(['left']);
 const slot=a.slots.findIndex((id:string)=>cardById[id].cost<=5);
 const denied=h.service.deploy('a',{match_id:h.id,client_action_id:'wrong-lane',slot,card_id:a.slots[slot],lane:'right'});
 expect(denied.data.error).toBe('LANE_NOT_OWNED');
 expect(h.service.state('a',h.id,'0').data.snapshot.players.find((p:any)=>p.id==='a')).toEqual(a);
 h.service.forfeit('a',{match_id:h.id,client_action_id:'forfeit-seat'});h.service.pulse();
 const units=h.service.state('b',h.id,'0').data.snapshot.units;
 expect(units.some((u:any)=>u.controllerId==='a')).toBe(true);
 expect(units.filter((u:any)=>u.controllerId==='a').every((u:any)=>u.lane==='left')).toBe(true);
 h.db.close();
});
test('event cursor gaps request a resync',()=>{
 const h=setup();h.service.pulse();h.db.query('DELETE FROM woe_match_events WHERE match_id=?').run(h.id);h.db.query('UPDATE woe_matches SET event_seq=2002 WHERE match_id=?').run(h.id);h.db.query('INSERT INTO woe_match_events VALUES (?,?,?)').run(h.id,2002,JSON.stringify({type:'spawn'}));expect(h.service.state('a',h.id,'0').data.resync_required).toBe(true);expect(h.service.state('a',h.id,'9999').data.resync_required).toBe(true);h.db.close();
});
test('timeout uses 1800 simulation ticks and releases both humans',()=>{
 const h=setup('1v1',['a','b']);for(let i=0;i<1800;i++)h.service.pulse();const state=h.service.state('a',h.id,'0').data;expect(state.tick).toBe(1800);expect(state.snapshot.result).toEqual({winner:null,reason:'timeout'});expect(activeWoe(h.db,'b',h.now())).toBe(false);h.db.close();
});
test('scheduler advances without polling and stops when fenced',async()=>{
 const h=setup('1v1',['a','b']);h.service.start();await Bun.sleep(350);h.disable();const tick=(h.db.query('SELECT state_json FROM woe_matches WHERE match_id=?').get(h.id) as any).state_json;await Bun.sleep(220);expect((h.db.query('SELECT state_json FROM woe_matches WHERE match_id=?').get(h.id) as any).state_json).toBe(tick);expect(JSON.parse(tick).tick).toBeGreaterThanOrEqual(2);h.service.stop();h.db.close();
});
test('started lobby reads committed match state after ticks and service restart',()=>{
 const h=setup('1v1',['a','b']);
 expect((h.db.query('SELECT match_json FROM woe_rooms WHERE room_id=?').get(h.room) as any).match_json).toBeNull();
 h.db.query("UPDATE woe_rooms SET match_json='legacy stale snapshot' WHERE room_id=?").run(h.room);
 for(let i=0;i<4;i++)h.service.pulse();
 const restarted=createWoeLobby(h.db,()=> 'duel_clearing',()=>true,h.now);
 expect(restarted.state('a',h.room).data.snapshot.tick).toBe(4);
 expect(h.service.state('a',h.id,'0').data.snapshot.tick).toBe(4);
 expect((h.db.query('SELECT match_json FROM woe_rooms WHERE room_id=?').get(h.room) as any).match_json).toBe('legacy stale snapshot');
 h.db.close();
});
test('scheduled tick errors back off without starving other matches or crashing',async()=>{
 const h=setup('1v1',['a','b']);let room=h.lobby.create('e',{mode:'1v1',client_action_id:'create'}).data;
 room=h.lobby.seat('e',{room_id:room.room_id,seat:'blue:left',expected_revision:room.revision,client_action_id:'seat'}).data;
 room=h.lobby.start('e',{room_id:room.room_id,expected_revision:room.revision,client_action_id:'start',fill_bots:true}).data;
 h.db.exec(`CREATE TRIGGER fail_one_tick BEFORE UPDATE OF state_json ON woe_matches WHEN old.match_id='${h.id}' BEGIN SELECT RAISE(ABORT,'fixture failure'); END`);
 const original=console.error;let errors=0;console.error=()=>{errors++};
 try {h.service.start();await Bun.sleep(1450);h.service.stop();expect(errors).toBeGreaterThanOrEqual(1);expect(errors).toBeLessThanOrEqual(2);expect(h.service.state('e',room.match_id,'0').data.tick).toBeGreaterThanOrEqual(10);expect(h.service.state('a',h.id,'0').data.tick).toBe(0)} finally {h.service.stop();console.error=original;h.db.close()}
});
test('scheduler guard exceptions back off and recover without terminating the process',async()=>{
 const h=setup('1v1',['a','b']);let throwOnce=true;let errors=0;const original=console.error;
 const runtime=createWoeMatchService(h.db,()=>true,h.now,{canSchedule:()=>{if(throwOnce){throwOnce=false;throw Error('fixture guard failure')}return true},coreDefense:{tickOne:()=>{}}});
 console.error=()=>{errors++};
 try {runtime.start();await Bun.sleep(1450);runtime.stop();expect(errors).toBe(1);expect(h.service.state('a',h.id,'0').data.tick).toBeGreaterThanOrEqual(2)} finally {runtime.stop();console.error=original;h.db.close()}
});
test('scheduler catches up after a short event-loop stall without duplicate ticks',async()=>{
 const h=setup('1v1',['a','b']);h.service.start();
 try {
  await Bun.sleep(150);const before=h.service.state('a',h.id,'0').data.tick;
  const started=performance.now();Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,350);await Bun.sleep(300);
  const elapsed=performance.now()-started,after=h.service.state('a',h.id,'0').data.tick;
  expect(after-before).toBeGreaterThanOrEqual(5);
  expect(after-before).toBeLessThanOrEqual(Math.ceil(elapsed/100)+1);
 } finally {h.service.stop();h.db.close()}
});
test('ordered event pagination and retention gap',()=>{
 const h=setup();for(let i=1;i<=205;i++)h.db.query('INSERT INTO woe_match_events VALUES (?,?,?)').run(h.id,i,JSON.stringify({type:'spawn',tick:i}));h.db.query('UPDATE woe_matches SET event_seq=205 WHERE match_id=?').run(h.id);const a=h.service.state('a',h.id,'0').data,b=h.service.state('a',h.id,String(a.cursor)).data,c=h.service.state('a',h.id,String(b.cursor)).data;expect([a.events.length,b.events.length,c.events.length]).toEqual([100,100,5]);expect(c.cursor).toBe(205);h.db.query('DELETE FROM woe_match_events WHERE match_id=? AND seq<50').run(h.id);expect(h.service.state('a',h.id,'0').data.resync_required).toBe(true);h.db.close();
});

test('simultaneous four-bot matches are isolated and deploy in both lanes',()=>{
 const h=setup();const now=h.now();for(let i=0;i<8;i++){const id='load'+i,ids=Array.from({length:4},(_,n)=>`${id}:bot:${n}`),state=initializeMatch('2v2',id,ids);h.db.query("INSERT INTO woe_matches(match_id,room_id,status,state_json,created_at,updated_at) VALUES (?,?,'RUNNING',?,?,?)").run(id,'room'+i,JSON.stringify(state),now,now);for(let n=0;n<4;n++)h.db.query('INSERT INTO woe_match_participants(match_id,controller_id,team,human) VALUES (?,?,?,0)').run(id,ids[n],n<2?'blue':'red');}
 const t=performance.now();for(let i=0;i<100;i++)h.service.pulse();const elapsed=performance.now()-t;console.log(`WOE load: 9 concurrent matches, 100 pulses: ${elapsed.toFixed(1)} ms`);
 for(let i=0;i<8;i++){const r:any=h.db.query('SELECT state_json FROM woe_matches WHERE match_id=?').get('load'+i);const state=JSON.parse(r.state_json);expect(state.tick).toBe(100);expect(state.units.length).toBeLessThanOrEqual(100);expect(state.units.length).toBeGreaterThan(0);expect(new Set(state.units.map((u:any)=>u.lane)).size).toBe(2);}
 h.db.close();
});
test('terminal retention expires and removes dependent journal records',()=>{
 const h=setup('1v1',['a','b']);h.service.forfeit('a',{match_id:h.id,client_action_id:'f'});h.advance(24*60*60_000+1);h.service.pulse();expect(h.service.state('b',h.id,'0').status).toBe(404);for(const table of ['woe_match_events','woe_match_actions','woe_match_participants'])expect((h.db.query(`SELECT count(*) n FROM ${table} WHERE match_id=?`).get(h.id) as any).n).toBe(0);h.db.close();
});
