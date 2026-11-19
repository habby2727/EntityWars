import { expect, mock, test } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readFileSync, readdirSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

let disabled = false;
mock.module("../db/postgres", () => ({
	AccountStatusUnavailableError: class extends Error {},
	isUserDisabled: async () => disabled,
	getPostgres: () => async () => [],
	pingPostgres: async () => true, postgresExample: async () => {}, upsertUser: async () => {}
}));
mock.module("../auth/idle", () => ({
	idleEnabled: () => true,
	resetIdle: async () => {}, checkIdle: async () => true,
	bindRefreshIdle: async () => {}, checkRefreshIdle: async () => true,
	rotateRefreshIdle: async () => true,
	touchIdle: async () => { throw new Error("injected Redis failure"); }
}));

test("failure to update idle after commit returns the confirmed action", async () => {
	const dir = mkdtempSync(join(tmpdir(), "ew-touch-failure-"));
	const dbPath = join(dir, "test.sqlite"), db = new Database(dbPath);
	for (const file of readdirSync(resolve(import.meta.dir, "../../migrations/sqlite")).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite", file), "utf8"));
	const probe = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: () => new Response() });
	const port = probe.port!; probe.stop();
	Object.assign(Bun.env, { DB_PATH: dbPath, NODE_ENV: "test", BUN_ENV: "test", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", AUTH_ACCOUNT_TIMEOUT_MS: "100" });
	await import("../index");
	const base = `http://127.0.0.1:${port}`;
	let ready = false;
	for (let n = 0; n < 100; n++) { try { if ((await fetch(base + "/health")).ok) { ready = true; break; } } catch {} await Bun.sleep(50); }
	expect(ready).toBe(true);
	const registration = await fetch(base + "/auth/register", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ username: "touchfailure", password: "secret1" }) });
	const account = await registration.json() as { token: string; player_id: string };
	const state = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(account.player_id) as any).state_json);
	state.wallet.essence = 1000; state.wallet.core = 100;
	db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), account.player_id);
	const payload = { action_type: "UPGRADE_BUILDING", client_action_id: "touch-failure", payload: { building_id: "lab_th" } };
	const action = () => fetch(base + "/player/action", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${account.token}` }, body: JSON.stringify(payload) });
	const response = await action();
	expect(response.status).toBe(200);
	expect((await response.json() as any).updated_player_state.lab.buildings.lab_th.level).toBe(2);
	expect((await action()).status).toBe(200);
	expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE client_action_id = ?").get(payload.client_action_id) as any).n).toBe(1);
	disabled = true;
	expect((await fetch(base + "/auth/reconnect", { method: "POST", headers: { authorization: `Bearer ${account.token}` } })).status).toBe(403);
	expect((await fetch(base + "/player/state", { headers: { authorization: `Bearer ${account.token}` } })).status).toBe(403);
	db.close();
}, 15000);
