CREATE INDEX IF NOT EXISTS pvp_active_deadline ON pvp_matches(decision_deadline) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS pvp_queue_expiry ON pvp_queue(expires_at);
