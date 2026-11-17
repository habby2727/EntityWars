-- Staged ranked PvP storage. No feature is enabled by this migration.
CREATE TABLE pvp_queue (
  player_id TEXT PRIMARY KEY REFERENCES players(player_id),
  queued_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  snapshot_json TEXT NOT NULL
);
CREATE INDEX pvp_queue_fifo ON pvp_queue(queued_at, player_id);

CREATE TABLE pvp_matches (
  match_id TEXT PRIMARY KEY,
  status TEXT NOT NULL CHECK(status IN ('ACTIVE', 'FINISHED')),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  revision INTEGER NOT NULL DEFAULT 0,
  combat_state_json TEXT NOT NULL,
  result_json TEXT,
  settled_at INTEGER
);
CREATE TABLE pvp_match_players (
  match_id TEXT NOT NULL REFERENCES pvp_matches(match_id),
  player_id TEXT NOT NULL REFERENCES players(player_id),
  side TEXT NOT NULL CHECK(side IN ('LEFT', 'RIGHT')),
  snapshot_json TEXT NOT NULL,
  active INTEGER NOT NULL CHECK(active IN (0, 1)),
  last_seen_at INTEGER NOT NULL,
  next_chat_at INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(match_id, player_id),
  UNIQUE(match_id, side)
);
CREATE UNIQUE INDEX pvp_one_active_match ON pvp_match_players(player_id) WHERE active = 1;
CREATE TABLE pvp_decisions (
  match_id TEXT NOT NULL REFERENCES pvp_matches(match_id),
  player_id TEXT NOT NULL REFERENCES players(player_id),
  revision INTEGER NOT NULL,
  client_action_id TEXT NOT NULL,
  decision_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(match_id, revision, player_id),
  UNIQUE(player_id, client_action_id)
);
CREATE TABLE pvp_events (
  match_id TEXT NOT NULL REFERENCES pvp_matches(match_id),
  seq INTEGER NOT NULL,
  kind TEXT NOT NULL,
  visibility TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(match_id, seq)
);
CREATE TABLE pvp_ratings (
  player_id TEXT PRIMARY KEY REFERENCES players(player_id),
  rating INTEGER NOT NULL DEFAULT 1000,
  updated_at INTEGER NOT NULL
);
CREATE TABLE pvp_actions (
  player_id TEXT NOT NULL REFERENCES players(player_id),
  client_action_id TEXT NOT NULL,
  request_json TEXT NOT NULL,
  response_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(player_id, client_action_id)
);
