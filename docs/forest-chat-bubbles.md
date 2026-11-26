# Forest chat bubbles

A successful new `/chat/send` message from a player with an entered Forest presence is sent to that player and entered peers in the same room as `peer_chat`. The event carries `player_id`, the persisted `message_id`, plain `text`, `created_at`, `expires_at` (ten seconds after creation), and `server_time`, all supplied by the server. Idempotent replays do not emit an event. Messages from Discord or system announcements do not use this path. Forest lease loss or absent presence does not block global chat.

The Forest client uses the welcome/pong clock and monotonic elapsed time to reject expired events. Bubbles are transient and do not replay chat history. A later message replaces the prior bubble; leaving a room or losing the connection clears it.
