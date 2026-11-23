import { expect, test } from 'bun:test';
import { Database } from 'bun:sqlite';
import { readFileSync, readdirSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { tmpdir } from 'node:os';
import { createServer } from 'node:net';
import { createFriends } from '../social/friends';
import { createGlobalChat } from '../global_chat';

function migrate(db: Database) {
 const dir = resolve(import.meta.dir, '../../migrations/sqlite');
 for (const file of readdirSync(dir).filter(f => f.endsWith('.sql')).sort()) db.exec(readFileSync(join(dir, file), 'utf8'));
}
const send = (f: ReturnType<typeof createFriends>, from: string, to: string, id: string) => f.request(from, {target_player_id: to, client_action_id: id});

test('persistent requests, authorization, replay, expiry and viewer-specific online order', () => {
 const db = new Database(':memory:'); migrate(db);
 db.exec("INSERT INTO players VALUES ('a','Zoe','{}',0),('b','Bob','{}',0),('c','Alice','{}',0)");
 let now = 1_000_000_000; let f = createFriends(db, () => now);
 expect(send(f, 'a', 'a', 'self').status).toBe(400);
 expect(send(f, 'a', 'missing', 'missing').status).toBe(404);
 expect(f.request('a', {target_player_id:'b', client_action_id:'disabled'}, false).status).toBe(404);
 const first = send(f, 'a', 'b', 'one');
 expect(first.status).toBe(200);
 expect(send(f, 'a', 'b', 'one')).toEqual(first);
 expect(send(f, 'a', 'c', 'one').status).toBe(409);
 expect(send(f, 'b', 'a', 'mutual').status).toBe(409);
 const id = first.data.request_id;
 expect(f.state('c')).toMatchObject({friends: [], incoming: [], outgoing: []});
 expect(f.state('b').incoming).toMatchObject([{request_id:id, requester_id:'a', requester_name:'Zoe'}]);
 expect(f.respond('c', {request_id:id, accept:true, client_action_id:'forged'}).status).toBe(404);
 expect(f.cancel('b', {request_id:id, client_action_id:'forged-cancel'}).status).toBe(404);
 const accepted = f.respond('b', {request_id:id, accept:true, client_action_id:'accept'});
 expect(accepted.data.status).toBe('ACCEPTED');
 expect(f.respond('b', {request_id:id, accept:true, client_action_id:'accept'})).toEqual(accepted);
 expect(f.respond('b', {request_id:id, accept:false, client_action_id:'other'}).status).toBe(409);
 f = createFriends(db, () => now);
 expect(f.state('a').friends).toEqual([{player_id:'b', display_name:'Bob'}]);
 expect(f.state('b').friends).toEqual([{player_id:'a', display_name:'Zoe'}]);
 const rejected = send(f, 'a', 'c', 'two').data.request_id;
 expect(f.respond('c', {request_id:rejected, accept:false, client_action_id:'reject'}).data.status).toBe('DECLINED');
 expect(send(f, 'a', 'c', 'cooldown').status).toBe(429);
 now += 120_000;
 const cancelled = send(f, 'a', 'c', 'three').data.request_id;
 expect(f.cancel('a', {request_id:cancelled, client_action_id:'cancel'}).data.status).toBe('CANCELLED');
 expect(f.respond('c', {request_id:cancelled, accept:true, client_action_id:'late'}).status).toBe(409);
 expect(send(f, 'a', 'c', 'cancel-cooldown').status).toBe(429);
 now += 30_000;
 const expired = send(f, 'a', 'c', 'four').data.request_id;
 now += 30_000;
 expect(f.state('c').incoming).toEqual([]);
 expect(f.respond('c', {request_id:expired, accept:true, client_action_id:'expired'}).status).toBe(409);
 const chat = createGlobalChat(db, () => now, false, f.friendIds);
 chat.state('a'); chat.state('b'); chat.state('c');
 const a = chat.state('a'), c = chat.state('c');
 expect(a.online_count).toBe(3);
 expect(a.online_players.map(x => [x.player_id,x.is_friend])).toEqual([['b',true],['c',false],['a',false]]);
 expect(c.online_players.map(x => x.player_id)).toEqual(['c','b','a']);
 expect(a.online_players.every(x => x.league === 'Copper')).toBe(true);
 chat.close(); db.close();
});

test('pending requests are bounded', () => {
 const db = new Database(':memory:'); migrate(db);
 for (let i = 0; i < 22; i++) db.query('INSERT INTO players VALUES (?, ?, ?, 0)').run(String(i), String(i), '{}');
 const f = createFriends(db, () => 1000000);
 for (let i = 1; i <= 20; i++) expect(send(f, '0', String(i), String(i)).status).toBe(200);
 expect(send(createFriends(db, () => 1000000), '0', '21', '21').status).toBe(429);
 db.close();
});

test('authenticated HTTP routes enforce identity and feature flag', async () => {
 const dir = mkdtempSync(join(tmpdir(), 'ew-friends-')); const path = join(dir, 'test.sqlite');
 const db = new Database(path); migrate(db); db.close();
 const port = await new Promise<number>((done, fail) => { const s = createServer(); s.once('error', fail); s.listen(0, '127.0.0.1', () => { const p = (s.address() as any).port; s.close(() => done(p)); }); });
 const env = {...process.env, NODE_ENV:'test', BUN_ENV:'test', HOST:'127.0.0.1', PORT:String(port), DB_PATH:path, DATABASE_URL:'postgres://x:x@127.0.0.1:1/test', REDIS_URL:'redis://127.0.0.1:1', AUTH_ACCOUNT_TIMEOUT_MS:'100', LOGIN_RATE_LIMIT_MAX:'100', SOCIAL_ENABLED:'1'};
 let server = Bun.spawn([process.execPath, 'src/index.ts'], {cwd:resolve(import.meta.dir, '../..'), env, stdout:'ignore', stderr:'ignore'});
 try {
  const base = `http://127.0.0.1:${port}`;
  let ready = false; for (let i=0;i<100;i++) { try { if ((await fetch(base+'/health')).ok) {ready=true; break;} } catch {} await Bun.sleep(100); } expect(ready).toBe(true);
  const post = (url:string, body:any, token?:string) => fetch(base+url,{method:'POST',headers:{'Content-Type':'application/json', ...(token ? {Authorization:`Bearer ${token}`} : {})},body:JSON.stringify(body)});
  expect((await fetch(base+'/social/state')).status).toBe(401);
  expect((await post('/social/friends/request', {})).status).toBe(401);
  const a:any = await (await post('/auth/register',{username:'Alice',password:'secret1'})).json();
  const b:any = await (await post('/auth/register',{username:'Bob',password:'secret1'})).json();
  const c:any = await (await post('/auth/register',{username:'Carol',password:'secret1'})).json();
  const get = async (token:string) => (await fetch(base+'/social/state',{headers:{Authorization:`Bearer ${token}`}})).json() as Promise<any>;
  const aid = (await get(a.token)).player_id, bid = (await get(b.token)).player_id;
  expect((await post('/social/friends/request',{target_player_id:bid,client_action_id:'large',padding:'x'.repeat(5000)},a.token)).status).toBe(413);
  const created:any = await (await post('/social/friends/request',{target_player_id:bid, client_action_id:'one', requester_id:bid, requester_name:'forged'},a.token)).json();
  expect((await get(b.token)).incoming[0]).toMatchObject({request_id:created.request_id,requester_id:aid,requester_name:'Alice'});
  expect((await post('/social/friends/respond',{request_id:created.request_id,accept:true,client_action_id:'forged'},a.token)).status).toBe(404);
  expect((await post('/social/friends/respond',{request_id:created.request_id,accept:true,client_action_id:'yes'},b.token)).status).toBe(200);
  expect((await get(a.token)).friends[0].player_id).toBe(bid);
  const login:any = await (await post('/auth/login',{username:'Alice',password:'secret1'})).json();
  expect((await get(login.token)).friends[0].player_id).toBe(bid);
  const cid = (await get(c.token)).player_id;
  const simultaneous = await Promise.all([
   post('/social/friends/request',{target_player_id:cid,client_action_id:'race-a'},a.token),
   post('/social/friends/request',{target_player_id:aid,client_action_id:'race-c'},c.token)
  ]);
  expect(simultaneous.map(r => r.status).sort()).toEqual([200,409]);
  const aState = await get(a.token), cState = await get(c.token);
  expect(aState.incoming.length + aState.outgoing.length).toBe(1);
  expect(cState.incoming.length + cState.outgoing.length).toBe(1);
  const pending = aState.incoming[0] ?? cState.incoming[0];
  const recipientToken = aState.incoming.length ? a.token : c.token;
  const decisions = await Promise.all([
   post('/social/friends/respond',{request_id:pending.request_id,accept:true,client_action_id:'accept-race'},recipientToken),
   post('/social/friends/respond',{request_id:pending.request_id,accept:false,client_action_id:'reject-race'},recipientToken)
  ]);
  expect(decisions.map(r => r.status).sort()).toEqual([200,409]);
  server.kill(); await server.exited;
  server = Bun.spawn([process.execPath, 'src/index.ts'], {cwd:resolve(import.meta.dir, '../..'), env, stdout:'ignore', stderr:'ignore'});
  ready = false; for (let i=0;i<100;i++) { try { if ((await fetch(base+'/health')).ok) {ready=true; break;} } catch {} await Bun.sleep(100); } expect(ready).toBe(true);
  const restored:any = await (await post('/auth/login',{username:'Alice',password:'secret1'})).json();
  expect((await get(restored.token)).friends.some((x:any) => x.player_id === bid)).toBe(true);
  server.kill(); await server.exited;
  server = Bun.spawn([process.execPath, 'src/index.ts'], {cwd:resolve(import.meta.dir, '../..'), env:{...env, SOCIAL_ENABLED:'0'}, stdout:'ignore', stderr:'ignore'});
  ready = false; for (let i=0;i<100;i++) { try { if ((await fetch(base+'/health')).ok) {ready=true; break;} } catch {} await Bun.sleep(100); } expect(ready).toBe(true);
  const afterRestart:any = await (await post('/auth/login',{username:'Alice',password:'secret1'})).json();
  const disabled = await fetch(base+'/social/state',{headers:{Authorization:`Bearer ${afterRestart.token}`}});
  expect(disabled.status).toBe(503);
  expect(await disabled.json()).toEqual({error:'SOCIAL_DISABLED'});
 } finally { server.kill(); await server.exited; for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch(e){if(i>=20) throw e; await Bun.sleep(250);}} }
}, 60000);
