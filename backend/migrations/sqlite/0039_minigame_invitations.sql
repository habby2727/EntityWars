CREATE TABLE minigame_invitations (
 invite_id TEXT PRIMARY KEY, room_id TEXT NOT NULL, game_kind TEXT NOT NULL CHECK(game_kind IN ('woe','core_defense')),
 inviter_id TEXT NOT NULL, recipient_id TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('PENDING','ACCEPTED','DECLINED','CANCELLED','EXPIRED')),
 created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, expires_at INTEGER NOT NULL
);
CREATE INDEX minigame_invites_incoming ON minigame_invitations(recipient_id,status,expires_at);
CREATE INDEX minigame_invites_outgoing ON minigame_invitations(inviter_id,status,expires_at);
CREATE INDEX minigame_invites_expiry ON minigame_invitations(status,updated_at);
CREATE TABLE minigame_invite_actions (
 player_id TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE, action_id TEXT NOT NULL, action_type TEXT NOT NULL, payload TEXT NOT NULL,
 status_code INTEGER NOT NULL, response TEXT NOT NULL, expires_at INTEGER NOT NULL, PRIMARY KEY(player_id,action_id)
);
CREATE INDEX minigame_invite_actions_expiry ON minigame_invite_actions(expires_at);
CREATE TABLE minigame_invite_clock (player_id TEXT PRIMARY KEY REFERENCES players(player_id) ON DELETE CASCADE, watermark INTEGER NOT NULL);
