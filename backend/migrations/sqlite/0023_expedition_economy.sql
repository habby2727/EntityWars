CREATE TABLE expedition_balances (
  player_id TEXT PRIMARY KEY,
  mana INTEGER NOT NULL DEFAULT 6 CHECK (mana BETWEEN 0 AND 6),
  crystals INTEGER NOT NULL DEFAULT 0 CHECK (crystals BETWEEN 0 AND 5),
  regen_at INTEGER NOT NULL DEFAULT 0 CHECK (regen_at >= 0 AND ((mana = 6 AND regen_at = 0) OR (mana < 6 AND regen_at > 0)))
);
ALTER TABLE action_log ADD COLUMN expedition_run_id TEXT;
ALTER TABLE action_log ADD COLUMN expedition_replay_compacted INTEGER NOT NULL DEFAULT 0;
ALTER TABLE expedition_runs ADD COLUMN replay_compacted_at INTEGER;
CREATE INDEX expedition_replay_backfill ON action_log(expedition_run_id,action_type,created_at) WHERE action_type GLOB 'EXPEDITION_*';
CREATE INDEX expedition_replay_run ON action_log(expedition_run_id,expedition_replay_compacted) WHERE expedition_run_id IS NOT NULL AND action_type GLOB 'EXPEDITION_*';
CREATE INDEX expedition_replay_pending ON expedition_runs(finished_at) WHERE status <> 'ACTIVE' AND replay_compacted_at IS NULL;
