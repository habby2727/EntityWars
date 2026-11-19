import { expect, test } from "bun:test";
import { ExpiringMap } from "../expiring_map";
import { createBossIpLimit } from "../boss_ip_limit";

test("incremental expiry reclaims idle entries and preserves live entries", () => {
	const entries = new ExpiringMap<number>();
	for (let i = 0; i < 1000; i++) entries.set(`old-${i}`, i, 100, 0);
	entries.set("live", 7, 200, 0);
	for (let i = 0; i < 70; i++) entries.get("live", 100);
	expect(entries.size).toBe(1);
	expect(entries.get("live", 199)).toBe(7);
	expect(entries.get("live", 200)).toBeUndefined();
});

test("boss IP limit retains its boundary and resets for a new window", () => {
	const allow = createBossIpLimit();
	expect(allow("ip", 100, 2, 0)).toBe(true);
	expect(allow("ip", 100, 2, 99)).toBe(true);
	expect(allow("ip", 100, 2, 100)).toBe(false);
	expect(allow("other", 100, 2, 100)).toBe(true);
	expect(allow("ip", 200, 2, 101)).toBe(true);
	expect(allow("ip", 200, 2, 101)).toBe(true);
	expect(allow("ip", 200, 2, 101)).toBe(false);
	expect(allow("ip", 200, 0, 101)).toBe(true);
});

test("updating an entry does not leave an obsolete expiry", () => {
	const entries = new ExpiringMap<number>();
	entries.set("player", 1, 100, 0);
	entries.set("player", 2, 200, 50);
	expect(entries.get("player", 100)).toBe(2);
	expect(entries.get("player", 200)).toBeUndefined();
});
