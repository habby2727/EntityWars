import {test, expect} from 'bun:test';
import {loadCatalog, validateCatalog, segmentInside, createForestPresence} from '../forest/presence';
import {readFileSync} from 'node:fs';
function harness(){let now=100000, valid=true;const service=createForestPresence(loadCatalog(),async()=>valid,()=>now);const connect=(id:string)=>{const events:any[]=[];const ws:any={data:{kind:'forest',playerId:id,displayName:'Name '+id,token:'secret'},send(s:string){events.push(JSON.parse(s));return 1;},close(){},getBufferedAmount(){return 0;}};service.open(ws);return {ws,events,send(m:any){service.message(ws,JSON.stringify({v:1,...m}));}}};return {service,connect,advance(ms:number){now+=ms},revoke(){valid=false}};}
test('catalog and concave segment validation',()=>{const c=JSON.parse(readFileSync(new URL('../../../data/static/forest_zones.json',import.meta.url),'utf8'));const zones=validateCatalog(c);expect(zones.size).toBe(6);expect([...zones.values()].flatMap(z=>z.portals)).toHaveLength(10);expect(segmentInside([1,3],[3,3],[[0,0],[4,0],[4,4],[2,2],[0,4]])).toBe(false);c.zones[0].portals[0].arrival=[-1,-1];expect(()=>validateCatalog(c)).toThrow();});
test('identity, movement, replacement, suspend and revocation',async()=>{const h=harness(),a=h.connect('a'),b=h.connect('b');a.send({type:'enter',summoner_id:'wizard',player_id:'fake',display_name:'fake'});b.send({type:'enter',summoner_id:'witch'});expect(b.events[0].peers[0]).toMatchObject({player_id:'a',display_name:'Name a'});a.events.length=0;b.events.length=0;h.advance(1000);a.send({type:'move',seq:1,x:980,y:760,facing:1});expect(b.events[0]).toMatchObject({type:'peer_move',x:980});a.send({type:'move',seq:1,x:981,y:760,facing:1});expect(a.events.at(-1).reason).toBe('INVALID_SEQ');a.send({type:'move',seq:2,x:1900,y:760,facing:1});expect(a.events.at(-1).reason).toBe('INVALID_MOVEMENT');a.send({type:'suspend'});expect(b.events.at(-1).type).toBe('peer_leave');const a2=h.connect('a');a2.send({type:'enter',summoner_id:'wizard'});expect(a2.events[0].self.x).toBe(980);const a3=h.connect('a');a3.send({type:'enter',summoner_id:'wizard'});expect(a3.events[0].self.x).toBe(980);h.revoke();await h.service.sweep();const fresh=h.connect('a');fresh.send({type:'enter',summoner_id:'wizard'});expect(fresh.events[0].self.x).toBe(960);});
test('real Bun websocket sends welcome',async()=>{const service=createForestPresence(loadCatalog(),async()=>true);const server=Bun.serve({port:0,fetch(req,server){if(server.upgrade(req,{data:{kind:'forest',playerId:'a',displayName:'Alice',token:'x'}}))return;return new Response('',{status:400});},websocket:{open(ws){service.open(ws as any)},message(ws,m){service.message(ws as any,m as any)},close(ws){service.close(ws as any)}}});try{const ws=new WebSocket(`ws://127.0.0.1:${server.port}`);const result=await new Promise<any>((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('timeout')),2000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard'}));ws.onmessage=e=>{clearTimeout(timer);resolve(JSON.parse(String(e.data)));};ws.onerror=()=>reject(Error('socket error'));});expect(result.type).toBe('welcome');ws.close();}finally{server.stop(true);}});

test('portal routing isolates peer snapshots and events',()=>{
 const h=harness(),a=h.connect('a'),b=h.connect('b');a.send({type:'enter',summoner_id:'wizard'});b.send({type:'enter',summoner_id:'wizard'});
 let seq=0; for(let y=710;y>=10;y-=50){h.advance(250);a.send({type:'move',seq:++seq,x:960,y,facing:2});}
 h.advance(250);a.send({type:'portal',seq:++seq,direction:'north',crossing_x:960,crossing_y:0});
 expect(a.events.at(-1)).toMatchObject({type:'zone',zone_id:'arcane_sanctuary',peers:[]});
 expect(b.events.at(-1)).toMatchObject({type:'peer_leave',player_id:'a'});
 b.events.length=0;h.advance(250);a.send({type:'cosmetic',summoner_id:'witch'});a.send({type:'move',seq:++seq,x:960,y:870,facing:2});expect(b.events).toEqual([]);
 const c=h.connect('c');c.send({type:'enter',summoner_id:'witch'});expect(c.events[0].peers.map((p:any)=>p.player_id)).toEqual(['b']);
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
test('production route rejects missing authorization, obsolete build, and invalid tokens before upgrade',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'ew-forest-')),dbPath=join(dir,'test.sqlite'),db=new Database(dbPath),migrations=resolve(import.meta.dir,'../../migrations/sqlite');
 for(const file of readdirSync(migrations).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(migrations,file),'utf8'));db.close();
 const port=await new Promise<number>((done,fail)=>{const p=createServer();p.once('error',fail);p.listen(0,'127.0.0.1',()=>{const n=(p.address() as any).port;p.close(()=>done(n));});});
 const env={...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(port),DB_PATH:dbPath,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:'redis://127.0.0.1:1',AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1',FOREST_WS_SINGLE_INSTANCE:'1'};
 const server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:resolve(import.meta.dir,'../..'),env,stdout:'ignore',stderr:'ignore'});
 try{const base=`http://127.0.0.1:${port}`;let ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ready=true;break;}}catch{}await Bun.sleep(100);}expect(ready).toBe(true);
 const handshake=(headers:Record<string,string>)=>fetch(base+'/forest/ws',{headers:{Upgrade:'websocket',...headers}});
 expect((await handshake({})).status).toBe(426);expect((await handshake({'X-EntityWars-Client-Build':'999999'})).status).toBe(401);
 expect((await handshake({'X-EntityWars-Client-Build':'999999',Authorization:'Bearer invalid'})).status).toBe(401);
 expect((await handshake({'X-EntityWars-Client-Build':'999999','x-dev-token':'invalid'})).status).toBe(401);
 const registered=await fetch(base+'/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'ForestAlice',password:'secret1'})});expect(registered.status).toBe(200);const credentials:any=await registered.json();
 const ws=new WebSocket(`ws://127.0.0.1:${port}/forest/ws`,{headers:{Authorization:`Bearer ${credentials.token}`,'X-EntityWars-Client-Build':'999999'}} as any);
 const welcome:any=await new Promise((done,fail)=>{const timeout=setTimeout(()=>fail(Error('websocket timeout')),3000);ws.onopen=()=>ws.send(JSON.stringify({v:1,type:'enter',summoner_id:'wizard',display_name:'Forged'}));ws.onmessage=e=>{clearTimeout(timeout);done(JSON.parse(String(e.data)));};ws.onerror=()=>fail(Error('websocket failed'));});expect(welcome.self.display_name).toBe('ForestAlice');ws.close();

 }finally{server.kill();await server.exited;for(let i=0;;i++){try{rmSync(dir,{recursive:true,force:true});break;}catch(e){if(i>=20)throw e;await Bun.sleep(250);}}}
},60000);
