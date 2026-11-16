import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { createGlobalChat } from "../global_chat";

test("global chat retains history, deduplicates, throttles and expires presence", async () => {
	const dir = mkdtempSync(join(tmpdir(), "ew-chat-"));
	const path = join(dir, "chat.sqlite");
	let db = new Database(path);
	try {
		db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
		db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite/0009_global_chat.sql"), "utf8"));
		db.exec("INSERT INTO players VALUES ('a', 'Alice'), ('b', 'Bob')");
		let now = 100_000;
		let chat = createGlobalChat(db, () => now);
		expect(chat.state("a").online_count).toBe(1);
		expect(chat.state("b").online_count).toBe(2);
		const first = chat.send("a", { text: "hello", client_message_id: "0", username: "Bob" });
		expect(first.data.message).toMatchObject({ username: "Alice", text: "hello" });
		expect(chat.send("a", { text: "hello", client_message_id: "0" }).data.duplicate).toBe(true);
		expect(chat.send("a", { text: "spam", client_message_id: "spam" }).status).toBe(429);
		expect(chat.send("b", { text: "reply", client_message_id: "reply" }).status).toBe(200);
		for (const text of ["", "   ", "a\nb", "x".repeat(201)]) expect(chat.send("b", { text, client_message_id: "invalid" }).status).toBe(400);
		for (let i = 2; i < 21; i++) {
			now += 2000;
			expect(chat.send("a", { text: `message ${i}`, client_message_id: String(i) }).status).toBe(200);
		}
		expect(chat.state("a").messages).toHaveLength(20);
		expect(chat.state("a").messages[0]).toMatchObject({ username: "Bob", text: "reply" });
		chat.close();
		db.close();
		db = new Database(path);
		chat = createGlobalChat(db, () => now);
		expect(chat.state("a").messages).toHaveLength(20);
		expect(chat.state("b").online_count).toBe(2);
		now += 45_000;
		expect(chat.state("a").online_count).toBe(1);
		chat.close();
	} finally {
		db.close();
		for (let i = 0; ; i++) { try { rmSync(dir, { recursive: true, force: true }); break; } catch (e) { if (i >= 20 || (e as NodeJS.ErrnoException).code !== "EBUSY") throw e; await Bun.sleep(250); } }
	}
});

test("chat HTTP routes require authentication and share messages", async () => {
	const dir = mkdtempSync(join(tmpdir(), "ew-chat-http-"));
	const dbPath = join(dir, "test.sqlite");
	const db = new Database(dbPath);
	const migrations = resolve(import.meta.dir, "../../migrations/sqlite");
	for (const file of readdirSync(migrations).filter(f => f.endsWith(".sql")).sort()) db.exec(readFileSync(join(migrations, file), "utf8"));
	db.close();
	const port = await new Promise<number>((done, fail) => {
		const probe = createServer(); probe.once("error", fail);
		probe.listen(0, "127.0.0.1", () => { const port = (probe.address() as { port: number }).port; probe.close(() => done(port)); });
	});
	const env = { ...process.env, NODE_ENV: "test", BUN_ENV: "test", HOST: "127.0.0.1", PORT: String(port), DB_PATH: dbPath, DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", REDIS_URL: "redis://127.0.0.1:1", AUTH_ACCOUNT_TIMEOUT_MS: "100", LOGIN_RATE_LIMIT_MAX: "100" };
	const server = Bun.spawn([process.execPath, "src/index.ts"], { cwd: resolve(import.meta.dir, "../.."), env, stdout: "ignore", stderr: "ignore" });
	try {
		const base = `http://127.0.0.1:${port}`;
		let ready = false;
		for (let i = 0; i < 100; i++) { try { if ((await fetch(base + "/health")).ok) { ready = true; break; } } catch {} await Bun.sleep(100); }
		expect(ready).toBe(true);
		const post = (path: string, body: unknown, token?: string) => fetch(base + path, { method: "POST", headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: JSON.stringify(body) });
		expect((await fetch(base + "/chat/state")).status).toBe(401);
		expect((await post("/chat/send", {})).status).toBe(401);
		const alice = await (await post("/auth/register", { username: "Alice", password: "secret1" })).json() as { token: string };
		const bob = await (await post("/auth/register", { username: "Bob", password: "secret1" })).json() as { token: string };
		expect((await post("/chat/send", { text: "hello", client_message_id: "1", username: "Bob" }, alice.token)).status).toBe(200);
		expect((await post("/chat/send", { text: "hi", client_message_id: "1" }, bob.token)).status).toBe(200);
		const state = await (await fetch(base + "/chat/state", { headers: { Authorization: `Bearer ${bob.token}` } })).json() as any;
		expect(state.messages.map((m: any) => [m.username, m.text])).toEqual([["Alice", "hello"], ["Bob", "hi"]]);
	} finally {
		server.kill(); await server.exited;
		for (let i = 0; ; i++) { try { rmSync(dir, { recursive: true, force: true }); break; } catch (e) { if (i >= 20 || (e as NodeJS.ErrnoException).code !== "EBUSY") throw e; await Bun.sleep(250); } }
	}
}, 60_000);
