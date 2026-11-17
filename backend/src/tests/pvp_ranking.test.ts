import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createPvpRanking, nextPvpSeason, pvpRank, pvpRatingDelta, pvpSeason, PVP_THRESHOLDS } from "../pvp/ranking";

test("rank thresholds and rating caps", () => {
 expect(PVP_THRESHOLDS).toHaveLength(16);
 for (const threshold of PVP_THRESHOLDS) expect(pvpRank(threshold.minimum)).toEqual(threshold);
 expect(pvpRank(0)).toEqual(PVP_THRESHOLDS[0]); expect(pvpRank(100000)).toEqual(PVP_THRESHOLDS[15]);
 expect(pvpRatingDelta(1000,1000,"win")).toBe(24); expect(pvpRatingDelta(2000,2000,"loss")).toBe(-20);
 expect(pvpRatingDelta(1000,100000,"win")).toBe(30); expect(pvpRatingDelta(5000,0,"loss")).toBe(-50);
 expect(pvpRatingDelta(1,5000,"loss")).toBe(-1); expect(pvpRatingDelta(1000,2000,"draw")).toBe(0);
});
test("leaderboards cache lists, keep personal ranks live and preserve monthly history", () => {
 const db = new Database(":memory:");
 db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 db.exec(readFileSync(resolve(import.meta.dir,"../../migrations/sqlite/0012_pvp_seasons.sql"),"utf8"));
 for (let i=0; i<12; i++) db.query("INSERT INTO players VALUES (?, ?)").run(`p${String(i).padStart(2,"0")}`, `Player ${i}`);
 let now = Date.UTC(2026,0,31,23,0); const ranking = createPvpRanking(db,()=>now);
 for (let i=0; i<12; i++) ranking.ensure(pvpSeason(now),`p${String(i).padStart(2,"0")}`,now);
 db.query("UPDATE pvp_season_ratings SET rating = 1250 WHERE player_id = ?").run("p11");
 const first = ranking.leaderboard("p00"); expect(first.global_top_10).toHaveLength(10); expect(first.division_top_10).toHaveLength(10);
 expect(first.global_top_10[0].player_id).toBe("p11"); expect(first.player.global_rank).toBe(2);
 db.query("UPDATE pvp_season_ratings SET rating = 1400 WHERE player_id = ?").run("p00");
 const live = ranking.leaderboard("p00"); expect(live.player.mp).toBe(1400); expect(live.player.global_rank).toBe(1); expect(live.global_top_10[0].player_id).toBe("p11");
 now += 1_200_000; expect(ranking.leaderboard("p00").global_top_10[0].player_id).toBe("p00");
 now = Date.UTC(2026,1,1); const next = ranking.leaderboard("p00"); expect(next.season).toBe("2026-02"); expect(next.player.mp).toBe(1000);
 expect((db.query("SELECT rating FROM pvp_season_ratings WHERE season = ? AND player_id = ?").get("2026-01","p00") as any).rating).toBe(1400);
 expect(nextPvpSeason(now)).toBe(Date.UTC(2026,2,1)); db.close();
});
