import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

test("expired session reauthenticates and applies the original HQ action once", async () => {
  const godot = process.env.GODOT_BIN || join(process.env.USERPROFILE || "", "Desktop", "Godot_v4.6.exe");
  expect(existsSync(godot)).toBe(true);
  const dir = mkdtempSync(join(tmpdir(), "ew-auth-recovery-"));
  const dbPath = join(dir, "test.sqlite");
  const db = new Database(dbPath);
  for (const name of readdirSync(resolve(import.meta.dir, "../../migrations/sqlite")).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite", name), "utf8"));
  const reserved = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: () => new Response("reserved") });
  const port = reserved.port; reserved.stop();
  const base = `http://127.0.0.1:${port}`;
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "test", BUN_ENV: "test", HOST: "127.0.0.1", PORT: String(port), SESSION_TTL_SECONDS: "8", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", AUTH_ACCOUNT_TIMEOUT_MS: "100", LOGIN_RATE_LIMIT_MAX: "100" };
  const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  try {
    let ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await fetch(base + "/health")).ok) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    const register = (username: string) => fetch(base + "/auth/register", { method: "POST", headers: { "content-type": "application/json", "X-EntityWars-Client-Build": "5504" }, body: JSON.stringify({ username, password: "secret1" }) });
    const first = await register("hqowner"); expect(first.status).toBe(200);
    const account = await first.json() as { token: string; player_id: string };
    expect((await register("otheruser")).status).toBe(200);
    const state = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(account.player_id) as any).state_json);
    state.wallet.essence = 1000; state.wallet.core = 100;
    expect(state.lab.buildings.lab_th.level).toBe(1);
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(state), account.player_id);
    const child = Bun.spawn([godot, "--headless", "--path", resolve(import.meta.dir, "../../.."), "--script", "res://scripts/tests/smoke_auth_recovery.gd"], { env: { ...env, APPDATA: dir, LOCALAPPDATA: dir, AUTH_E2E_ROOT: dir, AUTH_E2E_TOKEN: account.token, AUTH_E2E_PLAYER: account.player_id, ENTITYWARS_BACKEND_URL: base }, stdout: "pipe", stderr: "pipe" });
    const code = await Promise.race([child.exited, Bun.sleep(60000).then(() => { child.kill(); throw new Error("auth recovery timed out"); })]);
    const output = await new Response(child.stdout).text() + await new Response(child.stderr).text();
    expect({ code, output }).toEqual({ code: 0, output: expect.stringContaining("PASS expired token -> same account -> original HQ action confirmed once") });
    const finalState = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(account.player_id) as any).state_json);
    expect(finalState.lab.buildings.lab_th.level).toBe(2);
    expect(finalState.wallet.essence).toBe(700);
    expect(finalState.wallet.core).toBe(96);
    expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = 'expired-hq-upgrade'").get(account.player_id) as any).n).toBe(1);
    const saved = JSON.parse(readFileSync(join(dir, "Godot", "app_userdata", "EntityWars", "auth.json"), "utf8"));
    const replay = await fetch(base + "/player/action", { method: "POST", headers: { "content-type": "application/json", "X-EntityWars-Client-Build": "5504", authorization: `Bearer ${saved.token}` }, body: JSON.stringify({ action_type: "UPGRADE_BUILDING", client_action_id: "expired-hq-upgrade", payload: { building_id: "lab_th" }, client_time_unix_ms: 0 }) });
    expect(replay.status).toBe(200);
    const afterReplay = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(account.player_id) as any).state_json);
    expect(afterReplay.wallet).toEqual(finalState.wallet);
    expect(afterReplay.lab.buildings.lab_th.level).toBe(2);
    expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = 'expired-hq-upgrade'").get(account.player_id) as any).n).toBe(1);
  } finally { server.kill(); await server.exited; db.close(); rmSync(dir, { recursive: true, force: true }); }
}, 90000);
