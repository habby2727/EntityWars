import {test, expect} from 'bun:test';
import {Database} from 'bun:sqlite';
import {readFileSync, readdirSync, mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';
import {createServer} from 'node:net';
import Redis from 'ioredis';
import {createForestDuels} from '../forest/duels';
import {createForestPresence, loadCatalog} from '../forest/presence';

function migrate(db:Database) {const dir=resolve(import.meta.dir,'../../migrations/sqlite');for(const f of readdirSync(dir).filter(x=>x.endsWith('.sql')).sort()) db.exec(readFileSync(join(dir,f),'utf8'));}
function setup() {
 const db=new Database(':memory:');migrate(db);for(const id of ['a','b','c','d','e','f','g','h']) db.query('INSERT INTO players VALUES (?,?,?,0)').run(id,`Name ${id}`,'{}');
 let now=1_000_000, serving=true;const rooms=new Map(['a','b','c','d','e','f','g','h'].map(x=>[x,'room']));
 const service=createForestDuels(db,id=>rooms.get(id) ?? null,()=>serving,()=>now);
 return {db,service,rooms,advance:(ms:number)=>{now+=ms},fence:()=>{serving=false},now:()=>now};
}
const request=(s:ReturnType<typeof createForestDuels>,p:string,t:string,id:string)=>s.request(p,{target_player_id:t,client_action_id:id});
const respond=(s:ReturnType<typeof createForestDuels>,p:string,id:string,accept:boolean,key:string)=>s.respond(p,{invite_id:id,accept,client_action_id:key});
const cancel=(s:ReturnType<typeof createForestDuels>,p:string,id:string,key:string)=>s.cancel(p,{invite_id:id,client_action_id:key});

test('reservations are exclusive, private, idempotent and survive suspension until expiration',()=>{
 const h=setup(),s=h.service;
 expect(request(s,'a','a','self').status).toBe(400);
 expect(request(s,'a','missing','absent').status).toBe(404);
 expect(s.request('a',{target_player_id:'b',client_action_id:'disabled'},false).status).toBe(404);
 h.rooms.set('b','elsewhere');expect(request(s,'a','b','room').status).toBe(409);h.rooms.set('b','room');
 const first=request(s,'a','b','first');expect(first.data.invite).toMatchObject({challenger_id:'a',challenger_name:'Name a',recipient_id:'b',originating_zone:'room',status:'PENDING',expires_at:h.now()+30000});
 expect(request(s,'a','b','first')).toEqual(first);
 expect(request(s,'a','c','first').data.error).toBe('ACTION_CONFLICT');
 expect(request(s,'b','a','cross').data.error).toBe('PLAYER_BUSY');
 expect(request(s,'c','b','busy').status).toBe(409);
 const id=first.data.invite.invite_id;
 expect(s.state('c').data).toMatchObject({player_id:'c',incoming:[],outgoing:[],accepted:[]});
 expect(respond(s,'c',id,true,'forged').status).toBe(404);
 expect(cancel(s,'b',id,'forged').status).toBe(404);
 h.rooms.set('a','other');expect(respond(s,'b',id,true,'moved').data.error).toBe('FOREST_ROOM_MISMATCH');h.rooms.set('a','room');
 expect(s.respond('b',{invite_id:id,accept:true,client_action_id:'disabled-accept'},false).status).toBe(404);
 const accepted=respond(s,'b',id,true,'accept');expect(accepted.data.invite).toMatchObject({status:'ACCEPTED',expires_at:h.now()+180000});
 expect(respond(s,'b',id,true,'accept')).toEqual(accepted);
 h.rooms.delete('a');h.rooms.delete('b');expect(s.state('a').data.accepted[0].invite_id).toBe(id);
 h.advance(179999);expect(s.state('b').data.accepted).toHaveLength(1);h.advance(1);expect(s.state('a').data.accepted).toHaveLength(0);
 expect(h.db.query('SELECT status FROM forest_duel_invites WHERE invite_id=?').get(id)).toEqual({status:'EXPIRED'});
 expect(h.db.query('SELECT count(*) AS n FROM forest_duel_reservations').get()).toEqual({n:0});
 h.fence();expect(s.state('a').status).toBe(503);expect(request(s,'a','b','unavailable').status).toBe(503);h.db.close();
});

test('pending expiration, decline, cancel, PvP conflicts and notification limits',()=>{
 const h=setup(),s=h.service;
 const first=request(s,'a','b','one').data.invite.invite_id;
 h.advance(45000);expect(respond(s,'b',first,true,'too-late').data.error).toBe('INVITE_NOT_PENDING');
 let id=request(s,'a','b','two').data.invite.invite_id;
 expect(respond(s,'b',id,false,'decline').data.invite.status).toBe('DECLINED');
 expect(request(s,'a','b','cooldown').data.error).toBe('DUEL_COOLDOWN'); h.advance(120000);
 id=request(s,'a','b','three').data.invite.invite_id;
 expect(cancel(s,'a',id,'cancel').data.invite.status).toBe('CANCELLED');
 expect(request(s,'a','b','cancel-cooldown').data.error).toBe('DUEL_COOLDOWN'); h.advance(30000);
 h.db.query('INSERT INTO pvp_queue VALUES (?,?,?,?)').run('b',h.now(),h.now()+30000,'{}');
 expect(request(s,'a','b','queued').data.error).toBe('PLAYER_BUSY');
 h.db.query('DELETE FROM pvp_queue').run();
 id=request(s,'a','b','four').data.invite.invite_id;
 h.db.query('INSERT INTO pvp_queue VALUES (?,?,?,?)').run('b',h.now(),h.now()+30000,'{}');
 expect(respond(s,'b',id,true,'queued-accept').data.error).toBe('PLAYER_BUSY');
 expect(h.db.query('SELECT count(*) AS n FROM pvp_queue').get()).toEqual({n:1});
 h.db.query('DELETE FROM pvp_queue').run();expect(cancel(s,'a',id,'cancel-four').status).toBe(200);
 // Independent senders are not subject to a gameplay request limit.
 id=request(s,'c','b','fifth').data.invite.invite_id;
 expect(cancel(s,'c',id,'cancel-fifth').status).toBe(200);
 expect(request(s,'d','b','recipient-limit').status).toBe(200);
 expect(h.db.query('SELECT count(*) AS n FROM pvp_matches').get()).toEqual({n:0});
 expect(h.db.query('SELECT count(*) AS n FROM pvp_ratings').get()).toEqual({n:0});
 h.db.close();
});

test('active PvP and sender rate limits do not change Ranked tables',()=>{
 const h=setup(),s=h.service;
 h.db.query("INSERT INTO pvp_matches (match_id,status,created_at,updated_at,revision,combat_state_json) VALUES ('m','ACTIVE',0,0,1,'{}')").run();
 h.db.query("INSERT INTO pvp_match_players (match_id,player_id,side,snapshot_json,active,last_seen_at) VALUES ('m','b','LEFT','{}',1,0)").run();
 expect(request(s,'a','b','match').data.error).toBe('PLAYER_BUSY');
 expect(h.db.query("SELECT active FROM pvp_match_players WHERE player_id='b'").get()).toEqual({active:1});
 h.db.query('DELETE FROM pvp_match_players').run();
 for(let i=0;i<11;i++){
  const id=`x${i}`;h.db.query('INSERT INTO players VALUES (?,?,?,0)').run(id,id,'{}');h.rooms.set(id,'room');
  const result=request(s,'a',id,`send-${i}`);
  expect(result.status).toBe(200);expect(cancel(s,'a',result.data.invite.invite_id,`cancel-${i}`).status).toBe(200);
 }
 expect(h.db.query('SELECT count(*) AS n FROM pvp_matches').get()).toEqual({n:1});
 expect(h.db.query('SELECT count(*) AS n FROM pvp_ratings').get()).toEqual({n:0});
 h.db.close();
});

test('roomOf returns only an entered live session and obeys the lease',()=>{
 let valid=true;const p=createForestPresence(loadCatalog(),async()=>true,Date.now,()=>valid);
 const ws:any={data:{kind:'forest',playerId:'a',displayName:'Alice',token:'x'},send(){return 1},close(){},getBufferedAmount(){return 0}};
 p.open(ws);expect(p.roomOf('a')).toBeNull();p.message(ws,JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));expect(p.roomOf('a')).toBe('central_clearing');
 valid=false;expect(p.roomOf('a')).toBeNull();valid=true;p.message(ws,JSON.stringify({v:1,type:'suspend'}));expect(p.roomOf('a')).toBeNull();
 p.open(ws);p.message(ws,JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));p.close(ws);expect(p.roomOf('a')).toBeNull();p.fence();expect(p.roomOf('a')).toBeNull();
});

const redisBin=Bun.env.FOREST_TEST_REDIS_SERVER || Bun.which('redis-server');
async function freePort(){return new Promise<number>((done,fail)=>{const s=createServer();s.once('error',fail);s.listen(0,'127.0.0.1',()=>{const port=(s.address() as any).port;s.close(()=>done(port));});});}
test.skipIf(!redisBin)('authenticated HTTP and real Forest sockets revalidate room and preserve accepted handoff',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'ew-duels-')), path=join(dir,'db.sqlite'), db=new Database(path);migrate(db);db.close();
 const rp=await freePort(),port=await freePort();const redisProcess=Bun.spawn([redisBin!,'--bind','127.0.0.1','--port',String(rp),'--save','','--appendonly','no'],{stdout:'ignore',stderr:'ignore'});
 const redis=new Redis(`redis://127.0.0.1:${rp}`,{lazyConnect:true,retryStrategy:()=>null});redis.on('error',()=>{});
 let server:any;const sockets:WebSocket[]=[];
 try {
  let ready=false;for(let i=0;i<50;i++){try{await redis.connect();ready=true;break}catch{}await Bun.sleep(100)}expect(ready).toBe(true);
  const env={...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(port),DB_PATH:path,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:`redis://127.0.0.1:${rp}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1',FOREST_DUELS_ENABLED:'1',PVP_ENABLED:'0',PVP_RNG_SECRET:'test-secret-with-at-least-32-characters',LOGIN_RATE_LIMIT_MAX:'100'};
  server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env,stdout:'ignore',stderr:'ignore'});
  const base=`http://127.0.0.1:${port}`;ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ready=true;break}}catch{}await Bun.sleep(100)}expect(ready).toBe(true);
  const post=(url:string,body:any,token?:string)=>fetch(base+url,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body)});
  const state=(token:string)=>fetch(base+'/forest/duels/state',{headers:{Authorization:`Bearer ${token}`}});
  expect((await state('invalid')).status).toBe(401);
  const accounts:any[]=[];for(const username of ['DuelAlice','DuelBob','DuelCarol']){const res=await post('/auth/register',{username,password:'secret1'});expect(res.status).toBe(200);const login:any=await res.json();const response:any=await (await state(login.token)).json();accounts.push({token:login.token,id:response.player_id});}
  const [a,b,c]=accounts;
  expect((await post('/forest/duels/request',{target_player_id:b.id,client_action_id:'offline'},a.token)).status).toBe(409);
  const enter=async(account:any)=>{const ws=new WebSocket(base.replace('http:','ws:')+'/forest/ws',{headers:{Authorization:`Bearer ${account.token}`,'X-EntityWars-Client-Build':'5509'}} as any);sockets.push(ws);await new Promise<void>((ok,fail)=>{const timer=setTimeout(()=>fail(Error('welcome timeout')),4000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));ws.onmessage=e=>{if(JSON.parse(String(e.data)).type==='welcome'){clearTimeout(timer);ok()}};ws.onerror=()=>fail(Error('socket error'));});return ws;};
  const aw=await enter(a);const bw=await enter(b);
  const chatsA:any[]=[],chatsB:any[]=[];
  aw.addEventListener('message',e=>{const m=JSON.parse(String(e.data));if(m.type==='peer_chat')chatsA.push(m);});
  bw.addEventListener('message',e=>{const m=JSON.parse(String(e.data));if(m.type==='peer_chat')chatsB.push(m);});
  const sent=await post('/chat/send',{client_message_id:'forest-chat',text:'hello forest'},a.token);expect(sent.status).toBe(200);
  for(let i=0;i<30 && (!chatsA.length || !chatsB.length);i++) await Bun.sleep(50);
  expect(chatsA).toHaveLength(1);expect(chatsB).toHaveLength(1);expect(chatsA[0]).toMatchObject({player_id:a.id,text:'hello forest'});
  expect(chatsA[0].expires_at-chatsA[0].created_at).toBe(10000);
  const replay=await post('/chat/send',{client_message_id:'forest-chat',text:'hello forest'},a.token);expect((await replay.json() as any).duplicate).toBe(true);
  await Bun.sleep(100);expect(chatsA).toHaveLength(1);expect(chatsB).toHaveLength(1);
  const crossed=await Promise.all([
   post('/forest/duels/request',{target_player_id:b.id,client_action_id:'one',challenger_id:c.id,originating_zone:'fake'},a.token),
   post('/forest/duels/request',{target_player_id:a.id,client_action_id:'cross'},b.token)
  ]);
  expect(crossed.map(r=>r.status).sort()).toEqual([200,409]);
  const winner=crossed[0].status===200?0:1, challenger=winner===0?a:b, recipient=winner===0?b:a, challengerSocket=winner===0?aw:bw;
  const created:any=await crossed[winner].json();expect(created.invite).toMatchObject({challenger_id:challenger.id,recipient_id:recipient.id,originating_zone:'central_clearing'});
  expect((await post('/forest/duels/respond',{invite_id:created.invite.invite_id,accept:true,client_action_id:'forged'},c.token)).status).toBe(404);
  const accepted=await post('/forest/duels/respond',{invite_id:created.invite.invite_id,accept:true,client_action_id:'accept'},recipient.token);expect(accepted.status).toBe(200);
  await new Promise<void>((ok,fail)=>{const timer=setTimeout(()=>fail(Error('suspend timeout')),3000);challengerSocket.onmessage=e=>{if(JSON.parse(String(e.data)).type==='handoff_ack'){clearTimeout(timer);ok()}};challengerSocket.send(JSON.stringify({v:1,type:'suspend'}));});
  const after:any=await (await state(challenger.token)).json();expect(after.accepted[0].invite_id).toBe(created.invite.invite_id);
  const spells=JSON.parse(readFileSync(resolve(import.meta.dir,'../../../data/spells.json'),'utf8')).spells.filter((s:any)=>s.type==='sulfur').map((s:any)=>s.id);
  const selection={entity_id:'sulfur_01',weapon_ids:[null,null],homunculus_id:null,spell_ids:spells,mode:'attack'}, invite_id=created.invite.invite_id;
  const results=await Promise.all([post('/forest/duels/ready',{invite_id,selection,client_action_id:'ready-a'},challenger.token),post('/forest/duels/ready',{invite_id,selection,client_action_id:'ready-b'},recipient.token)]);
  expect(results.map(r=>r.status)).toEqual([200,200]); const payloads:any[]=await Promise.all(results.map(r=>r.json())); expect(payloads.map(x=>x.state).sort()).toEqual(['STARTED','WAITING']);
  const recovered:any=await (await state(challenger.token)).json(), match=recovered.started.match_id; expect(match).toBe(payloads.find(x=>x.match_id).match_id);
  expect((await fetch(base+'/forest/duels/match/state?match_id='+match,{headers:{Authorization:`Bearer ${c.token}`}})).status).toBe(404);
  const battle:any=await (await fetch(base+'/forest/duels/match/state?match_id='+match,{headers:{Authorization:`Bearer ${challenger.token}`}})).json();expect(battle.kind).toBe('friendly');
  expect((await post('/forest/duels/cancel',{invite_id,client_action_id:'cancel'},challenger.token)).status).toBe(409);
  expect((await post('/forest/duels/match/forfeit',{match_id:match,client_action_id:'forfeit'},challenger.token)).status).toBe(200);
  expect((await post('/forest/duels/request',{target_player_id:challenger.id,client_action_id:'suspended'},recipient.token)).status).toBe(409);
  const secondaryPort=await freePort();
  const secondary=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env:{...env,PORT:String(secondaryPort),FOREST_WS_ENABLED:'0'},stdout:'ignore',stderr:'ignore'});
  try {let up=false;for(let i=0;i<100;i++){try{if((await fetch(`http://127.0.0.1:${secondaryPort}/health`)).ok){up=true;break}}catch{}await Bun.sleep(100)}expect(up).toBe(true);
   const unavailable=await fetch(`http://127.0.0.1:${secondaryPort}/forest/duels/state`,{headers:{Authorization:`Bearer ${a.token}`}});expect(unavailable.status).toBe(503);expect(await unavailable.json()).toEqual({error:'FOREST_DUELS_UNAVAILABLE'});
  } finally {secondary.kill();await secondary.exited;}
 } finally {for(const ws of sockets)ws.close();if(server){server.kill();await server.exited}redis.disconnect();redisProcess.kill();await redisProcess.exited;for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break}catch(e){if(i>=20)throw e;await Bun.sleep(250)}}}
},60000);
for (const invalidSecret of ['', 'short']) test.skipIf(!redisBin)(`accept fails closed with ${invalidSecret ? 'short' : 'missing'} PvP secret`,async()=>{
 const dir=mkdtempSync(join(tmpdir(),'ew-duels-secret-')),path=join(dir,'db.sqlite'),db=new Database(path);migrate(db);db.close();
 const rp=await freePort(),port=await freePort(),redisProcess=Bun.spawn([redisBin!,'--bind','127.0.0.1','--port',String(rp),'--save','','--appendonly','no'],{stdout:'ignore',stderr:'ignore'}),redis=new Redis(`redis://127.0.0.1:${rp}`,{lazyConnect:true,retryStrategy:()=>null});redis.on('error',()=>{});
 let server:any;const sockets:WebSocket[]=[];
 try{
  let connected=false;for(let i=0;i<50;i++){try{await redis.connect();connected=true;break}catch{}await Bun.sleep(100)}expect(connected).toBe(true);
  const env={...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(port),DB_PATH:path,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:`redis://127.0.0.1:${rp}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1',FOREST_DUELS_ENABLED:'1',SOCIAL_ENABLED:'1',PVP_ENABLED:'0',PVP_RNG_SECRET:invalidSecret,LOGIN_RATE_LIMIT_MAX:'100'};
  server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env,stdout:'ignore',stderr:'ignore'});const base=`http://127.0.0.1:${port}`;
  let ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ready=true;break}}catch{}await Bun.sleep(100)}expect(ready).toBe(true);
  const post=(url:string,body:any,token?:string)=>fetch(base+url,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body)});
  const accounts:any[]=[];for(const username of ['NoSecretAlice','NoSecretBob']){const login:any=await (await post('/auth/register',{username,password:'secret1'})).json();const state:any=await (await fetch(base+'/social/state',{headers:{Authorization:`Bearer ${login.token}`}})).json();accounts.push({token:login.token,id:state.player_id});}
  for(const account of accounts){const ws=new WebSocket(base.replace('http:','ws:')+'/forest/ws',{headers:{Authorization:`Bearer ${account.token}`,'X-EntityWars-Client-Build':'5509'}} as any);sockets.push(ws);await new Promise<void>((ok,fail)=>{const timer=setTimeout(()=>fail(Error('welcome timeout')),4000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));ws.onmessage=e=>{if(JSON.parse(String(e.data)).type==='welcome'){clearTimeout(timer);ok()}};ws.onerror=()=>fail(Error('socket error'));});}
  const [a,b]=accounts,created:any=await (await post('/forest/duels/request',{target_player_id:b.id,client_action_id:'invite'},a.token)).json();
  const invite_id=created.invite.invite_id,accept=await post('/forest/duels/respond',{invite_id,accept:true,client_action_id:'accept'},b.token);
  expect(accept.status).toBe(503);expect(await accept.json()).toEqual({error:'PVP_SECRET_REQUIRED'});
  const state:any=await (await fetch(base+'/forest/duels/state',{headers:{Authorization:`Bearer ${a.token}`}})).json();expect(state.outgoing[0].status).toBe('PENDING');expect(state.accepted).toHaveLength(0);
  const rejected=await post('/forest/duels/respond',{invite_id,accept:false,client_action_id:'reject'},b.token);expect(rejected.status).toBe(200);
  expect((await post('/social/friends/request',{target_player_id:b.id,client_action_id:'friend'},a.token)).status).toBe(200);
  expect((await post('/chat/send',{text:'still works',client_message_id:'chat'},a.token)).status).toBe(200);
 }finally{for(const ws of sockets)ws.close();if(server){server.kill();await server.exited}redis.disconnect();redisProcess.kill();await redisProcess.exited;for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break}catch(e){if(i>=20)throw e;await Bun.sleep(250)}}}
},60000);
test.skipIf(!redisBin)('authenticated READY races with cancellation and Ranked join remain exclusive',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'ew-duels-race-')),path=join(dir,'db.sqlite'),db=new Database(path);migrate(db);db.close();
 const rp=await freePort(),port=await freePort(),redisProcess=Bun.spawn([redisBin!,'--bind','127.0.0.1','--port',String(rp),'--save','','--appendonly','no'],{stdout:'ignore',stderr:'ignore'}),redis=new Redis(`redis://127.0.0.1:${rp}`,{lazyConnect:true,retryStrategy:()=>null});redis.on('error',()=>{});let server:any;const sockets:WebSocket[]=[];
 try{
  let connected=false;for(let i=0;i<50;i++){try{await redis.connect();connected=true;break}catch{}await Bun.sleep(100)}expect(connected).toBe(true);
  const env={...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(port),DB_PATH:path,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:`redis://127.0.0.1:${rp}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1',FOREST_DUELS_ENABLED:'1',PVP_ENABLED:'1',PVP_RNG_SECRET:'test-secret-with-at-least-32-characters',LOGIN_RATE_LIMIT_MAX:'100'};
  server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env,stdout:'ignore',stderr:'ignore'});const base=`http://127.0.0.1:${port}`;
  let ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ready=true;break}}catch{}await Bun.sleep(100)}expect(ready).toBe(true);
  const post=(url:string,body:any,token:string)=>fetch(base+url,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token}`},body:JSON.stringify(body)}),get=(url:string,token:string)=>fetch(base+url,{headers:{Authorization:`Bearer ${token}`}});
  const accounts:any[]=[];for(const username of ['RaceAlice','RaceBob','RaceCarol','RaceDavid','RaceEva','RaceFrank']){const login:any=await (await fetch(base+'/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username,password:'secret1'})})).json();const state:any=await (await get('/forest/duels/state',login.token)).json();accounts.push({token:login.token,id:state.player_id});}
  for(const account of accounts){const ws=new WebSocket(base.replace('http:','ws:')+'/forest/ws',{headers:{Authorization:`Bearer ${account.token}`,'X-EntityWars-Client-Build':'5509'}} as any);sockets.push(ws);await new Promise<void>((ok,fail)=>{const timer=setTimeout(()=>fail(Error('welcome timeout')),4000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));ws.onmessage=e=>{if(JSON.parse(String(e.data)).type==='welcome'){clearTimeout(timer);ok()}};ws.onerror=()=>fail(Error('socket error'));});}
  const spells=JSON.parse(readFileSync(resolve(import.meta.dir,'../../../data/spells.json'),'utf8')).spells.filter((s:any)=>s.type==='sulfur').map((s:any)=>s.id),selection={entity_id:'sulfur_01',weapon_ids:[null,null],homunculus_id:null,spell_ids:spells,mode:'attack'};
  async function invite(a:any,b:any,key:string){const res=await post('/forest/duels/request',{target_player_id:b.id,client_action_id:'request-'+key},a.token);expect(res.status).toBe(200);const id=(await res.json() as any).invite.invite_id;expect((await post('/forest/duels/respond',{invite_id:id,accept:true,client_action_id:'accept-'+key},b.token)).status).toBe(200);return id;}
  const [a,b,c,d,e,f]=accounts;
  const expiring=await post('/forest/duels/request',{target_player_id:f.id,client_action_id:'expiry-request'},e.token);expect(expiring.status).toBe(200);const expiredId=(await expiring.json() as any).invite.invite_id;
  const editDb=new Database(path);editDb.query('UPDATE forest_duel_invites SET expires_at=? WHERE invite_id=?').run(Date.now()-1,expiredId);
  expect((await post('/forest/duels/respond',{invite_id:expiredId,accept:true,client_action_id:'expiry-accept'},f.token)).status).toBe(409);
  const prepExpiry=await invite(f,e,'expiry-ready');editDb.query('UPDATE forest_duel_invites SET expires_at=? WHERE invite_id=?').run(Date.now()-1,prepExpiry);
  expect((await post('/forest/duels/ready',{invite_id:prepExpiry,selection,client_action_id:'expiry-ready'},f.token)).status).toBe(409);
  expect((editDb.query('SELECT count(*) n FROM forest_duel_reservations WHERE invite_id IN (?,?)').get(expiredId,prepExpiry) as any).n).toBe(0);editDb.close();
  const id=await invite(a,b,'one');expect((await post('/forest/duels/ready',{invite_id:id,selection,client_action_id:'first'},a.token)).status).toBe(200);
  const [second,cancel]=await Promise.all([post('/forest/duels/ready',{invite_id:id,selection,client_action_id:'second'},b.token),post('/forest/duels/cancel',{invite_id:id,client_action_id:'cancel'},a.token)]);
  expect([second.status,cancel.status].sort()).toEqual([200,409]);
  const check=new Database(path,{readonly:true});let row:any=check.query('SELECT status FROM forest_duel_invites WHERE invite_id=?').get(id);let matches:any=check.query('SELECT match_id FROM pvp_matches WHERE invite_id=?').all(id);
  expect(['CANCELLED','STARTED']).toContain(row.status);expect(matches.length).toBe(row.status==='STARTED'?1:0);expect((check.query('SELECT count(*) n FROM forest_duel_reservations WHERE invite_id=?').get(id) as any).n).toBe(0);
  const id2=await invite(c,d,'two');expect((await post('/forest/duels/ready',{invite_id:id2,selection,client_action_id:'first2'},c.token)).status).toBe(200);
  const [second2,ranked]=await Promise.all([post('/forest/duels/ready',{invite_id:id2,selection,client_action_id:'second2'},d.token),post('/pvp/queue/join',{selection,client_action_id:'ranked-race'},c.token)]);
  expect(second2.status).toBe(200);const secondResult:any=await second2.json();expect([200,409]).toContain(ranked.status);const rank:any=await ranked.json();expect(rank.state==='FRIENDLY_ACTIVE'||rank.error==='PLAYER_BUSY').toBe(true);
  row=check.query('SELECT status FROM forest_duel_invites WHERE invite_id=?').get(id2);matches=check.query('SELECT match_id FROM pvp_matches WHERE invite_id=?').all(id2);expect(row.status).toBe('STARTED');expect(matches).toHaveLength(1);
  const match=matches[0].match_id;expect((await post('/forest/duels/match/decision',{match_id:match,client_action_id:'stale',combat_revision:0,decision:{turn:1,spell_id:spells[0]}},c.token)).status).toBe(409);
  expect((await get('/forest/duels/match/state?match_id='+match,a.token)).status).toBe(404);expect((check.query('SELECT count(*) n FROM pvp_queue').get() as any).n).toBe(0);expect((check.query('SELECT count(*) n FROM pvp_season_ratings').get() as any).n).toBe(0);
  expect((check.query('SELECT count(*) n FROM (SELECT player_id FROM pvp_match_players WHERE active=1 GROUP BY player_id HAVING count(*)>1)').get() as any).n).toBe(0);check.close();
  // Restart the real backend while retaining SQLite and Redis. Remove only this isolated fixture's dead lease.
  server.kill();await server.exited;await redis.del('lock:forest:presence:leader');
  server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env,stdout:'ignore',stderr:'ignore'});
  ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ready=true;break}}catch{}await Bun.sleep(100)}expect(ready).toBe(true);
  const replay=await post('/forest/duels/ready',{invite_id:id2,selection,client_action_id:'second2'},d.token);expect(replay.status).toBe(200);expect(await replay.json()).toEqual(secondResult);
  const recovered:any=await (await get('/forest/duels/match/state?match_id='+match,c.token)).json();expect(recovered).toMatchObject({match_id:match,kind:'friendly',status:'ACTIVE'});
  const body={match_id:match,client_action_id:'forfeit-after-restart'},forfeit=await post('/forest/duels/match/forfeit',body,c.token),forfeitData:any=await forfeit.json();expect(forfeit.status).toBe(200);expect(forfeitData.result.mp_delta).toBeUndefined();
  const repeated=await post('/forest/duels/match/forfeit',body,c.token);expect(await repeated.json()).toEqual(forfeitData);
 }finally{for(const ws of sockets)ws.close();if(server){server.kill();await server.exited}redis.disconnect();redisProcess.kill();await redisProcess.exited;for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break}catch(e){if(i>=20)throw e;await Bun.sleep(250)}}}
},60000);
