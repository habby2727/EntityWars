import type { Database } from "bun:sqlite";

// Call within the admission transaction; expiry never depends on lobby cleanup.
export const woeBusySql = (player: string, now: string) => `EXISTS (SELECT 1 FROM woe_members wm JOIN woe_rooms wr ON wr.room_id=wm.room_id WHERE wm.player_id=${player} AND wr.status IN ('WAITING','STARTED') AND wr.expires_at>${now})`;
export function activeWoe(db: Database, player: string, now: number): boolean {
  return !!db.query(`SELECT 1 WHERE ${woeBusySql('?', '?')}`).get(player, now);
}
