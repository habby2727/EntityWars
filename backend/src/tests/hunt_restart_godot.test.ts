import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir } from "node:os";
import { isAbsolute, join, relative, resolve } from "node:path";

const godot = process.env.GODOT_BIN || join(process.env.USERPROFILE || "", "Desktop", "Godot_v4.6.exe");
const project = resolve(import.meta.dir, "../../..");

for (const [mode, kind, committed] of [["hunt", "victory", true], ["hunt", "turn", false], ["hunt", "turn", true], ["hunt", "loadout", false], ["hunt", "loadout", true], ["hunt", "forfeit", false], ["hunt", "forfeit", true], ["hunt", "expired", false], ["hunt", "expired_loadout", false], ["hunt", "wrong_owner", false], ["hunt", "malformed", false], ["dungeon", "turn", false], ["dungeon", "turn", true], ["dungeon", "loadout", false], ["dungeon", "loadout", true], ["dungeon", "inspiration", false], ["dungeon", "inspiration", true], ["dungeon", "terminal", false], ["dungeon", "terminal", true], ["dungeon", "expired", false], ["dungeon", "expired_loadout", false]] as const) test(`Godot restart recovers ${committed ? "committed" : "uncommitted"} ${mode} ${kind}`, async () => {
  expect(existsSync(godot)).toBe(true);
  const directory = mkdtempSync(join(tmpdir(), "ew-restart-"));
  const dbPath = join(directory, "test.sqlite");
  const db = new Database(dbPath);
  const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
  for (const file of readdirSync(migrations).filter(name => name.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
  const listener = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: () => new Response("reserved") });
  const port = listener.port;
  listener.stop();
  const env = { ...process.env, DB_PATH: dbPath, NODE_ENV: "development", BUN_ENV: "development", HOST: "127.0.0.1", PORT: String(port), DATABASE_URL: process.env.NETR13_TEST_DATABASE_URL || "postgres://x:x@127.0.0.1:1/test", REDIS_URL: process.env.NETR13_TEST_REDIS_URL || "redis://127.0.0.1:1", PG_CONNECT_TIMEOUT_SECONDS: "1", DEBUG_BYPASS: "0", LOGIN_RATE_LIMIT_MAX: "500", RATE_LIMIT_MAX: "500" };
  const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
  const base = `http://127.0.0.1:${port}`;
  const request = async (path: string, body?: unknown, token?: string) => {
    const response = await fetch(base + path, { method: body === undefined ? "GET" : "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: response.status, data: await response.json() as any };
  };
  let first: ReturnType<typeof Bun.spawn> | undefined;
  let proxy: ReturnType<typeof Bun.serve> | undefined;
  try {
    let ready = false;
    for (let i = 0; i < 100; i++) { try { if ((await request("/health")).status === 200) { ready = true; break; } } catch {} await Bun.sleep(100); }
    expect(ready).toBe(true);
    const login = await request("/auth/register", { username: `restart_${committed}`, password: "test-password" });
    expect(login.status).toBe(200);
    const token: string = login.data.token, playerId: string = login.data.player_id;
    if (mode === "hunt" && kind === "turn" && !committed && process.env.AUTH_RESTART_ONLY !== "1") {
      if (process.env.AUTH_ABA_ONLY !== "1") {
      const gateRoot = join(directory, "gate-user");
      const gate = Bun.spawn([godot, "--headless", "--path", project, "--script", "res://scripts/tests/smoke_connection_gate.gd"], { env: { ...process.env, APPDATA: gateRoot, LOCALAPPDATA: gateRoot, GATE_TEST_ROOT: gateRoot, GATE_TEST_TOKEN: token, ENTITYWARS_BACKEND_URL: base }, stdout: "pipe", stderr: "pipe" });
      const gateExit = await Promise.race([gate.exited, Bun.sleep(60000).then(() => { gate.kill(); throw new Error("gate smoke timed out"); })]);
      const gateOutput = await new Response(gate.stdout).text() + await new Response(gate.stderr).text();
      expect({ gateExit, gateOutput }).toEqual({ gateExit: 0, gateOutput: expect.stringContaining("PASS authenticated heartbeat") });
      }
      const lostLogin = await request("/auth/dev_login", { name: "lost_response_smoke" });
      expect(lostLogin.status).toBe(200);
      expect((await request("/auth/dev_login", { name: "combat_account_b" })).status).toBe(200);
      const lostId: string = lostLogin.data.player_id;
      const lostState = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(lostId) as any).state_json);
      lostState.wallet.essence = 100; lostState.lab.buildings.build_forge = { level: 1, route: "" }; lostState.item_progress = {};
      db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(lostState), lostId);
      const reserved = Bun.serve({ port: 0, hostname: "127.0.0.1", fetch: () => new Response("reserved") });
      const lostPort = reserved.port; reserved.stop();
      const lostRoot = join(directory, "lost-user"), marker = join(directory, "lost-marker.json"), lostUrl = `http://127.0.0.1:${lostPort}`;
      const lostEnv = { ...env, FORGE_SMOKE_URL: base, LOST_RESPONSE_PORT: String(lostPort), LOST_RESPONSE_MARKER: marker, LOST_RESPONSE_URL: lostUrl, FORGE_SMOKE_USER_ROOT: lostRoot, APPDATA: lostRoot, LOCALAPPDATA: lostRoot };
      const lostProxy = Bun.spawn([process.execPath, "src/tests/lost_response_proxy.ts"], { cwd: resolve(import.meta.dir, "../.."), env: lostEnv, stdout: "ignore", stderr: "pipe" });
      try {
        let proxyReady = false;
        for (let i = 0; i < 100; i++) { try { if ((await fetch(lostUrl + "/health")).ok) { proxyReady = true; break; } } catch {} await Bun.sleep(100); }
        expect(proxyReady).toBe(true);
        for (const phase of ["0", "1"]) {
          const child = Bun.spawn([godot, "--headless", "--path", project, "--script", "res://scripts/tests/smoke_lost_response.gd"], { env: { ...lostEnv, LOST_RESPONSE_RESTART: phase }, stdout: "pipe", stderr: "pipe" });
          const code = await Promise.race([child.exited, Bun.sleep(90000).then(() => { child.kill(); throw new Error("pending queue smoke timed out"); })]);
          const output = await new Response(child.stdout).text() + await new Response(child.stderr).text();
          if (process.env.AUTH_ABA_ONLY === "1") console.log(output);
          expect({ code, output }).toEqual({ code: 0, output: expect.stringContaining(phase === "0" ? "PASS response lost" : "PASS restart recovery") });
        }
        expect(existsSync(marker)).toBe(true);
      } finally { lostProxy.kill(); await lostProxy.exited; }
      if (process.env.AUTH_ABA_ONLY === "1") return;
    }
    const player = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(playerId) as any).state_json);
    player.spell_progress = { learned_by_entity: { sulfur_01: ["steady_script"] }, active_research: null, equipped_by_mode: { attack: { sulfur_01: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"] }, defense: {} } };
    player.lab.hqLevel = 4; player.lab.buildings.sync_nexus = { level: 1 };
    db.query("UPDATE players SET state_json = ? WHERE player_id = ?").run(JSON.stringify(player), playerId);
    const schedule = (await request("/world/boss-hunts")).data;
    const started = await request(mode === "hunt" ? "/world/boss-hunts/start" : "/dungeon/start", mode === "hunt" ? { client_action_id: "start", hunt_id: "hunt_common", rotation_key: schedule.rotation_key } : { client_action_id: "start" }, token);
    expect(started.status).toBe(200);
    const sessionId = mode === "hunt" ? started.data.session_id : started.data.run_id;
    const loadout = mode === "hunt" ? { session_id: sessionId, client_action_id: "loadout", entity_id: "sulfur_01", weapon_ids: ["bismuth_talisman", "wind_amulet"], homunculus_id: "cinder", spell_ids: ["steady_script", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" } : { run_id: sessionId, client_action_id: "loadout", entity_id: "sulfur_01", weapon_ids: [null, null], homunculus_id: "cinder", spell_ids: ["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], mode: "attack" };
    const isLoadout = kind === "loadout" || kind === "expired_loadout";
    const isExpired = kind === "expired" || kind === "expired_loadout";
    if (!isLoadout) {
      const loaded = await request(mode === "hunt" ? "/world/boss-hunts/loadout" : "/dungeon/loadout", loadout, token);
      expect(loaded.status).toBe(200);
    }
    if (kind === "inspiration") {
      const state = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(sessionId) as any).combat_state_json);
      state.player.inspiration = 3; state.player.inspiration_pending = true; state.player.inspiration_offers = ["steady_script", "furnace_rush", "ash_temper"];
      db.query("UPDATE dungeon_runs SET combat_state_json = ? WHERE run_id = ?").run(JSON.stringify(state), sessionId);
    }
    if (kind === "terminal") {
      const state = JSON.parse((db.query("SELECT combat_state_json FROM dungeon_runs WHERE run_id = ?").get(sessionId) as any).combat_state_json);
      state.player.hp = 1; state.player.status.poison = 1; state.npc.hp = state.npc.max_hp = 1000;
      db.query("UPDATE dungeon_runs SET combat_state_json = ? WHERE run_id = ?").run(JSON.stringify(state), sessionId);
    }
    if (kind === "victory") {
      const state = JSON.parse((db.query("SELECT combat_state_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) as any).combat_state_json);
      state.boss.hp = 1;
      state.boss.def = Math.max(state.boss.def, state.player.atk);
      state.boss.max_hp = Math.max(state.boss.max_hp, state.player.max_hp);
      state.spells.find((spell: any) => spell.id === "steady_script").accuracy = 1;
      db.query("UPDATE solo_hunt_sessions SET combat_state_json = ? WHERE session_id = ?").run(JSON.stringify(state), sessionId);
      expect((db.query("SELECT status FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) as any).status).toBe("ACTIVE");
      db.exec("CREATE TRIGGER test_hunt_victory_guard BEFORE UPDATE OF status ON solo_hunt_sessions WHEN OLD.status = 'VERIFIED_WIN' BEGIN SELECT RAISE(ABORT, 'victory status cannot be updated twice'); END;");
    }
    const invalid = kind === "wrong_owner" || kind === "malformed";
    const endpoint = isLoadout ? "loadout" : invalid || isExpired || kind === "terminal" || kind === "victory" ? "turn" : kind;
    const path = mode === "hunt" ? `/world/boss-hunts/${endpoint}` : `/dungeon/${endpoint}`;
    const payload = isLoadout ? { ...loadout, client_action_id: "restart-turn" } : kind === "forfeit" ? { session_id: sessionId, client_action_id: "restart-turn" } : mode === "hunt" ? { session_id: sessionId, client_action_id: "restart-turn", expected_revision: 1, decision: { turn: 1, spell_id: "steady_script", target: "boss" } } : { run_id: sessionId, client_action_id: "restart-turn", expected_revision: 1, decision: kind === "inspiration" ? { kind: "decline" } : { turn: 1, spell_id: "cinder_fist", hom_action: "hold" } };
    const revision = kind === "forfeit" ? 0 : kind === "loadout" ? 1 : 2;
    const walletAtStart = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(playerId) as any).state_json).wallet;
    let victoryResponse: any;
    let observed!: () => void;
    const seen = new Promise<void>(resolveSeen => { observed = resolveSeen; });
    proxy = Bun.serve({ port: 0, hostname: "127.0.0.1", async fetch(req) {
      const url = new URL(req.url);
      if (url.pathname === path) {
        if (committed) { const forwarded = await fetch(base + url.pathname, { method: req.method, headers: req.headers, body: await req.arrayBuffer() }); if (!forwarded.ok) throw new Error(`Forwarded ${url.pathname}: ${forwarded.status} ${await forwarded.text()}`); if (kind === "victory") victoryResponse = await forwarded.json(); }
        observed();
        return await new Promise<Response>(() => {});
      }
      return fetch(base + url.pathname + url.search, { method: req.method, headers: req.headers, body: req.method === "GET" ? undefined : await req.arrayBuffer() });
    } });
    const user = join(directory, "user");
    const common = { ...process.env, APPDATA: user, LOCALAPPDATA: user, HUNT_RESTART_ROOT: user, HUNT_RESTART_SESSION: sessionId, HUNT_RESTART_PLAYER: playerId, HUNT_RESTART_ROTATION: String(schedule.rotation_key), HUNT_RESTART_TOKEN: token, RESTART_MODE: mode, RESTART_PATH: path, RESTART_PAYLOAD: JSON.stringify(payload), RESTART_REVISION: String(revision), RESTART_TERMINAL: kind === "terminal" ? "1" : "0", RESTART_WIN: kind === "victory" ? "1" : "0", RESTART_FORFEIT: kind === "forfeit" ? "1" : "0", RESTART_EXPIRED: isExpired ? "1" : "0", RESTART_EXPECT_LOCK: invalid ? "1" : "0" };
    const args = [godot, "--headless", "--path", project, "--script", "res://scripts/tests/smoke_hunt_restart_process.gd"];
    first = Bun.spawn(args, { env: { ...common, ENTITYWARS_BACKEND_URL: `http://127.0.0.1:${proxy.port}`, HUNT_RESTART_PHASE: "first" }, stdout: "pipe", stderr: "pipe" });
    await Promise.race([seen, Bun.sleep(30000).then(() => { throw new Error("first process did not submit"); }), first.exited.then(async () => { throw new Error("first process exited before submission: " + await new Response(first!.stderr).text()); })]);
    expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = 'restart-turn'").get(playerId) as any).n).toBe(committed ? 1 : 0);
    const journalFile = join(user, "Godot", "app_userdata", "EntityWars", `session_recovery_${createHash("sha256").update(playerId).digest("hex")}.json`);
    const pendingJournal = JSON.parse(readFileSync(journalFile, "utf8"));
    expect(pendingJournal.player_id).toBe(playerId);
    expect(pendingJournal.session_id).toBe(sessionId);
    expect(pendingJournal.payload.client_action_id).toBe("restart-turn");
    const walletBefore = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(playerId) as any).state_json).wallet;
    const receiptsBefore = (db.query("SELECT COUNT(*) AS n FROM combat_reward_receipts WHERE player_id = ?").get(playerId) as any).n;
    if (kind === "victory") {
      expect(victoryResponse.status).toBe("VERIFIED_WIN");
      expect(victoryResponse.combat_revision).toBe(2);
      expect(victoryResponse.events.filter((event: any) => event.kind === "combat_terminal")).toHaveLength(1);
    }
    first.kill();
    await first.exited;
    first = undefined;
    if (isExpired) {
      if (mode === "hunt") db.query("UPDATE solo_hunt_sessions SET status = 'EXPIRED' WHERE session_id = ?").run(sessionId);
      else db.query("UPDATE dungeon_runs SET status = 'EXPIRED' WHERE run_id = ?").run(sessionId);
    }
    if (invalid) {
      const journal = JSON.parse(readFileSync(journalFile, "utf8"));
      if (kind === "wrong_owner") journal.player_id = "other-player";
      writeFileSync(journalFile, kind === "malformed" ? "{invalid" : JSON.stringify(journal));
    }
    const second = Bun.spawn(args, { env: { ...common, ENTITYWARS_BACKEND_URL: base, HUNT_RESTART_PHASE: "second" }, stdout: "pipe", stderr: "pipe" });
    const exit = await Promise.race([second.exited, Bun.sleep(45000).then(() => { second.kill(); throw new Error("restart timed out"); })]);
    const output = await new Response(second.stdout).text() + await new Response(second.stderr).text();
    expect({ exit, output }).toEqual({ exit: 0, output: expect.stringContaining(invalid ? "PASS invalid recovery journal remains locked" : "PASS recovered original hunt turn") });
    if (invalid || isExpired) {
      expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = 'restart-turn'").get(playerId) as any).n).toBe(0);
      return;
    }
    const row = mode === "hunt" ? db.query("SELECT combat_revision FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) : db.query("SELECT combat_revision FROM dungeon_runs WHERE run_id = ?").get(sessionId);
    expect((row as any).combat_revision).toBe(kind === "forfeit" ? 1 : revision);
    if (kind === "terminal") expect((db.query("SELECT status FROM dungeon_runs WHERE run_id = ?").get(sessionId) as any).status).toBe("LOSS");
    expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = 'restart-turn'").get(playerId) as any).n).toBe(1);
    if (kind === "turn") {
      expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(playerId) as any).state_json).wallet).toEqual(walletBefore);
      expect((db.query("SELECT COUNT(*) AS n FROM combat_reward_receipts WHERE player_id = ?").get(playerId) as any).n).toBe(receiptsBefore);
    }
    if (kind === "victory") {
      const balance = JSON.parse(readFileSync(resolve(project, "data/static/balance.json"), "utf8")).balance;
      const reward = balance.solo_hunt_rewards.boss.common as Record<string, number>;
      const expectedWallet = { ...walletAtStart };
      for (const [id, amount] of Object.entries(reward)) expectedWallet[id] = Math.min((balance.wallet_caps[id] ?? balance.wallet_max_per_resource), (expectedWallet[id] ?? 0) + amount);
      expect(victoryResponse.pve_reward).toEqual({ grants: reward, source: "boss", tier: "common" });
      const victoryRow = db.query("SELECT player_id, session_id, status, combat_revision, result_metadata_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId) as any;
      expect(victoryRow).toMatchObject({ player_id: playerId, session_id: sessionId, status: "VERIFIED_WIN", combat_revision: 2 });
      const action = db.query("SELECT action_type, payload_json, result_state_json FROM action_log WHERE player_id = ? AND client_action_id = 'restart-turn'").get(playerId) as any;
      expect(action.action_type).toBe("SOLO_HUNT_TURN");
      expect(JSON.parse(action.payload_json)).toEqual({ session_id: sessionId, expected_revision: 1, decision: payload.decision });
      expect(JSON.parse(action.result_state_json)).toEqual(victoryResponse);
      const audit = db.query("SELECT delta_wallet FROM audit_wallet WHERE player_id = ? AND related_id = ? AND reason = 'SOLO_HUNT_REWARD'").all(playerId, sessionId) as { delta_wallet: string }[];
      expect(audit).toHaveLength(1);
      expect(JSON.parse(audit[0].delta_wallet)).toEqual(reward);
      expect(walletBefore).toEqual(expectedWallet);
      const other = await request("/auth/register", { username: "other_player", password: "test-password" });
      expect(other.status).toBe(200);
      const otherBefore = JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(other.data.player_id) as any).state_json).wallet;
      expect((await request(path, payload, other.data.token)).status).toBe(404);
      expect((await request("/combat/rewards/claim", { match_id: sessionId, client_action_id: crypto.randomUUID() }, other.data.token)).status).toBe(404);
      expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(other.data.player_id) as any).state_json).wallet).toEqual(otherBefore);
      expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = 'restart-turn'").get(other.data.player_id) as any).n).toBe(0);
      for (let i = 0; i < 2; i++) {
        const replay = await request(path, payload, token);
        expect(replay.status).toBe(200);
        expect(replay.data).toEqual(victoryResponse);
      }
      expect(JSON.parse((db.query("SELECT state_json FROM players WHERE player_id = ?").get(playerId) as any).state_json).wallet).toEqual(expectedWallet);
      expect((db.query("SELECT COUNT(*) AS n FROM action_log WHERE player_id = ? AND client_action_id = 'restart-turn'").get(playerId) as any).n).toBe(1);
      expect(db.query("SELECT player_id, session_id, status, combat_revision, result_metadata_json FROM solo_hunt_sessions WHERE session_id = ?").get(sessionId)).toEqual(victoryRow);
      expect((db.query("SELECT COUNT(*) AS n FROM audit_wallet WHERE player_id = ? AND related_id = ? AND reason = 'SOLO_HUNT_REWARD'").get(playerId, sessionId) as any).n).toBe(1);
      expect((db.query("SELECT COUNT(*) AS n FROM combat_reward_receipts WHERE player_id = ?").get(playerId) as any).n).toBe(receiptsBefore);
      console.log("VICTORY_REPLAY", JSON.stringify({ wallet_before: walletAtStart, reward, wallet_after: expectedWallet, actions: 1, status: "ACTIVE -> VERIFIED_WIN", audit: 1, receipts: receiptsBefore }));
    }
  } finally {
    first?.kill(); proxy?.stop(true); server.kill(); await server.exited; db.close();
    const rel = relative(resolve(tmpdir()), resolve(directory));
    if (!rel || rel.startsWith("..") || isAbsolute(rel)) throw new Error("Refusing to remove non-temporary test directory");
    rmSync(directory, { recursive: true, force: true });
  }
}, 120000);
