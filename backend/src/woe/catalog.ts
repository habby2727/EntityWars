import cardData from "../../../data/static/woe_cards.json";
import arenaData from "../../../data/static/woe_arena.json";
import homunculi from "../../../data/static/expedition_homunculi.json";
import types from "../../../data/types.json";

export type Element = keyof typeof types.effectiveness;
export interface Card { id: string; element: Element; cost: number; hp: number; damage: number; defense: number; speed: number; range: number; role: string }
export const ATTACK_INTERVAL_MS = 1000;
const expected: Record<string, number> = { neon: 2, luny: 3, mantillo: 3, nebulynx: 4, venam: 4, cedix: 4, flincho: 5, solcarp: 5, hyrox: 6, astralotl: 6 };
export const cards: readonly Readonly<Card>[] = Object.freeze(cardData.cards.map(raw => {
  const original = homunculi.homunculi.find(h => h.id === raw.id);
  if (!original || original.type !== raw.element || expected[raw.id] !== raw.cost || !raw.role || [raw.hp, raw.damage, raw.speed, raw.range].some(n => !Number.isSafeInteger(n) || n <= 0) || !Number.isSafeInteger(raw.defense) || raw.defense < 0) throw new Error("INVALID_WOE_CARD");
  return Object.freeze(raw as Card);
}));
if (cards.length !== 10 || new Set(cards.map(c => c.id)).size !== 10) throw new Error("INVALID_WOE_CATALOG");
export const cardById: Readonly<Record<string, Readonly<Card>>> = Object.freeze(Object.fromEntries(cards.map(c => [c.id, c])));
export const arena = arenaData;
export function elementalMultiplier(attacker: Element, defender: Element): number {
  const relation = (types.effectiveness as Record<string, Record<string, number>>)[attacker]?.[defender];
  if (![0.5, 1, 2].includes(relation)) throw new Error("INVALID_WOE_ELEMENT");
  return relation === 2 ? 1.18 : relation === 0.5 ? 0.84 : 1;
}
export function attackDamage(damage: number, defense: number, multiplier = 1): number {
  if (![damage, defense, multiplier].every(Number.isFinite) || damage < 0 || defense < 0 || ![0.84, 1, 1.18].includes(multiplier)) throw new Error("INVALID_WOE_DAMAGE");
  return Math.max(0, Math.min(10000, Math.round(Math.max(0, damage - defense) * multiplier)));
}
