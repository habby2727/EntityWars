CREATE TABLE forest_duel_invites (
 invite_id TEXT PRIMARY KEY,
 challenger_id TEXT NOT NULL REFERENCES players(player_id),
 recipient_id TEXT NOT NULL REFERENCES players(player_id),
 originating_zone TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('PENDING','ACCEPTED','DECLINED','CANCELLED','EXPIRED','STARTED')),
 created_at INTEGER NOT NULL,
 updated_at INTEGER NOT NULL,
 expires_at INTEGER NOT NULL,
 CHECK(challenger_id <> recipient_id)
);
CREATE INDEX forest_duel_challenger ON forest_duel_invites(challenger_id, status, created_at);
CREATE INDEX forest_duel_recipient ON forest_duel_invites(recipient_id, status, created_at);
CREATE INDEX forest_duel_expiry ON forest_duel_invites(expires_at) WHERE status IN ('PENDING','ACCEPTED');
CREATE INDEX forest_duel_retention ON forest_duel_invites(updated_at) WHERE status IN ('DECLINED','CANCELLED','EXPIRED');

-- One row per participant makes exclusivity independent of the invitation role.
CREATE TABLE forest_duel_reservations (
 player_id TEXT PRIMARY KEY REFERENCES players(player_id),
 invite_id TEXT NOT NULL REFERENCES forest_duel_invites(invite_id)
);
CREATE INDEX forest_duel_reservation_invite ON forest_duel_reservations(invite_id);

CREATE TABLE forest_duel_actions (
 player_id TEXT NOT NULL REFERENCES players(player_id),
 client_action_id TEXT NOT NULL,
 action_type TEXT NOT NULL,
 payload_json TEXT NOT NULL,
 status_code INTEGER NOT NULL,
 result_json TEXT NOT NULL,
 created_at INTEGER NOT NULL,
 PRIMARY KEY(player_id,client_action_id)
);
CREATE INDEX forest_duel_actions_retention ON forest_duel_actions(created_at);
