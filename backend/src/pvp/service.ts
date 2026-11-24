import { activePractice } from "../practice_service";
import { combatHomunculusAllowed } from "../homunculus_catalog";
import type { Database } from "bun:sqlite";
import { createHmac, randomInt, randomUUID } from "node:crypto";
import { createPvpCombatState, createPvpFighter, validatePvpDecision, resolvePvpExchange, resolvePvpInspiration, type PvpSide, type PvpCatalogs, type PvpSnapshot } from "./combat";
import { createPvpRanking, pvpRank, pvpRatingDelta, pvpSeason } from "./ranking";
import { sanitizePvpEvent, projectPvpFighter } from "./projection";

const PVP_TURN_TIMEOUT_MS = 90_000;

export function pvpRandom(secret: Uint8Array, matchId: string, battle: number, turn: number, draw: number): number {
  if (!(secret instanceof Uint8Array) || secret.length < 32 || typeof matchId !== "string" || !matchId || ![battle, turn, draw].every(n => Number.isSafeInteger(n) && n >= 0)) throw new Error("INVALID_PVP_RNG_INPUT");
  return createHmac("sha256", secret).update(JSON.stringify(["ranked-pvp-v1", matchId, battle, turn, draw])).digest().readUInt32BE(0) / 0x100000000;
}

/** Construct a snapshot exclusively from persisted server state and catalog IDs. */
export function trustedPvpSnapshot(playerId: string, selection: any, state: any, catalogs: PvpCatalogs): PvpSnapshot | null {
  if (!selection || typeof selection !== "object" || Array.isArray(selection) || Object.keys(selection).some(k => !["entity_id", "weapon_ids", "homunculus_id", "spell_ids", "mode"].includes(k)) || !state || state.player_id !== playerId || !["attack", "defense"].includes(selection.mode)) return null;
  if (selection.homunculus_id !== null && !combatHomunculusAllowed(state.homunculus_progress, selection.homunculus_id)) return null;
  const entity = catalogs.entities.find(e => e.id === selection.entity_id);
  const weapons = selection.weapon_ids, ids = selection.spell_ids;
  if (!entity || !Array.isArray(weapons) || weapons.length !== 2 || weapons.some((id: any) => id !== null && (typeof id !== "string" || !catalogs.items.some(i => i.id === id && i.slot === "build"))) || (weapons[0] !== null && weapons[0] === weapons[1]) || !(selection.homunculus_id === null || (typeof selection.homunculus_id === "string" && catalogs.homunculi.some(h => h.id === selection.homunculus_id))) || !Array.isArray(ids) || ids.length !== 4 || new Set(ids).size !== 4) return null;
  const learned = state.spell_progress?.learned_by_entity?.[entity.id] ?? [];
  const defaults = catalogs.spells.filter(s => s.type === entity.type).map(s => s.id);
  const equipped = state.spell_progress?.equipped_by_mode?.[selection.mode]?.[entity.id] ?? defaults;
  if (!Array.isArray(learned) || !Array.isArray(equipped) || JSON.stringify(ids) !== JSON.stringify(equipped) || ids.some((id: any) => typeof id !== "string" || !catalogs.spells.some(s => s.id === id && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(entity.type) && learned.includes(id)))))) return null;
  return { player_id: playerId, entity_id: entity.id, weapon_ids: [...weapons], homunculus_id: selection.homunculus_id, spell_ids: [...ids], item_progress: structuredClone(state.item_progress ?? {}), homunculus_progress: structuredClone(state.homunculus_progress ?? {}), spell_progress: structuredClone(state.spell_progress ?? {}) };
}

/** Called within the caller's immediate transaction with server-validated snapshots. */
export function createSharedPvpMatch(db: Database, catalogs: PvpCatalogs, a: PvpSnapshot, b: PvpSnapshot, now: number, kind: "ranked" | "friendly", inviteId: string | null = null, playbackProtocol = 0) {
  if (a.player_id === b.player_id || "error" in createPvpFighter(a, catalogs) || "error" in createPvpFighter(b, catalogs)) throw new Error("UNTRUSTED_SETUP");
  const [left, right] = randomInt(2) === 0 ? [a,b] : [b,a];
  const combat = createPvpCombatState(left, right, catalogs);
  if ("error" in combat) throw new Error(combat.error);
  const id = randomUUID(), season = pvpSeason(now);
  const rankings = createPvpRanking(db, () => now);
  const leftRating = kind === "ranked" ? rankings.ensure(season, left.player_id, now).rating : null;
  const rightRating = kind === "ranked" ? rankings.ensure(season, right.player_id, now).rating : null;
  db.query("INSERT INTO pvp_matches (match_id,status,created_at,updated_at,revision,combat_state_json,season,decision_deadline,kind,invite_id) VALUES (?,'ACTIVE',?,?,1,?,?,?,?,?)").run(id,now,now,JSON.stringify(combat),kind === "ranked" ? season : null,now+PVP_TURN_TIMEOUT_MS,kind,inviteId);
  if (playbackProtocol === 1) db.query("UPDATE pvp_matches SET playback_protocol=1, decision_deadline=? WHERE match_id=?").run(now+60_000,id);
  const member = db.query("INSERT INTO pvp_match_players (match_id,player_id,side,snapshot_json,active,last_seen_at,start_rating) VALUES (?,?,?,?,1,?,?)");
  member.run(id,left.player_id,"LEFT",JSON.stringify(left),now,leftRating);
  member.run(id,right.player_id,"RIGHT",JSON.stringify(right),now,rightRating);
  return id;
}

/** The caller must authenticate the user and construct a snapshot from authoritative
 * storage. Never pass a client-supplied snapshot to this service. */
export function createPvpQueue(db: Database, catalogs: PvpCatalogs, trustedSnapshot: (playerId: string, selection: unknown) => PvpSnapshot | null, clock: () => number = Date.now) {
  if (typeof trustedSnapshot !== "function") throw new Error("PVP_OWNERSHIP_VERIFIER_REQUIRED");
  const expire = db.prepare("DELETE FROM pvp_queue WHERE expires_at <= ?");
  const queued = db.prepare("SELECT player_id, queued_at, expires_at, snapshot_json FROM pvp_queue WHERE player_id = ?");
  const active = db.prepare("SELECT p.match_id, m.kind FROM pvp_match_players p JOIN pvp_matches m ON m.match_id=p.match_id WHERE p.player_id = ? AND p.active = 1");
  const first = db.prepare("SELECT q.player_id, q.queued_at, q.expires_at, q.snapshot_json FROM pvp_queue q WHERE q.player_id <> ? AND NOT EXISTS (SELECT 1 FROM forest_duel_reservations r JOIN forest_duel_invites i ON i.invite_id=r.invite_id WHERE r.player_id=q.player_id AND i.status IN ('PENDING','ACCEPTED') AND i.expires_at>?) ORDER BY q.queued_at, q.rowid LIMIT 1");
  const insert = db.prepare("INSERT INTO pvp_queue (player_id, queued_at, expires_at, snapshot_json) VALUES (?, ?, ?, ?)");
  const remove = db.prepare("DELETE FROM pvp_queue WHERE player_id = ?");
  const validId = (id: string) => typeof id === "string" && id.length > 0 && id.length <= 256;
  return {
    state(playerId: string) {
      if (!validId(playerId)) throw new Error("INVALID_PLAYER");
      return db.transaction(() => {
        expire.run(clock());
        const found = queued.get(playerId) as any, current = active.get(playerId) as any;
        return current ? (current.kind === "friendly" ? { state: "FRIENDLY_ACTIVE" } : { state: "MATCHED", match_id: current.match_id }) : found ? { state: "QUEUED", joined_at: found.queued_at, expires_at: found.expires_at } : { state: "IDLE" };
      }).immediate();
    },
    cancel(playerId: string) {
      if (!validId(playerId)) throw new Error("INVALID_PLAYER");
      return db.transaction(() => {
        expire.run(clock()); remove.run(playerId);
        const current = active.get(playerId) as any;
        return current ? (current.kind === "friendly" ? { state: "FRIENDLY_ACTIVE" } : { state: "MATCHED", match_id: current.match_id }) : { state: "IDLE" };
      }).immediate();
    },
    join(playerId: string, selection: unknown, playbackProtocol?: number) {
      if (!validId(playerId)) throw new Error("INVALID_PLAYER");
      if (playbackProtocol !== undefined && playbackProtocol !== 1) throw new Error("INVALID_REQUEST");
      return db.transaction(() => {
        const now = clock(); expire.run(now);
        const current = active.get(playerId) as any;
        if (current) return current.kind === "friendly" ? { state: "FRIENDLY_ACTIVE" } : { state: "MATCHED", match_id: current.match_id };
        db.query("UPDATE forest_duel_invites SET status='EXPIRED', updated_at=? WHERE status IN ('PENDING','ACCEPTED') AND expires_at<=?").run(now,now);
        db.query("DELETE FROM forest_duel_reservations WHERE invite_id IN (SELECT invite_id FROM forest_duel_invites WHERE status='EXPIRED')").run();
        if (db.query("SELECT 1 FROM forest_duel_reservations r JOIN forest_duel_invites i ON i.invite_id=r.invite_id WHERE r.player_id=? AND i.status IN ('PENDING','ACCEPTED') AND i.expires_at>?").get(playerId,now)) throw new Error("PLAYER_BUSY");
        const previous = queued.get(playerId) as any;
        if (previous) {
          const stored = JSON.parse(previous.snapshot_json);
          if (JSON.stringify(stored.selection) !== JSON.stringify(selection) || (stored.playback_protocol ?? 0) !== (playbackProtocol ?? 0)) throw new Error("QUEUE_CONFLICT");
          return { state: "QUEUED", joined_at: previous.queued_at, expires_at: previous.expires_at };
        }
        if (activePractice(db,playerId,now)) throw new Error("PLAYER_BUSY");
        const snapshot = trustedSnapshot(playerId, selection);
        if (!snapshot || snapshot.player_id !== playerId || "error" in createPvpFighter(snapshot, catalogs)) throw new Error("UNTRUSTED_SETUP");
        let opponent = first.get(playerId,now) as any, other: PvpSnapshot | null = null;
        while (opponent) {
          const stored = JSON.parse(opponent.snapshot_json);
          other = stored.snapshot ?? null;
          if (other && other.player_id === opponent.player_id && other.player_id !== playerId && !("error" in createPvpFighter(other, catalogs))) break;
          remove.run(opponent.player_id); opponent = first.get(playerId,now) as any;
        }
        if (!opponent || !other) { insert.run(playerId, now, now + 3_600_000, JSON.stringify({selection, snapshot, ...(playbackProtocol === 1 ? {playback_protocol:1} : {})})); return { state: "QUEUED", joined_at: now, expires_at: now + 3_600_000 }; }
        const id = createSharedPvpMatch(db,catalogs,snapshot,other,now,"ranked",null,playbackProtocol === 1 && JSON.parse(opponent.snapshot_json).playback_protocol === 1 ? 1 : 0);
        remove.run(other.player_id);
        return { state: "MATCHED", match_id: id };
      }).immediate();
    }
  };
}

export function queueAction(db: Database, player: string, clientId: string, request: unknown, perform: () => unknown, clock: () => number = Date.now) {
  if (typeof clientId !== "string" || !clientId.trim() || clientId.length > 64 || /[\u0000-\u001f\u007f-\u009f]/u.test(clientId)) throw new Error("INVALID_ACTION_ID");
  return db.transaction(() => {
    const payload = JSON.stringify(request);
    const prior = db.query("SELECT request_json, response_json FROM pvp_actions WHERE player_id = ? AND client_action_id = ?").get(player,clientId) as any;
    if (prior) { if (prior.request_json !== payload) throw new Error("ACTION_CONFLICT"); return JSON.parse(prior.response_json); }
    const response = perform();
    db.query("INSERT INTO pvp_actions (player_id, client_action_id, request_json, response_json, created_at) VALUES (?, ?, ?, ?, ?)").run(player,clientId,payload,JSON.stringify(response),clock());
    return response;
  }).immediate();
}

/** Internal settlement primitive. Caller must derive the result from trusted combat
 * or timeout/forfeit processing, never from an HTTP request body. */
export function settlePvpMatch(db: Database, matchId: string, winner: "left" | "right" | "draw", now: number, reward?: (playerId:string, snapshotJson:string, now:number)=>any) {
  if (typeof matchId !== "string" || !matchId || !["left", "right", "draw"].includes(winner)) throw new Error("INVALID_RESULT");
  const currentSeason = pvpSeason(now);
  return db.transaction(() => {
    const match = db.query("SELECT status, season, result_json, kind FROM pvp_matches WHERE match_id = ?").get(matchId) as any;
    if (!match) throw new Error("MATCH_NOT_FOUND");
    if (match.status === "FINISHED") { const prior = JSON.parse(match.result_json); if (prior.result !== winner) throw new Error("RESULT_CONFLICT"); return prior; }
    let xp: any = null;
    if (reward && winner !== "draw") {
      const participants = db.query("SELECT player_id,side,snapshot_json FROM pvp_match_players WHERE match_id=?").all(matchId) as any[];
      const victor = participants.find(p=>p.side.toLowerCase()===winner), opponent = participants.find(p=>p.side.toLowerCase()!==winner);
      if (!victor || !opponent) throw new Error("INVALID_MATCH_STATE");
      const day = Math.floor(now / 86_400_000) * 86_400_000;
      const count = match.kind === "friendly" ? (db.query("SELECT count(*) n FROM pvp_xp_rewards r JOIN pvp_matches m ON m.match_id=r.match_id WHERE r.winner_id=? AND r.opponent_id=? AND r.rewarded_at>=? AND r.rewarded_at<? AND m.kind='friendly'").get(victor.player_id,opponent.player_id,day,day+86_400_000) as any).n : 0;
      if (match.kind !== "friendly" || count < 3) {
        xp = reward(victor.player_id,victor.snapshot_json,now);
        if (xp && xp.xp_granted > 0) db.query("INSERT INTO pvp_xp_rewards VALUES (?,?,?,?)").run(matchId,victor.player_id,opponent.player_id,now);
      }
    }
    if (match.kind === "friendly") {
      const result = {result: winner, ...(xp ? {xp} : {})};
      db.query("UPDATE pvp_matches SET status='FINISHED', result_json=?, settled_at=?, updated_at=?, revision=revision+1 WHERE match_id=? AND status='ACTIVE'").run(JSON.stringify(result),now,now,matchId);
      db.query("UPDATE pvp_match_players SET active=0 WHERE match_id=?").run(matchId);
      return result;
    }
    if (match.kind !== "ranked") throw new Error("INVALID_MATCH_KIND");
    const rows = db.query("SELECT player_id, side, start_rating FROM pvp_match_players WHERE match_id = ?").all(matchId) as any[];
    const left = rows.find(r => r.side === "LEFT"), right = rows.find(r => r.side === "RIGHT");
    if (rows.length !== 2 || !left || !right || ![left.start_rating, right.start_rating].every(n => Number.isSafeInteger(n) && n >= 0) || !/^\d{4}-(0[1-9]|1[0-2])$/.test(match.season ?? "")) throw new Error("INVALID_MATCH_STATE");
    const delta = (own: any, rival: any, side: string) => match.season !== currentSeason || winner === "draw" ? 0 : pvpRatingDelta(own.start_rating, rival.start_rating, winner === side ? "win" : "loss");
    const ld = delta(left,right,"left"), rd = delta(right,left,"right");
    if (match.season === currentSeason) for (const [row, change] of [[left,ld],[right,rd]] as [any,number][]) {
      if (db.query("UPDATE pvp_season_ratings SET rating = MAX(0, rating + ?), updated_at = ? WHERE season = ? AND player_id = ?").run(change, now, match.season, row.player_id).changes !== 1) throw new Error("INVALID_RATING_STATE");
    }
    const currentRating = db.query("SELECT rating FROM pvp_season_ratings WHERE season = ? AND player_id = ?");
    const totals = { left: (currentRating.get(currentSeason, left.player_id) as any)?.rating ?? 1000, right: (currentRating.get(currentSeason, right.player_id) as any)?.rating ?? 1000 };
    const result = { result: winner, season: match.season, deltas: { left: ld, right: rd }, totals, ...(xp ? {xp} : {}) };
    db.query("UPDATE pvp_matches SET status = 'FINISHED', result_json = ?, settled_at = ?, updated_at = ?, revision = revision + 1 WHERE match_id = ? AND status = 'ACTIVE'").run(JSON.stringify(result),now,now,matchId);
    db.query("UPDATE pvp_match_players SET active = 0 WHERE match_id = ?").run(matchId);
    return result;
  }).immediate();
}

/** Private match chat; the caller authenticates playerId before invoking these methods. */
export function createPvpChat(db: Database, clock: () => number = Date.now) {
  const participant = db.prepare("SELECT 1 FROM pvp_match_players WHERE match_id = ? AND player_id = ?");
  const previous = db.prepare("SELECT id, match_id, player_id, client_message_id, text, created_at FROM pvp_chat WHERE match_id = ? AND player_id = ? AND client_message_id = ?");
  const recent = db.prepare("SELECT created_at FROM pvp_chat WHERE player_id = ? ORDER BY id DESC LIMIT 1");
  const messages = db.prepare("SELECT id, player_id, text, created_at FROM pvp_chat WHERE match_id = ? AND id > ? ORDER BY id ASC LIMIT 100");
  const insert = db.prepare("INSERT INTO pvp_chat (match_id, player_id, client_message_id, text, created_at) VALUES (?, ?, ?, ?, ?)");
  const textValid = (value: any, max: number) => typeof value === "string" && !!value.trim() && [...value].length <= max && !/[\u0000-\u001f\u007f-\u009f]/u.test(value);
  const authorize = (match: string, player: string) => { if (!textValid(match,256) || !textValid(player,256) || !participant.get(match,player)) throw new Error("MATCH_NOT_FOUND"); };
  return {
    list(match: string, player: string, after = 0) {
      authorize(match,player); if (!Number.isSafeInteger(after) || after < 0) throw new Error("INVALID_CURSOR");
      return messages.all(match,after);
    },
    send(match: string, player: string, clientId: string, text: string) {
      if (!textValid(clientId,200) || !textValid(text,200)) throw new Error("INVALID_CHAT");
      return db.transaction(() => {
        authorize(match,player);
        const existing = previous.get(match,player,clientId) as any;
        if (existing) { if (existing.text !== text) throw new Error("ACTION_CONFLICT"); return { message: existing, duplicate: true }; }
        const now = clock(), last = recent.get(player) as any;
        if (last && now - last.created_at < 10_000) throw new Error("CHAT_RATE_LIMIT");
        insert.run(match,player,clientId,text,now);
        return { message: previous.get(match,player,clientId), duplicate: false };
      }).immediate();
    }
  };
}

/** Server-only match coordinator. Every method requires a previously authenticated player ID. */
export function createPvpMatches(db: Database, secret: Uint8Array, clock: () => number = Date.now, reward?: (playerId:string, snapshotJson:string, now:number)=>any) {
  if (!(secret instanceof Uint8Array) || secret.length < 32) throw new Error("PVP_SECRET_REQUIRED");
  const get = db.prepare("SELECT m.*, p.side FROM pvp_matches m JOIN pvp_match_players p ON p.match_id = m.match_id WHERE m.match_id = ? AND p.player_id = ?");
  const pending = db.prepare("SELECT player_id, decision_json FROM pvp_decisions WHERE match_id = ? AND revision = ?");
  const players = db.prepare("SELECT p.player_id, p.side, u.display_name FROM pvp_match_players p JOIN players u ON u.player_id = p.player_id WHERE p.match_id = ?");
  const action = db.prepare("SELECT request_json, response_json FROM pvp_actions WHERE player_id = ? AND client_action_id = ?");
  const eventRows = db.prepare("SELECT seq, payload_json FROM pvp_events WHERE match_id = ? AND seq > ? ORDER BY seq LIMIT 500");
  const sides: PvpSide[] = ["left", "right"];
  const parse = (row: any) => JSON.parse(row.combat_state_json);
  const rng = (id: string, state: any) => (turn: number, draw: number) => pvpRandom(secret,id,state.battle_index,turn,draw);
  const members = (id: string) => players.all(id) as any[];
  const event = (id: string, entry: any, now: number) => {
    const n = (db.query("SELECT COALESCE(MAX(seq),0)+1 n FROM pvp_events WHERE match_id = ?").get(id) as any).n;
    db.query("INSERT INTO pvp_events (match_id, seq, kind, visibility, payload_json, created_at) VALUES (?, ?, ?, 'public', ?, ?)").run(id,n,String(entry.kind ?? "event"),JSON.stringify(entry),now);
  };
  const dto = (row: any, viewerId: string, after: number) => {
    const state = parse(row), viewer = row.side.toLowerCase() as PvpSide, rival: PvpSide = viewer === "left" ? "right" : "left", entries = members(row.match_id), decisions = pending.all(row.match_id,row.revision) as any[];
    const present = (side: PvpSide) => projectPvpFighter(state, side, viewer, entries.find(e => e.side.toLowerCase() === side));
    const finished = row.result_json ? JSON.parse(row.result_json) : null;
    const total = finished?.totals?.[viewer];
    const result = finished ? { result: finished.result === "draw" ? "draw" : finished.result === viewer ? "win" : "loss", ...(finished.result === viewer && finished.xp ? {homunculus_xp: finished.xp} : {}), ...(row.kind === "ranked" ? { mp_delta: finished.deltas?.[viewer] ?? 0, season: finished.season, ...(Number.isSafeInteger(total) && total >= 0 ? { mp_total_after: total, ...pvpRank(total) } : {}) } : {}) } : null;
    const anomaly = state.physical_anomaly ? { id: state.physical_anomaly.id, favored_type: state.physical_anomaly.favored_type, weakened_type: state.physical_anomaly.weakened_type, remaining_exchanges: state.physical_anomaly.remaining_exchanges } : null;
    return { match_id: row.match_id, kind: row.kind, status: row.status, combat_revision: row.revision, deadline: row.status === "ACTIVE" ? row.decision_deadline : null, ...(row.playback_protocol === 1 ? {phase:row.phase, server_time:clock(), playback_revision:row.phase === "PLAYBACK" ? row.revision : null, playback_until:row.phase === "PLAYBACK" ? row.decision_deadline : null, playback_event_end:row.playback_event_end} : {}), turn: state.turn, round: state.round, battle_index: state.battle_index, sudden_death: state.sudden_death, physical_anomaly: anomaly, score: { player: state.wins[viewer], enemy: state.wins[rival] }, player: present(viewer), enemy: present(rival), ready: { player: decisions.some(d => d.player_id === viewerId), enemy: decisions.some(d => d.player_id !== viewerId) }, result, events: (eventRows.all(row.match_id,after) as any[]).map(e => sanitizePvpEvent(JSON.parse(e.payload_json),viewer,e.seq)) };
  };
  const advance = (row: any, now: number, timeout: boolean) => {
    const eventStart = (db.query("SELECT COALESCE(MAX(seq),0) n FROM pvp_events WHERE match_id=?").get(row.match_id) as any).n;
    let state = parse(row); const entries = members(row.match_id), choices = pending.all(row.match_id,row.revision) as any[];
    const bySide: any = {}; for (const c of choices) { const m = entries.find(e => e.player_id === c.player_id); if (m) bySide[m.side.toLowerCase()] = JSON.parse(c.decision_json); }
    const inspiration = sides.filter(side => state.fighters[side].inspiration_pending);
    if (inspiration.length) {
      if (!timeout && inspiration.some(side => !bySide[side])) return;
      for (const side of inspiration) {
        const decision = bySide[side] ?? {kind:"decline"};
        const out = resolvePvpInspiration(state,side,decision,rng(row.match_id,state));
        if ("error" in out) throw new Error(out.error);
        state = out.state; for (const e of out.events) event(row.match_id,e,now);
      }
    } else {
      const missing = sides.filter(side => !bySide[side]);
      if (missing.length) {
        if (!timeout) return;
        const winner = missing.length === 2 ? "draw" : missing[0] === "left" ? "right" : "left";
        settlePvpMatch(db,row.match_id,winner,now); event(row.match_id,{kind:"match_timeout",result:winner,turn:state.turn},now); return;
      }
      const out = resolvePvpExchange(state,bySide.left,bySide.right,rng(row.match_id,state));
      if ("error" in out) throw new Error(out.error);
      state = out.state; for (const e of out.events) event(row.match_id,e,now);
    }
    const end = (db.query("SELECT COALESCE(MAX(seq),0) n FROM pvp_events WHERE match_id=?").get(row.match_id) as any).n;
    const playback = row.playback_protocol === 1 && !state.match_result;
    const deadline = playback ? now + Math.min(45_000, (end-eventStart)*1350 + 6000) : now + (row.playback_protocol === 1 ? 60_000 : PVP_TURN_TIMEOUT_MS);
    db.query("UPDATE pvp_matches SET combat_state_json = ?, revision = revision + 1, updated_at = ?, decision_deadline = ?, phase=?, playback_event_end=? WHERE match_id = ? AND status = 'ACTIVE'").run(JSON.stringify(state),now,deadline,playback ? "PLAYBACK" : "DECISION",end,row.match_id);
    if (state.match_result) settlePvpMatch(db,row.match_id,state.match_result,now,timeout ? undefined : reward);
  };
  const checkTimeout = (row: any, now: number) => { if (row.status === "ACTIVE" && row.decision_deadline <= now) { if (row.phase === "PLAYBACK") db.query("UPDATE pvp_matches SET phase='DECISION', decision_deadline=?, updated_at=? WHERE match_id=?").run(now+60_000,now,row.match_id); else advance(row,now,true); } };
  const lookup = (id: string, player: string) => { const row = get.get(id,player) as any; if (!row) throw new Error("MATCH_NOT_FOUND"); return row; };
  const transactAction = (id: string, player: string, clientId: string, request: any, fn: (row: any, now: number) => void) => {
    if (typeof clientId !== "string" || !clientId.trim() || clientId.length > 64 || /[\u0000-\u001f\u007f-\u009f]/u.test(clientId)) throw new Error("INVALID_ACTION_ID");
    return db.transaction(() => {
      let row = lookup(id,player); const body = JSON.stringify({match_id:id,...request}), old = action.get(player,clientId) as any;
      if (old) { if (old.request_json !== body) throw new Error("ACTION_CONFLICT"); return JSON.parse(old.response_json); }
      const now = clock(), timedOut = row.status === "ACTIVE" && row.phase !== "PLAYBACK" && row.decision_deadline <= now;
      checkTimeout(row,now); row = lookup(id,player);
      if (!timedOut) { if (row.status !== "ACTIVE") throw new Error("MATCH_FINISHED"); fn(row,now); row = lookup(id,player); }
      const response = dto(row,player,0);
      db.query("INSERT INTO pvp_actions (player_id, client_action_id, request_json, response_json, created_at) VALUES (?, ?, ?, ?, ?)").run(player,clientId,body,JSON.stringify(response),now);
      return response;
    }).immediate();
  };
  return {
    locate(player: string, kind = "ranked") {
      const row = db.query("SELECT m.match_id FROM pvp_match_players p JOIN pvp_matches m ON m.match_id = p.match_id WHERE p.player_id = ? AND m.kind=? ORDER BY p.active DESC, m.created_at DESC, m.match_id DESC LIMIT 1").get(player,kind) as any;
      return row?.match_id ?? null;
    },
    sweep() {
      const now = clock(), expired = db.query("SELECT match_id FROM pvp_matches WHERE status = 'ACTIVE' AND decision_deadline <= ? ORDER BY decision_deadline LIMIT 100").all(now) as any[];
      for (const item of expired) db.transaction(() => {
        const member = db.query("SELECT player_id FROM pvp_match_players WHERE match_id = ? LIMIT 1").get(item.match_id) as any;
        if (member) checkTimeout(lookup(item.match_id,member.player_id),now);
      }).immediate();
      return expired.length;
    },
    state(id: string, player: string, after = 0) { if (!Number.isSafeInteger(after) || after < 0) throw new Error("INVALID_CURSOR"); return db.transaction(() => { const row = lookup(id,player); checkTimeout(row,clock()); return dto(lookup(id,player),player,after); }).immediate(); },
    decide(id: string, player: string, clientId: string, revision: number, decision: any) {
      return transactAction(id,player,clientId,{kind:"decision",revision,decision},(row,now) => {
        if (row.phase === "PLAYBACK") throw new Error("PLAYBACK_PENDING");
        if (!Number.isSafeInteger(revision) || revision !== row.revision) throw new Error("STALE_REVISION");
        const state = parse(row), side = row.side.toLowerCase() as PvpSide;
        if (state.fighters.left.inspiration_pending || state.fighters.right.inspiration_pending) {
          if (!state.fighters[side].inspiration_pending) throw new Error("INVALID_DECISION");
          if ("error" in resolvePvpInspiration(state,side,decision,rng(id,state))) throw new Error("INVALID_DECISION");
        } else if ("error" in validatePvpDecision(state,side,decision)) throw new Error("INVALID_DECISION");
        if ((pending.all(id,row.revision) as any[]).some(e => e.player_id === player)) throw new Error("DECISION_ALREADY_SUBMITTED");
        db.query("INSERT INTO pvp_decisions (match_id, player_id, revision, client_action_id, decision_json, created_at) VALUES (?, ?, ?, ?, ?, ?)").run(id,player,row.revision,clientId,JSON.stringify(decision),now);
        advance(row,now,false);
      });
    },
    ack(id: string, player: string, revision: number) {
      if (!Number.isSafeInteger(revision) || revision < 1) throw new Error("INVALID_REQUEST");
      return db.transaction(() => {
        const now=clock(); let row=lookup(id,player); checkTimeout(row,now); row=lookup(id,player);
        if (row.playback_protocol !== 1 || row.revision !== revision) throw new Error("STALE_REVISION");
        if (row.status === "ACTIVE" && row.phase === "PLAYBACK") {
          db.query("UPDATE pvp_match_players SET playback_ack_revision=? WHERE match_id=? AND player_id=?").run(revision,id,player);
          const count=(db.query("SELECT count(*) n FROM pvp_match_players WHERE match_id=? AND playback_ack_revision=?").get(id,revision) as any).n;
          if (count === 2) db.query("UPDATE pvp_matches SET phase='DECISION', decision_deadline=?, updated_at=? WHERE match_id=?").run(now+60_000,now,id);
        }
        return dto(lookup(id,player),player,0);
      }).immediate();
    },
    forfeit(id: string, player: string, clientId: string) {
      return transactAction(id,player,clientId,{kind:"forfeit"},(row,now) => {
        const winner = row.side === "LEFT" ? "right" : "left"; settlePvpMatch(db,id,winner,now); event(id,{kind:"forfeit",result:winner,side:row.side.toLowerCase(),turn:parse(row).turn},now);
      });
    }
  };
}

/** Route adapter; all callers must authenticate before dispatch. */
export function dispatchPvpRequest(services: {db: Database; queue: ReturnType<typeof createPvpQueue>; matches: ReturnType<typeof createPvpMatches>; chat: ReturnType<typeof createPvpChat>; ranking: ReturnType<typeof createPvpRanking>}, player: string, method: string, path: string, body: any, query: URLSearchParams, kind: "ranked" | "friendly" = "ranked") {
  const {db,queue,matches,chat,ranking}=services;
  if (kind === "friendly") path = path.replace("/forest/duels/match/", "/pvp/match/");
  const authorize = (id: string) => { if (!db.query("SELECT 1 FROM pvp_matches m JOIN pvp_match_players p ON p.match_id=m.match_id WHERE m.match_id=? AND m.kind=? AND p.player_id=?").get(id,kind,player)) throw new Error("MATCH_NOT_FOUND"); };
  const fields = (v: any, allowed: string[]) => v && typeof v === "object" && !Array.isArray(v) && Object.keys(v).every(k=>allowed.includes(k));
  const cursor = () => { const raw=query.get("after") ?? "0"; if (!/^\d+$/.test(raw)) throw new Error("INVALID_CURSOR"); const value=Number(raw); if (!Number.isSafeInteger(value)) throw new Error("INVALID_CURSOR"); return value; };
  if (method === "GET" && path === "/pvp/queue/state") return queue.state(player);
  if (method === "GET" && path === "/pvp/leaderboard") { if (query.getAll("season").length > 1) throw new Error("INVALID_SEASON"); return ranking.leaderboard(player, query.get("season")); }
  if (method === "GET" && path === "/pvp/match/state") { const id=query.get("match_id") ?? matches.locate(player,kind); if (!id) return {match:null}; authorize(id); const raw=query.get("chat_after") ?? "0", chatAfter=Number(raw); if (!/^\d+$/.test(raw) || !Number.isSafeInteger(chatAfter)) throw new Error("INVALID_CURSOR"); return { ...matches.state(id,player,cursor()), chat: chat.list(id,player,chatAfter) }; }
  if (method === "POST" && path === "/pvp/queue/join") {
    if (!fields(body,["client_action_id","selection","playback_protocol"])) throw new Error("INVALID_REQUEST");
    return queueAction(db,player,body.client_action_id,{kind:"queue_join",selection:body.selection,...(body.playback_protocol === undefined ? {} : {playback_protocol:body.playback_protocol})},()=>queue.join(player,body.selection,body.playback_protocol));
  }
  if (method === "POST" && path === "/pvp/queue/cancel") {
    if (!fields(body,["client_action_id"])) throw new Error("INVALID_REQUEST");
    return queueAction(db,player,body.client_action_id,{kind:"queue_cancel"},()=>queue.cancel(player));
  }
  if (method === "POST" && path === "/pvp/match/decision") {
    if (!fields(body,["match_id","client_action_id","combat_revision","decision"]) || typeof body.match_id !== "string") throw new Error("INVALID_REQUEST");
    authorize(body.match_id); return matches.decide(body.match_id,player,body.client_action_id,body.combat_revision,body.decision);
  }
  if (method === "POST" && path === "/pvp/match/playback_ack") {
    if (!fields(body,["match_id","playback_revision"]) || typeof body.match_id !== "string") throw new Error("INVALID_REQUEST");
    authorize(body.match_id); return matches.ack(body.match_id,player,body.playback_revision);
  }
  if (method === "POST" && path === "/pvp/match/forfeit") {
    if (!fields(body,["match_id","client_action_id"]) || typeof body.match_id !== "string") throw new Error("INVALID_REQUEST");
    authorize(body.match_id); return matches.forfeit(body.match_id,player,body.client_action_id);
  }
  if (method === "POST" && path === "/pvp/match/chat") {
    if (!fields(body,["match_id","client_message_id","text"]) || typeof body.match_id !== "string") throw new Error("INVALID_REQUEST");
    authorize(body.match_id); const sent=chat.send(body.match_id,player,body.client_message_id,body.text);
    return {message:sent.message,duplicate:sent.duplicate};
  }
  throw new Error("UNKNOWN_ROUTE");
}
