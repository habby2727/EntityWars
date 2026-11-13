CREATE TABLE IF NOT EXISTS solo_hunt_sessions (
  session_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL,
  hunt_id TEXT NOT NULL,
  rotation_key INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'FORFEIT', 'EXPIRED', 'VERIFIED_WIN', 'VERIFIED_LOSS')),
  boss_snapshot_json TEXT NOT NULL,
  player_snapshot_json TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  finished_at INTEGER,
  result_metadata_json TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS solo_hunt_one_active_per_player ON solo_hunt_sessions(player_id) WHERE status = 'ACTIVE';
