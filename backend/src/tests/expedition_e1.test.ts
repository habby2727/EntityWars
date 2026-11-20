import { test, expect } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { grantXp, levelFromXp, normalizeHomunculusProgress, owned, PVE_VICTORY_XP, xpThreshold } from "../homunculus_experience";

const root = resolve(import.meta.dir, "../../..");
const read = (path: string) => JSON.parse(readFileSync(resolve(root, path), "utf8"));
const hom = read("data/static/expedition_homunculi.json").homunculi;
const enemies = read("data/static/expedition_enemies.json").enemies;
const originals = new Set<string>(read("data/homunculi.json").homunculi.map((e: any) => e.id));
const expedition = new Set<string>(hom.map((e: any) => e.id));
const mutations = new Set<string>(read("data/static/mutations.json").mutations.map((e: any) => e.id));
const file = (uri: string) => existsSync(resolve(root, uri.replace(/^res:\/\//, "")));

test("expedition catalogs reference unique known types and existing assets", () => {
  expect(hom).toHaveLength(14); expect(expedition.size).toBe(14);
  expect(enemies).toHaveLength(21); expect(new Set(enemies.map((e: any) => e.id)).size).toBe(21);
  const types = ["aether", "mercury", "gold", "vitriol", "sodium", "sulfur"];
  for (const h of hom) { expect(h.id).toMatch(/^[a-z]+$/); expect(types).toContain(h.type); expect(h.rarity).toBeGreaterThanOrEqual(1); expect(h.rarity).toBeLessThanOrEqual(10); expect(file(h.preview_texture) && file(h.combat_texture)).toBe(true); expect(originals.has(h.id)).toBe(false); }
  const codes: Record<string, string> = {A:"aether", M:"mercury", G:"gold", V:"vitriol", SO:"sodium", SU:"sulfur"};
  for (const e of enemies) { const match = e.texture.match(/\/(SO|SU|A|M|G|V)[_-](SO|SU|A|M|G|V)_/); expect(match).not.toBeNull(); expect(e.types).toEqual([codes[match![1]], codes[match![2]]]); expect(file(e.texture) && file(e.preview_texture)).toBe(true); }
});

test("cumulative XP, ownership and migration", () => {
  expect([1,2,3].map(xpThreshold)).toEqual([100,300,550]); expect(PVE_VICTORY_XP).toBe(20);
  expect(levelFromXp(99)).toBe(0); expect(levelFromXp(550)).toBe(3);
  const p = grantXp({level:0,xp:0,owned:true}, 550); expect(p).toEqual({level:3,xp:550,owned:true});
  expect(grantXp(p, xpThreshold(10)).level).toBe(10);
  expect(() => grantXp({level:0,xp:0,owned:false},20)).toThrow(); expect(() => levelFromXp(Infinity)).toThrow();
  const result = normalizeHomunculusProgress({cinder:{level:5,mutation_id:"catalyst",mutation_changed_at:123}, astralotl:{level:2,owned:true}, cedix:{level:Infinity,xp:NaN,owned:"true"}, bogus:{level:10}}, originals, expedition, mutations);
  expect(result.cinder).toEqual({level:5,xp:xpThreshold(5),owned:true,mutation_id:"catalyst",mutation_changed_at:123});
  expect(result.astralotl).toEqual({level:2,xp:300,owned:true}); expect(owned(result.cedix)).toBe(false); expect(result.cedix.xp).toBe(0); expect(result.bogus).toBeUndefined();
});
