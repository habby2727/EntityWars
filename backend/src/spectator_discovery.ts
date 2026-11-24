import type { Database } from "bun:sqlite";

/** Discover only initialized live combat for a bounded list of authenticated friends.
 * This function is read-only and never invokes a participant session service. */
export function spectatableActivities(db: Database, friends: string[], now: number): Map<string, string> {
  if (!friends.length) return new Map();
  const rows = db.query(`WITH requested(id) AS (SELECT value FROM json_each(?)), candidates AS (
    SELECT p.player_id, m.kind AS mode, 0 AS priority, m.created_at AS started
      FROM requested r JOIN pvp_match_players p ON p.player_id=r.id AND p.active=1
      JOIN pvp_matches m ON m.match_id=p.match_id AND m.status='ACTIVE'
    UNION ALL
    SELECT s.player_id, 'practice', 1, s.created_at FROM requested r
      JOIN practice_sessions s ON s.player_id=r.id AND s.status='ACTIVE' AND s.expires_at>?
    UNION ALL
    SELECT s.player_id, 'hunt', 2, s.started_at FROM requested r
      JOIN solo_hunt_sessions s ON s.player_id=r.id AND s.status='ACTIVE' AND s.expires_at>? AND s.combat_state_json IS NOT NULL
    UNION ALL
    SELECT d.player_id, 'dungeon', 3, d.started_at FROM requested r
      JOIN dungeon_runs d ON d.player_id=r.id AND d.status='ACTIVE' AND d.expires_at>? AND d.combat_state_json IS NOT NULL
      WHERE json_valid(d.combat_state_json) AND json_extract(d.combat_state_json,'$.terminal_result') IS NULL
    UNION ALL
    SELECT e.player_id, 'expedition', 4, e.started_at FROM requested r
      JOIN expedition_runs e ON e.player_id=r.id AND e.status='ACTIVE' AND e.heartbeat_at>?
      WHERE json_valid(e.state_json) AND json_extract(e.state_json,'$.phase')='COMBAT'
  ), ranked AS (SELECT player_id,mode,ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY priority,started DESC) AS position FROM candidates)
  SELECT player_id,mode FROM ranked WHERE position=1`).all(JSON.stringify(friends),now,now,now,now-240_000) as {player_id:string;mode:string}[];
  return new Map(rows.map(row => [row.player_id,row.mode]));
}
