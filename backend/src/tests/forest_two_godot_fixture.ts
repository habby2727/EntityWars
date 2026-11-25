import {Database} from 'bun:sqlite';
import {mkdtempSync,readdirSync,rmSync,readFileSync,mkdirSync,writeFileSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {createServer} from 'node:net';
import {randomUUID,createHash} from 'node:crypto';
import Redis from 'ioredis';
import assert from 'node:assert/strict';
import {applyDeployment, type MatchState} from '../woe/engine';
import {cardById} from '../woe/catalog';

async function port():Promise<number>{return new Promise((ok,fail)=>{const s=createServer();s.on('error',fail);s.listen(0,'127.0.0.1',()=>{const p=(s.address() as any).port;s.close(()=>ok(p));});});}
const backend=resolve(import.meta.dir,'../..'),root=resolve(backend,'..'),dir=mkdtempSync(join(tmpdir(),'forest-two-')),dbPath=join(dir,'db.sqlite'),db=new Database(dbPath),now=Date.now();
const tokenLifetime=process.env.FOREST_WOE_TIMEOUT_TEST==='1'?600000:120000;
const records=Array.from({length:3},(_,i)=>({id:randomUUID(),token:randomUUID(),name:`TwoGodot${i}`}));
for(const f of readdirSync(join(backend,'migrations/sqlite')).filter(f=>f.endsWith('.sql')).sort()) db.exec(readFileSync(join(backend,'migrations/sqlite',f),'utf8'));
const insert=db.prepare('INSERT INTO players (player_id,display_name,state_json,updated_at) VALUES (?,?,?,?)');for(const r of records) insert.run(r.id,r.name,'{}',now);if(process.env.FOREST_CD_TEST==='1'||process.env.FOREST_WOE_INVITE_TEST==='1'){const ids=[records[0].id,records[1].id].sort();db.query('INSERT INTO friendships VALUES (?,?,?)').run(ids[0],ids[1],now)}db.close();
const rp=await port(),ap=await port(),base=`http://127.0.0.1:${ap}`,redisBin=Bun.env.FOREST_TEST_REDIS_SERVER||Bun.which('redis-server');assert(redisBin,'redis-server required');
const redisProc=Bun.spawn([redisBin,'--bind','127.0.0.1','--port',String(rp),'--save','','--appendonly','no'],{stdout:'ignore',stderr:'ignore'});
const redis=new Redis(`redis://127.0.0.1:${rp}`,{lazyConnect:true,retryStrategy:()=>null});redis.on('error',()=>{});
let server:any,third:WebSocket|undefined,success=false;const godots:{log:string;proc:ReturnType<typeof Bun.spawn>}[]=[];
const serverLog=join(dir,'server.log'),serverErr=join(dir,'server-error.log');
const scrub=(value:string)=>{for(const r of records){value=value.split(r.token).join('[REDACTED]');value=value.split(createHash('sha256').update(r.token).digest('hex')).join('[REDACTED]');}return value;};
try {
 let ready=false;for(let i=0;i<50;i++){try{await redis.connect();ready=true;break}catch{await Bun.sleep(100)}}assert(ready,'Redis startup failed');
 const pipe=redis.pipeline();for(const r of records){const h=createHash('sha256').update(r.token).digest('hex');pipe.set(`access:${r.token}`,JSON.stringify({userId:r.id,createdAt:now,expiresAt:now+tokenLifetime}),'PX',tokenLifetime);pipe.set(`idle:${h}`,'1','EX',10800);pipe.set(`idle-initialized:${h}`,'1','PX',tokenLifetime);}await pipe.exec();
 server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:backend,env:{...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(ap),DB_PATH:dbPath,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:`redis://127.0.0.1:${rp}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1',FOREST_WOE_ENABLED:process.env.FOREST_WOE_TEST==='1'?'1':'0',FOREST_CORE_DEFENSE_ENABLED:process.env.FOREST_CD_TEST==='1'?'1':'0',SOCIAL_ENABLED:process.env.FOREST_CD_TEST==='1'||process.env.FOREST_WOE_INVITE_TEST==='1'?'1':'0',FOREST_DUELS_ENABLED:process.env.FOREST_DUEL_TEST==='1'?'1':'0',PVP_ENABLED:'0',PVP_RNG_SECRET:'friendly-fixture-secret-at-least-32-bytes',SESSION_IDLE_ENABLED:'1'},stdout:Bun.file(serverLog),stderr:Bun.file(serverErr)});
 ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ready=true;break}}catch{}await Bun.sleep(100)}assert(ready,'API startup failed');
 third=new WebSocket(base.replace('http:','ws:')+'/forest/ws',{headers:{Authorization:`Bearer ${records[2].token}`,'X-EntityWars-Client-Build':'5510'}} as any);
 await new Promise<void>((ok,fail)=>{const t=setTimeout(()=>fail(Error('third peer welcome timeout')),5000);third!.onopen=()=>third!.send(JSON.stringify({v:1,type:'enter',summoner_id:'cyberghost'}));third!.onmessage=e=>{if(JSON.parse(String(e.data)).type==='welcome'){clearTimeout(t);ok();}};third!.onerror=()=>fail(Error('third peer socket error'));third!.onclose=e=>{if(e.code!==1000)fail(Error(`third peer closed: ${e.code} ${e.reason}`));};});
 const exe=Bun.env.GODOT_BIN||join(Bun.env.USERPROFILE||'','Desktop','Godot_v4.6.exe');
 for(let i=0;i<2;i++){
  const log=join(dir,`godot${i}.log`),profile=join(dir,`profile${i}`);mkdirSync(profile,{recursive:true});
  const env={...process.env,APPDATA:profile,XDG_DATA_HOME:profile,FOREST_TEST_PROFILE:profile,FOREST_SMOKE_URL:'',FOREST_FAULT_URL:'',FOREST_TWO_URL:base,FOREST_TWO_ID:records[i].id,FOREST_TWO_TOKEN:records[i].token,FOREST_TWO_OTHER:records[1-i].id,FOREST_TWO_THIRD:records[2].id,FOREST_DUEL_ROLE:String(i),FOREST_WOE_SYNC:dir,FOREST_WOE_TIMEOUT_TEST:process.env.FOREST_WOE_TIMEOUT_TEST||'0',FOREST_WOE_LAB_TEST:process.env.FOREST_WOE_LAB_TEST||'0'};
  godots.push({log,proc:Bun.spawn([exe,'--headless',...(process.env.FOREST_GODOT_VERBOSE==='1'?['--verbose']:[]),'--path',root,'--log-file',log,'--script',process.env.FOREST_CD_TEST==='1'?'res://scripts/tests/smoke_core_defense_forest_e2e.gd':process.env.FOREST_WOE_TEST==='1'?'res://scripts/tests/smoke_woe_forest_e2e.gd':process.env.FOREST_DUEL_TEST==='1'?'res://scripts/tests/smoke_friendly_http.gd':'res://scripts/tests/smoke_forest_multiplayer.gd'],{cwd:root,env,stdout:'ignore',stderr:'ignore'})});
 }
 const injectLab=async()=>{
  if(process.env.FOREST_WOE_LAB_TEST!=='1')return;
  const hostFile=join(dir,'arena_0'),guestFile=join(dir,'arena_1');const deadline=Date.now()+60000;
  while((!existsSync(hostFile)||!existsSync(guestFile))&&Date.now()<deadline)await Bun.sleep(50);
  assert(existsSync(hostFile)&&existsSync(guestFile),'arena synchronization timed out');
  const id=readFileSync(hostFile,'utf8');assert.equal(id,readFileSync(guestFile,'utf8'));
  const fixtureDb=new Database(dbPath);fixtureDb.exec('PRAGMA busy_timeout=5000');
  try {fixtureDb.transaction(()=>{
   const row=fixtureDb.query('SELECT state_json FROM woe_matches WHERE match_id=? AND status=\'RUNNING\'').get(id) as any;assert(row,'running WOE match');
   const state=JSON.parse(row.state_json) as MatchState;state.laboratories.find(l=>l.id==='red:left')!.hp=0;state.laboratories.find(l=>l.id==='red:right')!.hp=1;
   const blue=state.controllers.find(c=>c.team==='blue')!;blue.zealTenths=100;
   const slot=blue.slots.findIndex(id=>!!cardById[id]);assert(slot>=0);
   const deployed=applyDeployment(state,{actionId:'fixture-lab',controllerId:blue.id,slot,cardId:blue.slots[slot],lane:'left'});assert(deployed.accepted);
   const next=deployed.state,unit=next.units.at(-1)!;unit.position={...next.laboratories.find(l=>l.id==='red:right')!.position};unit.targetLane='right';unit.cooldown=0;
   fixtureDb.query('UPDATE woe_matches SET state_json=? WHERE match_id=?').run(JSON.stringify(next),id);
  }).immediate()} finally {fixtureDb.close()}
 };
 const injectPotion=async()=>{
  if(process.env.FOREST_POTION_TEST!=='1')return;
  const prefix=process.env.FOREST_CD_TEST==='1'?'cd_arena_':'arena_';const a=join(dir,prefix+'0'),b=join(dir,prefix+'1'),deadline=Date.now()+60000;
  while((!existsSync(a)||!existsSync(b))&&Date.now()<deadline)await Bun.sleep(50);
  assert(existsSync(a)&&existsSync(b),'potion arena synchronization timed out');
  const id=readFileSync(a,'utf8');assert.equal(id,readFileSync(b,'utf8'));
  const fixtureDb=new Database(dbPath);fixtureDb.exec('PRAGMA busy_timeout=5000');
  try {fixtureDb.transaction(()=>{
   const row=fixtureDb.query("SELECT state_json FROM woe_matches WHERE match_id=? AND status='RUNNING'").get(id) as any;assert(row);
   const s=JSON.parse(row.state_json),p=s.controllers.find((c:any)=>c.id===records[0].id);assert(p);
   let slot=p.slots.indexOf('thunderlock');if(slot>=0)[p.slots[slot],p.slots[3]]=[p.slots[3],p.slots[slot]];
   else {slot=p.queue.indexOf('thunderlock');assert(slot>=0);[p.queue[slot],p.slots[3]]=[p.slots[3],p.queue[slot]];}
   p.zealTenths=100;fixtureDb.query('UPDATE woe_matches SET state_json=?,revision=revision+1 WHERE match_id=?').run(JSON.stringify(s),id);
  }).immediate()} finally {fixtureDb.close()}
  writeFileSync(join(dir,'potion_ready'),'ok');
 };
 // Test-only acceleration: edit only this fixture's temporary database. The real
 // scheduler produces the wave-complete, intermission, next-wave and defeat events.
 const accelerateCoreDefense=async()=>{
  if(process.env.FOREST_CD_TEST!=='1')return;
  const wait=async(name:string)=>{const deadline=Date.now()+60000;while(!existsSync(join(dir,name))&&Date.now()<deadline)await Bun.sleep(50);assert(existsSync(join(dir,name)),`CD fixture synchronization: ${name}`)};
  await wait('cd_deployed');await wait('cd_both_deployed');await wait('cd_arena_0');
  const id=readFileSync(join(dir,'cd_arena_0'),'utf8');
  const fixtureDb=new Database(dbPath);fixtureDb.exec('PRAGMA busy_timeout=5000');
  const edit=(fn:(state:any)=>void)=>fixtureDb.transaction(()=>{const row=fixtureDb.query("SELECT state_json FROM woe_matches WHERE match_id=? AND status='RUNNING'").get(id) as any;assert(row,'running CD fixture match');const state=JSON.parse(row.state_json);fn(state);fixtureDb.query('UPDATE woe_matches SET state_json=? WHERE match_id=?').run(JSON.stringify(state),id)}).immediate();
  try {
   edit(s=>{s.pendingSpawns=0;s.units=s.units.filter((u:any)=>u.kind!=='enemy')});
   await wait('cd_wave2_0');await wait('cd_wave2_1');
   // Move a live wave-two enemy to the last damaged laboratory; gameplay performs the kill.
   let deadline=Date.now()+10000,found=false;
   while(!found && Date.now()<deadline){
    const row=fixtureDb.query('SELECT state_json FROM woe_matches WHERE match_id=?').get(id) as any;
    found=JSON.parse(row.state_json).units.some((u:any)=>u.kind==='enemy');if(!found)await Bun.sleep(50);
   }
   assert(found,'wave-two enemy spawned');
   edit(s=>{const enemy=s.units.find((u:any)=>u.kind==='enemy');const labs=s.laboratories.filter((l:any)=>l.team==='blue');labs[0].hp=0;labs[1].hp=1;enemy.targetLane=labs[1].lane;enemy.position={...labs[1].position};enemy.cooldown=0;s.units=[enemy]});
  } finally {fixtureDb.close()}
 };
 let timer:any;const exits=await Promise.race([Promise.all([injectLab(),accelerateCoreDefense(),injectPotion(),...godots.map(g=>g.proc.exited)]).then(x=>x.slice(3)),new Promise<never>((_,fail)=>{timer=setTimeout(()=>fail(Error('overall client timeout; inspect last phase in retained logs')),process.env.FOREST_WOE_TIMEOUT_TEST==='1'||process.env.FOREST_WOE_CYCLES==='1'?360000:(process.env.FOREST_WOE_TEST==='1'||process.env.FOREST_CD_TEST==='1')?120000:60000);})]);clearTimeout(timer);
 const logs=godots.map(g=>scrub(readFileSync(g.log,'utf8')));for(const log of logs)console.log(log);assert.deepEqual(exits,[0,0]);
 if(process.env.FOREST_POTION_TEST==='1')assert(existsSync(join(dir,'potion_cast_0')),'authenticated potion cast not acknowledged');
 if(process.env.FOREST_WOE_TEST==='1'){assert(logs.every(log=>!log.includes('ERROR:')&&!log.includes('SCRIPT ERROR:')), 'Godot WOE client logged an error');const ids=logs.map(log=>/WOE_FOREST_E2E_PASS ([0-9a-f-]+)/.exec(log)?.[1]);assert(ids[0] && ids[0]===ids[1], 'WOE clients received different matches');}
 if(process.env.FOREST_WOE_TIMEOUT_TEST==='1'){
  const matchId=readFileSync(join(dir,'arena_0'),'utf8'), timingDb=new Database(dbPath,{readonly:true});
  try {const row=timingDb.query('SELECT created_at,finished_at,state_json FROM woe_matches WHERE match_id=?').get(matchId) as any;const state=JSON.parse(row.state_json);console.log(`WOE_TIMEOUT_TIMING wall_ms=${row.finished_at-row.created_at} tick=${state.tick} result=${JSON.stringify(state.result)}`)} finally {timingDb.close()}
 }
 if(process.env.FOREST_CD_TEST==='1'){assert(logs.every(log=>!log.includes('ERROR:')&&!log.includes('SCRIPT ERROR:')), 'Godot Core Defense client logged an error');const ids=logs.map(log=>/CORE_DEFENSE_FOREST_E2E_PASS ([0-9a-f-]+)/.exec(log)?.[1]);assert(ids[0] && ids[0]===ids[1], 'Core Defense clients received different matches');}
 if(process.env.FOREST_CD_TEST==='1'){
  const path='/forest/core-defense/leaderboard',headers={Authorization:`Bearer ${records[0].token}`,'X-EntityWars-Client-Build':'5510'};
  assert.equal((await fetch(base+path+'?mode=solo&month=current')).status,401);
  for(const q of ['mode=bad&month=current','mode=solo&mode=coop&month=current','mode=solo&month=current&extra=x']) assert.equal((await fetch(base+path+'?'+q,{headers})).status,400);
  for(const mode of ['solo','coop']){const res=await fetch(base+path+`?mode=${mode}&month=current`,{headers});assert.equal(res.status,200);const data=await res.json() as any;assert.equal(data.mode,mode);assert.equal(data.viewed_month,data.current_month);if(mode==='coop')assert(data.entries.some((e:any)=>e.display_name===records[0].name&&e.completed_waves>=1),'authoritative coop score');}
  const previous=await (await fetch(base+path+'?mode=coop&month=previous',{headers})).json() as any;assert.equal(previous.viewed_month,previous.previous_month);
  console.log('Authenticated leaderboard HTTP: unauthorized, invalid and duplicate filters, solo/coop and injected-fixture terminal score passed');
 }
 if(process.env.FOREST_WOE_TEST==='1'){
  const response=await fetch(base+'/forest/core-defense/leaderboard?mode=solo&month=current',{headers:{Authorization:`Bearer ${records[0].token}`,'X-EntityWars-Client-Build':'5510'}});
  assert.equal(response.status,503);console.log('Authenticated leaderboard HTTP: disabled flag passed');
 }
 if(process.env.FOREST_DUEL_TEST==='1'){const ids=logs.map(log=>/FRIENDLY_HTTP_PASS ([0-9a-f-]+)/.exec(log)?.[1]);assert(ids[0] && ids[0]===ids[1], 'Friendly participants received different matches');}
 success=true;console.log('Two authenticated clients with separate profiles and third WebSocket: passed');
} finally {
 third?.close();for(const g of godots)if(g.proc.exitCode===null){g.proc.kill();await g.proc.exited}if(server){server.kill();await server.exited}redis.disconnect();redisProc.kill();await redisProc.exited;
 if(!success){for(const path of [serverLog,serverErr,...godots.map(g=>g.log)])try{writeFileSync(path,scrub(readFileSync(path,'utf8')));}catch{} console.error(`Fixture failed; sanitized diagnostic logs retained in ${dir}`);}
 else for(let i=0;i<20;i++){try{rmSync(dir,{recursive:true,force:true});break}catch{await Bun.sleep(200)}}
}
