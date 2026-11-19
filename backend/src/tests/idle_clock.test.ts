import { expect, mock, test } from "bun:test";

let now = 0;
let ready = true;
const entries = new Map<string, number>();
const redis = {
	set: async (key: string, _value: string, _unit: string, seconds: number) => { entries.set(key, now + seconds * 1000); },
	exists: async (key: string) => Number((entries.get(key) ?? 0) > now),
	expire: async (key: string, seconds: number) => {
		if ((entries.get(key) ?? 0) <= now) return 0;
		entries.set(key, now + seconds * 1000); return 1;
	}
};
mock.module("../db/redis", () => ({ ensureRedisReady: async () => ready, getRedis: () => redis }));

test("idle window expires at exactly three hours and only touch extends it", async () => {
	Bun.env.SESSION_IDLE_ENABLED = "1";
	const idle = await import("../auth/idle");
	await idle.resetIdle("token");
	now = 10799_000;
	expect(await idle.checkIdle("token")).toBe(true);
	await idle.touchIdle("token");
	now += 10799_000;
	expect(await idle.checkIdle("token")).toBe(true);
	now += 1000;
	expect(await idle.checkIdle("token")).toBe(false);
	await idle.touchIdle("token");
	expect(await idle.checkIdle("token")).toBe(false);
	await idle.resetIdle("token");
	expect(await idle.checkIdle("token")).toBe(true);
	ready = false;
	await expect(idle.checkIdle("token")).rejects.toThrow();
	await expect(idle.resetIdle("token")).rejects.toThrow();
	Bun.env.SESSION_IDLE_ENABLED = "0";
	expect(await idle.checkIdle("token")).toBe(true);
});
