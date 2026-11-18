CREATE TABLE world_mission_progress (
 player_id TEXT NOT NULL REFERENCES players(player_id),
 period_type TEXT NOT NULL CHECK (period_type IN ('daily','weekly')),
 period_key TEXT NOT NULL,
 progress_json TEXT NOT NULL,
 claimed_json TEXT NOT NULL,
 updated_at INTEGER NOT NULL,
 PRIMARY KEY (player_id, period_type)
);

CREATE INDEX world_mission_period_idx ON world_mission_progress(period_type, period_key);
