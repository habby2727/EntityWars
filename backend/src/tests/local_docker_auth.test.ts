import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";

test("production rejects both dev login routes even with Docker-local enabled", async () => {
	const dir = mkdtempSync(join(tmpdir(), "entitywars-prod-login-"));
	const dbPath = join(dir, "isolated.sqlite");
	const db = new Database(dbPath);
	const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
	for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
	db.close();
	const port = await new Promise<number>((done, fail) => {
		const probe = createServer();
		probe.once("error", fail);
		probe.listen(0, "127.0.0.1", () => { const value = (probe.address() as { port: number }).port; probe.close(() => done(value)); });
	});
	const env = { ...process.env, NODE_ENV: "production", BUN_ENV: "production", HOST: "127.0.0.1", PORT: String(port), DB_PATH: dbPath, DEV_DOCKER_LOCAL_LOGIN: "1", DEBUG_BYPASS: "1", TOKEN_SIGNING_SECRET: "isolated-test-secret-not-for-production", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1" };
	const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "pipe" });
	try {
		const base = `http://127.0.0.1:${port}`;
		let ready = false;
		for (let i = 0; i < 100; i++) {
			if (server.exitCode !== null) throw new Error(`Server exited: ${await new Response(server.stderr).text()}`);
			try { if ((await fetch(`${base}/health`)).ok) { ready = true; break; } } catch {}
			await Bun.sleep(100);
		}
		expect(ready).toBe(true);
		for (const route of ["/auth/dev_login", "/v1/auth/login"]) {
			const response = await fetch(base + route, { method: "POST", headers: { "Content-Type": "application/json", "X-Debug-Bypass": "1" }, body: JSON.stringify({ name: "fixture" }) });
			expect(response.status).toBe(403);
		}
	} finally {
		server.kill();
		await server.exited;
		for (let i = 0; ; i++) {
			try { rmSync(dir, { recursive: true, force: true }); break; }
			catch (error) { if (i >= 20 || (error as NodeJS.ErrnoException).code !== "EBUSY") throw error; await Bun.sleep(250); }
		}
	}
}, 30_000);
