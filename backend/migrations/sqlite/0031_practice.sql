CREATE TABLE practice_sessions (
  match_id TEXT PRIMARY KEY, player_id TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('ACTIVE','FINISHED')),
  revision INTEGER NOT NULL, combat_json TEXT NOT NULL, snapshot_json TEXT NOT NULL, result_json TEXT,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, expires_at INTEGER NOT NULL
);
CREATE UNIQUE INDEX practice_one_active ON practice_sessions(player_id) WHERE status='ACTIVE';
CREATE INDEX practice_expiry ON practice_sessions(expires_at, status);
CREATE INDEX practice_retention ON practice_sessions(updated_at) WHERE status='FINISHED';
CREATE TABLE practice_events (match_id TEXT NOT NULL REFERENCES practice_sessions(match_id) ON DELETE CASCADE, seq INTEGER NOT NULL, payload_json TEXT NOT NULL, PRIMARY KEY(match_id,seq));
CREATE TABLE practice_actions (player_id TEXT NOT NULL, action_id TEXT NOT NULL, match_id TEXT NOT NULL REFERENCES practice_sessions(match_id) ON DELETE CASCADE, request_json TEXT NOT NULL, response_json TEXT NOT NULL, PRIMARY KEY(player_id,action_id));
CREATE INDEX practice_actions_match ON practice_actions(match_id);
CREATE TABLE practice_daily_xp (player_id TEXT NOT NULL, day INTEGER NOT NULL, xp INTEGER NOT NULL CHECK(xp BETWEEN 0 AND 60), PRIMARY KEY(player_id,day));
CREATE INDEX practice_daily_retention ON practice_daily_xp(day);
