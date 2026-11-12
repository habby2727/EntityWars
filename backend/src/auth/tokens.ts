import { ensureRedisReady, getRedis } from "../db/redis";

export type TokenRecord = {
	userId: string;
	createdAt: number;
	expiresAt: number;
	fingerprint?: string;
};

const accessMemory = new Map<string, TokenRecord>();
const refreshMemory = new Map<string, TokenRecord>();
const revokedAccess = new Set<string>();
const revokedRefresh = new Set<string>();
const localOnlyRefresh = new Set<string>();
const production = [Bun.env.NODE_ENV, Bun.env.BUN_ENV].some((v) => ["production", "prod"].includes((v ?? "").toLowerCase()));

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
	let persisted = false;
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.set(accessKey(token), JSON.stringify(record), "PX", ttlMs);
			persisted = true;
		}
	} catch (err) {
		console.warn("[auth] access token write failed", err);
	}
	if (production && !persisted) throw new Error("Token storage unavailable");
	accessMemory.set(token, record);
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
	let persisted = false;
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.set(refreshKey(token), JSON.stringify(record), "PX", ttlMs);
			persisted = true;
		}
	} catch (err) {
		console.warn("[auth] refresh token write failed", err);
	}
	if (production && !persisted) throw new Error("Token storage unavailable");
	if (!persisted) localOnlyRefresh.add(token);
	refreshMemory.set(token, record);
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
	if (revokedAccess.has(token)) return null;
	const now = Date.now();
	const cached = accessMemory.get(token);
	if (cached && !isExpired(cached, now) && !production) {
		return cached;
	}
	if (cached && isExpired(cached, now)) {
		accessMemory.delete(token);
	}
	try {
		const redis = getRedis();
		if (!(await ensureRedisReady())) {
			return null;
		}
		const raw = await redis.get(accessKey(token));
		if (!raw) {
			return null;
		}
		const parsed = JSON.parse(raw) as TokenRecord;
		if (!parsed || typeof parsed.userId != "string" || !Number.isFinite(parsed.expiresAt)) {
			return null;
		}
		if (isExpired(parsed, Date.now())) {
			await redis.del(accessKey(token));
			return null;
		}
		accessMemory.set(token, parsed);
		return parsed;
	} catch (err) {
		console.warn("[auth] access token read failed", err);
		return null;
	}
}

export async function getRefreshToken(token: string): Promise<TokenRecord | null> {
	if (revokedRefresh.has(token)) return null;
	const now = Date.now();
	const cached = refreshMemory.get(token);
	if (cached && !isExpired(cached, now) && !production) {
		return cached;
	}
	if (cached && isExpired(cached, now)) {
		refreshMemory.delete(token);
	}
	try {
		const redis = getRedis();
		if (!(await ensureRedisReady())) {
			return null;
		}
		const raw = await redis.get(refreshKey(token));
		if (!raw) {
			return null;
		}
		const parsed = JSON.parse(raw) as TokenRecord;
		if (!parsed || typeof parsed.userId != "string" || !Number.isFinite(parsed.expiresAt)) {
			return null;
		}
		if (isExpired(parsed, Date.now())) {
			await redis.del(refreshKey(token));
			return null;
		}
		refreshMemory.set(token, parsed);
		return parsed;
	} catch (err) {
		console.warn("[auth] refresh token read failed", err);
		return null;
	}
}

export async function revokeAccessToken(token: string): Promise<void> {
	revokedAccess.add(token);
	accessMemory.delete(token);
	let persisted = false;
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.del(accessKey(token));
			persisted = true;
		}
	} catch (err) {
		console.warn("[auth] access token delete failed", err);
	}
	if (production && !persisted) throw new Error("Token revocation unavailable");
}

export async function revokeRefreshToken(token: string): Promise<void> {
	revokedRefresh.add(token);
	localOnlyRefresh.delete(token);
	refreshMemory.delete(token);
	let persisted = false;
	try {
		const redis = getRedis();
		if (await ensureRedisReady()) {
			await redis.del(refreshKey(token));
			persisted = true;
		}
	} catch (err) {
		console.warn("[auth] refresh token delete failed", err);
	}
	if (production && !persisted) throw new Error("Token revocation unavailable");
}

export async function rotateRefreshToken(
	oldToken: string,
	refreshTtlMs: number,
	fingerprint?: string
): Promise<{ record: TokenRecord; refreshToken: string } | null> {
	if (!production && localOnlyRefresh.has(oldToken)) {
		const record = refreshMemory.get(oldToken);
		if (!record || revokedRefresh.has(oldToken) || isExpired(record, Date.now())) return null;
		localOnlyRefresh.delete(oldToken);
		revokedRefresh.add(oldToken);
		refreshMemory.delete(oldToken);
		const refreshToken = await issueRefreshToken(record.userId, refreshTtlMs, fingerprint ?? record.fingerprint);
		return { record, refreshToken };
	}
	if (!(await ensureRedisReady())) return null;
	const refreshToken = crypto.randomUUID();
	const now = Date.now();
	const script = `
		local raw = redis.call('GET', KEYS[1])
		if not raw then return nil end
		local ok, record = pcall(cjson.decode, raw)
		if not ok or type(record.userId) ~= 'string' or type(record.expiresAt) ~= 'number' or record.expiresAt <= tonumber(ARGV[1]) then return nil end
		local updated = {userId = record.userId, createdAt = tonumber(ARGV[1]), expiresAt = tonumber(ARGV[1]) + tonumber(ARGV[2])}
		if ARGV[3] ~= '' then updated.fingerprint = ARGV[3] elseif record.fingerprint then updated.fingerprint = record.fingerprint end
		redis.call('SET', KEYS[2], cjson.encode(updated), 'PX', ARGV[2])
		redis.call('DEL', KEYS[1])
		return raw`;
	try {
		const raw = await getRedis().eval(script, 2, refreshKey(oldToken), refreshKey(refreshToken), now, refreshTtlMs, fingerprint ?? "");
		if (typeof raw !== "string") return null;
		const record = JSON.parse(raw) as TokenRecord;
		revokedRefresh.add(oldToken);
		refreshMemory.delete(oldToken);
		refreshMemory.set(refreshToken, { userId: record.userId, createdAt: now, expiresAt: now + refreshTtlMs, fingerprint: fingerprint ?? record.fingerprint });
		return { record, refreshToken };
	} catch (err) {
		console.warn("[auth] refresh rotation failed", err);
		return null;
	}
}
