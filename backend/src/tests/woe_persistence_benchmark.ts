// Local before/after persistence microbenchmark. Auto-checkpoint is disabled only
// here to count cumulative WAL bytes; HTTP load uses production defaults.
import {Database} from 'bun:sqlite';
import {mkdtempSync,readdirSync,readFileSync,writeFileSync,copyFileSync,statSync,unlinkSync,rmSync,existsSync} from 'node:fs';
import {join,resolve} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {createWoeLobby} from '../woe/lobby';
import {createWoeMatchService} from '../woe/match_service';
import {initializeMatch,applyDeployment} from '../woe/engine';

const backend=resolve(import.meta.dir,'../..'),dir=mkdtempSync(join(tmpdir(),'ew-r2-persist-'));
const baselinePath=resolve(import.meta.dir,'../woe/.r2_baseline_match_service.ts');
if(existsSync(baselinePath))throw Error(`Refusing to overwrite ${baselinePath}`);
const old=Bun.spawnSync(['git','show','HEAD:backend/src/woe/match_service.ts'],{cwd:backend});if(old.exitCode!==0)throw Error(old.stderr.toString());
writeFileSync(baselinePath,old.stdout);
try {
 const baseline=(await import(pathToFileURL(baselinePath).href)).createWoeMatchService;
 const source=join(dir,'source.sqlite'),db=new Database(source);db.exec('PRAGMA busy_timeout=5000;PRAGMA journal_mode=WAL;PRAGMA synchronous=FULL');
 for(const f of readdirSync(join(backend,'migrations/sqlite')).filter(f=>f.endsWith('.sql')).sort())db.exec(readFileSync(join(backend,'migrations/sqlite',f),'utf8'));
 const now=1700000000000,lobby=createWoeLobby(db,()=> 'duel_clearing',()=>true,()=>now);
 for(let i=0;i<4;i++){
  const id=`player-${i}`;db.query('INSERT INTO players VALUES (?,?,?,0)').run(id,id,'{}');
  let room=lobby.create(id,{mode:'1v1',client_action_id:'create'}).data;
  room=lobby.seat(id,{room_id:room.room_id,seat:'blue:left',expected_revision:room.revision,client_action_id:'seat'}).data;
  room=lobby.start(id,{room_id:room.room_id,expected_revision:room.revision,client_action_id:'start',fill_bots:true}).data;
  let state=initializeMatch('1v1','r2-persistence',room.controllers.map((x:any)=>x.controller_id));
  for(const c of room.controllers){const p=state.controllers.find(x=>x.id===c.controller_id)!;p.zealTenths=100;const result=applyDeployment(state,{controllerId:p.id,actionId:'seed',slot:0,cardId:p.slots[0],lane:'left'});if(!result.accepted)throw Error(result.reason);state=result.state;}
  const originals=state.units;state.units=Array.from({length:30},(_,n)=>{const u=structuredClone(originals[n<15?0:1]);u.id=n+1;u.position={x:870+(n%10)*18,y:n<15?570+(n%3)*12:510-(n%3)*12};return u});state.nextUnitId=31;
  for(const p of state.controllers)p.actionIds=[];
  db.query('UPDATE woe_matches SET state_json=? WHERE match_id=?').run(JSON.stringify(state),room.match_id);
 }
 db.exec('PRAGMA wal_checkpoint(TRUNCATE)');db.close();
 for(let repeat=0;repeat<3;repeat++)for(const [name,factory] of (repeat%2?[['after',createWoeMatchService],['before',baseline]]:[['before',baseline],['after',createWoeMatchService]]) as [string,typeof createWoeMatchService][]){
  const path=join(dir,`${name}-${repeat}.sqlite`);copyFileSync(source,path);const testDb=new Database(path);testDb.exec('PRAGMA busy_timeout=5000;PRAGMA journal_mode=WAL;PRAGMA synchronous=FULL;PRAGMA wal_autocheckpoint=0');
  const service=factory(testDb,()=>true,()=>now),samples:number[]=[];for(let i=0;i<100;i++){const t=performance.now();service.pulse();samples.push(performance.now()-t)}
  samples.sort((a,b)=>a-b);const wal=statSync(path+'-wal').size,checkpoint=testDb.query('PRAGMA wal_checkpoint(PASSIVE)').get();
  console.log(JSON.stringify({name,repeat,matches:4,ticks:100,seeded_units:30,autocheckpoint:0,pulse_ms:{p50:samples[49],p95:samples[94],max:samples[99]},wal_bytes:wal,checkpoint}));testDb.close();
 }
} finally {try{unlinkSync(baselinePath)}catch{}try{rmSync(dir,{recursive:true,force:true})}catch{console.error(`Persistence fixture remains at ${dir}`)}}
