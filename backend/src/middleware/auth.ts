import { ensureRedisReady, getRedis } from "../db/redis";

export type SessionRecord = {
	userId: string;
	createdAt: number;
	expiresAt: number;
};

const inMemorySessions = new Map<string, SessionRecord>();

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
	inMemorySessions.set(token, record);
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.set(makeSessionKey(token), JSON.stringify(record), "PX", ttlMs);
		}
	} catch (err) {
		console.warn("[auth] redis session write failed", err);
	}
	return token;
}

export async function revokeSession(token: string): Promise<void> {
	inMemorySessions.delete(token);
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.del(makeSessionKey(token));
		}
	} catch (err) {
		console.warn("[auth] redis session delete failed", err);
	}
}

export async function getSession(token: string): Promise<SessionRecord | null> {
	const now = Date.now();
	const cached = inMemorySessions.get(token);
	if (cached) {
		if (cached.expiresAt > now) {
			return cached;
		}
		inMemorySessions.delete(token);
	}
	try {
		const redis = getRedis();
		if (!(await ensureRedisReady())) {
			return cached ?? null;
		}
		const raw = await redis.get(makeSessionKey(token));
		if (!raw) {
			return null;
		}
		const parsed = JSON.parse(raw) as SessionRecord;
		if (!parsed || typeof parsed.userId != "string") {
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
		return cached ?? null;
	}
}
