import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import postgres from "postgres";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
const dbUrl = process.env.PRODUCTION_AUTH_TEST_DATABASE_URL, redisBin = process.env.PRODUCTION_AUTH_TEST_REDIS_BIN;
test.skipIf(!dbUrl || !redisBin)("production rejects disabled accounts and reports Redis outages", async () => {
 const schema = `ew_auth_${crypto.randomUUID().replaceAll("-", "")}`, sql = postgres(dbUrl!, { max: 1 });
 const dir = mkdtempSync(join(tmpdir(), "ew-prod-auth-")), db = new Database(join(dir, "test.sqlite"));
 for (const n of readdirSync(resolve(import.meta.dir, "../../migrations/sqlite")).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite", n), "utf8")); db.close();
 await sql.unsafe(`CREATE SCHEMA ${schema}`); await sql.unsafe(`CREATE TABLE ${schema}.users (id text PRIMARY KEY, disabled boolean NOT NULL DEFAULT false)`);
 const reserve = () => { const s = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: () => new Response() }); const port = s.port; s.stop(); return port; };
 const redisPort = reserve(), port = reserve();
 const redis = Bun.spawn([redisBin!, "--port", String(redisPort), "--bind", "127.0.0.1", "--save", "", "--appendonly", "no"], { cwd: dir, stdout: "ignore", stderr: "ignore" });
 const env = { ...process.env, SESSION_IDLE_ENABLED: "1", NODE_ENV: "production", BUN_ENV: "production", MIN_CLIENT_BUILD: "5504", HOST: "127.0.0.1", PORT: String(port), DB_PATH: join(dir, "test.sqlite"), DATABASE_URL: `${dbUrl}${dbUrl!.includes("?") ? "&" : "?"}options=${encodeURIComponent(`-c search_path=${schema}`)}`, REDIS_URL: `redis://127.0.0.1:${redisPort}`, TOKEN_SIGNING_SECRET: "isolated-test-secret-not-for-production", EXPERIMENT_SECRET: "isolated-experiment-secret-0123456789", TRADE_SECRET: "isolated-trade-secret-012345678901234", WORLD_SECRET: "isolated-world-secret-012345678901234" };
 const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
 const base = `http://127.0.0.1:${port}`, headers = { "content-type": "application/json", "X-EntityWars-Client-Build": "5504" };
 try {
  let ready = false; for (let i = 0; i < 100; i++) { try { const r = await (await fetch(base + "/health")).json() as any; if (r.redis === "up" && r.postgres === "up") { ready = true; break; } } catch {} await Bun.sleep(100); } expect(ready).toBe(true);
  const login = (path: string) => fetch(base + path, { method: "POST", headers, body: JSON.stringify({ username: "disabled_user", password: "secret1" }) });
  const registered = await login("/auth/register"); expect(registered.status).toBe(200); const account = await registered.json() as { token: string; player_id: string };
  const state = (token: string) => fetch(base + "/player/state", { headers: { ...headers, authorization: `Bearer ${token}` } });
  expect((await state(account.token)).status).toBe(200); expect((await state("invalid-token")).status).toBe(401);
  await sql.unsafe(`INSERT INTO ${schema}.users (id, disabled) VALUES ($1, true)`, [account.player_id]);
  expect((await state(account.token)).status).toBe(403); expect((await login("/auth/login")).status).toBe(403);
  expect((await fetch(base + "/auth/reconnect", { method: "POST", headers: { ...headers, authorization: `Bearer ${account.token}` } })).status).toBe(403);
  await sql.unsafe(`UPDATE ${schema}.users SET disabled = false WHERE id = $1`, [account.player_id]); redis.kill(); await redis.exited;
  expect((await state(account.token)).status).toBe(503); expect((await state("invalid-token")).status).toBe(503);
  expect((await fetch(base + "/auth/reconnect", { method: "POST", headers: { ...headers, authorization: `Bearer ${account.token}` } })).status).toBe(503);
 } finally { redis.kill(); server.kill(); await server.exited; await sql.unsafe(`DROP SCHEMA ${schema} CASCADE`); await sql.end(); rmSync(dir, { recursive: true, force: true }); }
}, 30000);
