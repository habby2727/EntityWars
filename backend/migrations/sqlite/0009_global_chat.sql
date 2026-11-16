CREATE TABLE IF NOT EXISTS global_chat_messages (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	player_id TEXT NOT NULL,
	client_message_id TEXT NOT NULL,
	text TEXT NOT NULL,
	created_at INTEGER NOT NULL,
	UNIQUE(player_id, client_message_id)
);
