import Redis from "ioredis";

const DEFAULT_REDIS_URL = "redis://127.0.0.1:6379/0";
const redisUrl = Bun.env.REDIS_URL || DEFAULT_REDIS_URL;

const redis = new Redis(redisUrl, {
	lazyConnect: true,
	maxRetriesPerRequest: 1,
	enableReadyCheck: true,
	enableOfflineQueue: false,
	connectTimeout: Number(Bun.env.REDIS_CONNECT_TIMEOUT_MS || 800),
	commandTimeout: Number(Bun.env.REDIS_COMMAND_TIMEOUT_MS || 1500),
	retryStrategy: (times) => Math.min(times * 200, 2000),
	reconnectOnError: (err) => {
		const message = err?.message || "";
		return message.includes("READONLY") || message.includes("ECONNRESET");
	}
});

redis.on("error", (err) => {
	console.warn("[redis] error", err);
});

redis.on("reconnecting", () => {
	console.warn("[redis] reconnecting");
});

export function getRedis(): Redis {
	return redis;
}

export async function ensureRedisReady(): Promise<boolean> {
	try {
		if (redis.status !== "ready") {
			await redis.connect();
		}
		return redis.status === "ready";
	} catch {
		return false;
	}
}

export async function pingRedis(): Promise<boolean> {
	try {
		if (!(await ensureRedisReady())) {
			return false;
		}
		const res = await redis.ping();
		return res == "PONG";
	} catch {
		return false;
	}
}

export async function acquireLock(key: string, ttlMs: number): Promise<string | null> {
	const token = crypto.randomUUID();
	try {
		if (!(await ensureRedisReady())) {
			return null;
		}
		const result = await redis.set(`lock:${key}`, token, "PX", ttlMs, "NX");
		return result == "OK" ? token : null;
	} catch (err) {
		console.warn("[redis] lock acquire failed", err);
		return null;
	}
}

export async function releaseLock(key: string, token: string): Promise<boolean> {
	const script = `
		if redis.call("get", KEYS[1]) == ARGV[1] then
			return redis.call("del", KEYS[1])
		else
			return 0
		end
	`;
	try {
		const result = await redis.eval(script, 1, `lock:${key}`, token);
		return Number(result) > 0;
	} catch (err) {
		console.warn("[redis] lock release failed", err);
		return false;
	}
}

export async function redisExample(): Promise<void> {
	try {
		if (!(await ensureRedisReady())) {
			throw new Error("Redis unavailable");
		}
		const cached = await redis.get("example:hello");
		if (!cached) {
			await redis.set("example:hello", "world", "EX", 60);
		}
		const value = await redis.get("example:hello");
		console.log("[redis] example value", value);
	} catch (err) {
		console.warn("[redis] example skipped", err);
	}
}

export async function closeRedis(): Promise<void> {
	try {
		await redis.quit();
	} catch (err) {
		console.warn("[redis] close failed", err);
	}
}
