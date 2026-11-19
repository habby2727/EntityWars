import { expect, test } from "bun:test";
import { AccountStatusUnavailableError, isUserDisabled } from "../db/postgres";

test.skipIf(Bun.env.ACCOUNT_ISOLATED_CHILD === "1")("account status failure is tested in an isolated production process", async () => {
	const child = Bun.spawn([process.execPath, "test", import.meta.path], { env: { ...process.env, NODE_ENV: "production", BUN_ENV: "production", DATABASE_URL: "postgres://x:x@127.0.0.1:1/test", ACCOUNT_ISOLATED_CHILD: "1" }, stdout: "pipe", stderr: "pipe" });
	const code = await child.exited;
	const output = await new Response(child.stdout).text() + await new Response(child.stderr).text();
	expect({ code, output }).toEqual({ code: 0, output: expect.stringContaining("1 pass") });
}, 15000);

test.skipIf(Bun.env.NODE_ENV !== "production" || Bun.env.DATABASE_URL !== "postgres://x:x@127.0.0.1:1/test")("production rejects an unavailable account-status database", async () => {
	expect(Bun.env.NODE_ENV).toBe("production");
	await expect(isUserDisabled("isolated-test")).rejects.toBeInstanceOf(AccountStatusUnavailableError);
}, 10000);
