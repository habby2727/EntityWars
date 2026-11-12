import Redis from "ioredis";

const url = Bun.env.REDIS_URL || "";
const userId = Bun.env.TEST_AUTH_USER_ID || "";
if (!/^redis:\/\/127\.0\.0\.1:\d+$/.test(url) || !userId || Bun.env.FORGE_SMOKE_FIXTURE !== "1") throw new Error("Isolated Redis fixture required");
const redis = new Redis(url);
const now = Date.now();
await redis.set("access:integration-recovery-token", JSON.stringify({ userId, createdAt: now, expiresAt: now + 120000 }), "PX", 120000);
await redis.quit();
