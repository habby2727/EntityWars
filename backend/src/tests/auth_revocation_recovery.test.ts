import { expect, mock, test } from "bun:test";

let ready = true;
const records = new Map<string, string>();
const redis = {
	set: async (key: string, value: string) => { records.set(key, value); return "OK"; },
	get: async (key: string) => records.get(key) ?? null,
	del: async (key: string) => Number(records.delete(key))
};
mock.module("../db/redis", () => ({ getRedis: () => redis, ensureRedisReady: async () => ready }));

test("failed unknown revocations do not block independent credentials after Redis recovers", async () => {
	const tokens = await import("../auth/tokens");
	const sessions = await import("../middleware/auth");
	const access = await tokens.issueAccessToken("user", 60000);
	const refresh = await tokens.issueRefreshToken("user", 60000);
	const session = await sessions.issueSession("user", 60000);
	records.set("access:remote-token", JSON.stringify({ userId: "remote", createdAt: Date.now(), expiresAt: Date.now() + 60000 }));
	ready = false;
	await expect(tokens.revokeAccessToken("remote-token")).rejects.toThrow();
	for (let i = 0; i < 100; i++) {
		await expect(tokens.revokeAccessToken(`unknown-${i}`)).rejects.toThrow();
		await expect(tokens.revokeRefreshToken(`unknown-${i}`)).rejects.toThrow();
		await expect(sessions.revokeSession(`unknown-${i}`)).rejects.toThrow();
	}
	await expect(tokens.getAccessToken(access)).rejects.toThrow();
	await expect(sessions.getSession(session)).rejects.toThrow();
	expect(await tokens.getRefreshToken(refresh)).toBeNull();
	ready = true;
	expect((await tokens.getAccessToken("remote-token"))?.userId).toBe("remote");
	await tokens.revokeAccessToken("remote-token");
	expect(await tokens.getAccessToken("remote-token")).toBeNull();
	expect((await tokens.getAccessToken(access))?.userId).toBe("user");
	expect((await tokens.getRefreshToken(refresh))?.userId).toBe("user");
	expect((await sessions.getSession(session))?.userId).toBe("user");
	await tokens.revokeAccessToken(access);
	await tokens.revokeRefreshToken(refresh);
	await sessions.revokeSession(session);
	expect(await tokens.getAccessToken(access)).toBeNull();
	expect(await tokens.getRefreshToken(refresh)).toBeNull();
	expect(await sessions.getSession(session)).toBeNull();
});
