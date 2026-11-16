CREATE TABLE credentials (
	username TEXT PRIMARY KEY,
	player_id TEXT NOT NULL UNIQUE REFERENCES players(player_id),
	password_hash TEXT NOT NULL,
	created_at INTEGER NOT NULL
);
