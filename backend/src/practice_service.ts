import { activeWoe } from "./woe/busy";
import { endSpectatingForStart, spectatorNames } from "./spectator_guard";
import type { Database } from "bun:sqlite";
import { createHmac, randomUUID } from "node:crypto";
import { createPvpCombatState, createPvpFighter, resolvePvpExchange, resolvePvpInspiration, validatePvpDecision, type PvpCatalogs, type PvpSnapshot } from "./pvp/combat";
import { sanitizePvpEvent, projectPvpFighter } from "./pvp/projection";
import { chooseDungeonNpcSpell } from "./dungeon_combat";

const IDLE = 60 * 60_000, RETENTION = 7 * 86_400_000, MAX_REVISION = 500;

/** Call inside the same write transaction as the new protected start. */
export function activePractice(db: Database, player: string, now: number): boolean {
  return !!db.query("SELECT 1 FROM practice_sessions WHERE player_id=? AND status='ACTIVE' AND expires_at>?").get(player, now);
}
export function otherCombat(db: Database, player: string, now: number, includeWoe = true): boolean {
  return !!((includeWoe && activeWoe(db,player,now)) || db.query("SELECT 1 FROM pvp_match_players WHERE player_id=? AND active=1").get(player)
    || db.query("SELECT 1 FROM pvp_queue WHERE player_id=? AND expires_at>?").get(player,now)
    || db.query("SELECT 1 FROM forest_duel_reservations r JOIN forest_duel_invites i ON i.invite_id=r.invite_id WHERE r.player_id=? AND i.status IN ('PENDING','ACCEPTED') AND i.expires_at>?").get(player,now)
    || db.query("SELECT 1 FROM dungeon_runs WHERE player_id=? AND status='ACTIVE' AND expires_at>?").get(player,now)
    || db.query("SELECT 1 FROM solo_hunt_sessions WHERE player_id=? AND status='ACTIVE' AND expires_at>?").get(player,now)
    || db.query("SELECT 1 FROM expedition_runs WHERE player_id=? AND status='ACTIVE' AND heartbeat_at>?").get(player,now-240_000));
}
export function createPracticeService(db: Database, catalogs: PvpCatalogs, secret: Uint8Array, snapshot: (player:string, selection:any)=>PvpSnapshot | null, reward: (player:string, snapshot:string, now:number, allowance:number)=>any, clock:()=>number = Date.now) {
  if (secret.length < 32) throw new Error("PVP_SECRET_REQUIRED");
  const expire = (now:number, player?:string) => {
    if (player) db.query("UPDATE practice_sessions SET status='FINISHED',result_json=?,updated_at=expires_at WHERE player_id=? AND status='ACTIVE' AND expires_at<=?").run(JSON.stringify({result:'loss',reason:'timeout'}),player,now);
    db.query("UPDATE practice_sessions SET status='FINISHED',result_json=?,updated_at=expires_at WHERE match_id IN (SELECT match_id FROM practice_sessions WHERE status='ACTIVE' AND expires_at<=? LIMIT 100)").run(JSON.stringify({result:'loss',reason:'timeout'}),now);
    db.query("DELETE FROM practice_events WHERE match_id IN (SELECT match_id FROM practice_sessions WHERE status='FINISHED' AND updated_at<=? LIMIT 50)").run(now-RETENTION);
    db.query("DELETE FROM practice_actions WHERE match_id IN (SELECT match_id FROM practice_sessions WHERE status='FINISHED' AND updated_at<=? LIMIT 50)").run(now-RETENTION);
    db.query("DELETE FROM practice_sessions WHERE match_id IN (SELECT match_id FROM practice_sessions WHERE status='FINISHED' AND updated_at<=? LIMIT 50)").run(now-RETENTION);
    db.query("DELETE FROM practice_daily_xp WHERE rowid IN (SELECT rowid FROM practice_daily_xp WHERE day<? LIMIT 100)").run(Math.floor((now-RETENTION)/86_400_000));
  };
  const draw = (id:string, battle:number, turn:number, n:number, domain='combat') => createHmac('sha256',secret).update(JSON.stringify(['practice-v1',domain,id,battle,turn,n])).digest().readUInt32BE(0)/0x100000000;
  const get = (id:string, player:string) => { const row=db.query('SELECT * FROM practice_sessions WHERE match_id=? AND player_id=?').get(id,player) as any; if (!row) throw new Error('MATCH_NOT_FOUND'); return row; };
  const dto = (row:any, after=0) => {
    const s=JSON.parse(row.combat_json), outcome=row.result_json ? JSON.parse(row.result_json) : null;
    const anomaly=s.physical_anomaly ? (({id,favored_type,weakened_type,remaining_exchanges}:any)=>({id,favored_type,weakened_type,remaining_exchanges}))(s.physical_anomaly) : null;
    return {...spectatorNames(row.player_id),match_id:row.match_id,kind:'practice',status:row.status,combat_revision:row.revision,deadline:null,turn:s.turn,round:s.round,battle_index:s.battle_index,sudden_death:s.sudden_death,physical_anomaly:anomaly,score:{player:s.wins.left,enemy:s.wins.right},player:projectPvpFighter(s,'left','left',{player_id:row.player_id,display_name:s.fighters.left.name}),enemy:projectPvpFighter(s,'right','left',{player_id:'practice_npc',display_name:s.fighters.right.name}),ready:{player:false,enemy:false},result:outcome,events:(db.query('SELECT seq,payload_json FROM practice_events WHERE match_id=? AND seq>? ORDER BY seq LIMIT 500').all(row.match_id,after) as any[]).map(e=>sanitizePvpEvent(JSON.parse(e.payload_json),'left',e.seq))};
  };
  const writeEvents = (id:string, events:any[]) => { let seq=(db.query('SELECT COALESCE(MAX(seq),0) n FROM practice_events WHERE match_id=?').get(id) as any).n; const ins=db.query('INSERT INTO practice_events VALUES (?,?,?)'); for (const e of events) ins.run(id,++seq,JSON.stringify(e)); };
  const npc = (id:string):PvpSnapshot => {
    const entities=[...catalogs.entities].sort((a,b)=>a.id.localeCompare(b.id));
    const offset=Math.floor(draw(id,0,0,0,'setup')*entities.length);
    for (let i=0;i<entities.length;i++) {
      const entity=entities[(i+offset)%entities.length];
      const spells=catalogs.spells.filter(s=>s.type===entity.type && Array.isArray(s.effects));
      const attack=spells.find(s=>s.category==='attack' && s.cooldown_turns===0 && s.accuracy>=0.9);
      if (!attack || spells.length<4) continue;
      const selected=[attack,...spells.filter(s=>s.id!==attack.id)].slice(0,4);
      const candidate:PvpSnapshot={player_id:'practice:'+id,entity_id:entity.id,weapon_ids:[null,null],homunculus_id:null,spell_ids:selected.map(s=>s.id),item_progress:{},homunculus_progress:{},spell_progress:{}};
      if (!('error' in createPvpFighter(candidate,catalogs))) return candidate;
    }
    throw new Error('PVP_CATALOG_UNAVAILABLE');
  };
  const transact = (player:string, actionId:string, request:any, perform:(now:number)=>any) => {
    if (typeof actionId!=='string' || !actionId.trim() || actionId.length>64 || /[\u0000-\u001f\u007f-\u009f]/u.test(actionId)) throw new Error('INVALID_ACTION_ID');
    return db.transaction(()=>{
      const payload=JSON.stringify(request), old=db.query('SELECT request_json,response_json FROM practice_actions WHERE player_id=? AND action_id=?').get(player,actionId) as any;
      if (old) { if (old.request_json!==payload) throw new Error('ACTION_CONFLICT'); return JSON.parse(old.response_json); }
      const now=clock(); expire(now,player); const result=perform(now);
      const count=(db.query('SELECT count(*) n FROM practice_actions WHERE match_id=?').get(result.match_id) as any).n;
      if (count>=1024) throw new Error('ACTION_LIMIT');
      db.query('INSERT INTO practice_actions VALUES (?,?,?,?,?)').run(player,actionId,result.match_id,payload,JSON.stringify(result)); return result;
    }).immediate();
  };
  return {
    start(player:string, actionId:string, selection:any) { return transact(player,actionId,{kind:'start',selection},now=>{
      endSpectatingForStart(player);
      if (activePractice(db,player,now) || otherCombat(db,player,now)) throw new Error('PLAYER_BUSY');
      const own=snapshot(player,selection); if (!own || own.player_id!==player) throw new Error('UNTRUSTED_SETUP');
      const id=randomUUID(), state=createPvpCombatState(own,npc(id),catalogs); if ('error' in state) throw new Error(state.error);
      db.query("INSERT INTO practice_sessions VALUES (?,?,'ACTIVE',1,?,?,NULL,?,?,?)").run(id,player,JSON.stringify(state),JSON.stringify(own),now,now,now+IDLE);
      return dto(get(id,player));
    }); },
    state(player:string,id:string|null,after:number) { if (!Number.isSafeInteger(after) || after<0) throw new Error('INVALID_CURSOR'); return db.transaction(()=>{ expire(clock(),player); const row=id ? get(id,player) : db.query("SELECT * FROM practice_sessions WHERE player_id=? AND status='ACTIVE'").get(player) as any; return row ? dto(row,after) : {match:null}; }).immediate(); },
    decide(player:string,id:string,actionId:string,revision:number,decision:any) { return transact(player,actionId,{kind:'decision',id,revision,decision},now=>{
      const row=get(id,player); if (row.status!=='ACTIVE') throw new Error('MATCH_FINISHED'); if (revision!==row.revision || !Number.isSafeInteger(revision)) throw new Error('STALE_REVISION');
      let s=JSON.parse(row.combat_json), events:any[]=[]; const rng=(turn:number,n:number)=>draw(id,s.battle_index,turn,n);
      if (s.fighters.left.inspiration_pending) {
        const out=resolvePvpInspiration(s,'left',decision,rng); if ('error' in out) throw new Error(out.error); s=out.state; events.push(...out.events);
      } else {
        if ('error' in validatePvpDecision(s,'left',decision)) throw new Error('INVALID_DECISION');
        const f=s.fighters.right, target=s.fighters.left;
        const adapt=(x:any)=>({...x,cooldowns:x.spell_cooldowns,status:{...x.status,shield:x.status.shield_pct,reflect:x.status.reflect_pct,vuln:x.status.vuln_pct},combat_rules_version:2});
        let selected:string; try { selected=chooseDungeonNpcSpell(10,f.spell_ids,f.spells,f.spell_cooldowns,adapt(f),adapt(target),draw(id,s.battle_index,s.turn,0,'npc'),{types:s.types,anomaly:s.physical_anomaly}); } catch { selected=''; }
        let opponent:any={turn:s.turn+1,spell_id:selected};
        if ('error' in validatePvpDecision(s,'right',opponent)) { const legal=f.spell_ids.find((spell_id:string)=>!('error' in validatePvpDecision(s,'right',{turn:s.turn+1,spell_id}))); if (!legal) throw new Error('INVALID_DECISION'); opponent={turn:s.turn+1,spell_id:legal}; }
        const out=resolvePvpExchange(s,decision,opponent,rng); if ('error' in out) throw new Error(out.error); s=out.state; events.push(...out.events);
      }
      if (s.fighters.right.inspiration_pending) { const out=resolvePvpInspiration(s,'right',{kind:'decline'},rng); if ('error' in out) throw new Error(out.error); s=out.state; events.push(...out.events); }
      let result:any=null;
      if (s.match_result || revision>=MAX_REVISION) {
        result={result:s.match_result==='left'?'win':s.match_result==='draw'?'draw':'loss'};
        if (s.match_result==='left') { const day=Math.floor(now/86_400_000); const used=(db.query('SELECT xp FROM practice_daily_xp WHERE player_id=? AND day=?').get(player,day) as any)?.xp ?? 0; const allowance=Math.min(20,60-used); const xp=allowance>0 ? reward(player,row.snapshot_json,now,allowance) : undefined; if (xp) { result.homunculus_xp=xp; if (xp.xp_granted>0) db.query('INSERT INTO practice_daily_xp VALUES (?,?,?) ON CONFLICT(player_id,day) DO UPDATE SET xp=xp+excluded.xp').run(player,day,xp.xp_granted); } }
      }
      writeEvents(id,events); db.query('UPDATE practice_sessions SET combat_json=?,revision=revision+1,status=?,result_json=?,updated_at=?,expires_at=? WHERE match_id=?').run(JSON.stringify(s),result?'FINISHED':'ACTIVE',result?JSON.stringify(result):null,now,now+IDLE,id); return dto(get(id,player));
    }); },
    forfeit(player:string,id:string,actionId:string) { return transact(player,actionId,{kind:'forfeit',id},now=>{ const row=get(id,player); if (row.status==='ACTIVE') { writeEvents(id,[{kind:'forfeit',side:'left',result:'right',turn:JSON.parse(row.combat_json).turn}]); db.query("UPDATE practice_sessions SET status='FINISHED',revision=revision+1,result_json=?,updated_at=? WHERE match_id=?").run(JSON.stringify({result:'loss',reason:'forfeit'}),now,id); } return dto(get(id,player)); }); },
    sweep() { db.transaction(()=>expire(clock())).immediate(); }
  };
}
