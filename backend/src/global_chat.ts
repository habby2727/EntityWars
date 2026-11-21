import type { Database } from "bun:sqlite";
import { pvpRank, pvpSeason } from "./pvp/ranking";
import { ExpiringMap } from "./expiring_map";

// Message text is plain text. Consumers must render it as text, never HTML or BBCode.
export function createGlobalChat(db: Database, clock: () => number = Date.now, bridgeEnabled = false) {
	const presence = new Map<string, number>();
	const lastSend = new ExpiringMap<number>();
	const messages = db.query(`SELECT m.id, m.player_id, COALESCE(m.external_name, p.display_name) AS username, m.text, m.created_at, m.client_message_id,
		CASE WHEN m.source = 'system' THEN 'system' WHEN m.discord_message_id IS NOT NULL THEN 'discord' ELSE 'game' END AS source
		FROM global_chat_messages m LEFT JOIN players p ON p.player_id = m.player_id ORDER BY m.id DESC LIMIT 20`);
	const existing = db.query(`SELECT m.id, m.player_id, p.display_name AS username, m.text, m.created_at, m.client_message_id
		FROM global_chat_messages m JOIN players p ON p.player_id = m.player_id WHERE m.player_id = ? AND m.client_message_id = ?`);
	const insert = db.query("INSERT INTO global_chat_messages (player_id, client_message_id, text, created_at) VALUES (?, ?, ?, ?)");
	const prune = db.query("DELETE FROM global_chat_messages WHERE id NOT IN (SELECT id FROM global_chat_messages ORDER BY id DESC LIMIT 20)");
	const profile = db.query(`SELECT p.player_id, p.display_name AS username, r.rating
		FROM players p LEFT JOIN pvp_season_ratings r ON r.player_id = p.player_id AND r.season = ?
		WHERE p.player_id IN (SELECT value FROM json_each(?))`);
	function onlineCount() {
		const now = clock();
		for (const [id, seen] of presence) if (now - seen >= 45_000) presence.delete(id);
		return presence.size;
	}
	return {
		onlineCount,
		announceLogin(playerId: string, registered: boolean) {
			return db.transaction(() => {
				const player = db.query("SELECT display_name FROM players WHERE player_id = ?").get(playerId) as { display_name: string } | null;
				if (!player) throw new Error("Player unavailable for announcement.");
				const now = clock();
				const text = `${registered ? 'Welcome' : 'Welcome back'}, ${player.display_name}!`;
				const inserted = db.query("INSERT INTO global_chat_messages (player_id, client_message_id, text, created_at, external_name, source) VALUES (?, ?, ?, ?, 'Entity Wars', 'system')")
					.run('', crypto.randomUUID(), text, now);
				if (bridgeEnabled) {
					db.query("INSERT INTO discord_chat_outbox (message_id, username, text, created_at, source) VALUES (?, 'Entity Wars', ?, ?, 'system')").run(inserted.lastInsertRowid, text, now);
					db.query('DELETE FROM discord_chat_outbox WHERE message_id NOT IN (SELECT message_id FROM discord_chat_outbox ORDER BY message_id DESC LIMIT 1000)').run();
				}
				prune.run();
			}).immediate();
		},
		close() { messages.finalize(); existing.finalize(); insert.finalize(); prune.finalize(); profile.finalize(); },
		acceptDiscord(id: string, name: string, content: string) {
			if (!/^\d{1,32}$/.test(id) || typeof name !== 'string' || typeof content !== 'string') return false;
			const clean = (s: string, limit: number) => [...s.replace(/[\u0000-\u001f\u007f-\u009f]/gu, ' ').replace(/\s+/gu, ' ').trim()].slice(0, limit).join('');
			const text = clean(content, 200), username = clean(name, 50);
			if (!text || !username) return false;
			return db.transaction(() => {
				const now = clock();
				if (!db.query('INSERT OR IGNORE INTO discord_chat_seen VALUES (?, ?)').run(id, now).changes) return false;
				db.query('INSERT INTO global_chat_messages (player_id, client_message_id, text, created_at, external_name, discord_message_id) VALUES (?, ?, ?, ?, ?, ?)').run('', id, text, now, '[Discord] ' + username, id);
				prune.run();
				db.query('DELETE FROM discord_chat_seen WHERE message_id NOT IN (SELECT message_id FROM discord_chat_seen ORDER BY created_at DESC LIMIT 10000)').run();
				return true;
			}).immediate();
		},
		state(playerId: string) {
			const now = clock();
			presence.set(playerId, now);
			onlineCount();
			const season = pvpSeason(now);
			const rows = messages.all().reverse() as any[];
			const ids = [...new Set([...presence.keys(), ...rows.filter(row => row.source === 'game').map(row => row.player_id)])];
			const profiles = new Map((profile.all(season, JSON.stringify(ids)) as { player_id: string; username: string; rating: number | null }[]).map(row => [row.player_id, { player_id: row.player_id, username: row.username, ...pvpRank(row.rating ?? 1000) }]));
			const online_players = Array.from(presence.keys(), id => profiles.get(id)).filter(row => row !== undefined)
				.sort((a, b) => a.username.localeCompare(b.username) || a.player_id.localeCompare(b.player_id));
			return { messages: rows.map(row => ({ ...row, league: row.source !== 'game' ? null : profiles.get(row.player_id)?.league ?? null })), online_count: online_players.length, online_players };
		},
		send(playerId: string, body: any) {
			const text = body?.text;
			const clientId = body?.client_message_id;
			if (typeof text !== "string" || !text.trim() || [...text].length > 200 || /[\u0000-\u001f\u007f-\u009f]/u.test(text) ||
				typeof clientId !== "string" || !clientId.trim() || clientId.length > 200 || /[\u0000-\u001f\u007f-\u009f]/u.test(clientId)) {
				return { status: 400, data: { error: "Invalid message or client_message_id." } };
			}
			return db.transaction(() => {
				const previous = existing.get(playerId, clientId);
				if (previous) return { status: 200, data: { message: previous, duplicate: true } };
				const now = clock();
				const last = lastSend.get(playerId, now);
				if (last !== undefined && now - last < 2000) return { status: 429, data: { error: "Send rate limit exceeded." } };
				insert.run(playerId, clientId, text, now);
				prune.run();
				const message = existing.get(playerId, clientId);
				if (bridgeEnabled && message) {
					const row = message as { id: number; username: string; text: string };
					db.query('INSERT INTO discord_chat_outbox (message_id, username, text, created_at) VALUES (?, ?, ?, ?)').run(row.id, row.username, row.text, now);
					db.query('DELETE FROM discord_chat_outbox WHERE message_id NOT IN (SELECT message_id FROM discord_chat_outbox ORDER BY message_id DESC LIMIT 1000)').run();
				}
				lastSend.set(playerId, now, now + 2000, now);
				return { status: 200, data: { message, duplicate: false } };
			}).immediate();
		}
	};
}
