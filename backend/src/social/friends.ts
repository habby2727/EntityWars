import type { Database } from 'bun:sqlite';

const PENDING_MS = 30_000, REJECT_MS = 120_000;
const validId = (value: unknown): value is string => typeof value === 'string' && value.length > 0 && value.length <= 128 && value.trim() === value && !/[\u0000-\u001f\u007f-\u009f]/u.test(value);
type Result = { status: number; data: any };
const error = (status: number, message: string): Result => ({ status, data: { error: message } });

export function createFriends(db: Database, clock: () => number = Date.now) {
 const expire = (now: number) => db.query("UPDATE friend_requests SET status = 'CANCELLED', updated_at = ? WHERE status = 'PENDING' AND expires_at <= ?").run(now, now);
 const friendIds = (id: string): string[] => (db.query('SELECT CASE WHEN player_low = ? THEN player_high ELSE player_low END AS id FROM friendships WHERE player_low = ? OR player_high = ?').all(id, id, id) as {id: string}[]).map(row => row.id);
 const mutate = (player: string, body: any, type: string, payload: object, action: (now: number) => Result): Result => {
  if (!validId(body?.client_action_id)) return error(400, 'Invalid client_action_id.');
  const serialized = JSON.stringify(payload);
  return db.transaction(() => {
   const prior = db.query('SELECT action_type, payload_json, status_code, result_json FROM social_actions WHERE player_id = ? AND client_action_id = ?').get(player, body.client_action_id) as any;
   if (prior) return prior.action_type === type && prior.payload_json === serialized ? {status: prior.status_code, data: JSON.parse(prior.result_json)} : error(409, 'Action ID already used.');
   const now = clock();
   expire(now);
   const result = action(now);
   db.query('INSERT INTO social_actions VALUES (?, ?, ?, ?, ?, ?, ?)').run(player, body.client_action_id, type, serialized, result.status, JSON.stringify(result.data), now);
   return result;
  }).immediate();
 };
 return {
  friendIds,
  state(player: string) {
   return db.transaction(() => {
    const now = clock(); expire(now);
    const friends = db.query(`SELECT p.player_id, p.display_name FROM friendships f JOIN players p ON p.player_id = CASE WHEN f.player_low = ? THEN f.player_high ELSE f.player_low END WHERE f.player_low = ? OR f.player_high = ? ORDER BY p.display_name, p.player_id LIMIT 200`).all(player, player, player);
    const incoming = db.query(`SELECT r.request_id, r.requester_id, p.display_name AS requester_name, r.created_at, r.expires_at FROM friend_requests r JOIN players p ON p.player_id = r.requester_id WHERE r.recipient_id = ? AND r.status = 'PENDING' ORDER BY r.created_at, r.request_id LIMIT 100`).all(player);
    const outgoing = db.query(`SELECT r.request_id, r.recipient_id, p.display_name AS recipient_name, r.created_at, r.expires_at FROM friend_requests r JOIN players p ON p.player_id = r.recipient_id WHERE r.requester_id = ? AND r.status = 'PENDING' ORDER BY r.created_at, r.request_id LIMIT 20`).all(player);
    const cooldowns = db.query(`SELECT recipient_id AS player_id, MAX(CASE WHEN status='DECLINED' THEN updated_at + ? WHEN status IN ('PENDING','CANCELLED') THEN created_at + ? ELSE 0 END) AS cooldown_until FROM friend_requests WHERE requester_id=? AND ((status='DECLINED' AND updated_at + ?>?) OR (status IN ('PENDING','CANCELLED') AND created_at + ?>?)) GROUP BY recipient_id ORDER BY cooldown_until DESC LIMIT 200`).all(REJECT_MS,PENDING_MS,player,REJECT_MS,now,PENDING_MS,now);
    return {player_id: player, friends, incoming, outgoing, cooldowns, server_time:now};
   }).immediate();
  },
  request(player: string, body: any, targetAvailable = true): Result {
   if (!validId(body?.target_player_id)) return error(400, 'Invalid target_player_id.');
   const target = body.target_player_id;
   return mutate(player, body, 'request', {target_player_id: target}, now => {
    if (player === target) return error(400, 'Cannot friend yourself.');
    if (!targetAvailable || !db.query('SELECT 1 FROM players WHERE player_id = ?').get(target)) return error(404, 'Target unavailable.');
    const [low, high] = [player, target].sort();
    if (db.query('SELECT 1 FROM friendships WHERE player_low = ? AND player_high = ?').get(low, high)) return error(409, 'Already friends.');
    const pending = db.query("SELECT expires_at FROM friend_requests WHERE pair_low = ? AND pair_high = ? AND status = 'PENDING'").get(low, high) as {expires_at:number}|null;
    if (pending) return {status:409,data:{error:'Request already pending.',expires_at:pending.expires_at,cooldown_until:pending.expires_at,server_time:now}};
    const cooldown = (db.query("SELECT COALESCE(MAX(CASE WHEN status='DECLINED' THEN updated_at+? WHEN status IN ('PENDING','CANCELLED') THEN created_at+? ELSE 0 END),0) deadline FROM friend_requests WHERE requester_id=? AND recipient_id=?").get(REJECT_MS,PENDING_MS,player,target) as {deadline:number}).deadline;
    if (cooldown > now) return {status:429,data:{error:'Target cooldown active.',cooldown_until:cooldown,server_time:now}};
    const count = (sql: string, ...args: any[]) => (db.query(sql).get(...args) as {n: number}).n;
    if (count("SELECT count(*) AS n FROM friend_requests WHERE requester_id = ? AND status = 'PENDING'", player) >= 20 || count("SELECT count(*) AS n FROM friend_requests WHERE recipient_id = ? AND status = 'PENDING'", target) >= 100 || friendIds(player).length >= 200 || friendIds(target).length >= 200) return error(429, 'Friend request limit reached.');
    const request_id = crypto.randomUUID();
    db.query("INSERT INTO friend_requests VALUES (?, ?, ?, ?, ?, 'PENDING', ?, ?, ?)").run(request_id, player, target, low, high, now, now, now + PENDING_MS);
    return {status: 200, data: {request_id, status: 'PENDING', expires_at:now+PENDING_MS, cooldown_until:now+PENDING_MS, server_time:now}};
   });
  },
  respond(player: string, body: any): Result {
   if (!validId(body?.request_id) || typeof body?.accept !== 'boolean') return error(400, 'Invalid request_id or accept.');
   return mutate(player, body, 'respond', {request_id: body.request_id, accept: body.accept}, now => {
    const row = db.query('SELECT * FROM friend_requests WHERE request_id = ? AND recipient_id = ?').get(body.request_id, player) as any;
    if (!row) return error(404, 'Request unavailable.');
    if (row.status !== 'PENDING') return error(409, 'Request is no longer pending.');
    if (body.accept && (friendIds(row.requester_id).length >= 200 || friendIds(player).length >= 200)) return error(429, 'Friend limit reached.');
    const status = body.accept ? 'ACCEPTED' : 'DECLINED';
    if (body.accept) db.query('INSERT INTO friendships VALUES (?, ?, ?)').run(row.pair_low, row.pair_high, now);
    db.query('UPDATE friend_requests SET status = ?, updated_at = ? WHERE request_id = ?').run(status, now, row.request_id);
    return {status: 200, data: {request_id: row.request_id, status, ...(body.accept ? {} : {cooldown_until:now+REJECT_MS}), server_time:now}};
   });
  },
  cancel(player: string, body: any): Result {
   if (!validId(body?.request_id)) return error(400, 'Invalid request_id.');
   return mutate(player, body, 'cancel', {request_id: body.request_id}, now => {
    const row = db.query('SELECT status, created_at FROM friend_requests WHERE request_id = ? AND requester_id = ?').get(body.request_id, player) as any;
    if (!row) return error(404, 'Request unavailable.');
    if (row.status !== 'PENDING') return error(409, 'Request is no longer pending.');
    db.query("UPDATE friend_requests SET status = 'CANCELLED', updated_at = ? WHERE request_id = ?").run(now, body.request_id);
    return {status: 200, data: {request_id: body.request_id, status: 'CANCELLED', cooldown_until:row.created_at+PENDING_MS, server_time:now}};
   });
  }
 };
}
