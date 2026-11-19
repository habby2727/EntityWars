import { Client, GatewayIntentBits, MessageType } from 'discord.js';
import type { Database } from 'bun:sqlite';
import type { createGlobalChat } from './global_chat';

type Chat = ReturnType<typeof createGlobalChat>;
export function outgoingDiscordMessage(row: { message_id: number; username: string; text: string }) {
	return { content: `[Game] ${row.username}: ${row.text}`, allowedMentions: { parse: [] as never[] }, nonce: String(row.message_id), enforceNonce: true };
}
export function acceptDiscordMessage(chat: Chat, message: any, guildId: string, channelId: string, applicationId: string) {
	if (message.guildId !== guildId || message.channelId !== channelId || message.author?.bot || message.author?.id === applicationId || message.webhookId || message.system || ![MessageType.Default, MessageType.Reply].includes(message.type)) return false;
	return chat.acceptDiscord(message.id, message.member?.displayName || message.author?.globalName || message.author?.username || '', message.content);
}

export function startDiscordBridge(db: Database, chat: Chat, env: Record<string, string | undefined> = process.env) {
	const token = env.DISCORD_BOT_TOKEN;
	if (!token) return { enabled: false, close() {} };
	const guild = env.DISCORD_GUILD_ID || '1376365043775438871';
	const channelId = env.DISCORD_CHANNEL_ID || '1572758122810974360';
	const app = env.DISCORD_APPLICATION_ID || '1572757742270288033';
	const client = new Client({ intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages, GatewayIntentBits.MessageContent] });
	let stopped = false, busy = false, retry = 1000;
	let loginTimer: ReturnType<typeof setTimeout> | undefined;
	client.on('error', () => console.warn('Discord bridge connection error'));
	client.on('messageCreate', message => { try { acceptDiscordMessage(chat, message, guild, channelId, app); } catch { console.warn('Discord bridge could not store message'); } });
	async function connect() {
		if (stopped) return;
		try { await client.login(token); retry = 1000; }
		catch { console.warn('Discord bridge login failed; retrying'); loginTimer = setTimeout(connect, retry); retry = Math.min(retry * 2, 60000); }
	}
	async function dispatch() {
		if (stopped || busy || !client.isReady()) return;
		busy = true;
		let row: any;
		try {
			row = db.query('SELECT * FROM discord_chat_outbox WHERE next_attempt <= ? ORDER BY message_id LIMIT 1').get(Date.now());
			if (!row) return;
			const channel = await client.channels.fetch(channelId);
			if (!channel || !('send' in channel) || !('guildId' in channel) || channel.guildId !== guild) throw new Error('channel unavailable');
			await channel.send(outgoingDiscordMessage(row));
			db.query('DELETE FROM discord_chat_outbox WHERE message_id = ?').run(row.message_id);
		} catch {
			try { if (row) db.query('UPDATE discord_chat_outbox SET attempts = attempts + 1, next_attempt = ? WHERE message_id = ?').run(Date.now() + Math.min(300000, 2000 * 2 ** Math.min(row.attempts, 7)), row.message_id); } catch { /* Retry on the next dispatch tick. */ }
			console.warn('Discord bridge dispatch failed; retrying');
		} finally { busy = false; }
	}
	void connect();
	const timer = setInterval(() => void dispatch(), 2000);
	return { enabled: true, close() { stopped = true; clearInterval(timer); if (loginTimer) clearTimeout(loginTimer); client.destroy(); } };
}
