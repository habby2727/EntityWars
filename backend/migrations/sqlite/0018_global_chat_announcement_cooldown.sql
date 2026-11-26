CREATE TABLE global_chat_announcements (
    player_id TEXT PRIMARY KEY REFERENCES players(player_id) ON DELETE CASCADE,
    announced_at INTEGER NOT NULL
);
