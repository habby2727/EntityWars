import { expect, test } from "bun:test";
import { issueSession, getSession, revokeSession } from "../middleware/auth";
import { issueAccessToken, issueRefreshToken, getAccessToken, getRefreshToken, revokeAccessToken, revokeRefreshToken } from "../auth/tokens";
import { AuthStorageUnavailableError } from "../auth/storage_error";

test.skipIf(Bun.env.NODE_ENV !== "production" || Bun.env.REDIS_URL !== "redis://127.0.0.1:1")("production rejects unavailable token persistence", async () => {
  expect(Bun.env.NODE_ENV).toBe("production");
  expect(Bun.env.REDIS_URL).toBe("redis://127.0.0.1:1");
  await expect(issueSession("test-user", 1000)).rejects.toThrow();
  await expect(issueAccessToken("test-user", 1000)).rejects.toThrow();
  await expect(issueRefreshToken("test-user", 1000)).rejects.toThrow();
  await expect(getSession("unknown")).rejects.toBeInstanceOf(AuthStorageUnavailableError);
  await expect(getAccessToken("unknown")).rejects.toBeInstanceOf(AuthStorageUnavailableError);
  await expect(revokeSession("unknown")).rejects.toThrow();
  await expect(revokeAccessToken("unknown")).rejects.toThrow();
  await expect(revokeRefreshToken("unknown")).rejects.toThrow();
  await expect(getSession("any")).rejects.toBeInstanceOf(AuthStorageUnavailableError);
  await expect(getAccessToken("any")).rejects.toBeInstanceOf(AuthStorageUnavailableError);
  expect(await getRefreshToken("any")).toBeNull();
}, 15000);
