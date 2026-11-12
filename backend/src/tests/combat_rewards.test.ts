import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { randomUUID } from "node:crypto";
import { evaluateCombatReward, recordVerifiedCombatResult } from "../combat_rewards";

async function freePort(): Promise<number> {
	return new Promise((done, fail) => {
		const server = createServer();
		server.once("error", fail);
		server.listen(0, "127.0.0.1", () => { const port = (server.address() as { port: number }).port; server.close(() => done(port)); });
	});
}

test("verified rewards are isolated, atomic and cannot be forged or rerolled", async () => {
	const dir = mkdtempSync(join(tmpdir(), "entitywars-combat-rewards-"));
	const path = join(dir, "isolated.sqlite");
	const db = new Database(path);
	const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
	for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
	const ports = [await freePort(), await freePort()];
	while (ports[1] === ports[0]) ports[1] = await freePort();
	const env = { ...process.env, DB_PATH: path, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0" };
	const servers = ports.map(port => Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env: { ...env, PORT: String(port) }, stdout: "ignore", stderr: "pipe" }));
	const request = async (n: number, route: string, body?: unknown, token?: string) => {
		const res = await fetch(`http://127.0.0.1:${ports[n]}${route}`, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
		return { status: res.status, data: await res.json() as any };
	};
	try {
		for (let n = 0; n < 2; n++) {
			let ready = false;
			for (let i = 0; i < 100; i++) { try { if ((await request(n, "/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
			if (!ready) throw new Error(`Backend ${n} failed: ${servers[n].exitCode !== null ? await new Response(servers[n].stderr).text() : "startup timeout"}`);
		}
		const a = await request(0, "/auth/dev_login", { name: "combat_reward_fixture" });
		const a2 = await request(1, "/auth/dev_login", { name: "combat_reward_fixture" });
		const b = await request(0, "/auth/dev_login", { name: "combat_reward_other" });
		expect(a.status).toBe(200);
		expect(a2.data.player_id).toBe(a.data.player_id);
		const playerId = a.data.player_id as string;
		const readState = () => JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(playerId) as { state_json: string }).state_json);
		const initial = readState();
		initial.custom_fixture = { retained: true };
		db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(initial), playerId);
		const forceShard = { combat_rewards: { arcane_shard: 1, time_crystal: 0, primordial_sigil: 0 } };
		const noDrop = { combat_rewards: { arcane_shard: 0, time_crystal: 0, primordial_sigil: 0 } };
		const official = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/static/balance.json"), "utf8")).balance;
		expect(official.combat_rewards).toEqual({ arcane_shard: 0.025, time_crystal: 0.004, primordial_sigil: 0.001 });
		expect(evaluateCombatReward({ status: "VERIFIED_LOSS" }, forceShard)).toBeNull();
		expect(evaluateCombatReward({ status: "INVALID" }, forceShard)).toBeNull();
		expect(evaluateCombatReward({ status: "VERIFIED_WIN" }, noDrop)).toBeNull();
		const win = recordVerifiedCombatResult(db, { player_id: playerId, status: "VERIFIED_WIN" }, forceShard);
		const loss = recordVerifiedCombatResult(db, { player_id: playerId, status: "VERIFIED_LOSS" }, forceShard);
		const invalid = recordVerifiedCombatResult(db, { player_id: playerId, status: "INVALID" }, forceShard);
		const empty = recordVerifiedCombatResult(db, { player_id: playerId, status: "VERIFIED_WIN" }, noDrop);
		const claim = (n: number, match: string, action: string, token?: string, extra: object = {}) => request(n, "/combat/rewards/claim", { match_id: match, client_action_id: action, ...extra }, token);
		expect((await claim(0, win, randomUUID())).status).toBe(401);
		expect((await claim(0, win, randomUUID(), b.data.token)).status).toBe(404);
		const receiptsBefore = (db.query("SELECT count(*) AS n FROM combat_reward_receipts").get() as { n: number }).n;
		for (const id of [loss, invalid, randomUUID()]) expect((await claim(0, id, randomUUID(), a.data.token, { victory: true, score: "2-0" })).status).toBe(404);
		expect((db.query("SELECT count(*) AS n FROM combat_reward_receipts").get() as { n: number }).n).toBe(receiptsBefore);
		expect(readState().wallet.arcane_shard ?? 0).toBe(initial.wallet.arcane_shard ?? 0);
		const actionId = randomUUID();
		const concurrent = await Promise.all([claim(0, win, actionId, a.data.token), claim(1, win, actionId, a2.data.token)]);
		expect(concurrent.map(r => r.status)).toEqual([200, 200]);
		expect(concurrent.map(r => r.data.duplicate).sort()).toEqual([false, true]);
		expect(concurrent[0].data.reward).toEqual({ resource_id: "arcane_shard", amount: 1 });
		expect(concurrent[1].data.reward).toEqual(concurrent[0].data.reward);
		expect((await claim(0, win, randomUUID(), a.data.token)).data.duplicate).toBe(true);
		expect((await claim(0, win, actionId, a.data.token)).data.duplicate).toBe(true);
		expect((await claim(0, empty, actionId, a.data.token)).status).toBe(409);
		const after = readState();
		expect(after.wallet.arcane_shard).toBe((initial.wallet.arcane_shard ?? 0) + 1);
		expect(after.world).toEqual(initial.world);
		expect(after.spell_progress).toEqual(initial.spell_progress);
		expect(after.custom_fixture).toEqual({ retained: true });
		expect((db.query("SELECT count(*) AS n FROM audit_wallet WHERE player_id = ? AND reason = 'COMBAT_REWARD_CLAIM' AND related_id = ?").get(playerId, win) as { n: number }).n).toBe(1);
		const concurrentDifferent = recordVerifiedCombatResult(db, { player_id: playerId, status: "VERIFIED_WIN" }, forceShard);
		const differentActions = await Promise.all([claim(0, concurrentDifferent, randomUUID(), a.data.token), claim(1, concurrentDifferent, randomUUID(), a2.data.token)]);
		expect(differentActions.map(r => r.status)).toEqual([200, 200]);
		expect(differentActions.map(r => r.data.duplicate).sort()).toEqual([false, true]);
		expect(readState().wallet.arcane_shard).toBe((initial.wallet.arcane_shard ?? 0) + 2);
		expect((db.query("SELECT count(*) AS n FROM audit_wallet WHERE player_id = ? AND reason = 'COMBAT_REWARD_CLAIM' AND related_id = ?").get(playerId, concurrentDifferent) as { n: number }).n).toBe(1);
		const noReward = await claim(0, empty, randomUUID(), a.data.token);
		expect(noReward.status).toBe(200);
		expect(noReward.data.reward).toBeNull();
		expect((await claim(0, empty, randomUUID(), a.data.token)).data.duplicate).toBe(true);
		for (const resource of ["time_crystal", "primordial_sigil"] as const) {
			const table = { arcane_shard: 0, time_crystal: 0, primordial_sigil: 0, [resource]: 1 };
			const receipt = recordVerifiedCombatResult(db, { player_id: playerId, status: "VERIFIED_WIN" }, { combat_rewards: table });
			const result = await claim(0, receipt, randomUUID(), a.data.token);
			expect(result.status).toBe(200);
			expect(result.data.reward).toEqual({ resource_id: resource, amount: 1 });
			expect(readState().wallet[resource]).toBe((initial.wallet[resource] ?? 0) + 1);
		}
		const capState = readState();
		capState.wallet.arcane_shard = official.wallet_caps?.arcane_shard ?? official.wallet_max_per_resource ?? 1_000_000_000;
		db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(capState), playerId);
		const capped = recordVerifiedCombatResult(db, { player_id: playerId, status: "VERIFIED_WIN" }, forceShard);
		expect((await claim(0, capped, randomUUID(), a.data.token)).status).toBe(400);
		expect((db.query("SELECT claimed_at FROM combat_reward_receipts WHERE match_id = ?").get(capped) as { claimed_at: number | null }).claimed_at).toBeNull();
		expect(readState().wallet.arcane_shard).toBe(capState.wallet.arcane_shard);
		const corrupt = recordVerifiedCombatResult(db, { player_id: playerId, status: "VERIFIED_WIN" }, noDrop);
		db.query("UPDATE combat_reward_receipts SET reward_json = ? WHERE match_id = ?").run(JSON.stringify({ resource_id: "essence", amount: 10 }), corrupt);
		expect((await claim(0, corrupt, randomUUID(), a.data.token)).status).toBe(500);
		expect((db.query("SELECT claimed_at FROM combat_reward_receipts WHERE match_id = ?").get(corrupt) as { claimed_at: number | null }).claimed_at).toBeNull();
	} finally {
		for (const server of servers) server.kill();
		await Promise.all(servers.map(server => server.exited));
		db.close();
		for (let attempt = 0; ; attempt++) {
			try { rmSync(dir, { recursive: true, force: true }); break; }
			catch (error) {
				if (attempt >= 20 || (error as NodeJS.ErrnoException).code !== "EBUSY") throw error;
				await Bun.sleep(250);
			}
		}
	}
}, 60_000);
