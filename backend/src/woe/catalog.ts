import cardData from "../../../data/static/woe_cards.json";
import arenaData from "../../../data/static/woe_arena.json";
import homunculi from "../../../data/static/expedition_homunculi.json";
import types from "../../../data/types.json";

export type Element = keyof typeof types.effectiveness;
export interface Card { id: string; element: Element; cost: number; woe_cost?: number; hp: number; damage: number; defense: number; speed: number; range: number; role: string }
export interface Potion { id:string; kind:'potion'; cost:number; radius:number; duration_ticks:number; texture:string; name_key:string }
export const ATTACK_INTERVAL_MS = 1000;
const expected: Record<string, number> = { neon: 2, luny: 3, mantillo: 3, nebulynx: 4, venam: 4, cedix: 4, flincho: 5, solcarp: 5, hyrox: 6, astralotl: 6 };
export const cards: readonly Readonly<Card>[] = Object.freeze(cardData.cards.map(raw => {
  const original = homunculi.homunculi.find(h => h.id === raw.id);
  if (!original || original.type !== raw.element || expected[raw.id] !== raw.cost || !raw.role || [raw.hp, raw.damage, raw.speed, raw.range].some(n => !Number.isSafeInteger(n) || n <= 0) || ('woe_cost' in raw && (!Number.isSafeInteger(raw.woe_cost) || raw.woe_cost <= 0)) || !Number.isSafeInteger(raw.defense) || raw.defense < 0) throw new Error("INVALID_WOE_CARD");
  return Object.freeze(raw as Card);
}));
if (cards.length !== 10 || new Set(cards.map(c => c.id)).size !== 10) throw new Error("INVALID_WOE_CATALOG");
export const cardById: Readonly<Record<string, Readonly<Card>>> = Object.freeze(Object.fromEntries(cards.map(c => [c.id, c])));
export const potions: readonly Readonly<Potion>[] = Object.freeze(cardData.potions.map(raw=>Object.freeze(raw as Potion)));
if(potions.length!==4 || new Set(potions.map(p=>p.id)).size!==4 || potions.some(p=>!['thunderlock','vitriol_potion','blood_potion','aether_potion'].includes(p.id)||p.kind!=='potion'||![p.cost,p.radius,p.duration_ticks].every(n=>Number.isSafeInteger(n)&&n>0)||!p.texture||!p.name_key))throw new Error('INVALID_WOE_POTION');
export const potionById: Readonly<Record<string,Readonly<Potion>>> = Object.freeze(Object.fromEntries(potions.map(p=>[p.id,p])));
export function cardCost(card: Readonly<Card>, kind: string): number { return kind === 'woe' ? card.woe_cost ?? card.cost : card.cost; }
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
