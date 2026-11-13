import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";

test("solo hunts are isolated, persistent and idempotent without wallet changes", async () => {
  const port = await new Promise<number>((resolvePort) => {
    const socket = createServer().listen(0, "127.0.0.1", () => { const port = (socket.address() as { port: number }).port; socket.close(() => resolvePort(port)); });
  });
  const directory = mkdtempSync(join(tmpdir(), "entitywars-hunts-"));
  const dbPath = join(directory, "test.sqlite");
  const db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(name => name.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0" };
  let server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  const request = async (path: string, body?: unknown, token?: string) => {
    const response = await fetch(`http://127.0.0.1:${port}${path}`, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, data: await response.json() as any };
  };
  try {
    let ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    const a = await request("/auth/dev_login", { name: "hunt_test_a" });
    const b = await request("/auth/dev_login", { name: "hunt_test_b" });
    expect([a.status, b.status]).toEqual([200, 200]);
    const wallet = (id: string) => JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(id) as any).state_json).wallet;
    const beforeA = wallet(a.data.player_id), beforeB = wallet(b.data.player_id);
    const schedule = (await request("/world/boss-hunts")).data;
    const key = schedule.rotation_key;
    const start = (id: string, hunt = "hunt_common", rotation = key, token = a.data.token) => request("/world/boss-hunts/start", { client_action_id: id, hunt_id: hunt, rotation_key: rotation }, token);
    expect((await request("/world/boss-hunts/start", { client_action_id: "anonymous", hunt_id: "hunt_common", rotation_key: key })).status).toBe(401);
    expect((await start("bad-id", "fake_boss")).status).toBe(409);
    expect((await start("bad-key", "hunt_common", key - 1)).status).toBe(409);
    const unavailable = schedule.bosses.find((boss: any) => boss.tier !== "common" && !boss.available);
    expect((await start("unavailable", unavailable.id)).status).toBe(409);
    const concurrent = await Promise.all([start("concurrent"), start("concurrent")]);
    expect(concurrent.map(result => result.status)).toEqual([200, 200]);
    const session = concurrent[0].data;
    expect(concurrent[1].data.session_id).toBe(session.session_id);
    expect(session.expires_at - session.started_at).toBe(2700000);
    expect((await start("concurrent", "hunt_common", key - 1)).status).toBe(409);
    expect((await start("second")).status).toBe(409);
    expect((await request("/world/boss-hunts/session", undefined, b.data.token)).data.session).toBeNull();
    expect((await request("/world/boss-hunts/forfeit", { session_id: session.session_id, client_action_id: "other-player" }, b.data.token)).status).toBe(404);
    const snapshot = db.query("SELECT * FROM solo_hunt_sessions WHERE session_id = ?").get(session.session_id) as any;
    expect(JSON.parse(snapshot.player_snapshot_json).loadout_verification).toBe("UNVERIFIED");
    server.kill();
    await server.exited;
    server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
    ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    const relogin = await request("/auth/dev_login", { name: "hunt_test_a" });
    expect(relogin.status).toBe(200);
    a.data.token = relogin.data.token;
    expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.session.session_id).toBe(session.session_id);
    const forfeit = () => request("/world/boss-hunts/forfeit", { session_id: session.session_id, client_action_id: "forfeit" }, a.data.token);
    expect((await forfeit()).data.status).toBe("FORFEIT");
    expect((await forfeit()).data.duplicate).toBe(true);
    expect((await start("concurrent")).data.status).toBe("FORFEIT");
    expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.session).toBeNull();
    const competing = await Promise.all([start("next-a"), start("next-b")]);
    expect(competing.map(result => result.status).sort()).toEqual([200, 409]);
    const next = competing.find(result => result.status === 200)!;
    db.query("UPDATE solo_hunt_sessions SET expires_at = ? WHERE session_id = ?").run(Date.now() - 1, next.data.session_id);
    expect((await request("/world/boss-hunts/session", undefined, a.data.token)).data.session).toBeNull();
    expect((db.query("SELECT status FROM solo_hunt_sessions WHERE session_id = ?").get(next.data.session_id) as any).status).toBe("EXPIRED");
    expect((await request("/world/boss-hunts/forfeit", { session_id: next.data.session_id, client_action_id: "expired-forfeit" }, a.data.token)).status).toBe(409);
    const special = schedule.bosses.find((boss: any) => boss.tier !== "common" && boss.available);
    if (special) {
      const result = await start("special", special.id);
      expect(result.status).toBe(200);
      expect(result.data.hunt_id).toBe(special.id);
    }
    expect(wallet(a.data.player_id)).toEqual(beforeA);
    expect(wallet(b.data.player_id)).toEqual(beforeB);
  } finally {
    server.kill();
    await server.exited;
    db.close();
    rmSync(directory, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  }
}, 120000);
