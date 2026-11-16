ALTER TABLE solo_hunt_sessions ADD COLUMN common_cycle INTEGER;

CREATE TABLE solo_common_cycles (
  player_id TEXT NOT NULL,
  zone_id TEXT NOT NULL,
  cycle INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (player_id, zone_id)
);

CREATE TABLE solo_common_victories (
  player_id TEXT NOT NULL,
  zone_id TEXT NOT NULL,
  cycle INTEGER NOT NULL,
  appearance_id TEXT NOT NULL,
  session_id TEXT NOT NULL UNIQUE REFERENCES solo_hunt_sessions(session_id),
  defeated_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, zone_id, cycle, appearance_id)
);

CREATE TABLE solo_guardian_rosters (
  player_id TEXT NOT NULL,
  zone_id TEXT NOT NULL,
  parent_hunt_id TEXT NOT NULL,
  definitions_json TEXT NOT NULL,
  PRIMARY KEY (player_id, zone_id, parent_hunt_id)
);
