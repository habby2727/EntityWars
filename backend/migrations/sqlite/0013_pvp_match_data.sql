ALTER TABLE pvp_matches ADD COLUMN season TEXT;
ALTER TABLE pvp_matches ADD COLUMN decision_deadline INTEGER;
ALTER TABLE pvp_match_players ADD COLUMN start_rating INTEGER;
CREATE TABLE pvp_chat (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  match_id TEXT NOT NULL REFERENCES pvp_matches(match_id),
  player_id TEXT NOT NULL REFERENCES players(player_id),
  client_message_id TEXT NOT NULL,
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  UNIQUE (match_id, player_id, client_message_id)
);
CREATE INDEX pvp_chat_match_id ON pvp_chat(match_id, id);
CREATE INDEX pvp_chat_sender_id ON pvp_chat(player_id, id DESC);
