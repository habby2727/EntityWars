ALTER TABLE solo_hunt_sessions ADD COLUMN combat_loadout_json TEXT;
ALTER TABLE solo_hunt_sessions ADD COLUMN combat_state_json TEXT;
ALTER TABLE solo_hunt_sessions ADD COLUMN combat_revision INTEGER NOT NULL DEFAULT 0;
