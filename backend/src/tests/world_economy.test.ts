import { expect, test } from "bun:test";
import { incrementalBossTokens, worldDropAmount } from "../world_economy";

test("World Gate amounts cover the inclusive range, including roll 1", () => {
	expect([0, 0.25, 0.5, 0.75, 1].map(roll => worldDropAmount(1, 4, roll))).toEqual([1, 2, 3, 4, 4]);
	expect(worldDropAmount(4, 4, 1)).toBe(4);
});

test("boss tokens count only newly crossed cumulative thresholds", () => {
	expect(incrementalBossTokens(800, 1100, 1000)).toBe(1);
	expect(incrementalBossTokens(1100, 1999, 1000)).toBe(0);
	expect(incrementalBossTokens(1999, 2000, 1000)).toBe(1);
	expect(incrementalBossTokens(800, 3500, 1000)).toBe(3);
	expect(incrementalBossTokens(400, 500, 250)).toBe(1);
});
