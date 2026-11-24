CREATE TABLE spectator_events (
  mode TEXT NOT NULL, session_id TEXT NOT NULL, encounter TEXT NOT NULL,
  seq INTEGER NOT NULL, payload_json TEXT NOT NULL, created_at INTEGER NOT NULL,
  PRIMARY KEY(mode,session_id,encounter,seq)
);
CREATE INDEX spectator_events_expiry ON spectator_events(created_at);
CREATE TABLE spectator_final_combats (
  mode TEXT NOT NULL, session_id TEXT NOT NULL, encounter TEXT NOT NULL,
  combat_json TEXT NOT NULL, created_at INTEGER NOT NULL,
  PRIMARY KEY(mode,session_id,encounter)
);
CREATE INDEX spectator_final_expiry ON spectator_final_combats(created_at);
