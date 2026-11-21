import legacyData from "../../data/homunculi.json";
import expeditionData from "../../data/static/expedition_homunculi.json";
import mutationData from "../../data/static/mutations.json";
import { validatePassiveCatalog } from "./expedition_passives";
import { levelFromXp } from "./homunculus_experience";

const LEGACY_IDS = ["cinder", "silphide", "sodium", "drakon", "pyritc", "chimera", "nighty", "mothy"] as const;
const ELEMENTS = ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"] as const;
const SYNERGY_KEYS = new Set(["power_flat", "guard_flat", "tempo_flat", "type_adv_bonus", "type_neutralize", "incoming_mult", "reflect_pct", "dot_true", "item_effect_mult"]);
const object = (v: unknown): v is Record<string, any> => !!v && typeof v === "object" && !Array.isArray(v);
const finite = (v: unknown): v is number => typeof v === "number" && Number.isFinite(v);

/** Validates both sources before constructing a server-owned, isolated catalog. */
export function buildHomunculusCombatCatalog(legacy: unknown, expedition: unknown) {
  if (!object(legacy) || !Array.isArray(legacy.homunculi) || legacy.homunculi.length !== 8 || !object(expedition)) throw new Error("INVALID_HOMUNCULUS_CATALOG");
  validatePassiveCatalog(expedition);
  const seen = new Set<string>();
  const originals = legacy.homunculi.map((h: any) => {
    if (!object(h) || !LEGACY_IDS.includes(h.id) || seen.has(h.id) || typeof h.name !== "string" || !h.name.trim() || ![h.buff_hp, h.buff_atk, h.buff_def].every((v: unknown) => Number.isSafeInteger(v) && (v as number) >= 0 && (v as number) <= 10) || !object(h.per_type) || Object.keys(h.per_type).length !== ELEMENTS.length || !ELEMENTS.every(type => object(h.per_type[type]) && Object.entries(h.per_type[type]).every(([key, value]) => SYNERGY_KEYS.has(key) && finite(value) && value >= 0 && value <= 10))) throw new Error("INVALID_HOMUNCULUS_CATALOG");
    seen.add(h.id); return structuredClone(h);
  });
  const additions = expedition.homunculi.map((h: any) => {
    if (!object(h) || typeof h.id !== "string" || seen.has(h.id) || typeof h.name !== "string" || !h.name.trim() || !ELEMENTS.includes(h.type) || !Number.isInteger(h.rarity) || h.rarity < 1 || h.rarity > 10) throw new Error("INVALID_HOMUNCULUS_CATALOG");
    seen.add(h.id);
    // Uniform and deliberately below many legacy base/synergy combinations.
    return { id: h.id, name: h.name, rarity: h.rarity, type: h.type, passive: structuredClone(h.passive), buff_hp: 1, buff_atk: 1, buff_def: 1, per_type: Object.fromEntries(ELEMENTS.map(type => [type, {}])) };
  });
  return { originals, expedition: additions, all: [...structuredClone(originals), ...structuredClone(additions)] };
}

const catalog = buildHomunculusCombatCatalog(legacyData, expeditionData);
const mutationIds = new Set(mutationData.mutations.map(entry => entry.id));
const originals = new Set<string>(catalog.originals.map((h: any) => h.id));
const expedition = new Set<string>(catalog.expedition.map((h: any) => h.id));
export function homunculusCatalog() { return structuredClone(catalog); }
export function legacyHomunculusIds(): Set<string> { return new Set(originals); }
export function expeditionHomunculusIds(): Set<string> { return new Set(expedition); }

/** Progress must come from authenticated persisted state, never from a request. */
export function ownsHomunculus(progress: unknown, id: unknown): boolean {
  if (typeof id !== "string" || (!originals.has(id) && !expedition.has(id))) return false;
  if (progress !== undefined && !object(progress)) return false;
  const entry = object(progress) && Object.hasOwn(progress, id) ? progress[id] : undefined;
  if (entry === undefined) return originals.has(id);
  if (!object(entry) || (entry.owned !== undefined && typeof entry.owned !== "boolean") || (entry.level !== undefined && (!Number.isInteger(entry.level) || entry.level < 0 || entry.level > 10)) || (entry.xp !== undefined && (!Number.isSafeInteger(entry.xp) || entry.xp < 0)) || (entry.mutation_id !== undefined && (typeof entry.mutation_id !== "string" || !mutationIds.has(entry.mutation_id))) || (entry.mutation_changed_at !== undefined && (!Number.isSafeInteger(entry.mutation_changed_at) || entry.mutation_changed_at < 0))) return false;
  if (expedition.has(id) && (entry.owned !== true || !Number.isInteger(entry.level) || !Number.isSafeInteger(entry.xp) || (entry.mutation_id !== undefined && entry.level < 3) || levelFromXp(entry.xp) !== entry.level)) return false;
  return true;
}

/** Combat selection is derived solely from trusted persisted ownership. */
export function combatHomunculusAllowed(progress: unknown, id: unknown): boolean {
  return ownsHomunculus(progress, id);
}

/** Returns only the elemental factor; callers must apply it once, at attack time. */
export function homunculusAttackMultiplier(hom: any, defenderType: string, types: any, neutralizations: readonly number[] = []): number {
  if (!object(hom) || typeof hom.id !== "string" || !ELEMENTS.includes(defenderType as any) || !Array.isArray(neutralizations) || neutralizations.some(n => !finite(n) || n < 0 || n > 1)) throw new Error("INVALID_HOMUNCULUS_ATTACK");
  if (originals.has(hom.id)) return 1;
  const trusted = catalog.expedition.find((entry: any) => entry.id === hom.id);
  if (!trusted || hom.type !== trusted.type || !object(types) || !object(types.effectiveness) || !object(types.effectiveness[trusted.type])) throw new Error("INVALID_HOMUNCULUS_ATTACK");
  const relation = types.effectiveness[trusted.type][defenderType];
  if (!finite(relation) || ![0.5, 1, 2].includes(relation)) throw new Error("INVALID_HOMUNCULUS_ATTACK");
  const base = relation > 1 ? 1.18 : relation < 1 ? 0.84 : 1;
  return 1 + (base - 1) * (1 - Math.max(0, ...neutralizations));
}

/** Resolve the elemental factor from server-owned catalog data. */
export function homunculusAttackMultiplierById(id: string, defenderType: string, types: any, neutralizations: readonly number[] = []): number {
  if (originals.has(id)) return 1;
  const hom = catalog.expedition.find((entry: any) => entry.id === id);
  if (!hom) throw new Error("INVALID_HOMUNCULUS_ATTACK");
  return homunculusAttackMultiplier(hom, defenderType, types, neutralizations);
}
