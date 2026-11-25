// Isolated, authenticated HTTP load probe. Seeded crowds are synthetic, not replays.
// Run from backend: R2_MATCHES=4 R2_SECONDS=90 bun run src/tests/woe_http_load.ts
import {Database} from 'bun:sqlite';
import {mkdtempSync,readdirSync,readFileSync,statSync,existsSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {createServer} from 'node:net';
import {randomUUID,createHash} from 'node:crypto';
import Redis from 'ioredis';
import {createWoeLobby} from '../woe/lobby';
import {createCoreDefenseLobby} from '../woe/core_defense_lobby';
import {initializeMatch,applyDeployment} from '../woe/engine';
import {initializeCoreDefense,applyCoreDefenseDeployment,advanceCoreDefenseTick} from '../woe/core_defense';
import {cardById} from '../woe/catalog';

async function port():Promise<number>{return new Promise((ok,fail)=>{const s=createServer();s.on('error',fail);s.listen(0,'127.0.0.1',()=>{const p=(s.address() as any).port;s.close(()=>ok(p));});});}
const count=Number(process.env.R2_MATCHES||4), seconds=Number(process.env.R2_SECONDS||90), pollMs=Number(process.env.R2_POLL_MS||1000), kind=process.env.R2_SINGLE_KIND||'woe';
const root=resolve(import.meta.dir,'../..'),dir=mkdtempSync(join(tmpdir(),'ew-r2-http-')),path=join(dir,'test.sqlite'),db=new Database(path),started=Date.now();
db.exec('PRAGMA busy_timeout=5000;PRAGMA journal_mode=WAL;PRAGMA foreign_keys=ON');
for(const f of readdirSync(join(root,'migrations/sqlite')).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(root,'migrations/sqlite',f),'utf8'));
const yes=()=>true,cd=createCoreDefenseLobby(db,()=> 'duel_clearing',yes),woe=createWoeLobby(db,()=> 'duel_clearing',yes);
const clients:any[]=[];
function seed(c:any){
 const id=c.id,isCd=c.cd,sequence=++c.sequence;
 let r:any,s:any;
 if(isCd){r=cd.create(id,{mode:'solo',client_action_id:`create:${sequence}`});if(r.status!==200)throw Error(JSON.stringify(r));r=r.data;s=initializeCoreDefense('solo','r2',[id]);s.controllers[0].zealTenths=100;s=applyCoreDefenseDeployment(s,{controllerId:id,actionId:'seed',slot:0,cardId:s.controllers[0].slots[0],lane:'left'}).state;s=advanceCoreDefenseTick(s);}
 else {r=woe.create(id,{mode:'1v1',client_action_id:`create:${sequence}`}).data;r=woe.seat(id,{room_id:r.room_id,seat:'blue:left',expected_revision:r.revision,client_action_id:`seat:${sequence}`}).data;r=woe.start(id,{room_id:r.room_id,expected_revision:r.revision,client_action_id:`start:${sequence}`,fill_bots:true}).data;s=initializeMatch('1v1','r2',r.controllers.map((x:any)=>x.controller_id));for(const controller of r.controllers){const p=s.controllers.find((x:any)=>x.id===controller.controller_id);p.zealTenths=100;s=applyDeployment(s,{controllerId:p.id,actionId:'seed',slot:0,cardId:p.slots[0],lane:'left'}).state;}}
 // A deliberately injected crowded plaza makes combat work visible from the start.
 const blue=s.units.find((u:any)=>u.team==='blue'),red=s.units.find((u:any)=>u.team==='red');if(!blue||!red)throw Error(`seed units missing mode=${isCd?'cd':'woe'} teams=${s.units.map((u:any)=>u.team)}`);s.units=[];
 for(let n=0;n<30;n++){const u=structuredClone(n<15?blue:red);u.id=n+1;u.position={x:870+(n%10)*18,y:n<15?570+(n%3)*12:510-(n%3)*12};s.units.push(u)}
 s.nextUnitId=31;s.events=[];for(const p of s.controllers)p.actionIds=[];
 db.query('UPDATE woe_matches SET state_json=? WHERE match_id=?').run(JSON.stringify(s),r.match_id);
 c.match=r.match_id;c.cursor=0;c.first=null;c.last=null;
}
for(let i=0;i<count;i++){
 const id=randomUUID(),token=randomUUID(),isCd=count===1?kind==='cd':i%2===0;
 db.query('INSERT INTO players VALUES (?,?,?,0)').run(id,`R2-${i}`,'{}');
 const client={id,token,cd:isCd,sequence:0,latencies:[],statuses:{},actions:0,accepted:0,segments:[]};seed(client);clients.push(client);
}
const rp=await port(),ap=await port(),base=`http://127.0.0.1:${ap}`,redisBin=Bun.env.FOREST_TEST_REDIS_SERVER||Bun.which('redis-server');if(!redisBin)throw Error('redis-server required');
const redisProc=Bun.spawn([redisBin,'--bind','127.0.0.1','--port',String(rp),'--save','','--appendonly','no'],{stdout:'ignore',stderr:'ignore'}),redis=new Redis(`redis://127.0.0.1:${rp}`,{lazyConnect:true,retryStrategy:()=>null});redis.on('error',()=>{});
let server:any,done=false;
try {
 let ready=false;for(let i=0;i<50;i++){try{await redis.connect();ready=true;break}catch{await Bun.sleep(100)}}if(!ready)throw Error('Redis startup failed');
 const pipe=redis.pipeline();for(const c of clients){const h=createHash('sha256').update(c.token).digest('hex');pipe.set(`access:${c.token}`,JSON.stringify({userId:c.id,createdAt:started,expiresAt:started+600000}),'PX',600000);pipe.set(`idle:${h}`,'1','EX',10800);pipe.set(`idle-initialized:${h}`,'1','PX',600000)}await pipe.exec();
 const out=join(dir,'server.log'),err=join(dir,'server-error.log');
 server=Bun.spawn([process.execPath,'src/index.ts'],{cwd:root,env:{...process.env,NODE_ENV:'test',BUN_ENV:'test',HOST:'127.0.0.1',PORT:String(ap),DB_PATH:path,DATABASE_URL:'postgres://x:x@127.0.0.1:1/test',REDIS_URL:`redis://127.0.0.1:${rp}`,AUTH_ACCOUNT_TIMEOUT_MS:'100',FOREST_WS_ENABLED:'1',FOREST_WOE_ENABLED:'1',FOREST_CORE_DEFENSE_ENABLED:'1',SOCIAL_ENABLED:'0',PVP_ENABLED:'0',SESSION_IDLE_ENABLED:'1',FOREST_WOE_PULSE_PROFILE:'1'},stdout:Bun.file(out),stderr:Bun.file(err)});
 ready=false;for(let i=0;i<100;i++){try{if((await fetch(base+'/health')).ok){ready=true;break}}catch{}await Bun.sleep(100)}if(!ready)throw Error('API startup failed');
 const stats=()=>{if(process.platform!=='win32')return null;const cmd=`$p=Get-Process -Id ${server.pid}; [pscustomobject]@{cpu=$p.CPU;rss=$p.WorkingSet64} | ConvertTo-Json -Compress`;const x=Bun.spawnSync(['powershell','-NoProfile','-Command',cmd]);try{return JSON.parse(x.stdout.toString())}catch{return null}};
 const before=stats(),start=performance.now(),end=start+seconds*1000;
 await Promise.all(clients.map(async(c:any)=>{let next=0,actionAt=0;const prefix=c.cd?'core-defense':'woe',headers={Authorization:`Bearer ${c.token}`,'X-EntityWars-Client-Build':'5509','Content-Type':'application/json'};
  while(performance.now()<end){const t=performance.now();if(t<next){await Bun.sleep(next-t);continue}next=t+pollMs;
   const request=async(url:string,body?:any)=>{const at=performance.now();try{const res=await fetch(base+url,{headers,method:body?'POST':'GET',...(body?{body:JSON.stringify(body)}:{})});const data=await res.json() as any;c.latencies.push(performance.now()-at);c.statuses[res.status]=(c.statuses[res.status]||0)+1;return {status:res.status,data}}catch{c.statuses.network=(c.statuses.network||0)+1;return {status:0,data:{}}}};
   const res=await request(`/forest/${prefix}/match/state?match_id=${c.match}&after=${c.cursor}`);
   if(res.status===429){next=performance.now()+4000;continue}if(res.status!==200)continue;
   const now=performance.now();c.first??={tick:res.data.tick,at:now};c.last={tick:res.data.tick,at:now,status:res.data.status};c.cursor=res.data.cursor;
   if(res.data.status!=='RUNNING'){
    c.segments.push({first:c.first,last:c.last,hz:c.first&&c.last?(c.last.tick-c.first.tick)*1000/(c.last.at-c.first.at):null});
    if(process.env.R2_REPLENISH!=='1')break;
    seed(c);actionAt=0;continue;
   }
   if(now>=actionAt){actionAt=now+8000;const p=res.data.snapshot.players.find((x:any)=>x.id===c.id);const slot=p.slots.findIndex((x:string)=>cardById[x].cost<=p.zeal);if(slot>=0){c.actions++;const body={match_id:c.match,client_action_id:c.cd?`${res.data.server_time_unix_ms}:r2-${c.actions}`:`r2-${c.actions}`,slot,card_id:p.slots[slot],lane:c.actions%2?'left':'right'};const result=await request(`/forest/${prefix}/match/deploy`,body);if(result.status===200)c.accepted++;if(result.status===429)next=performance.now()+4000;}}
  }
 }));
 const elapsed=performance.now()-start,after=stats();const wal=existsSync(path+'-wal')?statSync(path+'-wal').size:0;const checkpoint=db.query('PRAGMA wal_checkpoint(PASSIVE)').get();
 const counts={events:db.query('SELECT count(*) n FROM woe_match_events').get(),matches:db.query("SELECT status,count(*) n FROM woe_matches GROUP BY status").all(),units:db.query("SELECT avg(json_array_length(state_json,'$.units')) avg,max(json_array_length(state_json,'$.units')) max FROM woe_matches WHERE status='RUNNING'").get()};
 const logs=readFileSync(out,'utf8'),pulses=[...logs.matchAll(/R2_PULSE ([\d.]+)/g)].map(m=>Number(m[1])).sort((a,b)=>a-b);const pct=(a:number[],p:number)=>a.length?a[Math.min(a.length-1,Math.ceil(p*a.length)-1)]:null;
 const all=clients.flatMap(c=>c.latencies).sort((a:number,b:number)=>a-b);
 console.log(JSON.stringify({count,kind,seconds,elapsed_ms:elapsed,poll_ms:pollMs,replenish:process.env.R2_REPLENISH==='1',seeded_units:30,pulse_ms:{samples:pulses.length,p50:pct(pulses,.5),p95:pct(pulses,.95),max:pct(pulses,1)},http_ms:{samples:all.length,p50:pct(all,.5),p95:pct(all,.95),max:pct(all,1)},server_cpu_seconds:before&&after?after.cpu-before.cpu:null,server_rss_before:before?.rss,server_rss_after:after?.rss,wal_bytes:wal,checkpoint,counts,clients:clients.map(c=>({mode:c.cd?'cd':'woe',first:c.first,last:c.last,hz:c.first&&c.last?(c.last.tick-c.first.tick)*1000/(c.last.at-c.first.at):null,finished_segments:c.segments,statuses:c.statuses,actions:c.actions,accepted:c.accepted}))}));done=true;
} finally {if(server){server.kill();await server.exited}redis.disconnect();redisProc.kill();await redisProc.exited;db.close();if(done){try{rmSync(dir,{recursive:true,force:true})}catch{console.error(`Temporary fixture remains at ${dir}`)}}else console.error(`Fixture failed; logs retained at ${dir}`)}
