CREATE TABLE core_defense_monthly_scores (
 month TEXT NOT NULL, mode TEXT NOT NULL CHECK(mode IN ('solo','coop')), player_id TEXT NOT NULL,
 completed_waves INTEGER NOT NULL CHECK(completed_waves>0), achieved_at INTEGER NOT NULL,
 PRIMARY KEY(month,mode,player_id)
);
CREATE INDEX core_defense_monthly_ranking ON core_defense_monthly_scores(month,mode,completed_waves DESC,achieved_at ASC,player_id ASC);
CREATE TABLE core_defense_monthly_clock (id INTEGER PRIMARY KEY CHECK(id=1), month TEXT NOT NULL);
