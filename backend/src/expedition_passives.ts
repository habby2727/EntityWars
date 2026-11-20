import catalog from "../../data/static/expedition_homunculi.json";

// E3 produces proposals only. E4 must persist the exchange marker and enforce
// replacement, expiry, ordering and ownership in every authoritative engine.
export type PassiveEvent = "before_attack" | "before_exchange" | "damage_received" | "spell_miss" | "dodge" | "inspiration_activated" | "weapon_switched" | "opponent_poison_damage";
type Condition = "always" | "advantage" | "below_half_hp" | "disadvantage" | "two_consecutive_spell_hits" | "target_debuffed" | "shielded" | "opening_attack" | "positive_damage" | "third_exchange";
type EffectKind = "power_flat" | "guard_flat" | "tempo_flat" | "accuracy_pct" | "evasion_pct" | "poison" | "heal";
type Duration = "current_attack" | "current_exchange" | "next_exchange" | "instant";
type Passive = { name: {en: string; es: string}; description: {en: string; es: string}; event: PassiveEvent; condition: Condition; limit: "once_per_exchange"; stacking: "replace"; levels: number[]; effects: {kind: EffectKind; target: "self" | "target"; duration: Duration; values: number[]}[] };
export type PassiveContext = {
  exchange: number;
  fighter: { hp: number; max_hp: number; shielded: boolean; consecutive_spell_hits: number; attacks_made: number };
  target: { debuffed: boolean };
  type_relation: "advantage" | "neutral" | "disadvantage";
  poison_damage: number;
  // The trusted combat adapter supplies markers committed earlier in this exchange.
  applied_markers: readonly string[];
};
export type PassiveProposal = { marker: string; exchange: number; stacking: "replace"; limit: "once_per_exchange"; effects: { kind: EffectKind; target: "self" | "target"; duration: Duration; amount: number }[] };

const expected: Record<string, [PassiveEvent, Condition]> = {
  astralotl: ["before_attack", "advantage"], cedix: ["before_attack", "below_half_hp"], crishvin: ["damage_received", "always"], flincho: ["spell_miss", "always"], honin: ["before_exchange", "disadvantage"], hyrox: ["dodge", "always"], luny: ["before_attack", "two_consecutive_spell_hits"], mantillo: ["before_attack", "target_debuffed"], nebulynx: ["inspiration_activated", "always"], neon: ["weapon_switched", "always"], ninux: ["before_exchange", "shielded"], solcarp: ["before_attack", "opening_attack"], venam: ["opponent_poison_damage", "positive_damage"], voltibis: ["before_exchange", "third_exchange"]
};
const effectShape: Record<string, string[]> = {
  astralotl: ["power_flat:self:current_attack"], cedix: ["power_flat:self:current_attack"], crishvin: ["guard_flat:self:next_exchange", "poison:target:instant"], flincho: ["accuracy_pct:self:next_exchange", "tempo_flat:self:next_exchange"], honin: ["guard_flat:self:current_exchange", "accuracy_pct:self:current_exchange"], hyrox: ["evasion_pct:self:next_exchange", "tempo_flat:self:next_exchange"], luny: ["power_flat:self:current_attack", "tempo_flat:self:current_exchange"], mantillo: ["power_flat:self:current_attack", "evasion_pct:self:current_exchange"], nebulynx: ["power_flat:self:next_exchange", "tempo_flat:self:next_exchange"], neon: ["guard_flat:self:next_exchange", "tempo_flat:self:next_exchange"], ninux: ["power_flat:self:current_exchange", "guard_flat:self:current_exchange"], solcarp: ["power_flat:self:current_attack", "accuracy_pct:self:current_attack"], venam: ["heal:self:instant"], voltibis: ["guard_flat:self:current_exchange", "tempo_flat:self:current_exchange"]
};
const caps: Record<EffectKind, number> = {power_flat: 3, guard_flat: 3, tempo_flat: 2, accuracy_pct: .05, evasion_pct: .05, poison: 2, heal: 3};
const durations = new Set(["current_attack", "current_exchange", "next_exchange", "instant"]);
const events = new Set<PassiveEvent>(Object.values(expected).map(x => x[0]));
const isObject = (v: unknown): v is Record<string, any> => !!v && typeof v === "object" && !Array.isArray(v);
const own = (o: object, k: string) => Object.prototype.hasOwnProperty.call(o, k);
const keysAre = (o: Record<string, any>, keys: string[]) => Object.keys(o).length === keys.length && keys.every(k => own(o, k));
const safeInt = (v: unknown) => Number.isSafeInteger(v) && (v as number) >= 0;

/** Fail closed on malformed catalogs, repeated identities or unsupported effects. */
export function validatePassiveCatalog(value: unknown): Map<string, Passive> {
  if (!isObject(value) || !Array.isArray(value.homunculi) || value.homunculi.length !== Object.keys(expected).length) throw new Error("INVALID_PASSIVE_CATALOG");
  const result = new Map<string, Passive>();
  for (const entry of value.homunculi) {
    if (!isObject(entry) || typeof entry.id !== "string" || !own(expected, entry.id) || result.has(entry.id) || !isObject(entry.passive)) throw new Error("INVALID_PASSIVE_CATALOG");
    const p = entry.passive;
    if (!keysAre(p, ["name", "description", "event", "condition", "limit", "stacking", "levels", "effects"]) || !isObject(p.name) || !isObject(p.description) || ![p.name, p.description].every(x => keysAre(x, ["en", "es"]) && [x.en, x.es].every(y => typeof y === "string" && y.trim().length > 0)) || p.event !== expected[entry.id][0] || p.condition !== expected[entry.id][1] || p.limit !== "once_per_exchange" || p.stacking !== "replace" || JSON.stringify(p.levels) !== "[0,3,6,10]" || !Array.isArray(p.effects) || p.effects.length < 1 || p.effects.length > 2) throw new Error("INVALID_PASSIVE_CATALOG");
    const seen = new Set<string>();
    for (const e of p.effects) {
      if (!isObject(e) || !keysAre(e, ["kind", "target", "duration", "values"]) || typeof e.kind !== "string" || !own(caps, e.kind) || seen.has(e.kind) || !durations.has(e.duration) || !Array.isArray(e.values) || e.values.length !== 4 || e.values.some((v: unknown, i: number) => typeof v !== "number" || !Number.isFinite(v) || v <= 0 || v > caps[e.kind as EffectKind] || (i > 0 && v < e.values[i - 1]) || (!["accuracy_pct", "evasion_pct"].includes(e.kind) && !Number.isInteger(v)))) throw new Error("INVALID_PASSIVE_CATALOG");
      if ((e.kind === "poison" && (e.target !== "target" || e.duration !== "instant" || entry.id !== "crishvin")) || (e.kind === "heal" && (e.target !== "self" || e.duration !== "instant" || entry.id !== "venam")) || (!["poison", "heal"].includes(e.kind) && (e.target !== "self" || e.duration === "instant"))) throw new Error("INVALID_PASSIVE_CATALOG");
      seen.add(e.kind);
    }
    if (JSON.stringify(p.effects.map((e: any) => `${e.kind}:${e.target}:${e.duration}`)) !== JSON.stringify(effectShape[entry.id])) throw new Error("INVALID_PASSIVE_CATALOG");
    result.set(entry.id, structuredClone(p) as Passive);
  }
  return result;
}

const passives = validatePassiveCatalog(catalog);
// Linear interpolation between catalog levels; whole-number stats round down.
function scaled(values: number[], level: number, integer: boolean): number {
  const levels = [0, 3, 6, 10];
  const upper = levels.findIndex(n => n >= level);
  if (upper === 0) return values[0];
  const lower = upper - 1;
  const n = values[lower] + (values[upper] - values[lower]) * (level - levels[lower]) / (levels[upper] - levels[lower]);
  return integer ? Math.floor(n + 1e-9) : Math.round(n * 10000) / 10000;
}

/** All inputs must originate in a server-owned combat state; never pass request data. */
export function evaluateExpeditionPassive(id: string, level: number, context: PassiveContext, event: PassiveEvent): PassiveProposal | null {
  if (typeof id !== "string" || !passives.has(id) || !Number.isInteger(level) || level < 0 || level > 10 || !events.has(event) || !isObject(context) || !isObject(context.fighter) || !isObject(context.target)) throw new Error("INVALID_PASSIVE_INPUT");
  const f = context.fighter;
  if (!safeInt(context.exchange) || context.exchange < 1 || !safeInt(f.hp) || !safeInt(f.max_hp) || f.max_hp < 1 || f.hp > f.max_hp || !safeInt(f.consecutive_spell_hits) || !safeInt(f.attacks_made) || typeof f.shielded !== "boolean" || typeof context.target.debuffed !== "boolean" || !["advantage", "neutral", "disadvantage"].includes(context.type_relation) || !safeInt(context.poison_damage) || !Array.isArray(context.applied_markers) || context.applied_markers.some(x => typeof x !== "string")) throw new Error("INVALID_PASSIVE_INPUT");
  const p = passives.get(id)!;
  const marker = `expedition_passive:${id}:${context.exchange}`;
  if (f.hp === 0 || event !== p.event || context.applied_markers.includes(marker)) return null;
  const matches: Record<Condition, boolean> = {
    always: true, advantage: context.type_relation === "advantage", below_half_hp: f.hp < f.max_hp / 2,
    disadvantage: context.type_relation === "disadvantage", two_consecutive_spell_hits: f.consecutive_spell_hits >= 2,
    target_debuffed: context.target.debuffed, shielded: f.shielded, opening_attack: f.attacks_made === 0,
    positive_damage: context.poison_damage > 0 && f.hp < f.max_hp, third_exchange: context.exchange % 3 === 0
  };
  if (!matches[p.condition]) return null;
  const effects = p.effects.map(e => {
    let amount = scaled(e.values, level, !["accuracy_pct", "evasion_pct"].includes(e.kind));
    if (e.kind === "heal") amount = Math.min(amount, context.poison_damage, f.max_hp - f.hp);
    return {kind: e.kind, target: e.target, duration: e.duration, amount};
  });
  return {marker, exchange: context.exchange, stacking: "replace", limit: "once_per_exchange", effects};
}
