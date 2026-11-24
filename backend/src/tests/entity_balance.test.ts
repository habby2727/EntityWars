import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

test("requested entity balance changes preserve their other base stats", () => {
  const data = JSON.parse(readFileSync(resolve(import.meta.dir, "../../../data/entities.json"), "utf8"));
  const stats = (id: string) => data.entities.find((entity: any) => entity.id === id).base_stats;
  expect(stats("mercury_01")).toEqual({ hp: 91, power: 23, guard: 10, tempo: 18 });
  expect(stats("sodium_01")).toEqual({ hp: 122, power: 16, guard: 16, tempo: 10 });
  expect(stats("vitriol_01")).toEqual({ hp: 120, power: 19, guard: 14, tempo: 12 });
  expect(stats("gold_01")).toEqual({ hp: 98, power: 19, guard: 14, tempo: 12 });
});
