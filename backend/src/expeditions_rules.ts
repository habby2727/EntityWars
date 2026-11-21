import { createHmac } from "node:crypto";
import enemyData from "../../data/static/expedition_enemies.json";
import homunculusData from "../../data/static/expedition_homunculi.json";
import typeData from "../../data/types.json";

/** Expedition-only rules. All random draws are keyed and domain-separated. */
export const EXPEDITION_MANA_CAP = 6;
export const EXPEDITION_CRYSTAL_CAP = 5;
export const EXPEDITION_MANA_INTERVAL_MS = 2 * 60 * 60 * 1000;
export const EXPEDITION_EXIT_COOLDOWN_MS = 60 * 1000;

const elements = new Set(typeData.types.map(entry => entry.id));
export const expeditionEnemies = (() => {
  const seen = new Set<string>();
  if (enemyData.enemies.length !== 21) throw new Error("INVALID_EXPEDITION_ENEMIES");
  return enemyData.enemies.map(enemy => {
    if (!/^[a-z][a-z0-9_]*$/.test(enemy.id) || seen.has(enemy.id) || !enemy.name || enemy.types.length !== 2 || enemy.types[0] === enemy.types[1] || enemy.types.some(type => !elements.has(type)) || !enemy.texture.startsWith("res://assets/entities/expeditions/gameplay/") || !enemy.preview_texture.startsWith("res://assets/entities/expeditions/preview/")) throw new Error("INVALID_EXPEDITION_ENEMIES");
    seen.add(enemy.id);
    return Object.freeze({ ...enemy, types: Object.freeze([...enemy.types]) });
  });
})();
export const expeditionCaptures = (() => {
  const seen = new Set<string>();
  if (homunculusData.homunculi.length !== 14) throw new Error("INVALID_EXPEDITION_CAPTURES");
  return homunculusData.homunculi.map(hom => {
    if (!/^[a-z][a-z0-9_]*$/.test(hom.id) || seen.has(hom.id) || !elements.has(hom.type) || !Number.isInteger(hom.rarity) || hom.rarity < 1 || hom.rarity > 10) throw new Error("INVALID_EXPEDITION_CAPTURES");
    seen.add(hom.id);
    return Object.freeze({ id: hom.id, name: hom.name, type: hom.type, rarity: hom.rarity, preview_texture: hom.preview_texture, combat_texture: hom.combat_texture });
  });
})();

export type ExpeditionMana = { mana: number; regen_at: number };
/** regen_at is the next tick; zero while the pool is full. */
export function regenerateExpeditionMana(pool: ExpeditionMana, now: number): ExpeditionMana {
  if (!pool || typeof pool.mana !== "number" || !Number.isSafeInteger(pool.mana * 10) || pool.mana < 0 || pool.mana > EXPEDITION_MANA_CAP || !Number.isSafeInteger(pool.regen_at) || pool.regen_at < 0 || !Number.isSafeInteger(now) || now < 0 || (pool.mana < EXPEDITION_MANA_CAP && pool.regen_at === 0)) throw new Error("INVALID_EXPEDITION_MANA");
  if (pool.mana === EXPEDITION_MANA_CAP) return { mana: pool.mana, regen_at: 0 };
  if (now < pool.regen_at) return { ...pool };
  const ticks = Math.floor((now - pool.regen_at) / EXPEDITION_MANA_INTERVAL_MS) + 1;
  const mana = Math.min(EXPEDITION_MANA_CAP * 10, Math.round(pool.mana * 10) + ticks * 10) / 10;
  return { mana, regen_at: mana === EXPEDITION_MANA_CAP ? 0 : pool.regen_at + ticks * EXPEDITION_MANA_INTERVAL_MS };
}
export function changeExpeditionMana(pool: ExpeditionMana, delta: number, now: number): ExpeditionMana {
  if (typeof delta !== "number" || !Number.isSafeInteger(delta * 10) || !(delta === 1 || (delta < 0 && delta >= -1))) throw new Error("INVALID_EXPEDITION_MANA_CHANGE");
  const current = regenerateExpeditionMana(pool, now);
  const tenths = Math.round(current.mana * 10) + Math.round(delta * 10);
  if (tenths < 0) throw new Error("EXPEDITION_MANA_EMPTY");
  const mana = Math.min(EXPEDITION_MANA_CAP * 10, tenths) / 10;
  return { mana, regen_at: mana === EXPEDITION_MANA_CAP ? 0 : current.mana === EXPEDITION_MANA_CAP ? now + EXPEDITION_MANA_INTERVAL_MS : current.regen_at };
}

/** Rarity 1 = 65%, rarity 10 = 20%, linear and bounded. */
export function expeditionCaptureChance(rarity: number): number {
  if (!Number.isInteger(rarity) || rarity < 1 || rarity > 10) throw new Error("INVALID_EXPEDITION_RARITY");
  return (70 - 5 * rarity) / 100;
}

/** Geometric mean of both defender relations, bounded to the resolver's elemental range. */
export function expeditionDualTypeMultiplier(attackType: string, defenders: readonly string[]): number {
  if (!elements.has(attackType) || defenders.length !== 2 || defenders[0] === defenders[1] || defenders.some(type => !elements.has(type))) throw new Error("INVALID_EXPEDITION_TYPES");
  const table: Record<string, Record<string, number>> = typeData.effectiveness;
  const factors = defenders.map(type => {
    const relation = table[attackType]?.[type];
    if (![0.5, 1, 2].includes(relation)) throw new Error("INVALID_EXPEDITION_TYPE_TABLE");
    return relation > 1 ? 1.18 : relation < 1 ? 0.84 : 1;
  });
  return Math.max(0.84, Math.min(1.18, Math.sqrt(factors[0] * factors[1])));
}

export function expeditionDraw(seed: Uint8Array, domain: string, index: number): number {
  if (!(seed instanceof Uint8Array) || seed.length < 32 || typeof domain !== "string" || !domain || !Number.isSafeInteger(index) || index < 0) throw new Error("INVALID_EXPEDITION_RNG");
  return createHmac("sha256", seed).update(JSON.stringify(["expedition-v1", domain, index])).digest().readUInt32BE(0) / 0x100000000;
}
