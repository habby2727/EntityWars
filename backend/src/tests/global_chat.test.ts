import { expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import { mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createServer } from "node:net";
import { createGlobalChat } from "../global_chat";
import { ActivityType } from "discord.js";
import { acceptDiscordMessage, createPresenceUpdater, outgoingDiscordMessage, startDiscordBridge } from "../discord_bridge";

test("Discord presence formats counts, skips unchanged values and refreshes on reconnect", () => {
	let count = 0;
	const updates: unknown[] = [];
	const client = { user: { setPresence: (presence: unknown) => updates.push(presence) } };
	const update = createPresenceUpdater({ onlineCount: () => count }, client as any);
	update();
	update();
	count = 2;
	update();
	update();
	count = 0;
	update();
	update(true);
	expect(updates).toEqual([0, 2, 0, 0].map(n => ({ activities: [{ name: `Entity Wars | ${n} online`, type: ActivityType.Playing }] })));
});

test("bridge filters Discord events and persists a deduplicated outbox", () => {
	const db = new Database(':memory:');
	db.exec('CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)');
	for (const name of ['0009_global_chat.sql', '0012_pvp_seasons.sql', '0015_discord_chat.sql', '0016_global_chat_system.sql']) db.exec(readFileSync(resolve(import.meta.dir, '../../migrations/sqlite', name), 'utf8'));
	db.exec("INSERT INTO players VALUES ('a', 'Alice')");
	let chat = createGlobalChat(db, () => 100000, true);
	expect(startDiscordBridge(db, chat, {}).enabled).toBe(false);
	expect(chat.send('a', {text: '@everyone hello', client_message_id: 'one'}).status).toBe(200);
	expect(chat.send('a', {text: '@everyone hello', client_message_id: 'one'}).data.duplicate).toBe(true);
	expect(db.query('SELECT * FROM discord_chat_outbox').all()).toHaveLength(1);
	expect(outgoingDiscordMessage(db.query('SELECT * FROM discord_chat_outbox').get() as any)).toMatchObject({content: '[Game] Alice: @everyone hello', allowedMentions: {parse: []}, nonce: '1', enforceNonce: true});
	const msg = { id: '123', guildId: 'guild', channelId: 'channel', type: 0, author: { id: 'user', username: 'Alex' }, content: 'hi\nthere' };
	for (const bad of [{...msg, guildId: 'other'}, {...msg, channelId: 'other'}, {...msg, webhookId: 'x'}, {...msg, author: {id: 'bot', bot: true}}, {...msg, author: {id: 'self'}}, {...msg, content: '   '}]) expect(acceptDiscordMessage(chat, bad, 'guild', 'channel', 'self')).toBe(false);
	expect(acceptDiscordMessage(chat, msg, 'guild', 'channel', 'self')).toBe(true);
	expect(acceptDiscordMessage(chat, msg, 'guild', 'channel', 'self')).toBe(false);
	expect(chat.state('a')).toMatchObject({online_count: 1, messages: [{username: 'Alice'}, {username: '[Discord] Alex', source: 'discord', league: null, text: 'hi there'}]});
	chat.close();
	chat = createGlobalChat(db, () => 100000, true);
	expect(db.query('SELECT * FROM discord_chat_outbox').all()).toHaveLength(1);
	expect(chat.acceptDiscord('123', 'Alex', 'hi')).toBe(false);
	expect(chat.acceptDiscord('456', 'Alex', 'x'.repeat(220))).toBe(true);
	expect((chat.state('a').messages.at(-1) as any).text.length).toBe(200);
	chat.close(); db.close();
});

test("global chat retains history, deduplicates, throttles and expires presence", async () => {
	const dir = mkdtempSync(join(tmpdir(), "ew-chat-"));
	const path = join(dir, "chat.sqlite");
	let db = new Database(path);
	try {
		db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
		db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite/0009_global_chat.sql"), "utf8"));
		db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite/0015_discord_chat.sql"), "utf8"));
		db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite/0016_global_chat_system.sql"), "utf8"));
		db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite/0012_pvp_seasons.sql"), "utf8"));
		db.exec("INSERT INTO players VALUES ('a', 'Alice'), ('b', 'Bob')");
		db.exec("INSERT INTO pvp_season_ratings VALUES ('1970-01', 'a', 3250, 0)");
		let now = 100_000;
		let chat = createGlobalChat(db, () => now);
		expect(chat.state("a").online_count).toBe(1);
		expect(chat.state("b").online_count).toBe(2);
		expect(chat.state("b").online_players).toMatchObject([{ username: "Alice", league: "Amethyst" }, { username: "Bob", league: "Copper" }]);
		const first = chat.send("a", { text: "hello", client_message_id: "0", username: "Bob" });
		expect(first.data.message).toMatchObject({ username: "Alice", text: "hello" });
		expect(chat.send("a", { text: "hello", client_message_id: "0" }).data.duplicate).toBe(true);
		expect(chat.send("a", { text: "spam", client_message_id: "spam" }).status).toBe(429);
		expect(chat.send("b", { text: "reply", client_message_id: "reply" }).status).toBe(200);
		now += 1999;
		expect(chat.send("a", { text: "early", client_message_id: "early" }).status).toBe(429);
		now += 1;
		expect(chat.send("a", { text: "on time", client_message_id: "on-time" }).status).toBe(200);
		for (const text of ["", "   ", "a\nb", "x".repeat(201)]) expect(chat.send("b", { text, client_message_id: "invalid" }).status).toBe(400);
		for (let i = 2; i < 21; i++) {
			now += 2000;
			expect(chat.send("a", { text: `message ${i}`, client_message_id: String(i) }).status).toBe(200);
		}
		expect(chat.state("a").messages).toHaveLength(20);
		expect(chat.state("a").messages.at(-1)).toMatchObject({ username: "Alice", league: "Amethyst" });
		expect(chat.state("a").messages[0]).toMatchObject({ username: "Alice", text: "on time" });
		chat.close();
		db.close();
		db = new Database(path);
		chat = createGlobalChat(db, () => now);
		expect(chat.state("a").messages).toHaveLength(20);
		expect(chat.state("b").online_count).toBe(2);
		now += 45_000;
		expect(chat.state("a").online_count).toBe(1);
		expect(chat.state("a").online_players).toMatchObject([{ username: "Alice" }]);
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
		expect((await post("/auth/logout", {}, "unknown-token")).status).toBe(503);
		expect((await post("/v1/auth/logout", { refresh_token: "unknown-refresh" }, "unknown-access")).status).toBe(503);
		expect((await post("/auth/login", { username: "aLiCe", password: "wrong-password" })).status).toBe(401);
		expect((await post("/auth/login", { username: "aLiCe", password: "secret1" })).status).toBe(200);
		expect((await post("/chat/send", { text: "hello", client_message_id: "1", username: "Bob" }, alice.token)).status).toBe(200);
		expect((await post("/chat/send", { text: "hi", client_message_id: "1" }, bob.token)).status).toBe(200);
		const state = await (await fetch(base + "/chat/state", { headers: { Authorization: `Bearer ${bob.token}` } })).json() as any;
		expect(state.messages.slice(0, 3).every((m: any) => m.source === "system" && m.league === null)).toBe(true);
		expect(state.messages.slice(3).every((m: any) => m.source === "game")).toBe(true);
		expect(state.messages.map((m: any) => [m.username, m.text])).toEqual([["Entity Wars", "Welcome, Alice!"], ["Entity Wars", "Welcome, Bob!"], ["Entity Wars", "Welcome back, Alice!"], ["Alice", "hello"], ["Bob", "hi"]]);
	} finally {
		server.kill(); await server.exited;
		for (let i = 0; ; i++) { try { rmSync(dir, { recursive: true, force: true }); break; } catch (e) { if (i >= 20 || (e as NodeJS.ErrnoException).code !== "EBUSY") throw e; await Bun.sleep(250); } }
	}
}, 60_000);

test("system announcements use server names, share pruning and cannot be forged", () => {
 const db = new Database(":memory:");
 db.exec("CREATE TABLE players (player_id TEXT PRIMARY KEY, display_name TEXT NOT NULL)");
 for (const file of ["0009_global_chat.sql", "0012_pvp_seasons.sql", "0015_discord_chat.sql", "0016_global_chat_system.sql"]) db.exec(readFileSync(resolve(import.meta.dir, "../../migrations/sqlite", file), "utf8"));
 db.exec("INSERT INTO players VALUES ('a', 'Alice')");
 const chat = createGlobalChat(db, () => 100000, true);
 for (let i = 0; i < 21; i++) chat.announceLogin("a", i === 0);
 const state = chat.state("a");
 expect(state.messages).toHaveLength(20);
 expect(new Set(state.messages.map((m: any) => m.client_message_id)).size).toBe(20);
 expect(state.messages.every((m: any) => m.source === "system" && m.username === "Entity Wars" && m.text === "Welcome back, Alice!" && m.league === null)).toBe(true);
 expect(db.query("SELECT * FROM discord_chat_outbox").all()).toHaveLength(0);
 expect(chat.send("a", {text:"Welcome, Alice!", client_message_id:"forged", source:"system", username:"Entity Wars"}).status).toBe(200);
 expect(chat.acceptDiscord("123", "Entity Wars", "Welcome, Alice!")).toBe(true);
 expect(chat.state("a").messages.slice(-2).map((m: any) => [m.source, m.username])).toEqual([["game", "Alice"], ["discord", "[Discord] Entity Wars"]]);
 chat.close(); db.close();
});
