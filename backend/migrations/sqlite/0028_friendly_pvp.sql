ALTER TABLE pvp_matches ADD COLUMN kind TEXT NOT NULL DEFAULT 'ranked' CHECK(kind IN ('ranked','friendly'));
ALTER TABLE pvp_matches ADD COLUMN invite_id TEXT REFERENCES forest_duel_invites(invite_id);
CREATE UNIQUE INDEX pvp_friendly_invite ON pvp_matches(invite_id) WHERE invite_id IS NOT NULL;
CREATE TRIGGER pvp_match_kind_insert BEFORE INSERT ON pvp_matches WHEN (NEW.kind='friendly') != (NEW.invite_id IS NOT NULL) BEGIN SELECT RAISE(ABORT, 'INVALID_MATCH_KIND'); END;
CREATE TRIGGER pvp_match_kind_update BEFORE UPDATE OF kind, invite_id ON pvp_matches BEGIN SELECT RAISE(ABORT, 'IMMUTABLE_MATCH_KIND'); END;
CREATE TRIGGER pvp_friendly_member BEFORE INSERT ON pvp_match_players WHEN (SELECT kind FROM pvp_matches WHERE match_id=NEW.match_id)='friendly' AND NOT EXISTS (SELECT 1 FROM pvp_matches m JOIN forest_duel_invites i ON i.invite_id=m.invite_id WHERE m.match_id=NEW.match_id AND NEW.player_id IN (i.challenger_id,i.recipient_id)) BEGIN SELECT RAISE(ABORT, 'INVALID_FRIENDLY_PARTICIPANT'); END;
CREATE TABLE forest_duel_ready (invite_id TEXT NOT NULL REFERENCES forest_duel_invites(invite_id) ON DELETE CASCADE, player_id TEXT NOT NULL REFERENCES players(player_id), snapshot_json TEXT NOT NULL, selection_json TEXT NOT NULL, PRIMARY KEY(invite_id,player_id));
CREATE TRIGGER forest_duel_ready_member BEFORE INSERT ON forest_duel_ready WHEN NOT EXISTS (SELECT 1 FROM forest_duel_invites WHERE invite_id=NEW.invite_id AND status='ACCEPTED' AND NEW.player_id IN (challenger_id,recipient_id)) BEGIN SELECT RAISE(ABORT, 'INVALID_READY_PARTICIPANT'); END;
