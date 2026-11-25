import {createWoeMatchService} from '../woe/match_service';
import {test,expect} from 'bun:test';
import {Database} from 'bun:sqlite';
import {readFileSync,readdirSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,join} from 'node:path';
import {createWoeLobby} from '../woe/lobby';
import {createForestDuels} from '../forest/duels';
import {createPvpQueue} from '../pvp/service';
import {activeWoe} from '../woe/busy';
const read=(n:string)=>JSON.parse(readFileSync(resolve(import.meta.dir,'../../../data',n),'utf8'));
const catalogs={entities:read('entities.json').entities,items:read('items.json').items,spells:read('spells.json').spells,homunculi:read('homunculi.json').homunculi,types:read('types.json'),mutations:read('static/mutations.json').mutations,balance:read('static/balance.json').balance};
function migrate(db:Database){const dir=resolve(import.meta.dir,'../../migrations/sqlite');for(const f of readdirSync(dir).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(dir,f),'utf8'));for(const id of ['a','b','c','d'])db.query('INSERT INTO players VALUES (?,?,?,0)').run(id,id,'{}')}
const snap=(id:string)=>({player_id:id,entity_id:'sulfur_01',weapon_ids:[null,null],homunculus_id:null,spell_ids:catalogs.spells.filter((s:any)=>s.type==='sulfur').slice(0,4).map((s:any)=>s.id)});
test('WOE membership guards Ranked and friendly admissions, expiry and candidate eligibility',()=>{
 const db=new Database(':memory:');migrate(db);let now=1000000;
 const w=createWoeLobby(db,()=> 'duel_clearing',()=>true,()=>now),q=createPvpQueue(db,catalogs,snap,()=>now),d=createForestDuels(db,()=> 'duel_clearing',()=>true,()=>now,{snapshot:(id)=>snap(id),start:()=>{throw Error('unexpected')}});
 let r=w.create('a',{mode:'2v2',client_action_id:'create'}).data;const room=r.room_id;
 expect(()=>q.join('a',{})).toThrow('PLAYER_BUSY');
 expect(d.request('a',{target_player_id:'b',client_action_id:'r1'}).data.error).toBe('PLAYER_BUSY');
 expect(d.request('b',{target_player_id:'a',client_action_id:'r2'}).data.error).toBe('PLAYER_BUSY');
 expect(q.join('b',{}).state).toBe('QUEUED');expect(w.join('b',{room_id_or_code:room,client_action_id:'busy'}).data.error).toBe('PLAYER_BUSY');q.cancel('b');
 r=w.seat('a',{room_id:room,seat:'blue:left',expected_revision:r.revision,client_action_id:'seat'}).data;
 r=w.start('a',{room_id:room,fill_bots:true,expected_revision:r.revision,client_action_id:'start'}).data;expect(r.match_id).toBeTruthy();
 expect(()=>q.join('a',{})).toThrow('PLAYER_BUSY');expect(d.request('b',{target_player_id:'a',client_action_id:'r3'}).data.error).toBe('PLAYER_BUSY');
 // Legacy inconsistent data must never allow the busy queued candidate to match.
 db.query('INSERT INTO pvp_queue VALUES (?,?,?,?)').run('a',now,now+1000,JSON.stringify({selection:{},snapshot:snap('a')}));
 expect(q.join('c',{}).state).toBe('QUEUED');expect((db.query('SELECT count(*) n FROM pvp_matches').get() as any).n).toBe(0);q.cancel('a');q.cancel('c');
 expect(w.leave('a',{room_id:room,client_action_id:'leave'}).status).toBe(200);expect(()=>q.join('a',{})).toThrow('PLAYER_BUSY');const matches=createWoeMatchService(db,()=>true,()=>now);expect(matches.forfeit('a',{match_id:r.match_id,client_action_id:'forfeit'}).status).toBe(200);expect(q.join('a',{}).state).toBe('QUEUED');q.cancel('a');
 r=w.create('a',{mode:'1v1',client_action_id:'again'}).data;now=r.expires_at;expect(activeWoe(db,'a',now)).toBe(false);expect(q.join('a',{}).state).toBe('QUEUED');
 expect((db.query('SELECT count(*) n FROM woe_members').get() as any).n).toBe(1);db.close();
});
test('friendly accept and ready reject either WOE participant without disturbing reservation',()=>{
 const db=new Database(':memory:');migrate(db);let now=1000;const d=createForestDuels(db,()=> 'duel_clearing',()=>true,()=>now,{snapshot:(id)=>snap(id),start:()=>{throw Error('unexpected')}});
 const invite=d.request('a',{target_player_id:'b',client_action_id:'request'}).data.invite.invite_id;
 db.query("INSERT INTO woe_rooms (room_id,join_code,mode,host_id,status,revision,created_at,updated_at,expires_at) VALUES ('x','X','1v1','a','WAITING',1,?,?,?)").run(now,now,now+1000);
 for(const player of ['a','b']){db.query('INSERT INTO woe_members VALUES (?,\'x\',NULL,?)').run(player,now);expect(d.respond('b',{invite_id:invite,accept:true,client_action_id:'accept-'+player}).data.error).toBe('PLAYER_BUSY');db.query('DELETE FROM woe_members').run()}
 expect(d.respond('b',{invite_id:invite,accept:true,client_action_id:'accept-ok'}).status).toBe(200);
 for(const player of ['a','b']){db.query('INSERT INTO woe_members VALUES (?,\'x\',NULL,?)').run(player,now);expect(d.ready('a',{invite_id:invite,selection:{},client_action_id:'ready-'+player}).data.error).toBe('PLAYER_BUSY');db.query('DELETE FROM woe_members').run()}
 expect((db.query('SELECT count(*) n FROM forest_duel_reservations').get() as any).n).toBe(2);db.close();
});

test('independent SQLite connections serialize competing WOE and friendly admissions',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'woe-race-')),path=join(dir,'race.sqlite');const db=new Database(path);migrate(db);db.close();
 try {for(let i=0;i<4;i++){
  const clear=new Database(path);clear.exec('DELETE FROM woe_actions; DELETE FROM woe_members; DELETE FROM woe_rooms; DELETE FROM forest_duel_actions; DELETE FROM forest_duel_reservations; DELETE FROM forest_duel_invites');clear.close();
  const env={...process.env,WOE_RACE_DB:path,WOE_RACE_AT:String(Date.now()+500)};
  const workers=['woe','duel'].map(kind=>Bun.spawn([process.execPath,resolve(import.meta.dir,'woe_race_worker.ts')],{env:{...env,WOE_RACE_KIND:kind},stdout:'pipe',stderr:'pipe'}));
  const outputs=await Promise.all(workers.map(async p=>{const [out,err,code]=await Promise.all([new Response(p.stdout).text(),new Response(p.stderr).text(),p.exited]);expect({code,err}).toEqual({code:0,err:''});return JSON.parse(out)}));
  expect(outputs.map(x=>x.status).sort()).toEqual([200,409]);
  const check=new Database(path);const members=(check.query('SELECT count(*) n FROM woe_members').get() as any).n,reservations=(check.query('SELECT count(*) n FROM forest_duel_reservations').get() as any).n;expect([members,reservations]).toEqual(outputs[0].status===200?[1,0]:[0,2]);check.close();
 }} finally {rmSync(dir,{recursive:true,force:true})}
},15000);

test('Ranked, Practice and friendly reservations prevent WOE admission and start',()=>{
 const db=new Database(':memory:');migrate(db);const now=1000000;
 const w=createWoeLobby(db,()=> 'duel_clearing',()=>true,()=>now),q=createPvpQueue(db,catalogs,snap,()=>now),d=createForestDuels(db,()=> 'duel_clearing',()=>true,()=>now);
 expect(q.join('a',{}).state).toBe('QUEUED');expect(w.create('a',{mode:'1v1',client_action_id:'ranked'}).data.error).toBe('PLAYER_BUSY');q.cancel('a');
 db.query("INSERT INTO practice_sessions VALUES ('p','a','ACTIVE',1,'{}','{}',NULL,?,?,?)").run(now,now,now+10000);
 expect(w.create('a',{mode:'1v1',client_action_id:'practice'}).data.error).toBe('PLAYER_BUSY');db.query('DELETE FROM practice_sessions').run();
 const invite=d.request('a',{target_player_id:'b',client_action_id:'invite'}).data.invite.invite_id;
 expect(w.create('a',{mode:'1v1',client_action_id:'friendly-a'}).data.error).toBe('PLAYER_BUSY');expect(w.create('b',{mode:'1v1',client_action_id:'friendly-b'}).data.error).toBe('PLAYER_BUSY');
 d.cancel('a',{invite_id:invite,client_action_id:'cancel'});
 let r=w.create('a',{mode:'1v1',client_action_id:'ok'}).data;r=w.seat('a',{room_id:r.room_id,seat:'blue:left',expected_revision:r.revision,client_action_id:'seat'}).data;
 db.query("INSERT INTO practice_sessions VALUES ('p','a','ACTIVE',1,'{}','{}',NULL,?,?,?)").run(now,now,now+10000);
 expect(w.start('a',{room_id:r.room_id,fill_bots:true,expected_revision:r.revision,client_action_id:'practice-start'}).data.error).toBe('PLAYER_BUSY');db.query('DELETE FROM practice_sessions').run();
 db.query('INSERT INTO pvp_queue VALUES (?,?,?,?)').run('a',now,now+10000,'{}');expect(w.start('a',{room_id:r.room_id,fill_bots:true,expected_revision:r.revision,client_action_id:'ranked-start'}).data.error).toBe('PLAYER_BUSY');db.query('DELETE FROM pvp_queue').run();
 db.query("INSERT INTO forest_duel_invites VALUES ('i','a','b','duel_clearing','PENDING',?,?,?)").run(now,now,now+10000);db.query("INSERT INTO forest_duel_reservations VALUES ('a','i')").run();expect(w.start('a',{room_id:r.room_id,fill_bots:true,expected_revision:r.revision,client_action_id:'friendly-start'}).data.error).toBe('PLAYER_BUSY');db.close();
});
