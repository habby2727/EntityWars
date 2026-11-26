import type { Database } from 'bun:sqlite';
import { spectatableActivities } from './spectator_discovery';
import { readHuntCombat } from './solo_hunt_retention';
import { sanitizePvpEvent, projectPvpFighter } from './pvp/projection';
import type { ObservedCombat } from './spectator_service';

const pick=(value:any,keys:string[])=>Object.fromEntries(keys.filter(k=>value?.[k]!==undefined).map(k=>[k,value[k]]));
const fighterKeys=['id','name','type','expedition_types','texture','hom_id','hom_name','hom_type','hom_texture','hp','max_hp','atk','def','status','persistent_statuses','passive_modifiers','defense_presentation','pending_drain','spell_neutralize_active','spell_neutralize_pending','strategic_trap','strategic_heal_suppression','hom_energy','hom_spent','item_id','inspiration','inspiration_used','active_weapon_slot'];
const ownKeys=[...fighterKeys,'spell_ids','cooldowns'];
const statusKeys=['poison','stun','shield','shield_pct','reflect','reflect_pct','atk_boost','atk_down','vuln','vuln_pct','hom_stun','tempo_bonus','focus_next','misalign_next','poison_on_reflect'];
const publicFighter=(entry:any,keys:string[])=>{
  const out=pick(entry,keys);
  out.status=Object.fromEntries(statusKeys.filter(k=>typeof entry?.status?.[k]==='number' && Number.isFinite(entry.status[k])).map(k=>[k,entry.status[k]]));
  if(['player','npc','boss','left','right'].includes(entry?.status?.hybrid_mark?.owner) && Number.isSafeInteger(entry?.status?.hybrid_mark?.remaining))out.status.hybrid_mark=pick(entry.status.hybrid_mark,['owner','remaining']);
  out.persistent_statuses=Object.fromEntries(['poison','burn','lethargy'].filter(k=>entry?.persistent_statuses?.[k]).map(k=>[k,pick(entry.persistent_statuses[k],['stage','remaining'])]));
  out.defense_presentation=Object.fromEntries(['shield','shield_pct','reflect','reflect_pct'].filter(k=>entry?.defense_presentation?.[k]).map(k=>[k,pick(entry.defense_presentation[k],['value','remaining'])]));
  out.passive_modifiers=Array.isArray(entry?.passive_modifiers)?entry.passive_modifiers.slice(0,32).map((x:any)=>pick(x,['kind','amount','duration','remaining'])):[];
  out.pending_drain=Array.isArray(entry?.pending_drain)?entry.pending_drain.slice(0,32).map((x:any)=>pick(x,['remaining'])):[];
  if(entry?.strategic_trap)out.strategic_trap=pick(entry.strategic_trap,['value','expires_turn']);
  if(entry?.strategic_heal_suppression)out.strategic_heal_suppression=pick(entry.strategic_heal_suppression,['expires_turn']);
  return out;
};
const eventKeys=['kind','turn','actor','target','side','target_side','actor_kind','category','verb','suffix','spell_id','spell_name','show_spell_link','amount','damage','actual_damage','hp','status','value','remaining','previous','effectiveness','result','hom_id','passive_id','trigger','hit','slot','action','source','item_id','boosted','actual_bonus_damage','duration'];
const publicEvents=new Set(['player_cast','spell','support_hit','damage','true_damage','reflect','corrosion','hom_corrosion','hom_damage','status_tick','heal','miss','evade','hom_miss','hom_attack','hom_dot','hom_passive','true_on_hit','dot_true','delayed_damage','poison','burn','lethargy','recoil','switch','inspiration','inspiration_offered','inspiration_chosen','inspiration_declined','inspiration_activated','physical_anomaly_cast','counter_trap_armed','heal_suppression_applied','heal_suppression_expired','cooldown_jam','buff_steal','debuff_transfer','ward_convert','hom_energy_siphon','combo_trigger','boss_action','boss_special_cast','combat_terminal','status_snapshot','boss_intent','status_applied','status_changed','status_consumed','status_cleansed','status_expired','elite_trait_triggered','elemental_proc','elemental_heal']);
const eventView=(event:any,id:number)=>{
  if(!publicEvents.has(event?.kind) && !String(event?.kind ?? '').startsWith('boss_shield')) return {id,kind:'event'};
  const result=pick(event,eventKeys);
  for(const key of Object.keys(result))if((!['string','number','boolean'].includes(typeof result[key]) && result[key]!==null) || (typeof result[key]==='number' && !Number.isFinite(result[key])))delete result[key];
  if(String(event?.kind ?? '').startsWith('inspiration_')) { delete result.spell_id; delete result.spell_name; }
  if(event?.anomaly) result.anomaly=anomaly(event.anomaly);
  if(Array.isArray(event?.effects)) result.effects=event.effects.slice(0,16).filter((e:any)=>e && typeof e.kind==='string' && ['player','npc','boss','left','right'].includes(e.target)).map((e:any)=>pick(e,['kind','target','amount','unit','duration','remaining']));
  if(event?.target_status && typeof event.target_status==='object') result.target_status=pick(event.target_status,['poison','stun','shield_pct','reflect_pct','atk_boost','atk_down','vuln_pct','hom_stun','tempo_bonus','focus_next','misalign_next','poison_on_reflect']);
  return {...result,id};
};
const anomaly=(value:any)=>value ? pick(value,['id','favored_type','weakened_type','remaining_exchanges']) : null;

/** Pure projections supplied by the existing participant presentation helpers. */
export function createSpectatorAdapters(db:Database, presentation:{dungeon:(combat:any)=>any; expedition:(combat:any)=>any; hunt:(combat:any)=>any}) {
  const locate=(target:string,now:number):ObservedCombat|null=>{
    const mode=spectatableActivities(db,[target],now).get(target);
    if(mode==='ranked'||mode==='friendly') {const row=db.query("SELECT m.match_id FROM pvp_match_players p JOIN pvp_matches m ON m.match_id=p.match_id WHERE p.player_id=? AND p.active=1 AND m.status='ACTIVE'").get(target) as any;return row?{mode,id:row.match_id,encounter:'0'}:null;}
    if(mode==='practice'){const row=db.query("SELECT match_id FROM practice_sessions WHERE player_id=? AND status='ACTIVE' AND expires_at>?").get(target,now) as any;return row?{mode,id:row.match_id,encounter:'0'}:null;}
    if(mode==='hunt'){const row=db.query("SELECT session_id FROM solo_hunt_sessions WHERE player_id=? AND status='ACTIVE' AND expires_at>? AND combat_state_json IS NOT NULL").get(target,now) as any;return row?{mode,id:row.session_id,encounter:'0'}:null;}
    if(mode==='dungeon'){const row=db.query("SELECT run_id,combat_state_json FROM dungeon_runs WHERE player_id=? AND status='ACTIVE' AND expires_at>? AND combat_state_json IS NOT NULL").get(target,now) as any;if(!row)return null;return {mode,id:row.run_id,encounter:String(JSON.parse(row.combat_state_json).floor)};}
    if(mode==='expedition'){const row=db.query("SELECT run_id,state_json FROM expedition_runs WHERE player_id=? AND status='ACTIVE' AND heartbeat_at>?").get(target,now-240_000) as any;if(!row)return null;const state=JSON.parse(row.state_json);return {mode,id:row.run_id,encounter:String(state.depth)};}
    return null;
  };
  const readEvents=(table:string,id:string,after:number,encounter?:string) => {
    const isPve=table==='spectator_events';
    const where=isPve ? "mode=? AND session_id=? AND encounter=?" : "match_id=?"+(table==='pvp_events' ? " AND visibility='public'" : "");
    const args=isPve ? [encounter!.split(':')[0],id,encounter!.split(':').slice(1).join(':')] : [id];
    const bounds=db.query(`SELECT MIN(seq) lo,MAX(seq) hi FROM ${table} WHERE ${where}`).get(...args) as any;
    const gap=after>0 && bounds.lo!==null && after<bounds.lo;
    const initial=after===0 || gap;
    const entries=(initial ? db.query(`SELECT seq,payload_json FROM ${table} WHERE ${where} ORDER BY seq DESC LIMIT 250`).all(...args) : db.query(`SELECT seq,payload_json FROM ${table} WHERE ${where} AND seq>? ORDER BY seq LIMIT 250`).all(...args,after)) as any[];
    if(initial)entries.reverse();
    const last=entries.at(-1)?.seq ?? after;
    return {entries,gap,more:bounds.hi!==null && last<bounds.hi};
  };
  const playerName=(id:string)=>(db.query('SELECT display_name FROM players WHERE player_id=?').get(id) as any)?.display_name ?? '';
  const project=(target:string,c:ObservedCombat,after:number,now:number)=>{
    if(c.mode==='ranked'||c.mode==='friendly'||c.mode==='practice') {
      const practice=c.mode==='practice';
      const row=practice?db.query('SELECT *,combat_json AS combat_state_json,\'LEFT\' AS side FROM practice_sessions WHERE match_id=? AND player_id=?').get(c.id,target) as any:db.query('SELECT m.*,p.side FROM pvp_matches m JOIN pvp_match_players p ON p.match_id=m.match_id WHERE m.match_id=? AND p.player_id=? AND m.kind=?').get(c.id,target,c.mode) as any;
      if(!row || (practice && row.status==='ACTIVE' && row.expires_at<=now))return null;
      const state=JSON.parse(row.combat_state_json), side=row.side.toLowerCase() as 'left'|'right', enemy=side==='left'?'right':'left';
      const identities=practice?[{side:'LEFT',player_id:target,display_name:playerName(target)},{side:'RIGHT',player_id:'practice_npc',display_name:state.fighters.right.name}]:db.query('SELECT p.side,p.player_id,u.display_name FROM pvp_match_players p JOIN players u ON u.player_id=p.player_id WHERE p.match_id=?').all(c.id) as any[];
      const identity=(s:string)=>identities.find((x:any)=>x.side.toLowerCase()===s);
      if(!identity(side)||!identity(enemy))return null;
      const own=projectPvpFighter(state,side,side,identity(side)) as any;delete own.inspiration_offers;
      const original=state.fighters[side].original_spell_ids;
      if(Array.isArray(original) && original.length===4){own.spell_ids=[...original];own.spell_cooldowns=Object.fromEntries(original.map((id:string)=>[id,state.fighters[side].spell_cooldowns?.[id] ?? 0]));}
      else {own.spell_ids=['','','',''];own.spell_cooldowns={};}
      const rival=projectPvpFighter(state,enemy,side,identity(enemy));
      const batch=readEvents(practice?'practice_events':'pvp_events',c.id,after);
      const events=batch.entries.map(e=>{const out=sanitizePvpEvent(JSON.parse(e.payload_json),side,e.seq);if(String(out.kind ?? "").startsWith("inspiration_")){delete out.spell_id;delete out.spell_name;}return out;});
      const final=row.result_json?JSON.parse(row.result_json):null;
      const outcome=practice ? final?.result : final?.result==='draw'?'draw':final?.result===side?'win':'loss';
      return {snapshot:{match_id:c.id,kind:c.mode,status:row.status,combat_revision:row.revision,turn:state.turn,round:state.round,battle_index:state.battle_index,sudden_death:state.sudden_death,physical_anomaly:anomaly(state.physical_anomaly),score:{player:state.wins[side],enemy:state.wins[enemy]},player:own,enemy:rival,ready:{player:false,enemy:false},result:final?{result:outcome}:null},events,cursor_reset:batch.gap,terminal:row.status!=='ACTIVE',closed:row.status!=='ACTIVE' && !batch.more};
    }
    if(c.mode==='hunt') {
      const row=db.query('SELECT * FROM solo_hunt_sessions WHERE session_id=? AND player_id=?').get(c.id,target) as any;
      if(!row?.combat_state_json || (row.status==='ACTIVE' && row.expires_at<=now))return null;
      const rawCombat=readHuntCombat(row.combat_state_json);
      const projected=presentation.hunt(rawCombat);
      const combat={...pick(projected,['turn','terminal_result']), physical_anomaly:anomaly(projected.physical_anomaly), strategic_delayed:(projected.strategic_delayed??[]).map((x:any)=>pick(x,['actor','target','amount','due_turn'])), player:publicFighter(projected.player,[...fighterKeys,'homunculus_id','homunculus_energy','homunculus_spent']), boss:publicFighter(projected.boss,[...fighterKeys,'tier','intent','intent_spell_id']), minions:(projected.minions??[]).map((x:any)=>publicFighter(x,fighterKeys)), moves:(projected.moves??[]).map((x:any)=>pick(x,['id','name','type','category','power_mult','accuracy','cooldown_remaining'])), shield:pick(projected.shield,['turns','reduction','suppressed']), fury:pick(projected.fury,['pending','multiplier']), power_turn:pick(projected.power_turn,['active','used'])};
      const boss=pick(JSON.parse(row.boss_snapshot_json),['id','name','tier','texture_id','texture_variants','minion_texture_id']);
      const frozen=JSON.parse(row.combat_loadout_json);
      const loadout=pick(frozen,['entity_id','weapon_ids','homunculus_id']);
      if(Array.isArray(frozen.spell_ids) && frozen.spell_ids.length===4) combat.moves=frozen.spell_ids.map((id:string)=>{const spell=(rawCombat.spells??[]).find((x:any)=>x.id===id);return {id,...pick(spell,['name','type','category','power_mult','accuracy']),cooldown_remaining:rawCombat.cooldowns?.[id] ?? 0};});
      else combat.moves=Array.from({length:4},()=>({id:''}));
      const batch=readEvents('spectator_events',c.id,after,'hunt:0');
      const events=batch.entries.map(e=>eventView(JSON.parse(e.payload_json),e.seq));
      const zone=row.global_event_id ? (db.query('SELECT zone_id FROM global_boss_events WHERE event_id=?').get(row.global_event_id) as any)?.zone_id : row.guardian_zone_id;
      return {snapshot:{session_id:c.id,status:row.status,combat_revision:row.combat_revision,boss_definition:boss,combat_loadout:loadout,combat_state:combat,zone_id:zone ?? ''},events,cursor_reset:batch.gap,terminal:row.status!=='ACTIVE',closed:row.status!=='ACTIVE' && !batch.more};
    }
    if(c.mode==='dungeon'||c.mode==='expedition') {
      const expedition=c.mode==='expedition';
      const row=expedition?db.query('SELECT * FROM expedition_runs WHERE run_id=? AND player_id=?').get(c.id,target) as any:db.query('SELECT * FROM dungeon_runs WHERE run_id=? AND player_id=?').get(c.id,target) as any;
      if(!row || row.status==='ACTIVE' && (expedition ? !(row.heartbeat_at>now-240_000) : row.expires_at<=now))return null;
      let state=expedition?(row.state_json?JSON.parse(row.state_json):null):null;
      if (expedition && state && row.loadout_json) state.frozen_spells=JSON.parse(row.loadout_json)?.spell_ids;
      if (expedition && (!state?.combat || String(state.depth)!==c.encounter || state.phase!=='COMBAT')) { const last=db.query("SELECT combat_json FROM spectator_final_combats WHERE mode='expedition' AND session_id=? AND encounter=?").get(c.id,c.encounter) as any; if(last)state={...JSON.parse(last.combat_json),phase:'FINISHED'}; }
      let combat=expedition?state?.combat:(row.combat_state_json?JSON.parse(row.combat_state_json):null);
      if (!expedition && (!combat || String(combat.floor)!==c.encounter)) { const last=db.query("SELECT combat_json FROM spectator_final_combats WHERE mode='dungeon' AND session_id=? AND encounter=?").get(c.id,c.encounter) as any; combat=last?JSON.parse(last.combat_json):null; }
      if(!combat || String(expedition?state.depth:combat.floor)!==c.encounter)return null;
      const visible=expedition ? presentation.expedition(combat) : presentation.dungeon(combat);
      const own=publicFighter(visible.player,ownKeys), enemy=publicFighter(visible.npc,fighterKeys);
      const frozen=expedition ? state?.frozen_spells : (row.loadout_json ? JSON.parse(row.loadout_json)?.spell_ids : null);
      const original=Array.isArray(frozen) && frozen.length===4 ? frozen : combat.player.original_spell_ids;
      if(Array.isArray(original) && original.length===4){own.spell_ids=[...original];own.cooldowns=Object.fromEntries(original.map((id:string)=>[id,visible.player.cooldowns?.[id] ?? 0]));}
      else {own.spell_ids=['','','',''];own.cooldowns={};}
      if(Array.isArray(visible.npc.weapons)) enemy.weapons=visible.npc.weapons.map((w:any)=>w ? pick(w,['id']) : null);
      const combatState:any={player:own,npc:enemy,...pick(visible,['floor','turn','terminal_result','weapons','active_weapon_slot','item_id']),strategic_delayed:(visible.strategic_delayed??[]).map((entry:any)=>pick(entry,['actor','target','amount','due_turn'])),physical_anomaly:anomaly(visible.physical_anomaly)};
      if(!expedition && visible.special_encounter)combatState.special_encounter=pick(visible.special_encounter,['kind','label','hint']);
      if(!expedition && visible.elite)combatState.elite={...pick(visible.elite,['label']),modifiers:pick(visible.elite.modifiers,['hp','attack','defense'])};
      if(!expedition && visible.elite_trait)combatState.elite_trait=pick(visible.elite_trait,['trait','label','hint','used']);
      const log=expedition ? (state.log??[]) : [];
      const base=expedition ? (state.log_base ?? 0) : 0;
      const gap=expedition && after>0 && after<base;
      const start=expedition && (after===0 || gap) ? Math.max(base,base+log.length-250) : after;
      const batch=expedition ? null : readEvents('spectator_events',c.id,after,'dungeon:'+c.encounter);
      const events=expedition ? log.slice(Math.max(0,start-base),Math.max(0,start-base)+250).map((e:any,i:number)=>eventView(e,start+i+1)) : batch!.entries.map(e=>eventView(JSON.parse(e.payload_json),e.seq));
      const more=expedition ? (start+events.length<base+log.length) : batch!.more;
      const terminal=expedition ? state.phase!=='COMBAT'||row.status!=='ACTIVE' : !!combat.terminal_result||row.status!=='ACTIVE';
      const closed=terminal && !more;
      return {snapshot:{status:closed?'FINISHED':'ACTIVE',combat_revision:expedition?row.revision:row.combat_revision,combat_state:combatState,...(expedition?{phase:state.phase,depth:state.depth,background_key:state.background}: {phase:closed?'FINISHED':'COMBAT',floor:combat.floor})},events,cursor_reset:expedition ? gap : batch!.gap,terminal,closed};
    }
    return null;
  };
  return {locate,project};
}
