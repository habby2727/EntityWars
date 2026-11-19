import { createHash } from "crypto";
import { ensureRedisReady, getRedis } from "../db/redis";
import { AuthStorageUnavailableError } from "./storage_error";

export const IDLE_SECONDS = 10800;
export const idleEnabled = () => Bun.env.SESSION_IDLE_ENABLED === "1";
const key = (token: string) => `idle:${createHash("sha256").update(token).digest("hex")}`;
const refreshKey = (token: string) => `idle-refresh:${createHash("sha256").update(token).digest("hex")}`;

async function storage() {
	if (!(await ensureRedisReady())) throw new AuthStorageUnavailableError();
	return getRedis();
}

export async function resetIdle(token: string): Promise<void> {
	if (!idleEnabled()) return;
	try { await (await storage()).set(key(token), "1", "EX", IDLE_SECONDS); }
	catch { throw new AuthStorageUnavailableError(); }
}

export async function checkIdle(token: string): Promise<boolean> {
	if (!idleEnabled()) return true;
	try { return (await (await storage()).exists(key(token))) === 1; }
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

export async function checkRefreshIdle(refresh: string): Promise<boolean> {
	if (!idleEnabled()) return true;
	try {
		const redis = await storage();
		const accessKey = await redis.get(refreshKey(refresh));
		return !!accessKey && await redis.exists(accessKey) === 1;
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
