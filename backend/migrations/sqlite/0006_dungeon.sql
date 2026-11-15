CREATE TABLE IF NOT EXISTS dungeon_runs (
  run_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL,
  season TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'LOSS', 'ABANDONED', 'EXPIRED')),
  started_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  finished_at INTEGER,
  cleared_floor INTEGER NOT NULL DEFAULT 0 CHECK (cleared_floor >= 0),
  total_turns INTEGER NOT NULL DEFAULT 0 CHECK (total_turns >= 0),
  combat_revision INTEGER NOT NULL DEFAULT 0 CHECK (combat_revision >= 0),
  player_snapshot_json TEXT NOT NULL,
  loadout_json TEXT,
  combat_state_json TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS dungeon_one_active_per_player
  ON dungeon_runs(player_id) WHERE status = 'ACTIVE';

CREATE TABLE IF NOT EXISTS dungeon_monthly_best (
  season TEXT NOT NULL,
  player_id TEXT NOT NULL,
  cleared_floor INTEGER NOT NULL CHECK (cleared_floor > 0),
  total_turns INTEGER NOT NULL CHECK (total_turns > 0),
  achieved_at INTEGER NOT NULL,
  run_id TEXT NOT NULL REFERENCES dungeon_runs(run_id),
  PRIMARY KEY (season, player_id)
);

CREATE INDEX IF NOT EXISTS dungeon_leaderboard_order
  ON dungeon_monthly_best(season, cleared_floor DESC, total_turns ASC, achieved_at ASC, player_id ASC);
