import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { maintainSoloHunts, readHuntCombat } from "../solo_hunt_retention";

test("maintenance expires and compacts bounded normal hunts without changing public combat", () => {
	const db = new Database(":memory:");
	try {
		const dir = resolve(import.meta.dir, "../../migrations/sqlite");
		for (const file of readdirSync(dir).filter(f => f.endsWith(".sql") && !f.startsWith("0021_")).sort()) db.exec(readFileSync(resolve(dir, file), "utf8"));
		const beforePlan = db.query("EXPLAIN QUERY PLAN SELECT session_id FROM solo_hunt_sessions WHERE status = 'ACTIVE' AND global_event_id IS NULL AND expires_at <= ? ORDER BY expires_at LIMIT 100").all(1);
		expect(JSON.stringify(beforePlan)).not.toContain("solo_hunt_active_expiry");
		db.exec(readFileSync(resolve(dir, "0021_solo_hunt_retention.sql"), "utf8"));
		const now = 20_000_000, combat = JSON.stringify({ player: { hp: 10 }, repeated: "x".repeat(5000) });
		const insert = db.query("INSERT INTO solo_hunt_sessions(session_id,player_id,hunt_id,rotation_key,status,boss_snapshot_json,player_snapshot_json,started_at,expires_at,finished_at,combat_state_json,global_event_id) VALUES(?,?, 'hunt_common', 1, ?, ?, ?, 1, ?, ?, ?, ?)");
		const add = (id: string, status: string, expires: number, finished: number | null, global: string | null = null) => insert.run(id, id, status, '{"name":"guardian"}', JSON.stringify({ large: "z".repeat(5000) }), expires, finished, combat, global);
		for (let i = 0; i < 101; i++) add(`active-${i}`, "ACTIVE", now - 1, null);
		add("live", "ACTIVE", now + 1, null);
		add("global", "ACTIVE", now - 1, null, "event");
		add("win", "VERIFIED_WIN", now - 10000000, now - 10000000);
		add("recent", "FORFEIT", now, now - 7199999);
		add("old", "VERIFIED_LOSS", now, now - 7200000);
		const query = "SELECT session_id FROM solo_hunt_sessions WHERE status = 'ACTIVE' AND global_event_id IS NULL AND expires_at <= ? ORDER BY expires_at LIMIT 100";
		expect(JSON.stringify(db.query(`EXPLAIN QUERY PLAN ${query}`).all(now))).toContain("solo_hunt_active_expiry");
		const terminal = "SELECT session_id FROM solo_hunt_sessions WHERE global_event_id IS NULL AND status IN ('VERIFIED_LOSS', 'FORFEIT', 'EXPIRED') AND compacted_at IS NULL AND (CASE WHEN status = 'EXPIRED' THEN expires_at ELSE finished_at END) <= ? ORDER BY (CASE WHEN status = 'EXPIRED' THEN expires_at ELSE finished_at END) LIMIT 100";
		expect(JSON.stringify(db.query(`EXPLAIN QUERY PLAN ${terminal}`).all(now))).toContain("solo_hunt_terminal_retention");
		expect(maintainSoloHunts(db, now)).toEqual({ expired: 50, compacted: 1 });
		expect(maintainSoloHunts(db, now)).toEqual({ expired: 50, compacted: 0 });
		expect(maintainSoloHunts(db, now)).toEqual({ expired: 1, compacted: 0 });
		const row = db.query("SELECT * FROM solo_hunt_sessions WHERE session_id = ?").get("old") as any;
		expect(row.player_snapshot_json).toBe("{}");
		expect(readHuntCombat(row.combat_state_json)).toEqual(JSON.parse(combat));
		expect(row.combat_state_json.length).toBeLessThan(combat.length / 4);
		expect(row.boss_snapshot_json).toBe('{"name":"guardian"}');
		for (const id of ["win", "recent", "global", "live"]) expect((db.query("SELECT compacted_at FROM solo_hunt_sessions WHERE session_id = ?").get(id) as any).compacted_at).toBeNull();
		expect((db.query("SELECT status FROM solo_hunt_sessions WHERE session_id = 'global'").get() as any).status).toBe("ACTIVE");
		expect(maintainSoloHunts(db, now)).toEqual({ expired: 0, compacted: 0 });
		db.query("UPDATE solo_hunt_sessions SET expires_at = ? WHERE session_id = 'active-0'").run(now - 7200000);
		expect(maintainSoloHunts(db, now)).toEqual({ expired: 0, compacted: 1 });
		expect((db.query("SELECT compacted_at FROM solo_hunt_sessions WHERE session_id = 'active-0'").get() as any).compacted_at).toBe(now);
	} finally { db.close(); }
});

test("independent SQLite connections make progress on expiry and compaction without duplicating work", () => {
	const dir = mkdtempSync(join(tmpdir(), "ew-hunt-two-db-")), path = join(dir, "test.sqlite");
	const first = new Database(path), second = new Database(path);
	try {
		const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
		for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) first.exec(readFileSync(resolve(migrations, file), "utf8"));
		const insert = first.query("INSERT INTO solo_hunt_sessions(session_id,player_id,hunt_id,rotation_key,status,boss_snapshot_json,player_snapshot_json,started_at,expires_at,finished_at) VALUES(?,?, 'hunt_common', 1, ?, '{}', '{}', 1, 2, ?)");
		for (let i = 0; i < 110; i++) { insert.run(`a${i}`, `a${i}`, "ACTIVE", null); insert.run(`f${i}`, `f${i}`, "FORFEIT", 2); }
		const now = 10_000_000;
		expect(maintainSoloHunts(first, now)).toEqual({ expired: 50, compacted: 50 });
		expect(maintainSoloHunts(second, now)).toEqual({ expired: 50, compacted: 50 });
		const third = maintainSoloHunts(first, now);
		expect(third.expired).toBe(10);
		expect(third.compacted).toBe(50);
	} finally { first.close(); second.close(); rmSync(dir, { recursive: true, force: true }); }
});

test("two processes serialize bounded maintenance on the same WAL database", async () => {
	const dir = mkdtempSync(join(tmpdir(), "ew-hunt-processes-")), path = join(dir, "test.sqlite");
	const db = new Database(path);
	try {
		db.exec("PRAGMA journal_mode=WAL");
		const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
		for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(migrations, file), "utf8"));
		const insert = db.query("INSERT INTO solo_hunt_sessions(session_id,player_id,hunt_id,rotation_key,status,boss_snapshot_json,player_snapshot_json,started_at,expires_at,finished_at) VALUES(?,?, 'hunt_common', 1, ?, '{}', '{}', 1, 2, ?)");
		for (let i = 0; i < 120; i++) { insert.run(`a${i}`, `a${i}`, "ACTIVE", null); insert.run(`f${i}`, `f${i}`, "FORFEIT", 2); }
		const script = `import { Database } from 'bun:sqlite'; import { maintainSoloHunts } from './src/solo_hunt_retention'; const db = new Database(process.env.HUNT_TEST_DB); db.exec('PRAGMA busy_timeout=10000'); console.log(JSON.stringify(maintainSoloHunts(db, 10000000))); db.close();`;
		const cwd = resolve(import.meta.dir, "../..");
		const children = [0, 1].map(() => Bun.spawn([process.execPath, "-e", script], { cwd, env: { ...process.env, HUNT_TEST_DB: path }, stdout: "pipe", stderr: "pipe" }));
		const results = await Promise.all(children.map(async child => ({ code: await child.exited, output: await new Response(child.stdout).text(), error: await new Response(child.stderr).text() })));
		expect(results.map(result => ({ code: result.code, error: result.error }))).toEqual([{ code: 0, error: "" }, { code: 0, error: "" }]);
		for (const result of results) { const counts = JSON.parse(result.output); expect(counts.expired + counts.compacted).toBeLessThanOrEqual(100); }
		expect((db.query("SELECT COUNT(*) AS n FROM solo_hunt_sessions WHERE status = 'ACTIVE'").get() as any).n).toBe(20);
		expect((db.query("SELECT COUNT(*) AS n FROM solo_hunt_sessions WHERE compacted_at IS NOT NULL").get() as any).n).toBeGreaterThanOrEqual(50);
	} finally { db.close(); rmSync(dir, { recursive: true, force: true }); }
}, 30000);

test("server expires an abandoned 45 minute hunt without owner traffic", async () => {
	const dir = mkdtempSync(join(tmpdir(), "ew-hunt-maintenance-"));
	const db = new Database(join(dir, "test.sqlite"));
	const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
	for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(migrations, file), "utf8"));
	const now = Date.now();
	db.query("INSERT INTO solo_hunt_sessions(session_id, player_id, hunt_id, rotation_key, status, boss_snapshot_json, player_snapshot_json, started_at, expires_at) VALUES('abandoned','absent','hunt_common',1,'ACTIVE','{}','{}',?,?)").run(now - 2700001, now - 1);
	const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env: { ...process.env, DB_PATH: join(dir, "test.sqlite"), NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: "0", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1" }, stdout: "ignore", stderr: "ignore" });
	try {
		const deadline = Date.now() + 75000;
		while (Date.now() < deadline && (db.query("SELECT status FROM solo_hunt_sessions WHERE session_id='abandoned'").get() as any).status === "ACTIVE") {
			if (server.exitCode !== null) throw new Error("server exited");
			await Bun.sleep(500);
		}
		expect((db.query("SELECT status FROM solo_hunt_sessions WHERE session_id='abandoned'").get() as any).status).toBe("EXPIRED");
	} finally { server.kill(); await server.exited; db.close(); rmSync(dir, { recursive: true, force: true }); }
}, 85000);
