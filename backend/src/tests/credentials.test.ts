import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";

test("credentials create a separate account and authenticate case insensitively", async () => {
	const dir = mkdtempSync(join(tmpdir(), "ew-credentials-"));
	const dbPath = join(dir, "test.sqlite");
	const db = new Database(dbPath);
	const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
	for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
	db.close();
	const port = await new Promise<number>((done, fail) => {
		const probe = createServer();
		probe.once("error", fail);
		probe.listen(0, "127.0.0.1", () => { const value = (probe.address() as { port: number }).port; probe.close(() => done(value)); });
	});
	const env = { ...process.env, NODE_ENV: "test", BUN_ENV: "test", HOST: "127.0.0.1", PORT: String(port), DB_PATH: dbPath, DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", AUTH_ACCOUNT_TIMEOUT_MS: "100", LOGIN_RATE_LIMIT_MAX: "100" };
	const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
	try {
		const base = `http://127.0.0.1:${port}`;
		let ready = false;
		for (let i = 0; i < 100; i++) {
			try { if ((await fetch(base + "/health")).ok) { ready = true; break; } } catch {}
			await Bun.sleep(100);
		}
		expect(ready).toBe(true);
		const post = (path: string, username: string, password: string) => fetch(base + path, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ username, password }) });
		expect((await post("/auth/register", "Tester", "short")).status).toBe(400);
		const registered = await post("/auth/register", "Tester", "secret1");
		expect(registered.status).toBe(200);
		const first = await registered.json() as { player_id: string; token: string };
		expect((await post("/auth/register", "tEsTeR", "secret1")).status).toBe(409);
		expect((await post("/auth/login", "tester", "wrongpass")).status).toBe(401);
		const logged = await post("/auth/login", "TESTER", "secret1");
		expect(logged.status).toBe(200);
		expect((await logged.json() as { player_id: string }).player_id).toBe(first.player_id);
		expect((await fetch(base + "/player/state", { headers: { Authorization: `Bearer ${first.token}` } })).status).toBe(200);
		expect((await fetch(base + "/player/state", { headers: { Authorization: "Bearer invalid" } })).status).toBe(401);
		const check = new Database(dbPath, { readonly: true });
		const row = check.query("SELECT password_hash FROM credentials WHERE username = ?").get("tester") as { password_hash: string };
		expect(row.password_hash.startsWith("$argon2id$")).toBe(true);
		expect(row.password_hash).not.toContain("secret1");
		check.close();
		if (process.env.GODOT_TEST_BINARY) {
			const runGodot = async (phase: string) => {
				const godot = Bun.spawn([process.env.GODOT_TEST_BINARY!, "--headless", "--path", resolve(import.meta.dir, "../../.."), "--script", "res://scripts/tests/smoke_auth_session.gd"], {
					env: { ...env, APPDATA: dir, AUTH_SMOKE_ROOT: dir, AUTH_SMOKE_PHASE: phase, ENTITYWARS_BACKEND_URL: base }, stdout: "pipe", stderr: "pipe"
				});
				const timer = setTimeout(() => godot.kill(), 22_000);
				const [code, out, err] = await Promise.all([godot.exited, new Response(godot.stdout).text(), new Response(godot.stderr).text()]);
				clearTimeout(timer);
				if (code !== 0) throw new Error(`Godot ${phase} failed (${code}): ${out}\n${err}`);
				console.log(out.trim());
			};
			await runGodot("register");
			await runGodot("cached");
			const authPath = join(dir, "Godot", "app_userdata", "EntityWars", "auth.json");
			const saved = readFileSync(authPath);
			await runGodot("invalid");
			writeFileSync(authPath, saved);
			server.kill();
			await server.exited;
			await runGodot("offline");
		}
	} finally {
		server.kill();
		await server.exited;
		for (let i = 0; ; i++) {
			try { rmSync(dir, { recursive: true, force: true }); break; }
			catch (error) { if (i >= 20 || (error as NodeJS.ErrnoException).code !== "EBUSY") throw error; await Bun.sleep(250); }
		}
	}
}, 60_000);
