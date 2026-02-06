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
	remaining?: number;
	resetSeconds?: number;
	message?: string;
};

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
			return { allowed: true, bypass: true };
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
		return { allowed: true, bypass: true };
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
