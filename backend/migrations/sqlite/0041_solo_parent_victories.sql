CREATE INDEX IF NOT EXISTS solo_parent_verified_victories
ON solo_hunt_sessions(player_id, guardian_zone_id, hunt_id, rotation_key, finished_at)
WHERE status = 'VERIFIED_WIN' AND guardian_id IS NULL AND global_event_id IS NULL AND common_cycle IS NULL;
