import type { Database } from "bun:sqlite";

export const PVP_THRESHOLDS = ["Copper", "Quartz", "Amethyst", "Obsidian"].flatMap((league, l) =>
  ["IV", "III", "II", "I"].map((division, d) => ({ league, division, minimum: 1000 + l * 1000 + d * 250 }))
);
const clamp = (value: number, min: number, max: number) => Math.max(min, Math.min(max, value));
const validMp = (mp: number) => Number.isSafeInteger(mp) && mp >= 0;
export function pvpRank(mp: number) {
  if (!validMp(mp)) throw new Error("INVALID_MP");
  return PVP_THRESHOLDS[clamp(Math.floor((mp - 1000) / 250), 0, 15)];
}
export function pvpRatingDelta(player: number, opponent: number, outcome: "win" | "loss" | "draw"): number {
  if (!validMp(player) || !validMp(opponent) || !["win", "loss", "draw"].includes(outcome)) throw new Error("INVALID_RATING_INPUT");
  if (outcome === "draw") return 0;
  const rank = pvpRank(player), index = ["Copper", "Quartz", "Amethyst", "Obsidian"].indexOf(rank.league);
  const adjustment = clamp(Math.round((opponent - player) / 300) * 2, -10, 10);
  return outcome === "win" ? clamp([24, 22, 20, 18][index] + adjustment, 1, 30) : -Math.min(player, clamp([12, 20, 30, 40][index] - adjustment, 1, 50));
}
export function pvpSeason(now: number): string {
  if (!Number.isSafeInteger(now) || now < 0 || !Number.isFinite(new Date(now).getTime())) throw new Error("INVALID_TIME");
  return new Date(now).toISOString().slice(0, 7);
}
export function nextPvpSeason(now: number): number {
  const date = new Date(now); pvpSeason(now);
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 1);
}
export function previousPvpSeason(now: number): string {
  const date = new Date(now); pvpSeason(now);
  return pvpSeason(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() - 1, 1));
}

/** Ranking data is cached, while the viewer's own rating and ranks are always read live. */
export function createPvpRanking(db: Database, clock: () => number = Date.now) {
  const insert = db.prepare("INSERT OR IGNORE INTO pvp_season_ratings (season, player_id, rating, updated_at) VALUES (?, ?, 1000, ?)");
  const get = db.prepare("SELECT rating, updated_at FROM pvp_season_ratings WHERE season = ? AND player_id = ?");
  const list = db.prepare("SELECT r.player_id, p.display_name, r.rating, r.updated_at FROM pvp_season_ratings r JOIN players p ON p.player_id = r.player_id WHERE r.season = ? ORDER BY r.rating DESC, r.player_id ASC");
  const prune = db.prepare("DELETE FROM pvp_season_ratings WHERE season < ?");
  let prunedThrough = "";
  const cache = new Map<string, { time: number; rows: any[] }>();
  const ensure = (season: string, playerId: string, now: number) => { insert.run(season, playerId, now); return get.get(season, playerId) as { rating: number; updated_at: number }; };
  return {
    ensure,
    invalidate() { cache.clear(); },
    leaderboard(playerId: string, requestedSeason?: string | null) {
      const now = clock(), season = pvpSeason(now), previous = previousPvpSeason(now);
      if (prunedThrough !== previous) { prune.run(previous); prunedThrough = previous; }
      const viewSeason = requestedSeason ?? season;
      if (viewSeason !== season && viewSeason !== previous) throw new Error("INVALID_SEASON");
      if (typeof playerId !== "string" || !playerId) throw new Error("INVALID_PLAYER");
      const current = ensure(season, playerId, now), division = pvpRank(current.rating);
      const live = list.all(season) as any[];
      const index = live.findIndex(row => row.player_id === playerId);
      const same = (row: any) => { const rank = pvpRank(row.rating); return rank.league === division.league && rank.division === division.division; };
      const personal = { mp: current.rating, ...division, global_rank: index + 1, division_rank: live.filter(same).findIndex(row => row.player_id === playerId) + 1 };
      for (const key of cache.keys()) if (key !== season && key !== previous) cache.delete(key);
      const cached = (key: string, rows?: any[]) => {
        let entry = cache.get(key);
        if (!entry || now < entry.time || now - entry.time >= 60_000) {
          entry = { time: now, rows: rows ?? list.all(key) as any[] }; cache.set(key, entry);
        }
        return entry;
      };
      const currentCache = cached(season, live), viewCache = cached(viewSeason, viewSeason === season ? live : undefined);
      const publicRow = (row: any, rank: number) => ({ player_id: row.player_id, display_name: row.display_name, mp: row.rating, rank, ...pvpRank(row.rating) });
      return { season, view_season: viewSeason, previous_season: previous, player: personal, global_top_10: viewCache.rows.slice(0, 10).map((row, i) => publicRow(row, i + 1)), division_top_10: currentCache.rows.filter(same).slice(0, 10).map((row, i) => publicRow(row, i + 1)), thresholds: PVP_THRESHOLDS, updated_at: viewCache.time, next_update_at: Math.min(viewCache.time + 60_000, currentCache.time + 60_000, nextPvpSeason(now)) };
    }
  };
}
