import { describe, expect, test } from "bun:test";
import { readdirSync } from "node:fs";
import { resolve } from "node:path";
import { EXPEDITION_BACKGROUNDS, expeditionBackgroundAt } from "../expeditions_backgrounds";
import { changeExpeditionMana, expeditionCaptureChance, expeditionDualTypeMultiplier, expeditionEnemies, expeditionCaptures, regenerateExpeditionMana, EXPEDITION_MANA_INTERVAL_MS } from "../expeditions_rules";

describe("expedition isolated rules", () => {
  test("manifest covers the actual assets and rotations contain each background", () => {
    const actual = readdirSync(resolve(import.meta.dir, "../../../assets/entities/expeditions/backgrounds")).filter(name => name.endsWith(".ogv")).sort();
    expect([...EXPEDITION_BACKGROUNDS].sort()).toEqual(actual);
    const seed = new Uint8Array(32).fill(7);
    for (let cycle = 0; cycle < 3; cycle++) {
      const backgrounds = Array.from({ length: 26 }, (_, i) => expeditionBackgroundAt(seed, "run", cycle * 26 + i));
      expect(new Set(backgrounds).size).toBe(26);
      expect(backgrounds).toEqual(Array.from({ length: 26 }, (_, i) => expeditionBackgroundAt(seed, "run", cycle * 26 + i)));
    }
    expect(expeditionEnemies.length).toBe(21);
    expect(expeditionCaptures.length).toBe(14);
  });
  test("mana is bounded, ticks lazily, and restarts its clock after spending from full", () => {
    const interval = EXPEDITION_MANA_INTERVAL_MS;
    expect(changeExpeditionMana({ mana: 6, regen_at: 0 }, -1, 100)).toEqual({ mana: 5, regen_at: 100 + interval });
    expect(regenerateExpeditionMana({ mana: 2, regen_at: 100 }, 100 + 2 * interval)).toEqual({ mana: 5, regen_at: 100 + 3 * interval });
    expect(regenerateExpeditionMana({ mana: 2, regen_at: 100 }, 100 + 5 * interval)).toEqual({ mana: 6, regen_at: 0 });
    expect(() => changeExpeditionMana({ mana: 0, regen_at: 100 }, -1, 99)).toThrow();
    expect(changeExpeditionMana({ mana: 5, regen_at: 100 }, 1, 99)).toEqual({ mana: 6, regen_at: 0 });
  });
  test("capture and dual-type rules are bounded and reject invalid inputs", () => {
    expect(expeditionCaptureChance(1)).toBe(0.65);
    expect(expeditionCaptureChance(10)).toBe(0.2);
    expect(() => expeditionCaptureChance(11)).toThrow();
    expect(expeditionDualTypeMultiplier("sulfur", ["vitriol", "aether"])).toBeCloseTo(Math.sqrt(1.18 * 0.84));
    expect(() => expeditionDualTypeMultiplier("sulfur", ["aether", "aether"])).toThrow();
  });
});
