import {test, expect} from 'bun:test';
import {loadCatalog, validateCatalog, segmentInside, createForestPresence} from '../forest/presence';
import {readFileSync} from 'node:fs';
function harness(){let now=100000, valid=true;const service=createForestPresence(loadCatalog(),async()=>valid,()=>now);const connect=(id:string)=>{const events:any[]=[];const ws:any={data:{kind:'forest',playerId:id,displayName:'Name '+id,token:'secret'},send(s:string){events.push(JSON.parse(s));return 1;},close(){},getBufferedAmount(){return 0;}};service.open(ws);return {ws,events,send(m:any){service.message(ws,JSON.stringify({v:1,...m}));}}};return {service,connect,advance(ms:number){now+=ms},revoke(){valid=false}};}
test('catalog and concave segment validation',()=>{const c=JSON.parse(readFileSync(new URL('../../../data/static/forest_zones.json',import.meta.url),'utf8'));const zones=validateCatalog(c);expect(zones.size).toBe(6);expect([...zones.values()].flatMap(z=>z.portals)).toHaveLength(10);expect(segmentInside([1,3],[3,3],[[0,0],[4,0],[4,4],[2,2],[0,4]])).toBe(false);c.zones[0].portals[0].arrival=[-1,-1];expect(()=>validateCatalog(c)).toThrow();});
test('identity, movement, replacement, suspend and revocation',async()=>{const h=harness(),a=h.connect('a'),b=h.connect('b');a.send({type:'enter',summoner_id:'wizard',player_id:'fake',display_name:'fake'});b.send({type:'enter',summoner_id:'witch'});expect(b.events[0].peers[0]).toMatchObject({player_id:'a',display_name:'Name a'});a.events.length=0;b.events.length=0;h.advance(1000);a.send({type:'move',seq:1,x:980,y:760,facing:1});expect(b.events[0]).toMatchObject({type:'peer_move',x:980});a.send({type:'move',seq:1,x:981,y:760,facing:1});expect(a.events.at(-1).reason).toBe('INVALID_SEQ');a.send({type:'move',seq:2,x:1900,y:760,facing:1});expect(a.events.at(-1).reason).toBe('INVALID_MOVEMENT');a.send({type:'suspend'});expect(b.events.at(-1).type).toBe('peer_leave');const a2=h.connect('a');a2.send({type:'enter',summoner_id:'wizard'});expect(a2.events[0].self.x).toBe(980);const a3=h.connect('a');a3.send({type:'enter',summoner_id:'wizard'});expect(a3.events[0].self.x).toBe(980);h.revoke();await h.service.sweep();const fresh=h.connect('a');fresh.send({type:'enter',summoner_id:'wizard'});expect(fresh.events[0].self.x).toBe(960);});
test('handoff acknowledgement follows committed removal and preserves TTL semantics',()=>{
 const h=harness(),a=h.connect('a'),b=h.connect('b');a.send({type:'enter',summoner_id:'wizard'});b.send({type:'enter',summoner_id:'witch'});
 h.advance(250);a.send({type:'move',seq:1,x:980,y:760,facing:1});a.send({type:'suspend'});
 expect(a.events.at(-1)).toEqual({v:1,type:'handoff_ack',kind:'suspend'});expect(b.events.at(-1)).toMatchObject({type:'peer_leave',player_id:'a'});
 h.advance(899999);const resumed=h.connect('a');resumed.send({type:'enter',summoner_id:'wizard'});expect(resumed.events[0].self.x).toBe(980);
 resumed.send({type:'leave'});expect(resumed.events.at(-1)).toEqual({v:1,type:'handoff_ack',kind:'leave'});
 const fresh=h.connect('a');fresh.send({type:'enter',summoner_id:'wizard'});expect(fresh.events[0].self.x).toBe(960);
});
test('disconnect and suspend have distinct expiry; old sockets cannot mutate a replacement',()=>{
 const h=harness(),a=h.connect('a'),observer=h.connect('b');a.send({type:'enter',summoner_id:'wizard'});observer.send({type:'enter',summoner_id:'witch'});
 h.advance(250);a.send({type:'move',seq:1,x:980,y:760,facing:1});h.service.close(a.ws);expect(observer.events.at(-1)).toMatchObject({type:'peer_leave',player_id:'a'});
 h.advance(119999);const resumed=h.connect('a');resumed.send({type:'enter',summoner_id:'wizard'});expect(resumed.events[0].self.x).toBe(980);
 a.send({type:'leave'});h.service.close(a.ws);expect(observer.events.at(-1).type).toBe('peer_join');
 h.service.close(resumed.ws);h.advance(120001);const expired=h.connect('a');expired.send({type:'enter',summoner_id:'wizard'});expect(expired.events[0].self.x).toBe(960);
 h.advance(250);expired.send({type:'move',seq:1,x:980,y:760,facing:1});expired.send({type:'suspend'});h.advance(900001);const after=h.connect('a');after.send({type:'enter',summoner_id:'wizard'});expect(after.events[0].self.x).toBe(960);
});
test('lease fence closes sessions and refuses subsequent messages',()=>{
 const h=harness(),a=h.connect('a'),b=h.connect('b');a.send({type:'enter',summoner_id:'wizard'});b.send({type:'enter',summoner_id:'witch'});const before=b.events.length;
 h.service.fence();a.send({type:'move',seq:1,x:960,y:760,facing:1});h.service.flush();expect(b.events).toHaveLength(before);
});
test('real Bun websocket sends welcome',async()=>{const service=createForestPresence(loadCatalog(),async()=>true);const server=Bun.serve({port:0,fetch(req,server){if(server.upgrade(req,{data:{kind:'forest',playerId:'a',displayName:'Alice',token:'x'}}))return;return new Response('',{status:400});},websocket:{open(ws){service.open(ws as any)},message(ws,m){service.message(ws as any,m as any)},close(ws){service.close(ws as any)}}});try{const ws=new WebSocket(`ws://127.0.0.1:${server.port}`);const result=await new Promise<any>((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('timeout')),2000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));ws.onmessage=e=>{clearTimeout(timer);resolve(JSON.parse(String(e.data)));};ws.onerror=()=>reject(Error('socket error'));});expect(result.type).toBe('welcome');ws.close();}finally{server.stop(true);}});

test('real websocket delivers handoff acknowledgement before close',async()=>{
 const service=createForestPresence(loadCatalog(),async()=>true);
 const server=Bun.serve({port:0,fetch(req,server){if(server.upgrade(req,{data:{kind:'forest',playerId:'handoff',displayName:'Test',token:'x'}}))return;return new Response('',{status:400});},websocket:{open(ws){service.open(ws as any)},message(ws,m){service.message(ws as any,m as any)},close(ws){service.close(ws as any)}}});
 try{const ws=new WebSocket(`ws://127.0.0.1:${server.port}`);const events:any[]=[];
  await new Promise<void>((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('handoff timeout')),3000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));ws.onmessage=e=>{const m=JSON.parse(String(e.data));events.push(m);if(m.type==='welcome')ws.send(JSON.stringify({v:1,type:'suspend'}));};ws.onclose=()=>{clearTimeout(timer);resolve();};ws.onerror=()=>reject(Error('socket error'));});
  expect(events.map(m=>m.type)).toEqual(['welcome','handoff_ack']);expect(events[1]).toEqual({v:1,type:'handoff_ack',kind:'suspend'});
 }finally{server.stop(true);}
});

test('handoff fallback closes only the old socket after replacement',async()=>{
 const service=createForestPresence(loadCatalog(),async()=>true);
 const server=Bun.serve({port:0,fetch(req,server){if(server.upgrade(req,{data:{kind:'forest',playerId:'same',displayName:'Test',token:'x'}}))return;return new Response('',{status:400});},websocket:{open(ws){service.open(ws as any)},message(ws,m){service.message(ws as any,m as any)},close(ws){service.close(ws as any)}}});
 const url=`ws://127.0.0.1:${server.port}`;let first:WebSocket|undefined,second:WebSocket|undefined;
 const enter=()=>new Promise<WebSocket>((ok,fail)=>{const ws=new WebSocket(url),timer=setTimeout(()=>fail(Error('welcome timeout')),3000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));ws.onmessage=e=>{if(JSON.parse(String(e.data)).type==='welcome'){clearTimeout(timer);ok(ws);}};ws.onerror=()=>fail(Error('socket error'));});
 try{first=await enter();await new Promise<void>((ok,fail)=>{const timer=setTimeout(()=>fail(Error('ack timeout')),3000);first!.onmessage=e=>{if(JSON.parse(String(e.data)).type==='handoff_ack'){clearTimeout(timer);ok();}};first!.send(JSON.stringify({v:1,type:'suspend'}));});second=await enter();await Bun.sleep(750);expect(second.readyState).toBe(WebSocket.OPEN);expect(first.readyState).toBe(WebSocket.CLOSED);let pong=false;second.onmessage=e=>{if(JSON.parse(String(e.data)).type==='pong')pong=true;};second.send(JSON.stringify({v:1,type:'ping'}));await Bun.sleep(100);expect(pong).toBe(true);
 }finally{first?.close();second?.close();server.stop(true);}
});

test('portal routing isolates peer snapshots and events',()=>{
 const h=harness(),a=h.connect('a'),b=h.connect('b');a.send({type:'enter',summoner_id:'wizard'});b.send({type:'enter',summoner_id:'wizard'});
 let seq=0; for(let y=710;y>=10;y-=50){h.advance(250);a.send({type:'move',seq:++seq,x:960,y,facing:2});}
 h.advance(20);a.send({type:'move',seq:++seq,x:960,y:5,facing:2});
 h.advance(20);a.send({type:'portal',seq:++seq,direction:'north',crossing_x:960,crossing_y:0});
 expect(a.events.at(-1)).toMatchObject({type:'zone',zone_id:'arcane_sanctuary',peers:[]});
 expect(h.service.roomOf('a')).toBe('arcane_sanctuary');expect(h.service.roomOf('b')).toBe('central_clearing');
 expect(b.events.at(-1)).toMatchObject({type:'peer_leave',player_id:'a'});
 b.events.length=0;h.advance(250);h.service.flush();expect(b.events).toEqual([]);a.send({type:'cosmetic',summoner_id:'witch'});a.send({type:'move',seq:++seq,x:960,y:870,facing:2});expect(b.events).toEqual([]);
 const c=h.connect('c');c.send({type:'enter',summoner_id:'witch'});expect(c.events[0].peers.map((p:any)=>p.player_id)).toEqual(['b']);
 a.events.length=0;b.events.length=0;c.events.length=0;
 h.service.peerChat('b',{id:1,player_id:'b',text:'hello',created_at:100000});
 expect(b.events.at(-1)).toMatchObject({type:'peer_chat',player_id:'b',message_id:1,text:'hello',expires_at:110000});
 expect(c.events.at(-1)).toMatchObject({type:'peer_chat',player_id:'b',message_id:1});expect(a.events).toEqual([]);
 b.send({type:'peer_chat',player_id:'a',text:'forged'});expect(b.events.at(-1)).toMatchObject({type:'error',error:'UNKNOWN_TYPE'});expect(c.events).toHaveLength(1);
 b.send({type:'suspend'});c.events.length=0;h.service.peerChat('b',{id:2,player_id:'b',text:'hidden',created_at:100000});expect(c.events).toEqual([]);
});
test('all ten directed portals follow the catalog',()=>{
 const h=harness(),a=h.connect('walker'),zones=loadCatalog();a.send({type:'enter',summoner_id:'wizard'});
 let zone='central_clearing',x=960,y=760,seq=0;
 const moveTo=(tx:number,ty:number)=>{const distance=Math.hypot(tx-x,ty-y),steps=Math.ceil(distance/40),ox=x,oy=y;for(let i=1;i<=steps;i++){h.advance(250);const nx=ox+(tx-ox)*i/steps,ny=oy+(ty-oy)*i/steps;a.send({type:'move',seq:++seq,x:nx,y:ny,facing:0});if(a.events.at(-1)?.type==='correction')throw Error(`${zone} ${nx},${ny}: ${a.events.at(-1).reason}`);x=nx;y=ny;}};
 for(const direction of ['north','south','west','north','south','east','east','west','south','north']){
  const z=zones.get(zone)!,p=z.portals.find(p=>p.direction===direction)!;expect(p).toBeDefined();moveTo(...z.spawn);
  const [l,t,r,b]=p.corridor;const bx=direction==='west'?0:direction==='east'?1920:(l+r)/2,by=direction==='north'?0:direction==='south'?1080:(t+b)/2;
  const ix=direction==='west'?10:direction==='east'?1910:bx,iy=direction==='north'?10:direction==='south'?1070:by;moveTo(ix,iy);
  h.advance(250);a.send({type:'portal',seq:++seq,direction,crossing_x:bx,crossing_y:by});expect(a.events.at(-1)).toMatchObject({type:'zone',zone_id:p.destination});zone=p.destination;[x,y]=p.arrival;
 }
});
test('resume expiry, leave, invalid frames and bounded burst',()=>{
 const h=harness(),players=Array.from({length:50},(_,i)=>h.connect('p'+i));for(const p of players)p.send({type:'enter',summoner_id:'wizard'});
 expect(players[49].events[0].peers).toHaveLength(49);const p=players[0];p.events.length=0;
 p.send({type:'move',seq:2147483648,x:960,y:760,facing:0});expect(p.events.at(-1).reason).toBe('INVALID_SEQ');
 p.send({type:'portal',seq:1,direction:'north',crossing_x:960,crossing_y:0});expect(p.events.at(-1).type).toBe('correction');
 p.send({type:'move',seq:2,x:1e100,y:760,facing:0});expect(p.events.at(-1).reason).toBe('INVALID_POSITION');
 p.send({type:'suspend'});h.advance(900001);const resumed=h.connect('p0');resumed.send({type:'enter',summoner_id:'wizard'});expect(resumed.events[0].self).toMatchObject({zone_id:'central_clearing',x:960,y:760});resumed.send({type:'leave'});
 const fresh=h.connect('p0');fresh.send({type:'enter',summoner_id:'wizard'});expect(fresh.events[0].self.x).toBe(960);
 for(let i=0;i<31;i++)fresh.send({type:'ping'});expect(players[1].events.at(-1)).toMatchObject({type:'peer_leave',player_id:'p0'});
});
import { Database } from 'bun:sqlite';
import { mkdtempSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createServer } from 'node:net';
import { createHash } from 'node:crypto';
import Redis from 'ioredis';
const redisBin = Bun.env.FOREST_TEST_REDIS_SERVER || Bun.which('redis-server');
async function freePort(){return await new Promise<number>((done,fail)=>{const p=createServer();p.once('error',fail);p.listen(0,'127.0.0.1',()=>{const n=(p.address() as any).port;p.close(()=>done(n));});});}
async function startRedis(){
 const port=await freePort();const proc=Bun.spawn([redisBin!, '--bind','127.0.0.1','--port',String(port),'--save','','--appendonly','no'],{stdout:'ignore',stderr:'ignore'});
 const client=new Redis(`redis://127.0.0.1:${port}`,{lazyConnect:true,retryStrategy:()=>null,connectTimeout:300});client.on('error',()=>{});
 let ready=false;for(let i=0;i<50;i++){try{if(client.status==='end')client.disconnect();await client.connect();ready=await client.ping()==='PONG';if(ready)break;}catch{}await Bun.sleep(100);}
 if(!ready){proc.kill();throw Error('isolated Redis failed to start');}return {port,proc,client};
}
test.skipIf(!redisBin)('production route rejects missing authorization, obsolete build, and invalid tokens before upgrade',async()=>{
 const redis=await startRedis();
 const dir=mkdtempSync(join(tmpdir(),'ew-forest-')),dbPath=join(dir,'test.sqlite'),db=new Database(dbPath),migrations=resolve(import.meta.dir,'../../migrations/sqlite');
 for(const file of readdirSync(migrations).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(migrations,file),'utf8'));db.close();
 const port=await new Promise<number>((done,fail)=>{const p=createServer();p.once('error',fail);p.listen(0,'127.0.0.1',()=>{const n=(p.address() as any).port;p.close(()=>done(n));});});
 const env={...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(port),DB_PATH:dbPath,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:`redis://127.0.0.1:${redis.port}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1',SESSION_IDLE_ENABLED:'1',SESSION_TTL_SECONDS:'3'};
 const server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env,stdout:'ignore',stderr:'ignore'});
 try{const base=`http://127.0.0.1:${port}`;let ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ready=true;break;}}catch{}await Bun.sleep(100);}expect(ready).toBe(true);
 const handshake=(headers:Record<string,string>)=>fetch(base+'/forest/ws',{headers:{Upgrade:'websocket',...headers}});
 expect((await handshake({})).status).toBe(426);expect((await handshake({'X-EntityWars-Client-Build':'999999'})).status).toBe(401);
 expect((await handshake({'X-EntityWars-Client-Build':'999999',Authorization:'Bearer invalid'})).status).toBe(401);
 expect((await handshake({'X-EntityWars-Client-Build':'999999','x-dev-token':'invalid'})).status).toBe(401);
 const registered=await fetch(base+'/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'ForestAlice',password:'secret1'})});expect(registered.status).toBe(200);const credentials:any=await registered.json();
 const ws=new WebSocket(`ws://127.0.0.1:${port}/forest/ws`,{headers:{Authorization:`Bearer ${credentials.token}`,'X-EntityWars-Client-Build':'999999'}} as any);
 const welcome:any=await new Promise((done,fail)=>{const timeout=setTimeout(()=>fail(Error('websocket timeout')),3000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard',display_name:'Forged'}));ws.onmessage=e=>{clearTimeout(timeout);done(JSON.parse(String(e.data)));};ws.onerror=()=>fail(Error('websocket failed'));});expect(welcome.self.display_name).toBe('ForestAlice');
 const bobRegister=await fetch(base+'/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'ForestBob',password:'secret1'})});const bob:any=await bobRegister.json();
 const waitLeave=new Promise<any>((done,fail)=>{const timeout=setTimeout(()=>fail(Error('peer leave timeout')),3000);ws.onmessage=e=>{const m=JSON.parse(String(e.data));if(m.type==='peer_leave'){clearTimeout(timeout);done(m);}};});
 const bobWs=new WebSocket(`ws://127.0.0.1:${port}/forest/ws`,{headers:{Authorization:`Bearer ${bob.token}`,'X-EntityWars-Client-Build':'999999'}} as any);
 const bobWelcome:any=await new Promise((done,fail)=>{const timeout=setTimeout(()=>fail(Error('bob timeout')),3000);bobWs.onopen=()=>bobWs.send(JSON.stringify({v:1,type:'enter',summoner_id:'witch'}));bobWs.onmessage=e=>{clearTimeout(timeout);done(JSON.parse(String(e.data)));};bobWs.onerror=()=>fail(Error('bob socket failed'));});
 const loggedOut=await fetch(base+'/auth/logout',{method:'POST',headers:{Authorization:`Bearer ${bob.token}`}});expect(loggedOut.status).toBe(200);expect(await waitLeave).toMatchObject({type:'peer_leave',player_id:bobWelcome.self.player_id});
 expect((await handshake({'X-EntityWars-Client-Build':'999999',Authorization:`Bearer ${bob.token}`})).status).toBe(401);
 const idleReg=await fetch(base+'/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'ForestIdle',password:'secret1'})});const idle:any=await idleReg.json();
 await redis.client.del('idle:'+createHash('sha256').update(idle.token).digest('hex'));
 expect((await handshake({'X-EntityWars-Client-Build':'999999',Authorization:`Bearer ${idle.token}`})).status).toBe(409);
 await Bun.sleep(3200);expect((await handshake({'X-EntityWars-Client-Build':'999999',Authorization:`Bearer ${credentials.token}`})).status).toBe(401);
 bobWs.close();ws.close();

 }finally{server.kill();await server.exited;redis.client.disconnect();redis.proc.kill();await redis.proc.exited;for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch(e){if(i>=20)throw e;await Bun.sleep(250);}}}
},60000);
test('rapid moves update authoritative state while broadcasts coalesce',()=>{
 const h=harness(),a=h.connect('a'),b=h.connect('b');a.send({type:'enter',summoner_id:'wizard'});b.send({type:'enter',summoner_id:'witch'});b.events.length=0;
 h.advance(200);a.send({type:'move',seq:1,x:970,y:760,facing:1});
 h.advance(90);a.send({type:'move',seq:2,x:980,y:770,facing:0});
 h.advance(90);a.send({type:'move',seq:3,x:990,y:780,facing:1});
 expect(b.events.filter((e:any)=>e.type==='peer_move').map((e:any)=>e.seq)).toEqual([1]);
 a.send({type:'move',seq:4,x:1900,y:780,facing:1});expect(a.events.at(-1)).toMatchObject({type:'correction',x:990,y:780});
 h.advance(19);h.service.flush();expect(b.events.filter((e:any)=>e.type==='peer_move')).toHaveLength(1);
 h.advance(1);h.service.flush();expect(b.events.at(-1)).toMatchObject({type:'peer_move',seq:3,x:990,y:780,facing:1});
 h.service.evict('a');expect(b.events.at(-1)).toMatchObject({type:'peer_leave',player_id:'a'});const again=h.connect('a');again.send({type:'enter',summoner_id:'wizard'});expect(again.events[0].self.x).toBe(960);
 h.advance(250);again.send({type:'move',seq:1,x:970,y:760,facing:1});again.send({type:'suspend'});h.service.evict('a');const cleared=h.connect('a');cleared.send({type:'enter',summoner_id:'wizard'});expect(cleared.events[0].self.x).toBe(960);
});
test('fifty players retain the latest coalesced movement',()=>{
 const h=harness(),players=Array.from({length:50},(_,i)=>h.connect('burst'+i));for(const p of players)p.send({type:'enter',summoner_id:'wizard'});for(const p of players)p.events.length=0;
 h.advance(250);for(const p of players)p.send({type:'move',seq:1,x:965,y:760,facing:1});
 h.advance(50);for(const p of players)p.send({type:'move',seq:2,x:970,y:760,facing:1});
 h.advance(150);h.service.flush();for(const p of players){const moves=p.events.filter((e:any)=>e.type==='peer_move');expect(moves).toHaveLength(98);expect(moves.filter((e:any)=>e.seq===2)).toHaveLength(49);}
});
test.skipIf(!redisBin)('Redis lease excludes other API processes, renews, recovers after crash and fences mismatch',async()=>{
 const redis=await startRedis(),dir=mkdtempSync(join(tmpdir(),'ew-forest-lease-')),dbPath=join(dir,'test.sqlite'),db=new Database(dbPath),migrations=resolve(import.meta.dir,'../../migrations/sqlite');
 for(const f of readdirSync(migrations).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(migrations,f),'utf8'));db.close();
 const children:any[]=[];const envBase={...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',DB_PATH:dbPath,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:`redis://127.0.0.1:${redis.port}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1'};
 async function start(enabled='1'){const port=await freePort();const child=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env:{...envBase,PORT:String(port),FOREST_WS_ENABLED:enabled},stdout:'ignore',stderr:'ignore'});children.push(child);return {child,base:`http://127.0.0.1:${port}`};}
 async function ready(base:string){for(let i=0;i<80;i++){try{if((await fetch(base+'/health')).ok)return true;}catch{}await Bun.sleep(100);}return false;}
 try{
  const owner=await start();expect(await ready(owner.base)).toBe(true);const key='lock:forest:presence:leader',token=await redis.client.get(key);expect(token).toBeTruthy();
  const blocked=await start();expect(await blocked.child.exited).not.toBe(0);expect(await redis.client.get(key)).toBe(token);
  await Bun.sleep(5100);expect(await redis.client.get(key)).toBe(token);expect(await redis.client.pttl(key)).toBeGreaterThan(10000);
  owner.child.kill('SIGKILL');await owner.child.exited;const retained=await redis.client.pttl(key);expect(retained).toBeGreaterThan(0);
  const tooEarly=await start();expect(await tooEarly.child.exited).not.toBe(0);
  await Bun.sleep(retained+300);const replacement=await start();expect(await ready(replacement.base)).toBe(true);expect(await redis.client.get(key)).not.toBe(token);
  const reg=await fetch(replacement.base+'/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'LeaseUser',password:'secret1'})});const credentials:any=await reg.json();
  const socket=new WebSocket(replacement.base.replace('http:','ws:')+'/forest/ws',{headers:{Authorization:`Bearer ${credentials.token}`,'X-EntityWars-Client-Build':'999999'}} as any);
  await new Promise<void>((done,fail)=>{socket.onopen=()=>{socket.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));};socket.onmessage=()=>done();socket.onerror=()=>fail(Error('socket failed'));});
  const closed=new Promise<void>(done=>{socket.onclose=()=>done();});
  await redis.client.set(key,'wrong-owner','PX',15000);expect(await Promise.race([replacement.child.exited,Bun.sleep(7000).then(()=>null)])).toBe(1);await Promise.race([closed,Bun.sleep(1000).then(()=>{throw Error('forest socket not closed');})]);expect(await redis.client.get(key)).toBe('wrong-owner');
  await redis.client.del(key);const delayed=await start();expect(await ready(delayed.base)).toBe(true);
  await redis.client.call('CLIENT','PAUSE','7000');expect(await Promise.race([delayed.child.exited,Bun.sleep(6500).then(()=>null)])).toBe(1);
  await Bun.sleep(1100);await redis.client.del(key);const live=await start();expect(await ready(live.base)).toBe(true);
  redis.client.disconnect();redis.proc.kill();await redis.proc.exited;
  expect(await Promise.race([live.child.exited,Bun.sleep(7000).then(()=>null)])).toBe(1);
  const unavailable=await start();expect(await unavailable.child.exited).not.toBe(0);
  const disabled=await start('0');expect(await ready(disabled.base)).toBe(true);expect((await fetch(disabled.base+'/forest/ws',{headers:{Upgrade:'websocket'}})).status).toBe(404);
 }finally{for(const child of children){if(child.exitCode===null){child.kill();await child.exited;}}redis.client.disconnect();if(redis.proc.exitCode===null){redis.proc.kill();await redis.proc.exited;}for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch(e){if(i>=20)throw e;await Bun.sleep(250);}}}
},60000);
test.skipIf(!redisBin)('handshake limits trust only the configured proxy and retain per-client buckets',async()=>{
 const redis=await startRedis(),dir=mkdtempSync(join(tmpdir(),'ew-forest-proxy-')),dbPath=join(dir,'test.sqlite'),db=new Database(dbPath),migrations=resolve(import.meta.dir,'../../migrations/sqlite');
 for(const f of readdirSync(migrations).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(migrations,f),'utf8'));db.close();const children:any[]=[];
 async function start(proxy:string){const port=await freePort();const child=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env:{...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(port),DB_PATH:dbPath,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:`redis://127.0.0.1:${redis.port}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1',FOREST_WS_TRUSTED_PROXY:proxy},stdout:'ignore',stderr:'ignore'});children.push(child);const base=`http://127.0.0.1:${port}`;let ok=false;for(let i=0;i<80;i++){try{if((await fetch(base+'/health')).ok){ok=true;break;}}catch{}await Bun.sleep(100);}expect(ok).toBe(true);return {child,base};}
 async function hit(base:string,ip:string){return (await fetch(base+'/forest/ws',{headers:{upgrade:'websocket','x-real-ip':ip,'x-forwarded-for':ip}})).status;}
 try{
  const proxy=await start('127.0.0.1');for(let i=0;i<120;i++)expect(await hit(proxy.base,'198.51.100.1')).toBe(426);expect(await hit(proxy.base,'198.51.100.1')).toBe(429);expect(await hit(proxy.base,'198.51.100.2')).toBe(426);
  proxy.child.kill();await proxy.child.exited;await redis.client.del('lock:forest:presence:leader');
  const direct=await start('127.0.0.2');for(let i=0;i<120;i++)expect(await hit(direct.base,`198.51.100.${i%250+1}`)).toBe(426);expect(await hit(direct.base,'203.0.113.1')).toBe(429);
 }finally{for(const child of children)if(child.exitCode===null){child.kill();await child.exited;}redis.client.disconnect();redis.proc.kill();await redis.proc.exited;for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch(e){if(i>=20)throw e;await Bun.sleep(250);}}}
},60000);
test.skipIf(!redisBin)('v1 logout evicts active and suspended forest state with access or refresh tokens',async()=>{
 const redis=await startRedis(),dir=mkdtempSync(join(tmpdir(),'ew-forest-v1-')),dbPath=join(dir,'test.sqlite'),db=new Database(dbPath),migrations=resolve(import.meta.dir,'../../migrations/sqlite');
 for(const f of readdirSync(migrations).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(migrations,f),'utf8'));db.close();
 const port=await freePort(),base=`http://127.0.0.1:${port}`,server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env:{...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(port),DB_PATH:dbPath,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',PG_CONNECT_TIMEOUT_SECONDS:'1',REDIS_URL:`redis://127.0.0.1:${redis.port}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1'},stdout:'ignore',stderr:'ignore'});
 const post=(path:string,data:any,token?:string)=>fetch(base+path,{method:'POST',headers:{'content-type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(data)});
 async function login(name:string){const r=await post('/v1/auth/login',{name});expect(r.status).toBe(200);return await r.json() as any;}
 async function joinForest(token:string){const ws=new WebSocket(`ws://127.0.0.1:${port}/forest/ws`,{headers:{Authorization:`Bearer ${token}`,'X-EntityWars-Client-Build':'999999'}} as any);const events:any[]=[];const welcome=await new Promise<any>((done,fail)=>{ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));ws.onmessage=e=>{const m=JSON.parse(String(e.data));events.push(m);if(m.type==='welcome')done(m);};ws.onerror=()=>fail(Error('socket failed'));});return {ws,welcome,events};}
 try{let ok=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ok=true;break;}}catch{}await Bun.sleep(100);}expect(ok).toBe(true);
  const alice=await login('V1Observer'), observer=await joinForest(alice.access_token);let bob=await login('V1ForestBob'), live=await joinForest(bob.access_token);
  expect((await post('/v1/auth/logout',{refresh_token:bob.refresh_token},alice.access_token)).status).toBe(200);await Bun.sleep(150);expect(observer.events.filter((m:any)=>m.type==='peer_leave')).toHaveLength(0);
  const left=new Promise<void>((done,fail)=>{const timeout=setTimeout(()=>fail(Error('logout did not broadcast leave')),3000);observer.ws.onmessage=e=>{const m=JSON.parse(String(e.data));if(m.type==='peer_leave'&&m.player_id===live.welcome.self.player_id){clearTimeout(timeout);done();}};});
  expect((await post('/v1/auth/logout',{},bob.access_token)).status).toBe(200);await left;
  bob=await login('V1ForestBob');live=await joinForest(bob.access_token);await Bun.sleep(300);live.ws.send(JSON.stringify({v:1,type:'move',seq:1,x:980,y:760,facing:1}));await Bun.sleep(100);
  live.ws.send(JSON.stringify({v:1,type:'suspend'}));await new Promise<void>(done=>{live.ws.onclose=()=>done();});
  expect((await post('/v1/auth/logout',{refresh_token:bob.refresh_token,player_id:observer.welcome.self.player_id})).status).toBe(200);expect(observer.ws.readyState).toBe(WebSocket.OPEN);
  bob=await login('V1ForestBob');live=await joinForest(bob.access_token);expect(live.welcome.self).toMatchObject({zone_id:'central_clearing',x:960,y:760});
  observer.ws.close();live.ws.close();
 }finally{server.kill();await server.exited;redis.client.disconnect();redis.proc.kill();await redis.proc.exited;for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch(e){if(i>=20)throw e;await Bun.sleep(250);}}}
},60000);
