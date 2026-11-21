CREATE TABLE expedition_runs (
  run_id TEXT PRIMARY KEY,
  player_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','LOSS','EXIT')),
  revision INTEGER NOT NULL CHECK(revision >= 1),
  snapshot_json TEXT,
  loadout_json TEXT,
  setup_json TEXT,
  state_json TEXT,
  started_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  finished_at INTEGER
);
CREATE UNIQUE INDEX expedition_one_active ON expedition_runs(player_id) WHERE status='ACTIVE';
CREATE INDEX expedition_finished_retention ON expedition_runs(finished_at,player_id) WHERE status <> 'ACTIVE';
CREATE INDEX expedition_action_retention ON action_log(player_id,action_type) WHERE action_type GLOB 'EXPEDITION_*';
CREATE TABLE expedition_player_cooldowns (
  player_id TEXT PRIMARY KEY,
  cooldown_until INTEGER NOT NULL
);
