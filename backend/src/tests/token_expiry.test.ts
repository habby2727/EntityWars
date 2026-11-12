import { test, expect } from "bun:test";
import { issueAccessToken, issueRefreshToken, getAccessToken, getRefreshToken, revokeAccessToken, revokeRefreshToken } from "../auth/tokens";

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
	await revokeAccessToken(a);
	await revokeRefreshToken(r);
	expect(await getAccessToken(a)).toBeNull();
	expect(await getRefreshToken(r)).toBeNull();
}, 30000);
