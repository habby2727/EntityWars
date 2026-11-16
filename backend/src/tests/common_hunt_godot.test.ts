import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

test("Godot common appearance reaches trusted combat and resumes", async () => {
  const godot = process.env.GODOT_BIN || join(process.env.USERPROFILE || "", "Desktop", "Godot_v4.6.exe");
  expect(existsSync(godot)).toBe(true);
  const dir = mkdtempSync(join(tmpdir(), "ew-common-e2e-"));
  const dbPath = join(dir, "test.sqlite");
  const db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const reserved = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: () => new Response("reserved") });
  const port = reserved.port; reserved.stop();
  const base = `http://127.0.0.1:${port}`;
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0" };
  const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  try {
    let ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await fetch(base + "/health")).ok) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    const login = await fetch(base + "/auth/dev_login", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: "common_e2e" }) });
    expect(login.status).toBe(200);
    const account = await login.json() as { token: string };
    const log = join(dir, "godot.log");
    const child = Bun.spawn([godot, "--headless", "--path", resolve(import.meta.dir, "../../.."), "--log-file", log, "--script", "res://scripts/tests/smoke_common_e2e.gd"], { env: { ...env, APPDATA: dir, LOCALAPPDATA: dir, EW_COMMON_ROOT: dir, EW_COMMON_TOKEN: account.token, ENTITYWARS_BACKEND_URL: base }, stdout: "ignore", stderr: "ignore" });
    const code = await Promise.race([child.exited, Bun.sleep(90000).then(() => { child.kill(); throw new Error("Godot common E2E timed out"); })]);
    const output = existsSync(log) ? readFileSync(log, "utf8") : "missing Godot log";
    expect({ code, output }).toEqual({ code: 0, output: expect.stringContaining("PASS common appearance -> session -> loadout -> combat -> resume") });
    expect(output).not.toMatch(/SCRIPT ERROR|ERROR:/);
  } finally { server.kill(); await server.exited; db.close(); rmSync(dir, { recursive: true, force: true }); }
}, 120000);
