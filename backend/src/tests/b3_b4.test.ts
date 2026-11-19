import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

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
