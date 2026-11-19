import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pruneWorldSessions } from "../world_session_retention";

test("incremental indexes improve sweep and queue expiration plans on an existing database", () => {
	const db = new Database(":memory:");
	try {
		const dir = resolve(import.meta.dir, "../../migrations/sqlite");
		const files = readdirSync(dir).filter(f => f.endsWith(".sql")).sort();
		for (const file of files.filter(f => !f.startsWith("0020_"))) db.exec(readFileSync(resolve(dir, file), "utf8"));
		const sweep = "SELECT match_id FROM pvp_matches WHERE status = 'ACTIVE' AND decision_deadline <= ? ORDER BY decision_deadline LIMIT 100";
		const expiry = "DELETE FROM pvp_queue WHERE expires_at <= ?";
		const plan = (sql: string) => JSON.stringify(db.query(`EXPLAIN QUERY PLAN ${sql}`).all(123));
		expect(plan(sweep)).toContain("SCAN pvp_matches");
		expect(plan(expiry)).toContain("SCAN pvp_queue");
		db.exec(readFileSync(resolve(dir, "0020_pvp_query_indexes.sql"), "utf8"));
		expect(plan(sweep)).toContain("pvp_active_deadline");
		expect(plan(expiry)).toContain("pvp_queue_expiry");
	} finally { db.close(); }
});

test("retention preserves loot, recent sessions and the 20 most active", () => {
	const day = 86400000, now = 400 * day;
	const sessions: Record<string, { started_at: number; last_farm_at: number; pending_loot: Record<string, number> }> = {};
	for (let i = 0; i < 25; i++) sessions[`old-${i}`] = { started_at: i * day, last_farm_at: 0, pending_loot: {} };
	sessions.loot = { started_at: 0, last_farm_at: 0, pending_loot: { essence: 1 } };
	sessions.recent = { started_at: 0, last_farm_at: now - 180 * day, pending_loot: {} };
	pruneWorldSessions(sessions, now);
	expect(sessions.loot).toBeDefined();
	expect(sessions.recent).toBeDefined();
	expect(Object.keys(sessions)).toHaveLength(21);
	expect(sessions["old-0"]).toBeUndefined();
	expect(sessions["old-24"]).toBeDefined();
});
