import { ensureRedisReady, getRedis } from "../db/redis";

export type SessionRecord = {
	userId: string;
	createdAt: number;
	expiresAt: number;
};

const inMemorySessions = new Map<string, SessionRecord>();
const revokedSessions = new Set<string>();
const production = [Bun.env.NODE_ENV, Bun.env.BUN_ENV].some(v => ["production", "prod"].includes((v ?? "").toLowerCase()));

function makeSessionKey(token: string): string {
	return `sess:${token}`;
}

export function extractToken(req: Request): string | null {
	const authHeader = req.headers.get("authorization");
	if (authHeader) {
		const parts = authHeader.split(" ");
		if (parts.length == 2 && parts[0].toLowerCase() == "bearer") {
			return parts[1];
		}
	}
	return req.headers.get("x-dev-token");
}

export async function issueSession(userId: string, ttlMs: number): Promise<string> {
	const token = crypto.randomUUID();
	const now = Date.now();
	const record: SessionRecord = {
		userId,
		createdAt: now,
		expiresAt: now + ttlMs
	};
	let persisted = false;
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.set(makeSessionKey(token), JSON.stringify(record), "PX", ttlMs);
			persisted = true;
		}
	} catch (err) {
		console.warn("[auth] redis session write failed", err);
	}
	if (production && !persisted) throw new Error("Session storage unavailable");
	inMemorySessions.set(token, record);
	return token;
}

export async function revokeSession(token: string): Promise<void> {
	inMemorySessions.delete(token);
	revokedSessions.add(token);
	let persisted = false;
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.del(makeSessionKey(token));
			persisted = true;
		}
	} catch (err) {
		console.warn("[auth] redis session delete failed", err);
	}
	if (production && !persisted) throw new Error("Session revocation unavailable");
}

export async function getSession(token: string): Promise<SessionRecord | null> {
	if (revokedSessions.has(token)) return null;
	const now = Date.now();
	const cached = inMemorySessions.get(token);
	if (cached) {
		if (cached.expiresAt > now && !production) {
			return cached;
		}
		inMemorySessions.delete(token);
	}
	try {
		const redis = getRedis();
		if (!(await ensureRedisReady())) {
			return !production && cached && cached.expiresAt > Date.now() ? cached : null;
		}
		const raw = await redis.get(makeSessionKey(token));
		if (!raw) {
			return null;
		}
		const parsed = JSON.parse(raw) as SessionRecord;
		if (!parsed || typeof parsed.userId != "string" || !Number.isFinite(parsed.expiresAt)) {
			return null;
		}
		if (parsed.expiresAt <= now) {
			await redis.del(makeSessionKey(token));
			return null;
		}
		inMemorySessions.set(token, parsed);
		return parsed;
	} catch (err) {
		console.warn("[auth] redis session read failed", err);
		return !production && cached && cached.expiresAt > Date.now() ? cached : null;
	}
}
