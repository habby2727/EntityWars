CREATE TABLE pvp_season_ratings (
  season TEXT NOT NULL,
  player_id TEXT NOT NULL REFERENCES players(player_id),
  rating INTEGER NOT NULL DEFAULT 1000 CHECK(rating >= 0),
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (season, player_id)
);
CREATE INDEX pvp_season_ratings_order ON pvp_season_ratings(season, rating DESC, player_id);
