CREATE TABLE woe_rooms (room_id TEXT PRIMARY KEY, join_code TEXT NOT NULL UNIQUE, mode TEXT NOT NULL CHECK(mode IN ('1v1','2v2')), host_id TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('WAITING','STARTED','EXPIRED')), revision INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, match_id TEXT UNIQUE, match_json TEXT, mapping_json TEXT);
CREATE INDEX woe_rooms_expiry ON woe_rooms(status,expires_at);
CREATE TABLE woe_members (player_id TEXT PRIMARY KEY REFERENCES players(player_id), room_id TEXT NOT NULL REFERENCES woe_rooms(room_id) ON DELETE CASCADE, seat TEXT, joined_at INTEGER NOT NULL, UNIQUE(room_id,seat));
CREATE INDEX woe_members_room ON woe_members(room_id,joined_at,player_id);
CREATE TABLE woe_actions (player_id TEXT NOT NULL REFERENCES players(player_id), client_action_id TEXT NOT NULL, action_type TEXT NOT NULL, payload_json TEXT NOT NULL, status_code INTEGER NOT NULL, result_json TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(player_id,client_action_id));
CREATE INDEX woe_actions_expiry ON woe_actions(created_at);
