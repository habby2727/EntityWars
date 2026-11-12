import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";

test("FORGE_UPGRADE persists, charges once and rejects invalid actions", async () => {
	await new Promise<void>((resolvePort, reject) => {
		const probe = createServer();
		probe.once("error", () => reject(new Error("Port 8787 is occupied; refusing to use an existing server")));
		probe.listen(8787, "0.0.0.0", () => probe.close(() => resolvePort()));
	});
  const directory = mkdtempSync(join(tmpdir(), "entitywars-forge-"));
  const dbPath = join(directory, "test.sqlite");
  const db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter((f) => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0" };
  let server: ReturnType<typeof Bun.spawn> | undefined;
  const start = async () => {
    server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
    for (let i = 0; i < 100; i++) {
      if (server.exitCode !== null) throw new Error("Test backend exited before startup (port 8787 may be occupied)");
      try { if ((await fetch("http://127.0.0.1:8787/health")).ok) return; } catch {}
      await Bun.sleep(100);
    }
    throw new Error("Test backend did not start on port 8787");
  };
  const stop = async () => { if (server) { server.kill(); await server.exited; server = undefined; } };
  const request = async (path: string, body?: unknown, token?: string) => {
    const res = await fetch("http://127.0.0.1:8787" + path, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: res.status, data: await res.json() as any };
  };
  try {
    await start();
    let login = await request("/auth/dev_login", { name: "forge_test_isolated" });
    expect(login.status).toBe(200);
    let token = login.data.token as string;
    const playerId = login.data.player_id as string;
    expect(token).toBeTruthy();
    expect(playerId).toBeTruthy();
    const getRow = () => db.query("SELECT state_json FROM players WHERE player_id = ?").get(playerId) as { state_json: string };
    const writeState = (state: any) => db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), playerId);
    const seed = JSON.parse(getRow().state_json);
    seed.wallet.essence = 100;
    seed.lab.buildings.build_forge = { level: 1, route: "" };
    seed.research_flags = { archive_basics: true };
    seed.custom_fixture = { retained: true };
    seed.item_progress = { bismuth_talisman: { level: 0, extra: { retained: true } } };
    const originalSpells = seed.spell_progress;
    writeState(seed);
    const action = (id: string) => request("/player/action", { client_action_id: id, action_type: "FORGE_UPGRADE", payload: { item_id: "bismuth_talisman" } }, token);
    const first = await action("forge-upgrade-1");
    expect(first.status).toBe(200);
    expect(first.data.updated_player_state.item_progress.bismuth_talisman.level).toBe(1);
    expect(first.data.updated_player_state.wallet.essence).toBe(80);
    expect(first.data.updated_player_state.state_revision).toBe((seed.state_revision ?? 0) + 1);
    const duplicate = await action("forge-upgrade-1");
    expect(duplicate.status).toBe(200);
    expect(duplicate.data.updated_player_state.state_revision).toBe(first.data.updated_player_state.state_revision);
    expect(JSON.parse(getRow().state_json).wallet.essence).toBe(80);
    expect(JSON.parse(getRow().state_json).item_progress.bismuth_talisman.level).toBe(1);
    const conflicting = await request("/player/action", { client_action_id: "forge-upgrade-1", action_type: "FORGE_UPGRADE", payload: { item_id: "wind_amulet" } }, token);
    expect(conflicting.status).toBe(409);
    const differentType = await request("/player/action", { client_action_id: "forge-upgrade-1", action_type: "CLAIM_PRODUCTION", payload: { item_id: "bismuth_talisman" } }, token);
    expect(differentType.status).toBe(409);
    const marketConflict = await request("/market/order", { client_action_id: "forge-upgrade-1", resource_id: "core", amount: 1, price_amount: 1 }, token);
    expect(marketConflict.status).toBe(409);
    const worldConflict = await request("/world/enter", { client_action_id: "forge-upgrade-1", zone_id: "zone_corrupted" }, token);
    expect(worldConflict.status).toBe(409);
    const marketPayload = { client_action_id: "market-id-test", resource_id: "core", amount: 1, price_amount: 1 };
    const market = await request("/market/order", marketPayload, token);
    expect(market.status).toBe(200);
    const marketRepeat = await request("/market/order", { price_amount: 1, amount: 1, resource_id: "core", client_action_id: "market-id-test" }, token);
    expect(marketRepeat.status).toBe(200);
    expect(marketRepeat.data.order_id).toBe(market.data.order_id);
    expect((await request("/market/order", { ...marketPayload, amount: 2 }, token)).status).toBe(409);
    const second = await action("forge-upgrade-2");
    expect(second.status).toBe(200);
    expect(second.data.updated_player_state.state_revision).toBe(first.data.updated_player_state.state_revision + 2);
    const oldRetry = await action("forge-upgrade-1");
    expect(oldRetry.data.updated_player_state.item_progress.bismuth_talisman.level).toBe(2);
    expect(oldRetry.data.updated_player_state.wallet.essence).toBe(50);
    await stop();
    await start();
    login = await request("/auth/dev_login", { name: "forge_test_isolated" });
    expect(login.status).toBe(200);
    token = login.data.token;
    const reloaded = (await request("/player/state", undefined, token)).data.updated_player_state;
    expect(reloaded.item_progress.bismuth_talisman.level).toBe(2);
    expect(reloaded.spell_progress).toEqual(originalSpells);
    expect(reloaded.research_flags.archive_basics).toBe(true);
    expect(reloaded.custom_fixture).toEqual({ retained: true });
    expect(reloaded.item_progress.bismuth_talisman.extra).toEqual({ retained: true });
    expect(reloaded.lab.buildings.build_forge.level).toBe(1);
    expect(reloaded.world.sessions).toEqual(seed.world.sessions);
    expect(reloaded.wallet.essence).toBe(50);
    const worldSeed = JSON.parse(getRow().state_json);
    worldSeed.world.stamina = 0;
    worldSeed.world.last_stamina_at = Date.now() - 3600_000;
    worldSeed.world.last_entry_reset_at = Date.now();
    worldSeed.world.last_boss_ticket_at = Date.now();
    writeState(worldSeed);
    const beforeWorldRevision = JSON.parse(getRow().state_json).state_revision;
    expect((await request("/world/state", undefined, token)).status).toBe(200);
    const afterWorld = JSON.parse(getRow().state_json);
    expect(afterWorld.world.stamina).toBeGreaterThan(0);
    expect(afterWorld.state_revision).toBe(beforeWorldRevision + 1);
    expect((await request("/world/state", undefined, token)).status).toBe(200);
    expect(JSON.parse(getRow().state_json).state_revision).toBe(afterWorld.state_revision);
    for (const [scenario, balance, expectedSuccesses, expectedLevel, expectedBalance] of [["enough", 100, 2, 2, 50], ["limited", 20, 1, 1, 0]] as const) {
      const state = JSON.parse(getRow().state_json);
      state.wallet.essence = balance;
      state.item_progress.bismuth_talisman.level = 0;
      writeState(state);
      const responses = await Promise.all([action(`forge-${scenario}-a`), action(`forge-${scenario}-b`)]);
      expect(responses.filter((response) => response.status === 200)).toHaveLength(expectedSuccesses);
      const after = JSON.parse(getRow().state_json);
      expect(after.item_progress.bismuth_talisman.level).toBe(expectedLevel);
      expect(after.wallet.essence).toBe(expectedBalance);
    }
    for (const scenario of ["insufficient", "unbuilt", "maximum"]) {
      const state = JSON.parse(getRow().state_json);
      state.wallet.essence = scenario === "insufficient" ? 0 : 100;
      state.lab.buildings.build_forge.level = scenario === "unbuilt" ? 0 : 1;
      state.item_progress.bismuth_talisman.level = scenario === "maximum" ? 10 : 1;
      writeState(state);
      const rejected = await action(`forge-${scenario}`);
      expect(rejected.status).toBe(400);
      const after = JSON.parse(getRow().state_json);
      expect(after.wallet.essence).toBe(state.wallet.essence);
      expect(after.item_progress.bismuth_talisman.level).toBe(state.item_progress.bismuth_talisman.level);
      expect(after.state_revision).toBe(state.state_revision);
    }
  } finally {
    await stop();
    db.close();
    rmSync(directory, { recursive: true, force: true });
  }
}, 60000);
