CREATE TABLE forest_quests (
 id TEXT PRIMARY KEY, player_id TEXT NOT NULL, npc_id TEXT NOT NULL, day TEXT NOT NULL,
 objective TEXT NOT NULL, difficulty TEXT NOT NULL, target INTEGER NOT NULL, progress INTEGER NOT NULL DEFAULT 0,
 progress_data TEXT NOT NULL DEFAULT '{}', reward TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'OFFERED',
 accepted_at INTEGER, expires_at INTEGER NOT NULL, completed_at INTEGER, claimed_at INTEGER,
 UNIQUE(player_id,npc_id,day)
);
CREATE INDEX forest_quests_player_state ON forest_quests(player_id,state,npc_id,expires_at);
CREATE INDEX forest_quests_retention ON forest_quests(expires_at);
CREATE TABLE forest_quest_actions (player_id TEXT NOT NULL, action_id TEXT NOT NULL, action TEXT NOT NULL, quest_id TEXT NOT NULL, result TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY(player_id,action_id));
CREATE INDEX forest_quest_actions_retention ON forest_quest_actions(created_at);
