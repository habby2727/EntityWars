CREATE TABLE core_defense_rooms (
 room_id TEXT PRIMARY KEY REFERENCES woe_rooms(room_id) ON DELETE CASCADE,
 mode TEXT NOT NULL CHECK(mode IN ('solo','solo_bot','coop'))
);
CREATE TABLE core_defense_participants (
 match_id TEXT NOT NULL, controller_id TEXT NOT NULL, last_active_at INTEGER NOT NULL,
 PRIMARY KEY(match_id,controller_id),
 FOREIGN KEY(match_id,controller_id) REFERENCES woe_match_participants(match_id,controller_id) ON DELETE CASCADE
);
CREATE TABLE core_defense_results (
 match_id TEXT PRIMARY KEY REFERENCES woe_matches(match_id) ON DELETE CASCADE,
 mode TEXT NOT NULL, completed_waves INTEGER NOT NULL, enemies_killed INTEGER NOT NULL,
 remaining_lab_hp INTEGER NOT NULL, elapsed_ticks INTEGER NOT NULL,
 reason TEXT NOT NULL, assisted INTEGER NOT NULL, finished_at INTEGER NOT NULL
);
CREATE TABLE core_defense_actions (
 match_id TEXT NOT NULL, player_id TEXT NOT NULL, action_id TEXT NOT NULL,
 kind TEXT NOT NULL, payload TEXT NOT NULL, status INTEGER NOT NULL, response TEXT NOT NULL,
 expires_at INTEGER NOT NULL, PRIMARY KEY(match_id,player_id,action_id)
);
CREATE INDEX core_defense_actions_expiry ON core_defense_actions(expires_at);
