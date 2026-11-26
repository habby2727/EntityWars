CREATE TABLE friendships (
  player_low TEXT NOT NULL REFERENCES players(player_id),
  player_high TEXT NOT NULL REFERENCES players(player_id),
  created_at INTEGER NOT NULL,
  PRIMARY KEY (player_low, player_high),
  CHECK (player_low < player_high)
);
CREATE INDEX friendships_high ON friendships(player_high, player_low);

CREATE TABLE friend_requests (
  request_id TEXT PRIMARY KEY,
  requester_id TEXT NOT NULL REFERENCES players(player_id),
  recipient_id TEXT NOT NULL REFERENCES players(player_id),
  pair_low TEXT NOT NULL REFERENCES players(player_id),
  pair_high TEXT NOT NULL REFERENCES players(player_id),
  status TEXT NOT NULL CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED')),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  CHECK (pair_low < pair_high AND ((requester_id = pair_low AND recipient_id = pair_high) OR (requester_id = pair_high AND recipient_id = pair_low)))
);
CREATE UNIQUE INDEX friend_requests_pending_pair ON friend_requests(pair_low, pair_high) WHERE status = 'PENDING';
CREATE INDEX friend_requests_inbox ON friend_requests(recipient_id, status, created_at);
CREATE INDEX friend_requests_outbox ON friend_requests(requester_id, status, created_at);
CREATE INDEX friend_requests_cooldown ON friend_requests(requester_id, recipient_id, status, updated_at);
CREATE INDEX friend_requests_expiry ON friend_requests(expires_at) WHERE status = 'PENDING';

CREATE TABLE social_actions (
  player_id TEXT NOT NULL REFERENCES players(player_id),
  client_action_id TEXT NOT NULL,
  action_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  status_code INTEGER NOT NULL,
  result_json TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY(player_id, client_action_id)
);
