import { createHash } from "crypto";
import { ensureRedisReady, getRedis } from "../db/redis";
import { AuthStorageUnavailableError } from "./storage_error";

export const IDLE_SECONDS = 10800;
export const idleEnabled = () => Bun.env.SESSION_IDLE_ENABLED === "1";
const key = (token: string) => `idle:${createHash("sha256").update(token).digest("hex")}`;
const markerKey = (token: string) => `idle-initialized:${createHash("sha256").update(token).digest("hex")}`;
const refreshKey = (token: string) => `idle-refresh:${createHash("sha256").update(token).digest("hex")}`;

async function storage() {
	if (!(await ensureRedisReady())) throw new AuthStorageUnavailableError();
	return getRedis();
}

export async function resetIdle(token: string, expiresAt?: number): Promise<void> {
	if (!idleEnabled()) return;
	try {
		const redis = await storage();
		if (expiresAt !== undefined) {
			await redis.eval(`redis.call('SET', KEYS[1], '1', 'EX', ARGV[1]); redis.call('SET', KEYS[2], '1', 'PX', ARGV[2])`, 2, key(token), markerKey(token), IDLE_SECONDS, Math.max(1, expiresAt - Date.now()));
		} else await redis.set(key(token), "1", "EX", IDLE_SECONDS);
	}
	catch { throw new AuthStorageUnavailableError(); }
}

export async function checkIdle(token: string, expiresAt: number): Promise<boolean> {
	if (!idleEnabled()) return true;
	try {
		const script = `if redis.call('SET', KEYS[2], '1', 'PX', ARGV[1], 'NX') then
			redis.call('SET', KEYS[1], '1', 'EX', ARGV[2], 'NX') end
			return redis.call('EXISTS', KEYS[1])`;
		return Number(await (await storage()).eval(script, 2, key(token), markerKey(token), Math.max(1, expiresAt - Date.now()), IDLE_SECONDS)) === 1;
	}
	catch { throw new AuthStorageUnavailableError(); }
}

// Never revive a window that expired while the action was executing.
export async function touchIdle(token: string): Promise<void> {
	if (!idleEnabled()) return;
	try { await (await storage()).expire(key(token), IDLE_SECONDS); }
	catch { throw new AuthStorageUnavailableError(); }
}

export async function bindRefreshIdle(refresh: string, access: string, ttlMs: number): Promise<void> {
	if (!idleEnabled()) return;
	try { await (await storage()).set(refreshKey(refresh), key(access), "PX", ttlMs); }
	catch { throw new AuthStorageUnavailableError(); }
}

export async function checkRefreshIdle(refresh: string, expiresAt: number): Promise<boolean> {
	if (!idleEnabled()) return true;
	try {
		const script = `local access = redis.call('GET', KEYS[1])
			if not access then
				access = KEYS[2]; redis.call('SET', access, '1', 'EX', ARGV[2])
				redis.call('SET', KEYS[1], access, 'PX', ARGV[1])
			end
			return redis.call('EXISTS', access)`;
		return Number(await (await storage()).eval(script, 2, refreshKey(refresh), `idle-legacy-refresh:${createHash("sha256").update(refresh).digest("hex")}`, Math.max(1, expiresAt - Date.now()), IDLE_SECONDS)) === 1;
	} catch { throw new AuthStorageUnavailableError(); }
}

export async function rotateRefreshIdle(oldRefresh: string, newRefresh: string, access: string, ttlMs: number): Promise<boolean> {
	if (!idleEnabled()) return true;
	try {
		const script = `local old = redis.call('GET', KEYS[1]); if not old then return 0 end
			local ttl = redis.call('PTTL', old); if ttl <= 0 then return 0 end
			redis.call('SET', KEYS[2], '1', 'PX', ttl)
			redis.call('SET', KEYS[3], KEYS[2], 'PX', ARGV[1])
			redis.call('DEL', KEYS[1]); return 1`;
		return Number(await (await storage()).eval(script, 3, refreshKey(oldRefresh), key(access), refreshKey(newRefresh), ttlMs)) === 1;
	} catch { throw new AuthStorageUnavailableError(); }
}
