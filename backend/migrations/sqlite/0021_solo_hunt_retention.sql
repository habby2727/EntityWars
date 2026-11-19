ALTER TABLE solo_hunt_sessions ADD COLUMN compacted_at INTEGER;
CREATE INDEX solo_hunt_active_expiry ON solo_hunt_sessions(expires_at) WHERE status = 'ACTIVE' AND global_event_id IS NULL;
CREATE INDEX solo_hunt_terminal_retention ON solo_hunt_sessions(CASE WHEN status = 'EXPIRED' THEN expires_at ELSE finished_at END) WHERE global_event_id IS NULL AND status IN ('VERIFIED_LOSS', 'FORFEIT', 'EXPIRED') AND compacted_at IS NULL;
