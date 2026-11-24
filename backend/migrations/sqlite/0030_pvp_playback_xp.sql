ALTER TABLE pvp_matches ADD COLUMN playback_protocol INTEGER NOT NULL DEFAULT 0;
ALTER TABLE pvp_matches ADD COLUMN phase TEXT NOT NULL DEFAULT 'DECISION';
ALTER TABLE pvp_matches ADD COLUMN playback_event_end INTEGER NOT NULL DEFAULT 0;
ALTER TABLE pvp_match_players ADD COLUMN playback_ack_revision INTEGER NOT NULL DEFAULT 0;
ALTER TABLE forest_duel_ready ADD COLUMN playback_protocol INTEGER NOT NULL DEFAULT 0;
CREATE TABLE pvp_xp_rewards (
  match_id TEXT PRIMARY KEY REFERENCES pvp_matches(match_id),
  winner_id TEXT NOT NULL,
  opponent_id TEXT NOT NULL,
  rewarded_at INTEGER NOT NULL
);
CREATE INDEX pvp_xp_rewards_pair_day ON pvp_xp_rewards(winner_id, opponent_id, rewarded_at);
