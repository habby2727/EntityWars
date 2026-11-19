import type { Database } from "bun:sqlite";
import { gzipSync, gunzipSync } from "node:zlib";

const prefix = "gz1:";
export function readHuntCombat(value: string): any {
	return JSON.parse(value.startsWith(prefix) ? gunzipSync(Buffer.from(value.slice(prefix.length), "base64")).toString("utf8") : value);
}

export function maintainSoloHunts(db: Database, now: number): { expired: number; compacted: number } {
	return db.transaction(() => {
		const expired = db.query(`UPDATE solo_hunt_sessions SET status = 'EXPIRED', finished_at = ? WHERE session_id IN (
			SELECT session_id FROM solo_hunt_sessions WHERE status = 'ACTIVE' AND global_event_id IS NULL AND expires_at <= ? ORDER BY expires_at LIMIT 100
		) AND status = 'ACTIVE' AND global_event_id IS NULL`).run(now, now).changes;
		const candidates = db.query(`SELECT session_id, combat_state_json FROM solo_hunt_sessions
			WHERE global_event_id IS NULL AND status IN ('VERIFIED_LOSS', 'FORFEIT', 'EXPIRED') AND compacted_at IS NULL
			AND (CASE WHEN status = 'EXPIRED' THEN expires_at ELSE finished_at END) <= ?
			ORDER BY (CASE WHEN status = 'EXPIRED' THEN expires_at ELSE finished_at END) LIMIT ?`).all(now - 7200000, 100 - expired) as { session_id: string; combat_state_json: string | null }[];
		const update = db.query("UPDATE solo_hunt_sessions SET player_snapshot_json = '{}', combat_state_json = ?, compacted_at = ? WHERE session_id = ? AND compacted_at IS NULL AND global_event_id IS NULL AND status IN ('VERIFIED_LOSS', 'FORFEIT', 'EXPIRED')");
		let compacted = 0;
		for (const row of candidates) {
			const value = row.combat_state_json;
			const compressed = value ? prefix + gzipSync(Buffer.from(value)).toString("base64") : value;
			compacted += update.run(compressed && value && compressed.length >= value.length ? value : compressed, now, row.session_id).changes;
		}
		return { expired, compacted };
	}).immediate();
}
