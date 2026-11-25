import type { Database } from 'bun:sqlite';
import { advanceTick, applyDeployment, getPublicSnapshot, type MatchState, type Team } from './engine';
import { chooseBotDeployment } from './bot_ai';
import {potionById} from './catalog';
import { cleanupCoreDefense } from './core_defense_retention';

const PAGE=100, EVENT_LIMIT=2000, ACTION_LIMIT=2048, RETENTION=24*60*60_000;
type Result={status:number;data:any};
const fail=(status:number,error:string):Result=>({status,data:{error}});
const valid=(v:unknown):v is string=>typeof v==='string' && v.length>0 && v.length<=128 && v.trim()===v && !/[\u0000-\u001f\u007f-\u009f]/u.test(v);

export function createWoeMatchService(db:Database, canServe:()=>boolean, clock:()=>number=Date.now, shared?:{canSchedule:()=>boolean; coreDefense:{tickOne:(id:string)=>void}}) {
 const row=(id:string)=>db.query('SELECT * FROM woe_matches WHERE match_id=? AND room_id NOT IN (SELECT room_id FROM core_defense_rooms)').get(id) as any;
 const member=(id:string,player:string)=>db.query('SELECT * FROM woe_match_participants WHERE match_id=? AND controller_id=? AND human=1').get(id,player) as any;
 const inTransaction=(f:()=>Result):Result=>{if(!canServe())return fail(503,'FOREST_WOE_UNAVAILABLE');return db.transaction(()=>canServe()?f():fail(503,'FOREST_WOE_UNAVAILABLE')).immediate()};
 function append(id:string, seq:number, events:any[]) {for(const e of events)db.query('INSERT INTO woe_match_events VALUES (?,?,?)').run(id,++seq,JSON.stringify(e));if(seq>EVENT_LIMIT)db.query('DELETE FROM woe_match_events WHERE match_id=? AND seq<=?').run(id,seq-EVENT_LIMIT);return seq}
 function spawnEvent(state:MatchState) {const u=state.units[state.units.length-1];return {type:'spawn',tick:state.tick,unit_id:u.id,card_id:u.cardId,team:u.team,lane:u.lane,position:u.position,controller_id:u.controllerId}}
 function save(r:any,state:MatchState,events:any[],now:number) {
  if(!canServe())throw new Error('FOREST_WOE_FENCED');
  if(state.result)events.push({type:'result',tick:state.tick,result:state.result});
  const seq=append(r.match_id,r.event_seq,events);const done=!!state.result;
  // The engine's duplicate cache is unnecessary here: durable action IDs are stored separately.
  for(const c of state.controllers)c.actionIds=[];
  const json=JSON.stringify(state);
  db.query('UPDATE woe_matches SET state_json=?,event_seq=?,revision=revision+1,updated_at=?,status=?,finished_at=? WHERE match_id=?').run(json,seq,now,done?'FINISHED':'RUNNING',done?now:null,r.match_id);
  if(done){db.query("UPDATE woe_rooms SET status='EXPIRED',updated_at=? WHERE room_id=?").run(now,r.room_id);db.query('DELETE FROM woe_members WHERE room_id=?').run(r.room_id)}
 }
 function snapshot(r:any,player:string,after:number) {
  const first=db.query('SELECT min(seq) AS n FROM woe_match_events WHERE match_id=?').get(r.match_id) as any;
  const gap=after>r.event_seq || (first.n===null ? after<r.event_seq : after<first.n-1);
  const events=gap?[]:(db.query('SELECT seq,event_json FROM woe_match_events WHERE match_id=? AND seq>? ORDER BY seq LIMIT ?').all(r.match_id,after,PAGE) as any[]).map(x=>({seq:x.seq,...JSON.parse(x.event_json)}));
  const state=JSON.parse(r.state_json) as MatchState;const snap=getPublicSnapshot(state,player);snap.events=[];
  return {match_id:r.match_id,status:r.status,revision:r.revision,tick:state.tick,server_time_unix_ms:clock(),snapshot:snap,events,cursor:gap?r.event_seq:(events.at(-1)?.seq??after),latest_event_seq:r.event_seq,resync_required:gap};
 }
 function action(player:string,b:any,kind:'deploy'|'forfeit'):Result {
  const targeted=kind==='deploy' && !!b && typeof b==='object' && ('target_x' in b || 'target_y' in b);
  const keys=kind==='deploy'?(targeted?['match_id','client_action_id','slot','card_id','target_x','target_y']:['match_id','client_action_id','slot','card_id','lane']):['match_id','client_action_id'];
  if(!b||typeof b!=='object'||Array.isArray(b)||Object.keys(b).some(k=>!keys.includes(k))||!valid(b.match_id)||!valid(b.client_action_id))return fail(400,'INVALID_REQUEST');
  const payload=JSON.stringify(keys.map(k=>[k,b[k]]));
  return inTransaction(()=>{
   const r=row(b.match_id);if(!r)return fail(404,'MATCH_UNAVAILABLE');const p=member(b.match_id,player);if(!p)return fail(403,'NOT_PARTICIPANT');
   const old=db.query('SELECT * FROM woe_match_actions WHERE match_id=? AND player_id=? AND action_id=?').get(b.match_id,player,b.client_action_id) as any;
   if(old)return old.kind===kind&&old.payload===payload?{status:old.status,data:JSON.parse(old.response)}:fail(409,'ACTION_CONFLICT');
   if((db.query('SELECT count(*) n FROM woe_match_actions WHERE match_id=? AND player_id=?').get(b.match_id,player) as any).n>=ACTION_LIMIT)return fail(429,'ACTION_LIMIT');
   let result:Result; const state=JSON.parse(r.state_json) as MatchState;
   if(r.status!=='RUNNING'||p.forfeited)result=fail(409,r.status!=='RUNNING'?'MATCH_FINISHED':'FORFEITED');
   else if(kind==='deploy'){
    const applied=applyDeployment(state,{actionId:b.client_action_id,controllerId:player,slot:b.slot,cardId:b.card_id,lane:b.lane,target_x:b.target_x,target_y:b.target_y});
    if(!applied.accepted)result=fail(409,applied.reason);
    else {save(r,applied.state,potionById[b.card_id]?applied.state.events.slice(state.events.length):[spawnEvent(applied.state)],clock());result={status:200,data:snapshot(row(b.match_id),player,r.event_seq)}}
   } else {
    db.query('UPDATE woe_match_participants SET forfeited=1 WHERE match_id=? AND controller_id=?').run(b.match_id,player);
    const remaining=db.query('SELECT team,count(*) n FROM woe_match_participants WHERE match_id=? AND human=1 AND forfeited=0 GROUP BY team').all(b.match_id) as any[];
    const allies=remaining.find(x=>x.team===p.team)?.n??0, total=remaining.reduce((n,x)=>n+x.n,0);
    if(state.mode==='1v1')state.result={winner:p.team==='blue'?'red':'blue',reason:'forfeit'};
    else if(!total)state.result={winner:null,reason:'abandoned'};
    else if(!allies)state.result={winner:(p.team==='blue'?'red':'blue') as Team,reason:'forfeit'};
    save(r,state,[],clock());result={status:200,data:snapshot(row(b.match_id),player,r.event_seq)};
   }
   db.query('INSERT INTO woe_match_actions VALUES (?,?,?,?,?,?,?)').run(b.match_id,player,b.client_action_id,kind,payload,result.status,JSON.stringify(result.data));if(!canServe())throw new Error('FOREST_WOE_FENCED');return result;
  });
 }
 function tickOne(id:string) {
  if(!canServe())return;
  db.transaction(()=>{
   if(!canServe())return;const r=row(id);if(!r||r.status!=='RUNNING')return;
   let state=JSON.parse(r.state_json) as MatchState;const events:any[]=[];
   if(state.tick%10===0){const bots=db.query('SELECT controller_id FROM woe_match_participants WHERE match_id=? AND (human=0 OR forfeited=1) ORDER BY controller_id').all(id) as any[];for(const bot of bots){const cmd=chooseBotDeployment(state,bot.controller_id);if(cmd){const applied=applyDeployment(state,cmd);if(applied.accepted){const fresh=applied.state.events.slice(state.events.length);state=applied.state;events.push(...(potionById[cmd.cardId]?fresh:[spawnEvent(state)]))}}}}
   state=advanceTick(state);events.push(...state.events);if(!canServe())throw new Error('FOREST_WOE_FENCED');save(r,state,events,clock());if(!canServe())throw new Error('FOREST_WOE_FENCED');
  }).immediate();
 }
 let timer:ReturnType<typeof setTimeout>|undefined;let lastCleanup=0, nextDue=0;
 const failures=new Map<string,{until:number;delay:number}>();
 function runPulse(isolateFailures=false){if(!(shared?.canSchedule() ?? canServe()))return;const now=clock();if(now-lastCleanup>60_000){
   // Some deployments do not enable SQLite foreign keys; explicitly remove children.
   db.transaction(()=>{if(!(shared?.canSchedule() ?? canServe()))throw new Error('FOREST_WOE_FENCED');const expired=db.query("SELECT m.match_id, c.room_id IS NOT NULL AS cd FROM woe_matches m LEFT JOIN core_defense_rooms c ON c.room_id=m.room_id WHERE m.status='FINISHED' AND m.finished_at<=? LIMIT 32").all(now-RETENTION) as any[];for(const r of expired){if(r.cd){const actions=db.query('SELECT rowid AS id FROM core_defense_actions WHERE match_id=? LIMIT 32').all(r.match_id) as {id:number}[];for(const a of actions)db.query('DELETE FROM core_defense_actions WHERE rowid=?').run(a.id);if(db.query('SELECT 1 FROM core_defense_actions WHERE match_id=? LIMIT 1').get(r.match_id))continue;}for(const table of ['core_defense_actions','core_defense_results','core_defense_participants','woe_match_events','woe_match_actions','woe_match_participants'])db.query(`DELETE FROM ${table} WHERE match_id=?`).run(r.match_id);db.query('DELETE FROM woe_matches WHERE match_id=?').run(r.match_id)}cleanupCoreDefense(db,now);if(!(shared?.canSchedule() ?? canServe()))throw new Error('FOREST_WOE_FENCED')}).immediate();lastCleanup=now}
  const running=db.query("SELECT m.match_id, c.room_id IS NOT NULL AS cd FROM woe_matches m LEFT JOIN core_defense_rooms c ON c.room_id=m.room_id WHERE m.status='RUNNING' ORDER BY m.match_id LIMIT 256").all() as any[];
  if(isolateFailures){const live=new Set(running.map(r=>r.match_id));for(const id of failures.keys())if(!live.has(id))failures.delete(id)}
  for(const r of running){
   if(!(shared?.canSchedule() ?? canServe()))break;
   if(isolateFailures && performance.now()<(failures.get(r.match_id)?.until??0))continue;
   try {if(r.cd)shared?.coreDefense.tickOne(r.match_id);else tickOne(r.match_id);failures.delete(r.match_id)}
   catch(error){if(!isolateFailures)throw error;if(!(shared?.canSchedule() ?? canServe()))break;const delay=Math.min(30000,(failures.get(r.match_id)?.delay??500)*2);failures.set(r.match_id,{until:performance.now()+delay,delay});console.error('FOREST_MINIGAME_TICK_FAILED',r.match_id,error)}
  }
 }
 function pulse(isolateFailures=false){if(Bun.env.FOREST_WOE_PULSE_PROFILE!=='1')return runPulse(isolateFailures);const start=performance.now();try{return runPulse(isolateFailures)}finally{console.log(`R2_PULSE ${performance.now()-start}`)}}
 // Deadlines use a monotonic clock. Bound work per callback and wall-time debt;
 // discarded debt slows simulation under overload but never skips game ticks.
 function arm(delay:number){timer=setTimeout(scheduled,Math.max(1,delay));timer.unref()}
 function scheduled(){
  if(!timer)return;
  try {
   if(!(shared?.canSchedule() ?? canServe())){nextDue=performance.now()+100;arm(100);return}
   const now=performance.now();nextDue=Math.max(nextDue,now-300);
   let steps=0;while(steps<3 && performance.now()>=nextDue && (shared?.canSchedule() ?? canServe())){pulse(true);nextDue+=100;steps++}arm(nextDue-performance.now())
  }
  catch(error){console.error('FOREST_MINIGAME_SCHEDULER_FAILED',error);nextDue=performance.now()+1000;arm(1000)}
 }
 return {
  start(){if(!timer){nextDue=performance.now()+100;arm(100)}},stop(){if(timer)clearTimeout(timer);timer=undefined;failures.clear()},pulse:()=>pulse(),
  state(player:string,id:unknown,after:unknown):Result {if(!valid(id)||typeof after!=='string'||!/^\d{1,15}$/.test(after)||!Number.isSafeInteger(Number(after)))return fail(400,'INVALID_REQUEST');return inTransaction(()=>{const r=row(id);if(!r)return fail(404,'MATCH_UNAVAILABLE');if(!member(id,player))return fail(403,'NOT_PARTICIPANT');return {status:200,data:snapshot(r,player,Number(after))}})},
  current(player:string):Result{return inTransaction(()=>{const r=db.query("SELECT m.* FROM woe_matches m JOIN woe_match_participants p ON p.match_id=m.match_id WHERE p.controller_id=? AND p.human=1 AND m.room_id NOT IN (SELECT room_id FROM core_defense_rooms) ORDER BY (m.status='RUNNING') DESC,m.created_at DESC LIMIT 1").get(player) as any;return {status:200,data:r?snapshot(r,player,0):{match:null,server_time_unix_ms:clock()}}})},
  deploy:(player:string,b:any)=>action(player,b,'deploy'),forfeit:(player:string,b:any)=>action(player,b,'forfeit')
 };
}
