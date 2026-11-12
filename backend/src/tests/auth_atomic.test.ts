import { expect, test } from "bun:test";
import { issueRefreshToken, rotateRefreshToken, issueAccessToken, getAccessToken } from "../auth/tokens";
import { issueSession, getSession, revokeSession } from "../middleware/auth";

test.skipIf(Bun.env.AUTH_ISOLATED_TEST !== "1")("real Redis: legacy expiration, revocation and concurrent refresh", async () => {
  expect(Bun.env.AUTH_ISOLATED_TEST).toBe("1");
  expect(Bun.env.REDIS_URL).toMatch(/^redis:\/\/127\.0\.0\.1:\d+$/);
  const expired = await issueSession("test-user", 100);
  await Bun.sleep(200);
  expect(await getSession(expired)).toBeNull();
  const revoked = await issueSession("test-user", 10000);
  expect(await getSession(revoked)).not.toBeNull();
  await revokeSession(revoked);
  expect(await getSession(revoked)).toBeNull();
  const access = await issueAccessToken("test-user", 10000);
  expect((await getAccessToken(access))?.userId).toBe("test-user");
  const refresh = await issueRefreshToken("test-user", 10000);
  const results = await Promise.all(Array.from({ length: 20 }, () => rotateRefreshToken(refresh, 10000)));
  expect(results.filter(Boolean)).toHaveLength(1);
  expect(await rotateRefreshToken(refresh, 10000)).toBeNull();
}, 15000);
