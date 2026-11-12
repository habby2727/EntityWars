import { expect, test } from "bun:test";
import { issueSession, getSession } from "../middleware/auth";
import { issueAccessToken, issueRefreshToken, getAccessToken } from "../auth/tokens";

test.skipIf(Bun.env.NODE_ENV !== "production" || Bun.env.REDIS_URL !== "redis://127.0.0.1:1")("production rejects unavailable token persistence", async () => {
  expect(Bun.env.NODE_ENV).toBe("production");
  expect(Bun.env.REDIS_URL).toBe("redis://127.0.0.1:1");
  await expect(issueSession("test-user", 1000)).rejects.toThrow();
  await expect(issueAccessToken("test-user", 1000)).rejects.toThrow();
  await expect(issueRefreshToken("test-user", 1000)).rejects.toThrow();
  expect(await getSession("unknown")).toBeNull();
  expect(await getAccessToken("unknown")).toBeNull();
}, 15000);
