import { test, expect } from "bun:test";
import { issueAccessToken, issueRefreshToken, getAccessToken, getRefreshToken, revokeAccessToken, revokeRefreshToken, rotateRefreshToken } from "../auth/tokens";
import { issueSession, getSession, revokeSession } from "../middleware/auth";

test.skipIf(Bun.env.REDIS_URL !== "redis://127.0.0.1:1" || Bun.env.NODE_ENV !== "development")("expired and revoked tokens are rejected when Redis is unavailable", async () => {
	const access = await issueAccessToken("test", 300);
	const refresh = await issueRefreshToken("test", 300);
	expect((await getAccessToken(access))?.userId).toBe("test");
	expect((await getRefreshToken(refresh))?.userId).toBe("test");
	await Bun.sleep(350);
	expect(await getAccessToken(access)).toBeNull();
	expect(await getRefreshToken(refresh)).toBeNull();
	const a = await issueAccessToken("test", 10000);
	const r = await issueRefreshToken("test", 10000);
	await expect(revokeAccessToken(a)).rejects.toThrow();
	await expect(revokeRefreshToken(r)).rejects.toThrow();
	expect(await getAccessToken(a)).toBeNull();
	expect(await getRefreshToken(r)).toBeNull();
	const session = await issueSession("test", 10000);
	await expect(revokeSession(session)).rejects.toThrow();
	expect(await getSession(session)).toBeNull();
	const rotating = await issueRefreshToken("test", 10000);
	const rotated = await rotateRefreshToken(rotating, 10000);
	expect(rotated).not.toBeNull();
	expect(await rotateRefreshToken(rotating, 10000)).toBeNull();
	expect(await getRefreshToken(rotating)).toBeNull();
	expect((await getRefreshToken(rotated!.refreshToken))?.userId).toBe("test");
}, 30000);
