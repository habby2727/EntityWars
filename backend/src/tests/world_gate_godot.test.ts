import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";

test("Godot World Gate shows server cooldown and retains session access", async () => {
	const godot = process.env.GODOT_BIN || join(process.env.USERPROFILE || "", "Desktop", "Godot_v4.6.exe");
	if (!existsSync(godot)) throw new Error(`Godot 4.6 not found: ${godot}`);
	const dir = mkdtempSync(join(tmpdir(), "entitywars-world-godot-"));
	const dbPath = join(dir, "test.sqlite");
	const db = new Database(dbPath);
	const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
	for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
	const port = await new Promise<number>((done, fail) => {
		const probe = createServer();
		probe.once("error", fail);
		probe.listen(0, "127.0.0.1", () => { const value = (probe.address() as { port: number }).port; probe.close(() => done(value)); });
	});
	const base = `http://127.0.0.1:${port}`;
	const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0" };
	const backend = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "pipe" });
	try {
		let ready = false;
		for (let i = 0; i < 100; i++) {
			if (backend.exitCode !== null) throw new Error(`Backend exited: ${await new Response(backend.stderr).text()}`);
			try { if ((await fetch(`${base}/health`)).ok) { ready = true; break; } } catch {}
			await Bun.sleep(100);
		}
		expect(ready).toBe(true);
		const login = await fetch(`${base}/auth/dev_login`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: "world_gate_smoke" }) });
		expect(login.status).toBe(200);
		const row = db.query("SELECT player_id, state_json FROM players WHERE display_name = ?").get("world_gate_smoke") as { player_id: string; state_json: string };
		const state = JSON.parse(row.state_json);
		state.wallet.essence = 100;
		state.lab.buildings.world_gate = { level: 1, route: "" };
		db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), row.player_id);
		const log = join(dir, "godot.log");
		const godotEnv = { ...env, APPDATA: dir, LOCALAPPDATA: dir, FORGE_SMOKE_USER_ROOT: dir, FORGE_SMOKE_URL: base, ENTITYWARS_BACKEND_URL: "" };
		const processGodot = Bun.spawn([godot, "--headless", "--path", resolve(import.meta.dir, "../../.."), "--log-file", log, "--script", "res://scripts/tests/smoke_world_entry.gd"], { env: godotEnv, stdout: "ignore", stderr: "ignore" });
		const timeout = setTimeout(() => processGodot.kill(), 30_000);
		const exit = await processGodot.exited;
		clearTimeout(timeout);
		const output = existsSync(log) ? readFileSync(log, "utf8") : "missing Godot log";
		expect({ exit, output }).toEqual(expect.objectContaining({ exit: 0, output: expect.stringContaining("PASS World Gate: explicit entry, cooldown and existing session access") }));
		expect(output).not.toMatch(/SCRIPT ERROR|WORLD_ENTRY_FAIL/);
		for (const [name, level] of [["combat_account_a", 10], ["combat_account_b", 0]] as const) {
			const created = await fetch(`${base}/auth/dev_login`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) });
			expect(created.status).toBe(200);
			const account = db.query("SELECT player_id, state_json FROM players WHERE display_name = ?").get(name) as { player_id: string; state_json: string };
			const accountState = JSON.parse(account.state_json);
			accountState.item_progress = { saltstone_charm: { level } };
			accountState.spell_progress = level === 10
				? { learned_by_entity: { sulfur_01: ["steady_script"] }, equipped_by_mode: { attack: { sulfur_01: ["steady_script", "cinder_fist", "furnace_rush", "ash_temper"] } } }
				: { learned_by_entity: {}, equipped_by_mode: {} };
			db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(accountState), account.player_id);
		}
		const accountLog = join(dir, "accounts.log");
		const accountDir = join(dir, "account-user");
		mkdirSync(accountDir);
		const accountEnv = { ...godotEnv, APPDATA: accountDir, LOCALAPPDATA: accountDir, FORGE_SMOKE_USER_ROOT: accountDir };
		const accountTest = Bun.spawn([godot, "--headless", "--path", resolve(import.meta.dir, "../../.."), "--log-file", accountLog, "--script", "res://scripts/tests/smoke_combat_accounts.gd"], { env: accountEnv, stdout: "ignore", stderr: "ignore" });
		const accountTimeout = setTimeout(() => accountTest.kill(), 60_000);
		const accountExit = await accountTest.exited;
		clearTimeout(accountTimeout);
		const accountOutput = existsSync(accountLog) ? readFileSync(accountLog, "utf8") : "missing Godot log";
		expect({ exit: accountExit, output: accountOutput }).toEqual(expect.objectContaining({ exit: 0, output: expect.stringContaining("PASS real Combat accounts A/B/A") }));
		expect(accountOutput).not.toMatch(/SCRIPT ERROR|COMBAT_SMOKE_FAIL/);
	} finally {
		backend.kill();
		await backend.exited;
		db.close();
		for (let i = 0; ; i++) {
			try { rmSync(dir, { recursive: true, force: true }); break; }
			catch (error) { if (i >= 20 || (error as NodeJS.ErrnoException).code !== "EBUSY") throw error; await Bun.sleep(250); }
		}
	}
}, 90_000);
