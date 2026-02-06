import { ensureRedisReady, getRedis } from "../db/redis";

export type TokenRecord = {
	userId: string;
	createdAt: number;
	expiresAt: number;
	fingerprint?: string;
};

const accessMemory = new Map<string, TokenRecord>();
const refreshMemory = new Map<string, TokenRecord>();

function accessKey(token: string): string {
	return `access:${token}`;
}

function refreshKey(token: string): string {
	return `refresh:${token}`;
}

function isExpired(record: TokenRecord, now: number): boolean {
	return record.expiresAt <= now;
}

export async function issueAccessToken(userId: string, ttlMs: number): Promise<string> {
	const token = crypto.randomUUID();
	const now = Date.now();
	const record: TokenRecord = { userId, createdAt: now, expiresAt: now + ttlMs };
	accessMemory.set(token, record);
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.set(accessKey(token), JSON.stringify(record), "PX", ttlMs);
		}
	} catch (err) {
		console.warn("[auth] access token write failed", err);
	}
	return token;
}

export async function issueRefreshToken(
	userId: string,
	ttlMs: number,
	fingerprint?: string
): Promise<string> {
	const token = crypto.randomUUID();
	const now = Date.now();
	const record: TokenRecord = { userId, createdAt: now, expiresAt: now + ttlMs, fingerprint };
	refreshMemory.set(token, record);
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.set(refreshKey(token), JSON.stringify(record), "PX", ttlMs);
		}
	} catch (err) {
		console.warn("[auth] refresh token write failed", err);
	}
	return token;
}

export async function issueTokenPair(
	userId: string,
	accessTtlMs: number,
	refreshTtlMs: number,
	fingerprint?: string
): Promise<{ accessToken: string; refreshToken: string }> {
	const accessToken = await issueAccessToken(userId, accessTtlMs);
	const refreshToken = await issueRefreshToken(userId, refreshTtlMs, fingerprint);
	return { accessToken, refreshToken };
}

export async function getAccessToken(token: string): Promise<TokenRecord | null> {
	const now = Date.now();
	const cached = accessMemory.get(token);
	if (cached && !isExpired(cached, now)) {
		return cached;
	}
	if (cached && isExpired(cached, now)) {
		accessMemory.delete(token);
	}
	try {
		const redis = getRedis();
		if (!(await ensureRedisReady())) {
			return cached ?? null;
		}
		const raw = await redis.get(accessKey(token));
		if (!raw) {
			return null;
		}
		const parsed = JSON.parse(raw) as TokenRecord;
		if (!parsed || typeof parsed.userId != "string") {
			return null;
		}
		if (isExpired(parsed, now)) {
			await redis.del(accessKey(token));
			return null;
		}
		accessMemory.set(token, parsed);
		return parsed;
	} catch (err) {
		console.warn("[auth] access token read failed", err);
		return cached ?? null;
	}
}

export async function getRefreshToken(token: string): Promise<TokenRecord | null> {
	const now = Date.now();
	const cached = refreshMemory.get(token);
	if (cached && !isExpired(cached, now)) {
		return cached;
	}
	if (cached && isExpired(cached, now)) {
		refreshMemory.delete(token);
	}
	try {
		const redis = getRedis();
		if (!(await ensureRedisReady())) {
			return cached ?? null;
		}
		const raw = await redis.get(refreshKey(token));
		if (!raw) {
			return null;
		}
		const parsed = JSON.parse(raw) as TokenRecord;
		if (!parsed || typeof parsed.userId != "string") {
			return null;
		}
		if (isExpired(parsed, now)) {
			await redis.del(refreshKey(token));
			return null;
		}
		refreshMemory.set(token, parsed);
		return parsed;
	} catch (err) {
		console.warn("[auth] refresh token read failed", err);
		return cached ?? null;
	}
}

export async function revokeAccessToken(token: string): Promise<void> {
	accessMemory.delete(token);
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.del(accessKey(token));
		}
	} catch (err) {
		console.warn("[auth] access token delete failed", err);
	}
}

export async function revokeRefreshToken(token: string): Promise<void> {
	refreshMemory.delete(token);
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.del(refreshKey(token));
		}
	} catch (err) {
		console.warn("[auth] refresh token delete failed", err);
	}
}

export async function rotateRefreshToken(
	oldToken: string,
	refreshTtlMs: number,
	fingerprint?: string
): Promise<{ record: TokenRecord; refreshToken: string } | null> {
	const record = await getRefreshToken(oldToken);
	if (!record) {
		return null;
	}
	await revokeRefreshToken(oldToken);
	const refreshToken = await issueRefreshToken(record.userId, refreshTtlMs, fingerprint ?? record.fingerprint);
	return { record, refreshToken };
}
