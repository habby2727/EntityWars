import { expect, test } from "bun:test";
import { AccountStatusUnavailableError, isUserDisabled } from "../db/postgres";

test.skipIf(Bun.env.NODE_ENV !== "production" || Bun.env.DATABASE_URL !== "postgres://x:x@127.0.0.1:1/test")("production rejects an unavailable account-status database", async () => {
	expect(Bun.env.NODE_ENV).toBe("production");
	await expect(isUserDisabled("isolated-test")).rejects.toBeInstanceOf(AccountStatusUnavailableError);
}, 10000);
