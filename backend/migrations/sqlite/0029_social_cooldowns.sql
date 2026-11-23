UPDATE friend_requests SET expires_at = MIN(expires_at, created_at + 30000) WHERE status='PENDING';
UPDATE forest_duel_invites SET expires_at = MIN(expires_at, created_at + 30000) WHERE status='PENDING';
CREATE INDEX friend_request_pair_cooldown ON friend_requests(requester_id,recipient_id,created_at,updated_at);
CREATE INDEX forest_duel_pair_cooldown ON forest_duel_invites(challenger_id,recipient_id,created_at,updated_at);
