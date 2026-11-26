ALTER TABLE forest_quests ADD COLUMN cancelled_until INTEGER NOT NULL DEFAULT 0;
UPDATE forest_quests SET state='EXPIRED' WHERE state='ACTIVE' AND expires_at <= CAST(strftime('%s','now') AS INTEGER)*1000;
UPDATE forest_quests SET state='OFFERED', progress=0, progress_data='{}', accepted_at=NULL,
 expires_at=(CAST(strftime('%s', day || 'T00:00:00Z') AS INTEGER)+86400)*1000
WHERE state='ACTIVE' AND id IN (
 SELECT id FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY accepted_at, id) AS rn FROM forest_quests WHERE state='ACTIVE') WHERE rn>1
);
CREATE UNIQUE INDEX forest_quests_one_active ON forest_quests(player_id) WHERE state='ACTIVE';
CREATE INDEX forest_quests_cooldown ON forest_quests(player_id,npc_id,cancelled_until);
