import { ensureRedisReady, getRedis } from "../db/redis";

export type RateLimitKeyBy = "ip" | "user" | "ip+route";

export type RateLimitOptions = {
	keyPrefix: string;
	windowSeconds: number;
	max: number;
	keyBy?: RateLimitKeyBy;
	ip?: string;
	userId?: string | null;
	route?: string;
};

export type RateLimitResult = {
	allowed: boolean;
	bypass: boolean;
	status?: number;
	remaining?: number;
	resetSeconds?: number;
	message?: string;
};

const memoryLimits = new Map<string, { count: number; expiresAt: number }>();

function limitWithoutRedis(key: string, options: RateLimitOptions): RateLimitResult {
	const isProduction = [Bun.env.NODE_ENV, Bun.env.BUN_ENV].some(
		(value) => value?.toLowerCase() == "production" || value?.toLowerCase() == "prod"
	);
	if (isProduction) {
		return { allowed: false, bypass: false, status: 503, message: "Rate limit unavailable." };
	}
	const now = Date.now();
	for (const [storedKey, entry] of memoryLimits) {
		if (entry.expiresAt <= now) memoryLimits.delete(storedKey);
	}
	const windowMs = Math.max(1, Math.floor(options.windowSeconds * 1000));
	const max = Math.max(1, Math.floor(options.max));
	let entry = memoryLimits.get(key);
	if (!entry) {
		entry = { count: 0, expiresAt: now + windowMs };
		memoryLimits.set(key, entry);
	}
	entry.count += 1;
	const remaining = Math.max(0, max - entry.count);
	const resetSeconds = Math.max(1, Math.ceil((entry.expiresAt - now) / 1000));
	return {
		allowed: entry.count <= max,
		bypass: false,
		remaining,
		resetSeconds,
		...(entry.count > max ? { message: "Rate limit exceeded." } : {})
	};
}

function buildKey(options: RateLimitOptions): string {
	const keyBy = options.keyBy ?? "ip";
	const ip = options.ip ?? "unknown";
	const userId = options.userId ?? "anon";
	const route = options.route ?? "global";
	switch (keyBy) {
		case "user":
			return `${options.keyPrefix}:${userId}`;
		case "ip+route":
			return `${options.keyPrefix}:${ip}:${route}`;
		default:
			return `${options.keyPrefix}:${ip}`;
	}
}

export async function rateLimit(options: RateLimitOptions): Promise<RateLimitResult> {
	const key = buildKey(options);
	try {
		const redis = getRedis();
		if (!(await ensureRedisReady())) {
			return limitWithoutRedis(key, options);
		}
		const count = await redis.incr(key);
		if (count == 1) {
			await redis.expire(key, options.windowSeconds);
		}
		const remaining = Math.max(0, options.max - count);
		if (count > options.max) {
			return {
				allowed: false,
				bypass: false,
				remaining,
				resetSeconds: options.windowSeconds,
				message: "Rate limit exceeded."
			};
		}
		return { allowed: true, bypass: false, remaining, resetSeconds: options.windowSeconds };
	} catch (err) {
		console.warn("[rate-limit] redis unavailable", err);
		return limitWithoutRedis(key, options);
	}
}

export async function checkLoginRateLimit(ip: string): Promise<{ allowed: boolean; error?: string }> {
	const result = await rateLimit({
		keyPrefix: "rl:login",
		windowSeconds: Number(Bun.env.LOGIN_RATE_LIMIT_WINDOW_SECONDS || 600),
		max: Number(Bun.env.LOGIN_RATE_LIMIT_MAX || 10),
		keyBy: "ip",
		ip
	});
	if (!result.allowed) {
		return { allowed: false, error: result.message };
	}
	return { allowed: true };
}
