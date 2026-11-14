ALTER TABLE solo_hunt_sessions ADD COLUMN guardian_zone_id TEXT;
ALTER TABLE solo_hunt_sessions ADD COLUMN guardian_parent_id TEXT;
ALTER TABLE solo_hunt_sessions ADD COLUMN guardian_id TEXT;

CREATE TABLE IF NOT EXISTS solo_guardian_victories (
  player_id TEXT NOT NULL,
  zone_id TEXT NOT NULL,
  parent_hunt_id TEXT NOT NULL,
  guardian_id TEXT NOT NULL,
  session_id TEXT NOT NULL UNIQUE,
  defeated_at INTEGER NOT NULL,
  PRIMARY KEY (player_id, zone_id, parent_hunt_id, guardian_id)
);
