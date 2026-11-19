import { expect, test } from "bun:test";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

test("Godot saved-token startup keeps forms hidden until an authoritative result", async () => {
	const godot = Bun.env.GODOT_BIN || join(process.env.USERPROFILE || "", "Desktop", "Godot_v4.6.exe");
	expect(existsSync(godot)).toBe(true);
	for (const phase of ["valid", "401", "426", "503", "idle", "offline"]) {
		const dir = mkdtempSync(join(tmpdir(), "ew-startup-"));
		const server = Bun.serve({ hostname: "127.0.0.1", port: 0, fetch(req) {
			const path = new URL(req.url).pathname;
			if (path === "/static/version") return Response.json({ min_client_build: phase === "426" ? 999999 : 1 });
			if (phase === "401") return Response.json({ error: "invalid" }, { status: 401 });
			if (phase === "503") return Response.json({ error: "unavailable" }, { status: 503 });
			if (phase === "idle") return Response.json({ error: "SESSION_IDLE" }, { status: 409 });
			return Response.json({ ok: true, updated_player_state: { player_id: "owner" } });
		} });
		const base = phase === "offline" ? "http://127.0.0.1:1" : `http://127.0.0.1:${server.port}`;
		const child = Bun.spawn([godot, "--headless", "--path", resolve(import.meta.dir, "../../.."), "--script", "res://scripts/tests/smoke_startup_states.gd"], { env: { ...process.env, APPDATA: dir, LOCALAPPDATA: dir, STARTUP_TEST_ROOT: dir, STARTUP_TEST_PHASE: phase, ENTITYWARS_BACKEND_URL: base }, stdout: "pipe", stderr: "pipe" });
		try {
			const exit = await Promise.race([child.exited, Bun.sleep(15000).then(() => { child.kill(); throw new Error(`${phase} timed out`); })]);
			const output = await new Response(child.stdout).text() + await new Response(child.stderr).text();
			expect({ exit, output }).toEqual({ exit: 0, output: expect.stringContaining(`PASS startup ${phase}`) });
		} finally { if (child.exitCode === null) child.kill(); server.stop(true); rmSync(dir, { recursive: true, force: true }); }
	}
}, 90000);
