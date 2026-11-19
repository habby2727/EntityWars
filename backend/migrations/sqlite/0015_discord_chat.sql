ALTER TABLE global_chat_messages ADD COLUMN external_name TEXT;
ALTER TABLE global_chat_messages ADD COLUMN discord_message_id TEXT;
CREATE UNIQUE INDEX global_chat_discord_message ON global_chat_messages(discord_message_id) WHERE discord_message_id IS NOT NULL;
CREATE TABLE discord_chat_seen (message_id TEXT PRIMARY KEY, created_at INTEGER NOT NULL);
CREATE TABLE discord_chat_outbox (message_id INTEGER PRIMARY KEY, username TEXT NOT NULL, text TEXT NOT NULL, created_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER NOT NULL DEFAULT 0);
