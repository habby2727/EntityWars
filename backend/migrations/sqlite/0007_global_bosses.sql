ALTER TABLE solo_hunt_sessions ADD COLUMN global_event_id TEXT;

CREATE TABLE global_boss_events (
  event_id TEXT PRIMARY KEY,
  zone_id TEXT NOT NULL,
  tier TEXT NOT NULL,
  boss_snapshot_json TEXT NOT NULL,
  spawned_at INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'COMPLETE')),
  winner_count INTEGER NOT NULL DEFAULT 0 CHECK (winner_count BETWEEN 0 AND 5),
  completed_at INTEGER
);
CREATE UNIQUE INDEX global_boss_one_active_zone ON global_boss_events(zone_id) WHERE status = 'ACTIVE';

CREATE TABLE global_boss_winners (
  event_id TEXT NOT NULL REFERENCES global_boss_events(event_id),
  player_id TEXT NOT NULL,
  session_id TEXT NOT NULL UNIQUE REFERENCES solo_hunt_sessions(session_id),
  status TEXT NOT NULL CHECK (status IN ('WAITING', 'PAID')),
  reward_json TEXT,
  won_at INTEGER NOT NULL,
  PRIMARY KEY (event_id, player_id)
);
