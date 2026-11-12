CREATE TABLE IF NOT EXISTS combat_reward_receipts (
	match_id TEXT PRIMARY KEY,
	player_id TEXT NOT NULL,
	status TEXT NOT NULL CHECK (status IN ('VERIFIED_WIN', 'VERIFIED_LOSS', 'INVALID')),
	reward_json TEXT NOT NULL,
	verified_at INTEGER NOT NULL,
	claimed_at INTEGER,
	created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_combat_reward_receipts_player ON combat_reward_receipts(player_id);
