import type { Database } from 'bun:sqlite';
import { advanceTick, applyDeployment, getPublicSnapshot, type MatchState, type Team } from './engine';
import { chooseBotDeployment } from './bot_ai';

const PAGE=100, EVENT_LIMIT=2000, ACTION_LIMIT=2048, RETENTION=24*60*60_000;
type Result={status:number;data:any};
const fail=(status:number,error:string):Result=>({status,data:{error}});
const valid=(v:unknown):v is string=>typeof v==='string' && v.length>0 && v.length<=128 && v.trim()===v && !/[\u0000-\u001f\u007f-\u009f]/u.test(v);

export function createWoeMatchService(db:Database, canServe:()=>boolean, clock:()=>number=Date.now) {
 const row=(id:string)=>db.query('SELECT * FROM woe_matches WHERE match_id=?').get(id) as any;
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
  db.query('UPDATE woe_rooms SET match_json=?,updated_at=? WHERE room_id=?').run(json,now,r.room_id);
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
  const keys=kind==='deploy'?['match_id','client_action_id','slot','card_id','lane']:['match_id','client_action_id'];
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
    const applied=applyDeployment(state,{actionId:b.client_action_id,controllerId:player,slot:b.slot,cardId:b.card_id,lane:b.lane});
    if(!applied.accepted)result=fail(409,applied.reason);
    else {save(r,applied.state,[spawnEvent(applied.state)],clock());result={status:200,data:snapshot(row(b.match_id),player,r.event_seq)}}
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
   if(state.tick%10===0){const bots=db.query('SELECT controller_id FROM woe_match_participants WHERE match_id=? AND (human=0 OR forfeited=1) ORDER BY controller_id').all(id) as any[];for(const bot of bots){const cmd=chooseBotDeployment(state,bot.controller_id);if(cmd){const applied=applyDeployment(state,cmd);if(applied.accepted){state=applied.state;events.push(spawnEvent(state))}}}}
   state=advanceTick(state);events.push(...state.events);if(!canServe())throw new Error('FOREST_WOE_FENCED');save(r,state,events,clock());if(!canServe())throw new Error('FOREST_WOE_FENCED');
  }).immediate();
 }
 let timer:ReturnType<typeof setInterval>|undefined;let lastCleanup=0;
 function pulse(){if(!canServe())return;const now=clock();if(now-lastCleanup>60_000){
   // Some deployments do not enable SQLite foreign keys; explicitly remove children.
   db.transaction(()=>{const expired=db.query("SELECT match_id FROM woe_matches WHERE status='FINISHED' AND finished_at<=? LIMIT 32").all(now-RETENTION) as any[];for(const r of expired){for(const table of ['woe_match_events','woe_match_actions','woe_match_participants'])db.query(`DELETE FROM ${table} WHERE match_id=?`).run(r.match_id);db.query('DELETE FROM woe_matches WHERE match_id=?').run(r.match_id)}}).immediate();lastCleanup=now}
  const running=db.query("SELECT match_id FROM woe_matches WHERE status='RUNNING' ORDER BY match_id LIMIT 256").all() as any[];for(const r of running){if(!canServe())break;tickOne(r.match_id)}
 }
 return {
  start(){if(!timer){timer=setInterval(pulse,100);timer.unref()}},stop(){if(timer)clearInterval(timer);timer=undefined},pulse,
  state(player:string,id:unknown,after:unknown):Result {if(!valid(id)||typeof after!=='string'||!/^\d{1,15}$/.test(after)||!Number.isSafeInteger(Number(after)))return fail(400,'INVALID_REQUEST');return inTransaction(()=>{const r=row(id);if(!r)return fail(404,'MATCH_UNAVAILABLE');if(!member(id,player))return fail(403,'NOT_PARTICIPANT');return {status:200,data:snapshot(r,player,Number(after))}})},
  current(player:string):Result{return inTransaction(()=>{const r=db.query("SELECT m.* FROM woe_matches m JOIN woe_match_participants p ON p.match_id=m.match_id WHERE p.controller_id=? AND p.human=1 ORDER BY (m.status='RUNNING') DESC,m.created_at DESC LIMIT 1").get(player) as any;return {status:200,data:r?snapshot(r,player,0):{match:null,server_time_unix_ms:clock()}}})},
  deploy:(player:string,b:any)=>action(player,b,'deploy'),forfeit:(player:string,b:any)=>action(player,b,'forfeit')
 };
}
