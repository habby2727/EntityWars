import type {Database} from 'bun:sqlite';
import type {CoreDefenseState} from './core_defense';

const monthAt=(now:number)=>new Date(now).toISOString().slice(0,7);
function previous(month:string) { const [y,m]=month.split('-').map(Number); return `${String(m===1?y-1:y).padStart(4,'0')}-${String(m===1?12:m-1).padStart(2,'0')}`; }
// Must run inside the caller's fenced transaction. The watermark never recedes.
export function maintainMonthlyScores(db:Database,now:number) {
 const current=monthAt(now);
 db.query('INSERT INTO core_defense_monthly_clock VALUES (1,?) ON CONFLICT(id) DO UPDATE SET month=max(month,excluded.month)').run(current);
 const high=(db.query('SELECT month FROM core_defense_monthly_clock WHERE id=1').get() as {month:string}).month;
 const prior=previous(high);
 db.query('DELETE FROM core_defense_monthly_scores WHERE rowid IN (SELECT rowid FROM core_defense_monthly_scores WHERE month<? LIMIT 32)').run(prior);
 return {current:high,previous:prior};
}
export function recordMonthlyScore(db:Database,matchId:string,state:CoreDefenseState,now:number) {
 if(state.result?.reason!=='laboratories'||!Number.isSafeInteger(state.completedWaves)||state.completedWaves<=0||!['solo','coop'].includes(state.mode))return;
 const participants=db.query('SELECT controller_id,human,forfeited,team FROM woe_match_participants WHERE match_id=?').all(matchId) as any[];
 const count=state.mode==='solo'?1:2;
 if(!(db.query('SELECT 1 FROM woe_matches m JOIN core_defense_rooms r ON r.room_id=m.room_id WHERE m.match_id=? AND r.mode=?').get(matchId,state.mode))||participants.length!==count||participants.some(p=>p.human!==1||p.forfeited!==0||p.team!=='blue')||state.controllers.length!==count||new Set(state.controllers.map(c=>c.id)).size!==count||state.controllers.some(c=>c.team!=='blue'||!participants.some(p=>p.controller_id===c.id))||state.units.some(u=>u.team==='blue'&&!participants.some(p=>p.controller_id===u.controllerId)))return;
 const months=maintainMonthlyScores(db,now),month=monthAt(now);
 if(month<months.previous||month>months.current)return;
 const insert=db.query('INSERT INTO core_defense_monthly_scores VALUES (?,?,?,?,?) ON CONFLICT(month,mode,player_id) DO UPDATE SET completed_waves=excluded.completed_waves,achieved_at=excluded.achieved_at WHERE excluded.completed_waves>core_defense_monthly_scores.completed_waves');
 for(const p of participants)insert.run(month,state.mode,p.controller_id,state.completedWaves,now);
}
export function readMonthlyScores(db:Database,mode:unknown,month:unknown,now:number) {
 if((mode!=='solo'&&mode!=='coop')||(month!=='current'&&month!=='previous'))return {status:400,data:{error:'INVALID_REQUEST'}};
 const months=maintainMonthlyScores(db,now),viewed=month==='current'?months.current:months.previous;
 const entries=db.query('SELECT p.display_name,s.completed_waves FROM core_defense_monthly_scores s JOIN players p ON p.player_id=s.player_id WHERE s.month=? AND s.mode=? ORDER BY s.completed_waves DESC,s.achieved_at ASC,s.player_id ASC LIMIT 100').all(viewed,mode);
 return {status:200,data:{current_month:months.current,previous_month:months.previous,viewed_month:viewed,mode,entries}};
}
