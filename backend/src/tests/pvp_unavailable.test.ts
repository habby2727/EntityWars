import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { createGlobalChat } from "../global_chat";

test("presence counts distinct accounts in the existing 45-second window", () => {
  const db = new Database(":memory:");
  db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT); CREATE TABLE global_chat_messages (id INTEGER PRIMARY KEY, player_id TEXT, text TEXT, created_at INTEGER, client_message_id TEXT)");
  let now = 0; const chat = createGlobalChat(db, () => now);
  expect(chat.onlineCount()).toBe(0); chat.state("a"); chat.state("a"); expect(chat.onlineCount()).toBe(1);
  now = 1000; chat.state("b"); expect(chat.onlineCount()).toBe(2);
  now = 45000; expect(chat.onlineCount()).toBe(1); now = 46000; expect(chat.onlineCount()).toBe(0);
  chat.close(); db.close();
});

test("ranked routes require authentication and fail closed with either flag setting", async () => {
  const port = await new Promise<number>(r => { const s = createServer().listen(0, "127.0.0.1", () => { const p = (s.address() as { port: number }).port; s.close(() => r(p)); }); });
  const dir = mkdtempSync(join(tmpdir(), "ew-pvp-off-")), db = new Database(join(dir, "test.sqlite"));
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const env = { ...process.env, DB_PATH: join(dir, "test.sqlite"), NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0", PVP_ENABLED: "0", PVP_RNG_SECRET: "" };
  const spawn = () => Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  let server = spawn();
  const request = async (path: string, body?: unknown, token?: string) => { const response = await fetch(`http://127.0.0.1:${port}${path}`, { method: body === undefined ? "GET" : "POST", headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) }); return { status: response.status, data: await response.json() as any }; };
  const ready = async () => { for (let i = 0; i < 120; i++) { try { if ((await request("/health")).status === 200) return; } catch {} await Bun.sleep(100); } throw new Error("server readiness timeout"); };
  try {
    for (const enabled of ["0", "1"]) {
      if (enabled === "1") { server.kill(); await server.exited; env.PVP_ENABLED = enabled; server = spawn(); }
      await ready();
      const a = (await request("/auth/dev_login", { name: "pvp_test_a" })).data;
      const b = (await request("/auth/dev_login", { name: "pvp_test_b" })).data;
      expect(a.token).toBeTruthy(); expect(b.token).toBeTruthy();
      const routes: [string, unknown?][] = [["/pvp/queue/state"], ["/pvp/queue/join", {}], ["/pvp/queue/cancel", {}], ["/pvp/match/state"], ["/pvp/match/decision", {}], ["/pvp/match/forfeit", {}], ["/pvp/match/chat", {}], ["/pvp/leaderboard"]];
      for (const [path, body] of routes) {
        expect((await request(path, body)).status).toBe(401);
        for (const token of [a.token, b.token]) { const response = await request(path, body, token); expect(response.status).toBe(503); expect(response.data.error).toBe(enabled === "0" ? "PVP_DISABLED" : "PVP_SECRET_REQUIRED"); }
      }
      expect((db.query("SELECT COUNT(*) AS n FROM pvp_queue").get() as any).n).toBe(0);
      expect((db.query("SELECT COUNT(*) AS n FROM pvp_matches").get() as any).n).toBe(0);
    }
  } finally { server.kill(); await server.exited; db.close(); rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }); }
}, 120000);
