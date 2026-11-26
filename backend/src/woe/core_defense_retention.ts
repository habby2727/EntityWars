import {maintainMonthlyScores} from './core_defense_leaderboard';
﻿import type {Database} from 'bun:sqlite';

// Called inside the scheduler's fenced transaction, even when WOE is disabled.
// Every selection is capped; more work is picked up on later maintenance passes.
export function cleanupCoreDefense(db:Database,now:number) {
 maintainMonthlyScores(db,now);
 const limit=32, rows=(sql:string,...args:any[])=>db.query(sql).all(...args) as any[];
 for(const r of rows("SELECT r.room_id FROM woe_rooms r JOIN core_defense_rooms c ON c.room_id=r.room_id WHERE r.status='WAITING' AND r.expires_at<=? ORDER BY r.expires_at LIMIT ?",now,limit)) {
  db.query("UPDATE woe_rooms SET status='EXPIRED',updated_at=? WHERE room_id=? AND status='WAITING'").run(now,r.room_id);
  db.query('DELETE FROM woe_members WHERE room_id=?').run(r.room_id);
 }
 // Advance the durable high-water mark before deleting a replay record. A clock
 // rollback after cleanup must never make the deleted timestamp acceptable again.
 for(const a of rows("SELECT a.match_id,a.player_id,a.action_id FROM core_defense_actions a JOIN core_defense_participants p ON p.match_id=a.match_id AND p.controller_id=a.player_id WHERE a.kind='deploy' AND a.expires_at<? ORDER BY a.expires_at LIMIT ?",now,limit)) {
  db.query('UPDATE core_defense_participants SET replay_watermark=max(replay_watermark,?) WHERE match_id=? AND controller_id=?').run(now,a.match_id,a.player_id);
  db.query('DELETE FROM core_defense_actions WHERE match_id=? AND player_id=? AND action_id=?').run(a.match_id,a.player_id,a.action_id);
 }
 // Keep room markers until the match and its retained score are gone, including
 // installations that do not enforce foreign keys.
 for(const r of rows("SELECT r.room_id FROM woe_rooms r JOIN core_defense_rooms c ON c.room_id=r.room_id WHERE r.status='EXPIRED' AND r.updated_at<=? AND NOT EXISTS (SELECT 1 FROM woe_matches m WHERE m.room_id=r.room_id) ORDER BY r.updated_at LIMIT ?",now-7*86_400_000,limit)) {
  db.query('DELETE FROM woe_members WHERE room_id=?').run(r.room_id);
  db.query('DELETE FROM core_defense_rooms WHERE room_id=?').run(r.room_id);
  db.query('DELETE FROM woe_rooms WHERE room_id=?').run(r.room_id);
 }
 for(const r of rows('SELECT c.room_id FROM core_defense_rooms c WHERE NOT EXISTS (SELECT 1 FROM woe_rooms r WHERE r.room_id=c.room_id) AND NOT EXISTS (SELECT 1 FROM woe_matches m WHERE m.room_id=c.room_id) LIMIT ?',limit)) db.query('DELETE FROM core_defense_rooms WHERE room_id=?').run(r.room_id);
 for(const table of ['core_defense_actions','core_defense_participants','core_defense_results']) {
  const ids=rows(`SELECT rowid AS id FROM ${table} t WHERE NOT EXISTS (SELECT 1 FROM woe_matches m WHERE m.match_id=t.match_id) LIMIT ?`,limit);
  for(const r of ids)db.query(`DELETE FROM ${table} WHERE rowid=?`).run(r.id);
 }
 // Composite participant references can also be orphaned when FK enforcement
 // was disabled while a match still existed.
 for(const table of ['core_defense_actions','core_defense_participants']) {
  const playerColumn=table==='core_defense_actions'?'player_id':'controller_id';
  const ids=rows(`SELECT rowid AS id FROM ${table} t WHERE NOT EXISTS (SELECT 1 FROM woe_match_participants p WHERE p.match_id=t.match_id AND p.controller_id=t.${playerColumn}) LIMIT ?`,limit);
  for(const r of ids)db.query(`DELETE FROM ${table} WHERE rowid=?`).run(r.id);
 }
 for(const a of rows("SELECT rowid AS id FROM woe_actions WHERE action_type LIKE 'cd:%' AND created_at<=? LIMIT ?",now-7*86_400_000,limit))db.query('DELETE FROM woe_actions WHERE rowid=?').run(a.id);
}
