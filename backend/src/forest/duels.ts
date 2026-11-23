import type { Database } from 'bun:sqlite';
import type { PvpSnapshot } from '../pvp/combat';

const PENDING_MS = 45_000, PREPARING_MS = 180_000, RETENTION_MS = 7 * 86_400_000;
const validId = (v: unknown): v is string => typeof v === 'string' && v.length > 0 && v.length <= 128 && v.trim() === v && !/[\u0000-\u001f\u007f-\u009f]/u.test(v);
type Result = {status: number; data: any};
const fail = (status: number, error: string): Result => ({status, data: {error}});

export function createForestDuels(db: Database, roomOf: (id: string) => string | null, canServe: () => boolean, clock: () => number = Date.now, combat?: {snapshot: (id:string, selection:unknown)=>PvpSnapshot|null; start: (a:PvpSnapshot,b:PvpSnapshot,now:number,inviteId:string)=>string}) {
 const expire = (now: number) => {
  db.query("UPDATE forest_duel_invites SET status='EXPIRED', updated_at=? WHERE status IN ('PENDING','ACCEPTED') AND expires_at<=?").run(now, now);
  db.query("DELETE FROM forest_duel_reservations WHERE invite_id IN (SELECT invite_id FROM forest_duel_invites WHERE status='EXPIRED')").run();
 };
 const clean = (now: number) => {
  expire(now);
  db.query('DELETE FROM forest_duel_actions WHERE created_at <= ?').run(now - RETENTION_MS);
  db.query("DELETE FROM forest_duel_invites WHERE status IN ('DECLINED','CANCELLED','EXPIRED') AND updated_at <= ?").run(now - RETENTION_MS);
 };
 const row = (id: string) => db.query(`SELECT i.invite_id, i.challenger_id, a.display_name AS challenger_name, i.recipient_id, b.display_name AS recipient_name, i.originating_zone, i.status, i.created_at, i.updated_at, i.expires_at FROM forest_duel_invites i JOIN players a ON a.player_id=i.challenger_id JOIN players b ON b.player_id=i.recipient_id WHERE i.invite_id=?`).get(id) as any;
 const busyPvp = (id: string, now: number) => !!db.query('SELECT 1 FROM pvp_queue WHERE player_id=? AND expires_at>? UNION ALL SELECT 1 FROM pvp_match_players WHERE player_id=? AND active=1 LIMIT 1').get(id, now, id);
 const reserved = (id: string) => !!db.query('SELECT 1 FROM forest_duel_reservations WHERE player_id=?').get(id);
 const mutate = (player: string, body: any, type: string, payload: object, run: (now:number)=>Result): Result => {
  if (!canServe()) return fail(503, 'FOREST_DUELS_UNAVAILABLE');
  if (!validId(body?.client_action_id)) return fail(400, 'INVALID_ACTION_ID');
  const json = JSON.stringify(payload);
  return db.transaction(() => {
   if (!canServe()) return fail(503, 'FOREST_DUELS_UNAVAILABLE');
   const now = clock(); clean(now);
   const prior = db.query('SELECT * FROM forest_duel_actions WHERE player_id=? AND client_action_id=?').get(player, body.client_action_id) as any;
   if (prior) return prior.action_type === type && prior.payload_json === json ? {status:prior.status_code, data:JSON.parse(prior.result_json)} : fail(409, 'ACTION_CONFLICT');
   const count = db.query('SELECT count(*) AS n FROM forest_duel_actions WHERE player_id=?').get(player) as {n:number};
   if (count.n >= 500) return fail(429, 'ACTION_LIMIT');
   const result = run(now);
   db.query('INSERT INTO forest_duel_actions VALUES (?,?,?,?,?,?,?)').run(player, body.client_action_id, type, json, result.status, JSON.stringify(result.data), now);
   return result;
  }).immediate();
 };
 const unlock = (id: string) => db.query('DELETE FROM forest_duel_reservations WHERE invite_id=?').run(id);
 return {
  participants(inviteId:unknown): string[] {
   if (!validId(inviteId)) return [];
   const i = db.query("SELECT challenger_id,recipient_id FROM forest_duel_invites WHERE invite_id=?").get(inviteId) as any;
   return i ? [i.challenger_id,i.recipient_id] : [];
  },
  challengerFor(recipient:string, inviteId:unknown): string | null {
   if (!validId(inviteId)) return null;
   const found = db.query("SELECT challenger_id FROM forest_duel_invites WHERE invite_id=? AND recipient_id=? AND status='PENDING'").get(inviteId, recipient) as {challenger_id:string}|null;
   return found?.challenger_id ?? null;
  },
  state(player: string): Result {
   if (!canServe()) return fail(503, 'FOREST_DUELS_UNAVAILABLE');
   return db.transaction(() => {
    if (!canServe()) return fail(503, 'FOREST_DUELS_UNAVAILABLE');
    clean(clock());
    const records = db.query(`SELECT i.invite_id, i.challenger_id, a.display_name AS challenger_name, i.recipient_id, b.display_name AS recipient_name, i.originating_zone, i.status, i.created_at, i.updated_at, i.expires_at FROM forest_duel_invites i JOIN players a ON a.player_id=i.challenger_id JOIN players b ON b.player_id=i.recipient_id WHERE (i.challenger_id=? OR i.recipient_id=?) AND i.status IN ('PENDING','ACCEPTED') ORDER BY i.created_at, i.invite_id LIMIT 1`).all(player,player) as any[];
    const started = db.query("SELECT i.invite_id,m.match_id FROM forest_duel_invites i JOIN pvp_matches m ON m.invite_id=i.invite_id WHERE (i.challenger_id=? OR i.recipient_id=?) AND i.status='STARTED' ORDER BY i.updated_at DESC LIMIT 1").get(player,player) as any;
    for (const record of records.filter(r=>r.status==='ACCEPTED')) { const ready = db.query('SELECT player_id FROM forest_duel_ready WHERE invite_id=?').all(record.invite_id) as any[]; record.ready = {player:ready.some(x=>x.player_id===player),enemy:ready.some(x=>x.player_id!==player)}; }
    return {status:200, data:{...(started ? {started} : {}), player_id:player, incoming:records.filter(r=>r.status==='PENDING' && r.recipient_id===player), outgoing:records.filter(r=>r.status==='PENDING' && r.challenger_id===player), accepted:records.filter(r=>r.status==='ACCEPTED')}};
   }).immediate();
  },
  request(player:string, body:any, targetAvailable = true):Result {
   if (!validId(body?.target_player_id)) return fail(400,'INVALID_TARGET');
   const target = body.target_player_id;
   return mutate(player, body, 'request', {target_player_id:target}, now => {
    if (player===target) return fail(400,'SELF_DUEL');
    if (!targetAvailable || !db.query('SELECT 1 FROM players WHERE player_id=?').get(target) || !db.query('SELECT 1 FROM players WHERE player_id=?').get(player)) return fail(404,'PLAYER_UNAVAILABLE');
    const zone = roomOf(player);
    if (!zone || roomOf(target)!==zone) return fail(409,'FOREST_ROOM_MISMATCH');
    if (reserved(player) || reserved(target) || busyPvp(player,now) || busyPvp(target,now)) return fail(409,'PLAYER_BUSY');
    const sent = db.query('SELECT count(*) AS n FROM forest_duel_invites WHERE challenger_id=? AND created_at>?').get(player, now-60_000) as {n:number};
    const received = db.query('SELECT count(*) AS n FROM forest_duel_invites WHERE recipient_id=? AND created_at>?').get(target, now-60_000) as {n:number};
    if (sent.n>=10 || received.n>=5) return fail(429,'DUEL_RATE_LIMIT');
    const id = crypto.randomUUID();
    db.query("INSERT INTO forest_duel_invites VALUES (?,?,?,?,'PENDING',?,?,?)").run(id,player,target,zone,now,now,now+PENDING_MS);
    const reserve = db.query('INSERT INTO forest_duel_reservations VALUES (?,?)'); reserve.run(player,id); reserve.run(target,id);
    return {status:200, data:{invite:row(id)}};
   });
  },
  respond(player:string, body:any, challengerAvailable = true):Result {
   if (!validId(body?.invite_id) || typeof body?.accept !== 'boolean') return fail(400,'INVALID_REQUEST');
   return mutate(player, body, 'respond', {invite_id:body.invite_id,accept:body.accept}, now => {
    const invitation = row(body.invite_id);
    if (!invitation || invitation.recipient_id!==player) return fail(404,'INVITE_UNAVAILABLE');
    if (invitation.status!=='PENDING') return fail(409,'INVITE_NOT_PENDING');
    if (body.accept) {
     if (!challengerAvailable) return fail(404,'PLAYER_UNAVAILABLE');
     if (roomOf(player)!==invitation.originating_zone || roomOf(invitation.challenger_id)!==invitation.originating_zone) return fail(409,'FOREST_ROOM_MISMATCH');
     if (busyPvp(player,now) || busyPvp(invitation.challenger_id,now)) return fail(409,'PLAYER_BUSY');
     db.query("UPDATE forest_duel_invites SET status='ACCEPTED', updated_at=?, expires_at=? WHERE invite_id=?").run(now,now+PREPARING_MS,body.invite_id);
    } else {
     db.query("UPDATE forest_duel_invites SET status='DECLINED', updated_at=? WHERE invite_id=?").run(now,body.invite_id); unlock(body.invite_id);
    }
    return {status:200, data:{invite:row(body.invite_id)}};
   });
  },
  ready(player:string, body:any, available = true):Result {
   if (!validId(body?.invite_id) || !body || Object.keys(body).some(k=>!['invite_id','selection','client_action_id'].includes(k))) return fail(400,'INVALID_REQUEST');
   if (!combat) return fail(503,'PVP_SECRET_REQUIRED');
   return mutate(player,body,'ready',{invite_id:body.invite_id,selection:body.selection},now=>{
    const invitation = row(body.invite_id);
    if (!invitation || ![invitation.challenger_id,invitation.recipient_id].includes(player)) return fail(404,'INVITE_UNAVAILABLE');
    if (invitation.status === 'STARTED') { const found=db.query('SELECT match_id FROM pvp_matches WHERE invite_id=?').get(body.invite_id) as any; return {status:200,data:{state:'STARTED',match_id:found.match_id}}; }
    if (invitation.status !== 'ACCEPTED') return fail(409,'INVITE_NOT_ACTIVE');
    if (!available) return fail(404,'PLAYER_UNAVAILABLE');
    if (busyPvp(invitation.challenger_id,now) || busyPvp(invitation.recipient_id,now)) return fail(409,'PLAYER_BUSY');
    const reservations=db.query('SELECT player_id FROM forest_duel_reservations WHERE invite_id=?').all(body.invite_id) as any[];
    if (reservations.length!==2 || ![invitation.challenger_id,invitation.recipient_id].every(id=>reservations.some(r=>r.player_id===id))) return fail(409,'INVITE_NOT_ACTIVE');
    const old=db.query('SELECT selection_json FROM forest_duel_ready WHERE invite_id=? AND player_id=?').get(body.invite_id,player) as any;
    if (old && old.selection_json!==JSON.stringify(body.selection)) return fail(409,'READY_CONFLICT');
    if (!old) {
     const snapshot=combat.snapshot(player,body.selection);
     if (!snapshot || snapshot.player_id!==player) return fail(400,'UNTRUSTED_SETUP');
     db.query('INSERT INTO forest_duel_ready VALUES (?,?,?,?)').run(body.invite_id,player,JSON.stringify(snapshot),JSON.stringify(body.selection));
    }
    const ready=db.query('SELECT player_id,snapshot_json FROM forest_duel_ready WHERE invite_id=?').all(body.invite_id) as any[];
    if (ready.length<2) return {status:200,data:{state:'WAITING',invite_id:body.invite_id}};
    const a=ready.find(r=>r.player_id===invitation.challenger_id),b=ready.find(r=>r.player_id===invitation.recipient_id);
    if (!a || !b) throw new Error('INVALID_READY_STATE');
    const matchId=combat.start(JSON.parse(a.snapshot_json),JSON.parse(b.snapshot_json),now,body.invite_id);
    db.query("UPDATE forest_duel_invites SET status='STARTED',updated_at=? WHERE invite_id=? AND status='ACCEPTED'").run(now,body.invite_id);
    unlock(body.invite_id);
    return {status:200,data:{state:'STARTED',match_id:matchId}};
   });
  },
  cancel(player:string, body:any):Result {
   if (!validId(body?.invite_id)) return fail(400,'INVALID_REQUEST');
   return mutate(player, body, 'cancel', {invite_id:body.invite_id}, now => {
    const invitation = row(body.invite_id);
    if (!invitation || (invitation.challenger_id!==player && !(invitation.recipient_id===player && invitation.status==='ACCEPTED'))) return fail(404,'INVITE_UNAVAILABLE');
    if (!['PENDING','ACCEPTED'].includes(invitation.status)) return fail(409,'INVITE_NOT_ACTIVE');
    db.query("UPDATE forest_duel_invites SET status='CANCELLED', updated_at=? WHERE invite_id=?").run(now,body.invite_id); unlock(body.invite_id);
    return {status:200, data:{invite:row(body.invite_id)}};
   });
  }
 };
}
