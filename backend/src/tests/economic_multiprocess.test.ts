import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { createHash } from "node:crypto";

async function freePort(): Promise<number> {
  return new Promise((done, fail) => {
    const server = createServer();
    server.once("error", fail);
    server.listen(0, "127.0.0.1", () => { const port = (server.address() as {port:number}).port; server.close(() => done(port)); });
  });
}

test("shared SQLite serializes economic actions across two Bun processes", async () => {
  const dir = mkdtempSync(join(tmpdir(), "entitywars-multiprocess-"));
  const path = join(dir, "isolated.sqlite");
  const db = new Database(path);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const ports = [await freePort(), await freePort()];
  while (ports[1] === ports[0]) ports[1] = await freePort();
  const base = ports.map(p => `http://127.0.0.1:${p}`);
  const balance = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/static/balance.json"), "utf8")).balance;
  const interval = Math.max(1, Number(balance.boss_interval_minutes ?? 120)) * 60000;
  const window = Math.max(1, Number(balance.boss_window_minutes ?? 15)) * 60000;
  const now = Date.now();
  let worldSecret = "";
  for (let i = 0; i < 10000; i++) {
    const candidate = `test-world-${i}`;
    const offset = createHash("sha256").update(`${candidate}:boss_offset:boss_common`).digest().readUInt32BE(0) % Math.max(1, interval - window);
    const start = Math.floor((now - offset) / interval) * interval + offset;
    if (now >= start && now + 60000 < start + window) { worldSecret = candidate; break; }
  }
  if (!worldSecret) throw new Error("Could not create active boss fixture");
  const env = { ...process.env, DB_PATH: path, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0", WORLD_SECRET: worldSecret };
  const processes = ports.map(port => Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env: { ...env, PORT: String(port) }, stdout: "ignore", stderr: "pipe" }));
  const request = async (server: number, route: string, body?: unknown, token?: string) => {
    const res = await fetch(base[server] + route, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: res.status, data: await res.json() as any };
  };
  try {
    for (let server = 0; server < 2; server++) {
      let ready = false;
      for (let i = 0; i < 100; i++) { try { if ((await request(server, "/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
      if (!ready && processes[server].exitCode !== null) throw new Error(`Backend ${server} exited: ${await new Response(processes[server].stderr).text()}`);
      expect(ready).toBe(true);
    }
    const a = await request(0, "/auth/dev_login", { name: "multi_buyer" });
    const b = await request(1, "/auth/dev_login", { name: "multi_buyer" });
    expect(a.data.player_id).toBe(b.data.player_id);
    const id = a.data.player_id as string;
    const tokens = [a.data.token, b.data.token];
    const row = () => db.query("SELECT state_json FROM players WHERE player_id = ?").get(id) as {state_json:string};
    const state = JSON.parse(row().state_json);
    state.wallet.essence = 1000;
    state.wallet.core = 100;
    state.lab.buildings.build_forge = { level: 1, route: "" };
    state.lab.buildings.world_gate = { level: 1, route: "" };
    state.item_progress = {};
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), id);
    const pair = (route: string, payloads: unknown[]) => Promise.all([request(0, route, payloads[0], tokens[0]), request(1, route, payloads[1], tokens[1])]);
    const forge = {client_action_id:"multi-forge", action_type:"FORGE_UPGRADE", payload:{item_id:"bismuth_talisman"}};
    const upgraded = await pair("/player/action", [forge, forge]);
    expect(upgraded.map(r => r.status)).toEqual([200, 200]);
    expect(JSON.parse(row().state_json).wallet.essence).toBe(980);
    expect(JSON.parse(row().state_json).item_progress.bismuth_talisman.level).toBe(1);
    const conflictA = {...forge, client_action_id:"multi-conflict", payload:{item_id:"bismuth_talisman"}};
    const conflictB = {...forge, client_action_id:"multi-conflict", payload:{item_id:"wind_amulet"}};
    expect((await pair("/player/action", [conflictA, conflictB])).map(r => r.status).sort()).toEqual([200, 409]);
    const order = {client_action_id:"multi-order", resource_id:"core", amount:10, price_amount:2};
    const orders = await pair("/market/order", [order, order]);
    expect(orders.map(r => r.status)).toEqual([200, 200]);
    expect(orders[0].data.order_id).toBe(orders[1].data.order_id);
    expect(JSON.parse(row().state_json).wallet.core).toBe(90);
    const buyerA = await request(0, "/auth/dev_login", { name: "multi_customer" });
    const buyerB = await request(1, "/auth/dev_login", { name: "multi_customer" });
    expect(buyerA.data.player_id).toBe(buyerB.data.player_id);
    const buyerId = buyerA.data.player_id as string;
    const buyerRow = () => db.query("SELECT state_json FROM players WHERE player_id = ?").get(buyerId) as {state_json:string};
    const buyerState = JSON.parse(buyerRow().state_json);
    buyerState.wallet.essence = 100;
    buyerState.wallet.core = 0;
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(buyerState), buyerId);
    const buy = {client_action_id:"multi-buy", order_id:orders[0].data.order_id, amount:4};
    const buys = await Promise.all([request(0, "/market/buy", buy, buyerA.data.token), request(1, "/market/buy", buy, buyerB.data.token)]);
    expect(buys.map(r => r.status)).toEqual([200, 200]);
    expect(JSON.parse(buyerRow().state_json).wallet.essence).toBe(92);
    expect(JSON.parse(buyerRow().state_json).wallet.core).toBe(4);
    expect((db.query("SELECT COUNT(*) AS n FROM market_fills WHERE order_id = ?").get(orders[0].data.order_id) as {n:number}).n).toBe(1);
    expect((db.query("SELECT amount FROM escrow WHERE player_id = ? AND resource_id = 'core'").get(id) as {amount:number}).amount).toBe(6);
    const job = {client_action_id:"multi-job", input_resource_id:"core", input_amount:2, output_resource_id:"arcane_shard", output_min:1, output_max:3, duration_sec:0, commission_resource_id:"essence", commission_amount:5, queue_limit:2};
    const jobs = await pair("/trade/jobs", [job, job]);
    expect(jobs.map(r => r.status)).toEqual([200, 200]);
    expect(jobs[0].data.job_id).toBe(jobs[1].data.job_id);
    expect((await request(0, "/trade/jobs", {...job, input_amount:3}, tokens[0])).status).toBe(409);
    const submit = {client_action_id:"multi-submit", job_id:jobs[0].data.job_id};
    const submits = await Promise.all([request(0, "/trade/submit", submit, buyerA.data.token), request(1, "/trade/submit", submit, buyerB.data.token)]);
    expect(submits.map(r => r.status)).toEqual([200, 200]);
    expect(submits[0].data.run_id).toBe(submits[1].data.run_id);
    expect(JSON.parse(buyerRow().state_json).wallet.core).toBe(2);
    const claim = {client_action_id:"multi-claim", run_id:submits[0].data.run_id};
    const claims = await Promise.all([request(0, "/trade/claim", claim, buyerA.data.token), request(1, "/trade/claim", claim, buyerB.data.token)]);
    expect(claims.map(r => r.status)).toEqual([200, 200]);
    expect((db.query("SELECT COUNT(*) AS n FROM trade_job_runs WHERE job_id = ?").get(jobs[0].data.job_id) as {n:number}).n).toBe(1);
    const beforeWorld = JSON.parse(row().state_json).wallet.essence;
    const entry = {client_action_id:"multi-world", zone_id:"zone_corrupted"};
    const worlds = await pair("/world/enter", [entry, entry]);
    expect(worlds.map(r => r.status)).toEqual([200, 200]);
    expect(worlds[0].data.session_id).toBe(worlds[1].data.session_id);
    expect(JSON.parse(row().state_json).world.daily_entries).toBe(1);
    const worldRow = db.query("SELECT state_json FROM world LIMIT 1").get() as {state_json:string};
    const worldFixture = JSON.parse(worldRow.state_json);
    const rotatedZone = worldFixture.zones.find((zone:any) => zone.zone_id === "zone_corrupted");
    rotatedZone.rotation_ends_at = Date.now() - 1;
    db.query("UPDATE world SET state_json = ?").run(JSON.stringify(worldFixture));
    const rotated = await request(1, "/world/state", undefined, tokens[1]);
    expect(rotated.data.world_state.zones.find((zone:any) => zone.zone_id === "zone_corrupted").rotation_ends_at).toBeGreaterThan(Date.now());
    expect((await request(1, "/world/enter", entry, tokens[1])).status).toBe(200);
    expect((await request(1, "/world/enter", {...entry, zone_id:"zone_unknown"}, tokens[1])).status).toBe(409);
    expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = ?").get(id, "multi-world") as {n:number}).n).toBe(1);
    expect((db.query("SELECT COUNT(*) AS n FROM market_orders WHERE seller_id = ?").get(id) as {n:number}).n).toBe(1);
    expect(JSON.parse(row().state_json).wallet.essence).toBe(beforeWorld - 5);
    const tickets = JSON.parse(row().state_json).world.boss_tickets;
    const attack = {client_action_id:"multi-boss", boss_id:"boss_common"};
    const attacks = await pair("/boss/attack", [attack, attack]);
    expect(attacks.map(r => r.status)).toEqual([200, 200]);
    expect(JSON.parse(row().state_json).world.boss_tickets).toBe(tickets - 1);
    expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = ?").get(id, "multi-boss") as {n:number}).n).toBe(1);
    expect((await request(1, "/boss/attack", {...attack, boss_id:"boss_colossus"}, tokens[1])).status).toBe(409);
    let closedSecret = "";
    for (let i = 0; i < 10000; i++) {
      const candidate = `test-closed-${i}`;
      const current = Date.now();
      const offset = createHash("sha256").update(`${candidate}:boss_offset:boss_common`).digest().readUInt32BE(0) % Math.max(1, interval - window);
      const start = Math.floor((current - offset) / interval) * interval + offset;
      if (current >= start + window) { closedSecret = candidate; break; }
    }
    expect(closedSecret).not.toBe("");
    processes[1].kill();
    await processes[1].exited;
    processes[1] = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env: { ...env, PORT: String(ports[1]), WORLD_SECRET: closedSecret }, stdout: "ignore", stderr: "pipe" });
    let restarted = false;
    for (let i = 0; i < 100; i++) { try { if ((await request(1, "/health")).status === 200) { restarted = true; break; } } catch {} await Bun.sleep(100); }
    expect(restarted).toBe(true);
    const relogin = await request(1, "/auth/dev_login", {name:"multi_buyer"});
    const bossState = await request(1, "/boss/state");
    const boss = bossState.data.bosses.find((item: any) => item.boss_id === "boss_common");
    expect(Date.now()).toBeGreaterThan(boss.window_ends_at);
    expect((await request(1, "/boss/attack", attack, relogin.data.token)).status).toBe(200);
    expect(JSON.parse(row().state_json).world.boss_tickets).toBe(tickets - 1);
  } finally {
    for (const process of processes) process.kill();
    await Promise.all(processes.map(p => p.exited));
    db.close();
    rmSync(dir, {recursive:true, force:true});
  }
}, 60000);
