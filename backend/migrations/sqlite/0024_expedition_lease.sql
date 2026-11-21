CREATE TABLE expedition_runs_v24 (
  run_id TEXT PRIMARY KEY, player_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('ACTIVE','LOSS','EXIT','ABANDONED')),
  revision INTEGER NOT NULL CHECK(revision >= 1), snapshot_json TEXT, loadout_json TEXT,
  setup_json TEXT, state_json TEXT, started_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
  finished_at INTEGER, replay_compacted_at INTEGER,
  lease_hash TEXT, heartbeat_at INTEGER
);
INSERT INTO expedition_runs_v24(run_id,player_id,status,revision,snapshot_json,loadout_json,setup_json,state_json,started_at,updated_at,finished_at,replay_compacted_at)
SELECT run_id,player_id,status,revision,snapshot_json,loadout_json,setup_json,state_json,started_at,updated_at,finished_at,replay_compacted_at FROM expedition_runs;
DROP TABLE expedition_runs;
ALTER TABLE expedition_runs_v24 RENAME TO expedition_runs;
CREATE UNIQUE INDEX expedition_one_active ON expedition_runs(player_id) WHERE status='ACTIVE';
CREATE INDEX expedition_finished_retention ON expedition_runs(finished_at,player_id) WHERE status <> 'ACTIVE';
CREATE INDEX expedition_replay_pending ON expedition_runs(finished_at) WHERE status <> 'ACTIVE' AND replay_compacted_at IS NULL;
CREATE INDEX expedition_lease_expiry ON expedition_runs(heartbeat_at) WHERE status='ACTIVE';
