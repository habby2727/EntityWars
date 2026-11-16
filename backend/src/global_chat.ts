import type { Database } from "bun:sqlite";

// Message text is plain text. Consumers must render it as text, never HTML or BBCode.
export function createGlobalChat(db: Database, clock: () => number = Date.now) {
	const presence = new Map<string, number>();
	const lastSend = new Map<string, number>();
	const messages = db.query(`SELECT m.id, m.player_id, p.display_name AS username, m.text, m.created_at, m.client_message_id
		FROM global_chat_messages m JOIN players p ON p.player_id = m.player_id ORDER BY m.id DESC LIMIT 20`);
	const existing = db.query(`SELECT m.id, m.player_id, p.display_name AS username, m.text, m.created_at, m.client_message_id
		FROM global_chat_messages m JOIN players p ON p.player_id = m.player_id WHERE m.player_id = ? AND m.client_message_id = ?`);
	const insert = db.query("INSERT INTO global_chat_messages (player_id, client_message_id, text, created_at) VALUES (?, ?, ?, ?)");
	const prune = db.query("DELETE FROM global_chat_messages WHERE id NOT IN (SELECT id FROM global_chat_messages ORDER BY id DESC LIMIT 20)");
	return {
		close() { messages.finalize(); existing.finalize(); insert.finalize(); prune.finalize(); },
		state(playerId: string) {
			const now = clock();
			for (const [id, seen] of presence) if (now - seen >= 45_000) presence.delete(id);
			presence.set(playerId, now);
			return { messages: messages.all().reverse(), online_count: presence.size };
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
				const last = lastSend.get(playerId);
				if (last !== undefined && now - last < 2000) return { status: 429, data: { error: "Send rate limit exceeded." } };
				insert.run(playerId, clientId, text, now);
				prune.run();
				const message = existing.get(playerId, clientId);
				lastSend.set(playerId, now);
				return { status: 200, data: { message, duplicate: false } };
			}).immediate();
		}
	};
}
