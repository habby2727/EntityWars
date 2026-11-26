-- Replay expiry must not manufacture participant activity or postpone abandonment.
ALTER TABLE core_defense_participants ADD COLUMN replay_watermark INTEGER NOT NULL DEFAULT 0;
-- Existing Core Defense rooms may contain the former duplicate snapshot.
UPDATE woe_rooms SET match_json=NULL WHERE match_json IS NOT NULL AND room_id IN (SELECT room_id FROM core_defense_rooms);
