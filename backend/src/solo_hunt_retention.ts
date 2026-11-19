import type { Database } from "bun:sqlite";
import { gzipSync, gunzipSync } from "node:zlib";

const prefix = "gz1:";
export function readHuntCombat(value: string): any {
	return JSON.parse(value.startsWith(prefix) ? gunzipSync(Buffer.from(value.slice(prefix.length), "base64")).toString("utf8") : value);
}

export function maintainSoloHunts(db: Database, now: number): { expired: number; compacted: number } {
	// Compress outside the write transaction; revalidate each candidate before updating it.
	const candidates = db.query(`SELECT session_id, combat_state_json FROM solo_hunt_sessions
		WHERE global_event_id IS NULL AND status IN ('VERIFIED_LOSS', 'FORFEIT', 'EXPIRED') AND compacted_at IS NULL
		AND (CASE WHEN status = 'EXPIRED' THEN expires_at ELSE finished_at END) <= ?
		ORDER BY (CASE WHEN status = 'EXPIRED' THEN expires_at ELSE finished_at END) LIMIT 50`).all(now - 7200000) as { session_id: string; combat_state_json: string | null }[];
	const prepared = candidates.map(row => {
		const value = row.combat_state_json;
		const compressed = value ? prefix + gzipSync(Buffer.from(value)).toString("base64") : value;
		return { ...row, compressed: compressed && value && compressed.length >= value.length ? value : compressed };
	});
	db.exec("BEGIN IMMEDIATE");
	try {
		const expired = db.query(`UPDATE solo_hunt_sessions SET status = 'EXPIRED', finished_at = ? WHERE session_id IN (
			SELECT session_id FROM solo_hunt_sessions WHERE status = 'ACTIVE' AND global_event_id IS NULL AND expires_at <= ? ORDER BY expires_at LIMIT 50
		) AND status = 'ACTIVE' AND global_event_id IS NULL`).run(now, now).changes;
		const update = db.query("UPDATE solo_hunt_sessions SET player_snapshot_json = '{}', combat_state_json = ?, compacted_at = ? WHERE session_id = ? AND combat_state_json IS ? AND compacted_at IS NULL AND global_event_id IS NULL AND status IN ('VERIFIED_LOSS', 'FORFEIT', 'EXPIRED') AND (CASE WHEN status = 'EXPIRED' THEN expires_at ELSE finished_at END) <= ?");
		let compacted = 0;
		for (const row of prepared) {
			compacted += update.run(row.compressed, now, row.session_id, row.combat_state_json, now - 7200000).changes;
		}
		db.exec("COMMIT");
		return { expired, compacted };
	} catch (error) {
		db.exec("ROLLBACK");
		throw error;
	}
}
