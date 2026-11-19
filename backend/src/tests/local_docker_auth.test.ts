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
	const env = { ...process.env, MIN_CLIENT_BUILD: "5504", NODE_ENV: "production", BUN_ENV: "production", HOST: "127.0.0.1", PORT: String(port), DB_PATH: dbPath, DEV_DOCKER_LOCAL_LOGIN: "1", DEBUG_BYPASS: "1", DUNGEON_DEBUG_PREPARE: "1", TOKEN_SIGNING_SECRET: "isolated-test-secret-not-for-production", EXPERIMENT_SECRET: "isolated-experiment-secret-0123456789", TRADE_SECRET: "isolated-trade-secret-012345678901234", WORLD_SECRET: "isolated-world-secret-012345678901234", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1" };
	let server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "pipe" });
	try {
		const base = `http://127.0.0.1:${port}`;
		let ready = false;
		for (let i = 0; i < 100; i++) {
			if (server.exitCode !== null) throw new Error(`Server exited: ${await new Response(server.stderr).text()}`);
			try { if ((await fetch(`${base}/health`)).ok) { ready = true; break; } } catch {}
			await Bun.sleep(100);
		}
		expect(ready).toBe(true);
		const version = await fetch(base + "/static/version");
		expect(version.status).toBe(200);
		expect((await version.json()).min_client_build).toBe(5504);
		for (const build of [undefined, "5503", "invalid", "5504.0"]) {
			const headers: Record<string, string> = {};
			if (build !== undefined) headers["X-EntityWars-Client-Build"] = build;
			const response = await fetch(base + "/player/state", { headers });
			expect(response.status).toBe(426);
			expect(await response.json()).toEqual({ error: "CLIENT_UPDATE_REQUIRED", min_client_build: 5504 });
		}
		expect((await fetch(base + "/player/state", { headers: { "X-EntityWars-Client-Build": "5504" } })).status).not.toBe(426);
		expect((await fetch(base + "/player/state", { headers: { "X-EntityWars-Client-Build": "5504", Authorization: "Bearer unavailable" } })).status).toBe(503);
		for (const route of ["/auth/dev_login", "/v1/auth/login"]) {
			const response = await fetch(base + route, { method: "POST", headers: { "Content-Type": "application/json", "X-Debug-Bypass": "1" }, body: JSON.stringify({ name: "fixture" }) });
			expect(response.status).toBe(403);
		}
		const headers = { "Content-Type": "application/json", "X-Debug-Bypass": "1" };
		expect((await fetch(base + "/debug/dungeons/prepare", { method: "POST", headers, body: "{}" })).status).toBe(404);
		expect((await fetch(base + "/ws", { headers })).status).toBe(403);
		server.kill();
		await server.exited;
		server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env: { ...env, MIN_CLIENT_BUILD: "5506" }, stdout: "ignore", stderr: "pipe" });
		let restarted = false;
		for (let i = 0; i < 100; i++) {
			if (server.exitCode !== null) throw new Error(`Server exited: ${await new Response(server.stderr).text()}`);
			try { if ((await fetch(base + "/health")).ok) { restarted = true; break; } } catch {}
			await Bun.sleep(100);
		}
		expect(restarted).toBe(true);
		expect((await (await fetch(base + "/static/version")).json()).min_client_build).toBe(5506);
		const outdated = await fetch(base + "/player/state", { headers: { "X-EntityWars-Client-Build": "5505" } });
		expect(outdated.status).toBe(426);
		expect((await outdated.json()).min_client_build).toBe(5506);
		expect((await fetch(base + "/player/state", { headers: { "X-EntityWars-Client-Build": "5506" } })).status).not.toBe(426);
	} finally {
		server.kill();
		await server.exited;
		for (let i = 0; ; i++) {
			try { rmSync(dir, { recursive: true, force: true }); break; }
			catch (error) { if (i >= 20 || (error as NodeJS.ErrnoException).code !== "EBUSY") throw error; await Bun.sleep(250); }
		}
	}
}, 30_000);


test("production rejects invalid minimum client builds at startup", async () => {
	const dir = mkdtempSync(join(tmpdir(), "entitywars-invalid-build-"));
	try {
		for (const value of ["", "0", "-1", "5504.5", "abc", "9007199254740992"]) {
			const env = { ...process.env, NODE_ENV: "production", BUN_ENV: "production", MIN_CLIENT_BUILD: value, DB_PATH: join(dir, "unused.sqlite"), TOKEN_SIGNING_SECRET: "isolated-test-secret-not-for-production", EXPERIMENT_SECRET: "isolated-experiment-secret-0123456789", TRADE_SECRET: "isolated-trade-secret-012345678901234", WORLD_SECRET: "isolated-world-secret-012345678901234", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1" };
			const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "pipe" });
			const error = await new Response(server.stderr).text();
			expect(await server.exited).not.toBe(0);
			expect(error).toContain("MIN_CLIENT_BUILD must be a positive safe integer");
		}
	} finally {
		rmSync(dir, { recursive: true, force: true });
	}
}, 30_000);
