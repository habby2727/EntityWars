import { effectiveTimedDefense, applyTimedDefense, expireTimedDefenses, drainHealth, applyTimedAwarePassive } from "../solo_hunt_combat";
import { newExpeditionPassiveState, beginPassiveExchange, applyCombatPassive, passiveModifiers, finishPassiveAttack, finishPassiveExchange, recordPassiveSpellHit } from "../expedition_passive_state";
import { recordPoisonChange, poisonTickMetadata, recordInspirationActivation } from "../combat_event_provenance";
import { combatHomunculusAllowed, homunculusAttackMultiplierById } from "../homunculus_catalog";
import { castPhysicalAnomaly, physicalAnomalyMultiplier, tickPhysicalAnomaly, validPhysicalAnomalySpell } from "../physical_anomaly";
import { STRATEGIC_EFFECTS, finishStrategicExchange, jamStrategicCooldown, queueDelayedDamage, strategicCounter, strategicHeal, transferStrategicStatus, validStrategicStatusEffect } from "../strategic_effects";

/**
 * PvP groundwork only. Inputs and subsequent states must come from trusted server
 * storage; this module does not authenticate ownership or persist decisions.
 * Combat state is authoritative and must never be accepted from a client.
 */
export type PvpSide = "left" | "right";
export type PvpError = { error: "UNTRUSTED_SETUP" | "INVALID_DECISION" | "INVALID_RNG" | "PVP_COMBAT_PARITY_UNAVAILABLE" };
export type PvpSnapshot = {
  player_id: string; entity_id: string; weapon_ids: (string | null)[];
  homunculus_id: string | null; spell_ids: string[];
  item_progress?: unknown; homunculus_progress?: unknown; spell_progress?: unknown;
};
export type PvpCatalogs = { entities: any[]; items: any[]; spells: any[]; homunculi: any[]; types: unknown; mutations?: any[]; balance?: any };
export type PvpDecision = { turn: number; spell_id?: string; switch_slot?: 1 | 2; hom_action?: "hold" | "attack" | "sacrifice"; ultra?: boolean };
export type PvpFighter = {
  player_id: string; entity: any; weapons: (any | null)[]; homunculus: any | null; spells: any[];
  item_progress: unknown; homunculus_progress: unknown; spell_progress: unknown;
  active_weapon_slot: 1 | 2; spell_cooldowns: Record<string, number>;
  hom_energy: number; hom_spent: boolean; ultra_used: boolean;
  id: string; name: string; type: string; hp: number; max_hp: number; atk: number; def: number;
  hom_id: string; hom_name: string; hom_max_energy: number; hom_ready_at: number;
  hom_synergy: Record<string, number>; hom_bonus: Record<string, number>; mutation: any | null;
  mods: { atk_flat: number; def_flat: number }; item_fx: Record<string, number>; active_weapon: any | null;
  status: Record<string, any>; spell_ids: string[]; original_spell_ids: string[];
  inspiration: number; inspiration_pending: boolean; inspiration_used_this_battle: boolean; inspiration_offers: string[]; inspiration_catalog: any[];
  temporary_spell_id: string; temporary_replaced_slot: number;
  spell_hit_this_exchange: boolean; spell_hit_last_exchange: boolean;
  spell_neutralize_pending: number; spell_neutralize_active: number;
};
export type PvpCombatState = { turn: number; round: number; player_turn: boolean; battle_index: number; wins: Record<PvpSide, number>; sudden_death: boolean; fighters: Record<PvpSide, PvpFighter>; types: unknown; physical_anomaly: any | null; strategic_delayed: any[]; strategic_jams: any[]; rng_counter: number; match_result?: PvpSide | "draw"; battle_result?: PvpSide | "draw"; battle_over?: boolean };

const object = (x: any): x is Record<string, any> => x !== null && typeof x === "object" && !Array.isArray(x);
const number = (x: any) => typeof x === "number" && Number.isFinite(x);
const itemKeys = new Set(["power_flat", "guard_flat", "tempo_flat", "true_on_hit", "dot_true", "vuln_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"]);
const pctKeys = new Set(["ward_pct", "reflect_pct", "evasion_pct", "disadvantage_reduction", "ignore_reflect_chance", "vuln_on_hit"]);
const synergyKeys = new Set(["power_flat", "guard_flat", "tempo_flat", "type_adv_bonus", "type_neutralize", "incoming_mult", "reflect_pct", "dot_true", "item_effect_mult"]);
const supportedEffects = new Set(["heal", "shield", "reflect", "atk_boost", "atk_down", "vuln", "poison", "hom_stun", "type_neutralize", "focus_next", "misalign_next", "tempo_shift", "cleanse_one", "poison_on_reflect", "bonus_if_poisoned", "bonus_if_hit_last_exchange", "bonus_if_low_hp", "bonus_if_marked", "bonus_power_if_poisoned", "bonus_if_shielded", "bonus_power_if_hit_last_exchange", "pierce_ward", "ward_dispel", "recoil", "life_leech", "consume_poison", "hybrid_mark", "shield_by_order", "ward_convert", "physical_anomaly", ...STRATEGIC_EFFECTS]);
const statusInitial = () => ({ poison: 0, stun: 0, shield_pct: 0, atk_boost: 0, vuln_pct: 0, atk_down: 0, hom_stun: 0, reflect_pct: 0, tempo_bonus: 0 });
const validLevel = (v: any) => v === undefined || (Number.isInteger(v) && v >= 0 && v <= 10);
const validCatalog = (entries: unknown): entries is any[] => Array.isArray(entries) && entries.every(e => object(e) && typeof e.id === "string" && e.id.length > 0) && new Set(entries.map(e => e.id)).size === entries.length;
const displayName = (name: string) => name.trim().replaceAll("(TEMP)", "").replaceAll("(Temp)", "").replaceAll("TEMP", "").replaceAll("temp", "").trim();

function effectiveWeapon(item: any, progress: any, catalogs: PvpCatalogs): any {
  if (!item) return null;
  if (!object(item.effects) || (item.base_effects !== undefined && !object(item.base_effects))) throw new Error("INVALID_ITEM");
  const entry = progress[item.id] ?? {};
  if (!object(entry) || !validLevel(entry.level)) throw new Error("INVALID_PROGRESS");
  const level = entry.level ?? 0, effects: Record<string, number[]> = {};
  for (const [key, values] of Object.entries(item.effects)) {
    if (!itemKeys.has(key) || !Array.isArray(values) || values.length === 0 || !values.every(number)) throw new Error("INVALID_ITEM");
    const base = item.base_effects?.[key];
    if (base !== undefined && !number(base)) throw new Error("INVALID_ITEM");
    effects[key] = [level === 0 && values.length === 10 && base !== undefined ? base : values[Math.min(Math.max(level - 1, 0), values.length - 1)]];
  }
  const add = (key: string, amount: number) => {
    if (!itemKeys.has(key) || !number(amount)) throw new Error("INVALID_PROGRESS");
    const value = (effects[key]?.[0] ?? 0) + amount;
    effects[key] = [pctKeys.has(key) ? Math.max(0, Math.min(1, value)) : value];
  };
  if (entry.specialization !== undefined || entry.traits !== undefined) {
    const pool = catalogs.balance?.forge_trait_pool?.[entry.specialization], traits = entry.traits;
    if (!object(pool) || !Array.isArray(traits) || traits.length !== 3) throw new Error("INVALID_PROGRESS");
    let allocated = 0; const seen = new Set<string>();
    for (const trait of traits) {
      if (!object(trait) || typeof trait.id !== "string" || seen.has(trait.id) || !Number.isInteger(trait.points) || trait.points < 0 || trait.points > 4 || (allocated += trait.points) > level || !number(pool[trait.id]) || pool[trait.id] <= 0 || !itemKeys.has(trait.id)) throw new Error("INVALID_PROGRESS");
      seen.add(trait.id); if (trait.points) add(trait.id, pool[trait.id] * trait.points);
    }
  }
  if (entry.fusion !== undefined && entry.fusion !== null) {
    const donor = entry.fusion?.donor_id, imprint = catalogs.balance?.forge_fusion_imprints?.[donor];
    if (!object(entry.fusion) || Object.keys(entry.fusion).some(k => k !== "donor_id") || typeof donor !== "string" || donor === item.id || !catalogs.items.some(i => i?.id === donor) || level < 3 || !object(progress[donor]) || !validLevel(progress[donor].level) || (progress[donor].level ?? 0) < 3 || !object(imprint) || Object.keys(imprint).length !== 1) throw new Error("INVALID_PROGRESS");
    for (const [key, value] of Object.entries(imprint)) { if (!["true_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "dot_true", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"].includes(key) || !number(value) || (value as number) <= 0) throw new Error("INVALID_PROGRESS"); add(key, value as number); }
  }
  return { ...structuredClone(item), forge_level: level, effects };
}

function fighter(snapshot: PvpSnapshot, catalogs: PvpCatalogs): PvpFighter | null {
  if (!snapshot || typeof snapshot.player_id !== "string" || !snapshot.player_id || typeof snapshot.entity_id !== "string" || !Array.isArray(snapshot.weapon_ids) || snapshot.weapon_ids.length !== 2 || !Array.isArray(snapshot.spell_ids) || snapshot.spell_ids.length !== 4 || new Set(snapshot.spell_ids).size !== 4 || !snapshot.spell_ids.every(id => typeof id === "string" && id.length > 0) || !(snapshot.homunculus_id === null || typeof snapshot.homunculus_id === "string")) return null;
  if (![snapshot.item_progress ?? {}, snapshot.homunculus_progress ?? {}, snapshot.spell_progress ?? {}].every(object) || snapshot.weapon_ids.some(id => id !== null && (typeof id !== "string" || !id))) return null;
  if (snapshot.homunculus_id !== null && !combatHomunculusAllowed(snapshot.homunculus_progress, snapshot.homunculus_id)) return null;
  const entity = catalogs.entities.find(e => e?.id === snapshot.entity_id);
  if (!entity || typeof entity.name !== "string" || typeof entity.type !== "string" || !object(entity.base_stats) || ![entity.base_stats.hp, entity.base_stats.power, entity.base_stats.guard].every(number) || entity.base_stats.hp <= 0 || entity.base_stats.power < 0 || entity.base_stats.guard < 0) return null;
  const weapons = snapshot.weapon_ids.map(id => id === null ? null : catalogs.items.find(i => i?.id === id && i.slot === "build"));
  if (weapons.some(w => w === undefined) || (snapshot.weapon_ids[0] !== null && snapshot.weapon_ids[0] === snapshot.weapon_ids[1])) return null;
  const hom = snapshot.homunculus_id === null ? null : catalogs.homunculi.find(h => h?.id === snapshot.homunculus_id);
  if (hom === undefined) return null;
  const spells = snapshot.spell_ids.map(id => catalogs.spells.find(s => s?.id === id && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(entity.type)))));
  if (spells.some(s => !s || !["attack", "support"].includes(s.category) || !number(s.power_mult) || s.power_mult < 0 || !number(s.accuracy) || s.accuracy < 0 || s.accuracy > 1 || !Number.isSafeInteger(s.cooldown_turns) || s.cooldown_turns < 0 || !Array.isArray(s.effects) || s.effects.some((e: any) => !object(e) || typeof e.kind !== "string" || !number(e.value) || !["self", "enemy"].includes(e.target)))) return null;
  const itemProgress = snapshot.item_progress ?? {}, homProgress: any = snapshot.homunculus_progress ?? {};
  if (Object.values(itemProgress).some((e: any) => !object(e) || !validLevel(e.level)) || Object.values(homProgress).some((e: any) => !object(e) || !validLevel(e.level))) return null;
  const entry = hom ? homProgress[hom.id] ?? {} : {};
  if (!object(entry) || !validLevel(entry.level) || (entry.mutation_id !== undefined && (typeof entry.mutation_id !== "string" || !entry.mutation_id || (entry.level ?? 0) < 3))) return null;
  const mutation = entry.mutation_id ? catalogs.mutations?.find(m => m?.id === entry.mutation_id) : null;
  if (entry.mutation_id && (!mutation || !object(mutation.effects) || Object.entries(mutation.effects).some(([key, v]) => !["hp_flat", "power_flat", "guard_flat", "favorable_type_bonus"].includes(key) || !number(v)))) return null;
  if (hom && (typeof hom.name !== "string" || ![hom.buff_hp, hom.buff_atk, hom.buff_def].every(number) || !object(hom.per_type))) return null;
  const synergy = hom?.per_type?.[entity.type] ?? {};
  if (!object(synergy) || Object.entries(synergy).some(([key, v]) => !synergyKeys.has(key) || !number(v))) return null;
  const level = entry.level ?? 0, me = mutation?.effects ?? {};
  const hom_bonus = hom ? { hp_flat: hom.buff_hp + level + (me.hp_flat ?? 0), power_flat: hom.buff_atk + Math.trunc(level / 5) + (me.power_flat ?? 0), guard_flat: hom.buff_def + Math.trunc(level / 3) + (me.guard_flat ?? 0), favorable_type_bonus: me.favorable_type_bonus ?? 0 } : { hp_flat: 0, power_flat: 0, guard_flat: 0, favorable_type_bonus: 0 };
  const base: PvpFighter = structuredClone({ player_id: snapshot.player_id, entity, weapons: weapons.map(w => effectiveWeapon(w, itemProgress, catalogs)), homunculus: hom, spells, item_progress: itemProgress, homunculus_progress: homProgress, spell_progress: snapshot.spell_progress ?? {}, active_weapon_slot: 1, spell_cooldowns: {}, hom_energy: 0, hom_spent: hom === null, ultra_used: false, id: entity.id, name: entity.name, type: entity.type, hp: 0, max_hp: 0, atk: 0, def: 0, hom_id: hom?.id ?? "", hom_name: hom?.name ?? "", hom_max_energy: 6, hom_ready_at: 3, hom_synergy: synergy, hom_bonus, mutation, mods: { atk_flat: 0, def_flat: 0 }, item_fx: {}, active_weapon: null, status: statusInitial(), spell_ids: [...snapshot.spell_ids], original_spell_ids: [...snapshot.spell_ids], inspiration: 0, inspiration_pending: false, inspiration_used_this_battle: false, inspiration_offers: [], inspiration_catalog: catalogs.spells.filter(s => !snapshot.spell_ids.includes(s.id) && ["attack", "support"].includes(s.category) && number(s.power_mult) && (s.category === "attack" ? s.power_mult > 0 : s.power_mult === 0) && number(s.accuracy) && s.accuracy >= 0 && s.accuracy <= 1 && Number.isSafeInteger(s.cooldown_turns) && s.cooldown_turns >= 0 && Array.isArray(s.effects) && s.effects.every((e: any) => object(e) && supportedEffects.has(e.kind) && number(e.value) && (e.value >= 0 || e.kind === "tempo_shift") && ["self", "enemy"].includes(e.target) && (e.kind !== "physical_anomaly" || validPhysicalAnomalySpell(s)) && (!STRATEGIC_EFFECTS.includes(e.kind) || validStrategicStatusEffect(e))) && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(entity.type)))).sort((a, b) => a.id.localeCompare(b.id)), temporary_spell_id: "", temporary_replaced_slot: -1, spell_hit_this_exchange: false, spell_hit_last_exchange: false, spell_neutralize_pending: 0, spell_neutralize_active: 0 });
  if (hom?.passive) (base as any).expedition_passive = newExpeditionPassiveState(hom.id, level);
  base.name = displayName(base.name); base.hom_name = displayName(base.hom_name);
  const result = refreshPvpWeapon(base); result.hp = result.max_hp; return result;
}

/** Snapshots and catalogs must already be validated and owned by the server. */
export function createPvpCombatState(left: PvpSnapshot, right: PvpSnapshot, catalogs: PvpCatalogs): PvpCombatState | PvpError {
  if (!catalogs || ![catalogs.entities, catalogs.items, catalogs.spells, catalogs.homunculi].every(validCatalog) || (catalogs.mutations !== undefined && !validCatalog(catalogs.mutations)) || !object(catalogs.types) || !object(catalogs.types.effectiveness) || !left || !right || left.player_id === right.player_id) return { error: "UNTRUSTED_SETUP" };
  try {
    const l = fighter(left, catalogs), r = fighter(right, catalogs);
    if (!l || !r || !object(catalogs.types.effectiveness[l.type]) || !object(catalogs.types.effectiveness[r.type]) || !number(catalogs.types.effectiveness[l.type][r.type]) || !number(catalogs.types.effectiveness[r.type][l.type])) return { error: "UNTRUSTED_SETUP" };
    return { turn: 0, round: 1, player_turn: true, battle_index: 1, wins: { left: 0, right: 0 }, sudden_death: false, fighters: { left: l, right: r }, types: structuredClone(catalogs.types), physical_anomaly: null, strategic_delayed: [], strategic_jams: [], rng_counter: 0 };
  } catch { return { error: "UNTRUSTED_SETUP" }; }
}

/** Construct one fighter from server-owned input; this does not authenticate ownership. */
export function createPvpFighter(snapshot: PvpSnapshot, catalogs: PvpCatalogs): PvpFighter | PvpError {
  if (!catalogs || ![catalogs.entities, catalogs.items, catalogs.spells, catalogs.homunculi].every(validCatalog) || (catalogs.mutations !== undefined && !validCatalog(catalogs.mutations))) return { error: "UNTRUSTED_SETUP" };
  try { return fighter(snapshot, catalogs) ?? { error: "UNTRUSTED_SETUP" }; } catch { return { error: "UNTRUSTED_SETUP" }; }
}

/** Recalculate from base stats and the selected effective weapon; never stack modifiers. */
export function refreshPvpWeapon(fighter: PvpFighter, slot: 1 | 2 = fighter.active_weapon_slot): PvpFighter {
  if (![1, 2].includes(slot) || (slot !== fighter.active_weapon_slot && !fighter.weapons[slot - 1])) throw new Error("INVALID_WEAPON_SLOT");
  const f: PvpFighter & Record<string, any> = structuredClone(fighter);
  if (slot !== f.active_weapon_slot) {
    for (const field of ["shield_pct", "reflect_pct"]) if (Object.hasOwn(f, `weapon_${field}`)) {
      f.status[field] = f[`other_${field}`] ?? 0; delete f[`weapon_${field}`]; delete f[`other_${field}`];
    }
  }
  f.active_weapon_slot = slot;
  const synergy = f.hom_spent ? {} : f.hom_synergy;
  const weapon = f.weapons[slot - 1];
  f.active_weapon = weapon ? structuredClone(weapon) : null;
  const scale = Math.max(0, Math.min(2, synergy.item_effect_mult ?? 1));
  if (f.active_weapon) for (const values of Object.values(f.active_weapon.effects) as number[][]) values[0] *= scale;
  const effect = (key: string) => f.active_weapon?.effects?.[key]?.[0] ?? 0;
  f.mods = { atk_flat: Math.trunc(effect("power_flat")), def_flat: Math.trunc(effect("guard_flat")) };
  const stats = f.entity.base_stats, bonus = f.hom_spent ? {} : f.hom_bonus;
  f.atk = Math.trunc(stats.power) + Math.trunc(bonus.power_flat ?? 0) + Math.trunc(synergy.power_flat ?? 0) + f.mods.atk_flat;
  f.def = Math.trunc(stats.guard) + Math.trunc(bonus.guard_flat ?? 0) + Math.trunc(synergy.guard_flat ?? 0) + f.mods.def_flat;
  f.max_hp = Math.trunc(stats.hp) + Math.trunc(bonus.hp_flat ?? 0);
  f.hp = Math.min(f.hp, f.max_hp);
  f.item_fx = {};
  for (const key of ["true_on_hit", "dot_true", "vuln_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"]) f.item_fx[key] = ["true_on_hit", "dot_true"].includes(key) ? effect(key) : Math.max(0, effect(key));
  return f;
}

/** Equivalent to _reset_fighter; sacrifice, weapon slot and ultra use persist. */
export function resetPvpFighter(fighter: PvpFighter): PvpFighter {
  const f: PvpFighter & Record<string, any> = structuredClone(fighter);
  if (f.temporary_spell_id) { f.spell_ids = [...f.original_spell_ids]; f.spells = f.spells.filter(s => s.id !== f.temporary_spell_id || f.original_spell_ids.includes(s.id)); delete f.spell_cooldowns[f.temporary_spell_id]; }
  f.original_spell_ids = [...f.spell_ids];
  f.temporary_spell_id = ""; f.temporary_replaced_slot = -1;
  if (f.expedition_passive && !f.hom_spent) f.expedition_passive = newExpeditionPassiveState(f.expedition_passive.id, f.expedition_passive.level);
  f.inspiration = 0; f.inspiration_pending = false; f.inspiration_used_this_battle = false; f.inspiration_offers = [];
  for (const key of ["timed_defenses", "strategic_trap", "strategic_heal_suppression", "spell_ward", "spell_ward_baseline", "hom_reflect_active", "hom_other_reflect", "weapon_shield_pct", "other_shield_pct", "weapon_reflect_pct", "other_reflect_pct", "poison_source", "poison_reflect_source", "inspiration_activation"]) delete f[key];
  f.hom_energy = 0; f.hp = f.max_hp; f.spell_cooldowns = {}; f.status = statusInitial();
  f.spell_hit_this_exchange = false; f.spell_hit_last_exchange = false;
  f.spell_neutralize_pending = 0; f.spell_neutralize_active = 0;
  return f;
}

/** Start the next battle after the caller has recorded its score and battle index. */
export function startPvpBattle(state: PvpCombatState): PvpCombatState {
  const next: PvpCombatState & Record<string, any> = structuredClone(state);
  next.turn = 0; next.rng_counter = 0; next.round = 1; next.player_turn = true; next.fighters.left = resetPvpFighter(next.fighters.left); next.fighters.right = resetPvpFighter(next.fighters.right);
  next.physical_anomaly = null; next.strategic_delayed = []; next.strategic_jams = [];
  return next;
}

export function pvpHomReady(fighter: PvpFighter): boolean {
  return !fighter.hom_spent && fighter.hom_energy >= fighter.hom_ready_at;
}

/** _initiative consumes tempo_bonus; return the new fighter without mutating input. */
export function pvpInitiative(fighter: PvpFighter): { initiative: number; fighter: PvpFighter } {
  const next = structuredClone(fighter);
  const value = (next.entity?.base_stats?.tempo ?? 10) + (next.active_weapon?.effects?.tempo_flat?.[0] ?? 0) + (next.hom_spent ? 0 : next.hom_synergy.tempo_flat ?? 0) + (next.status.tempo_bonus ?? 0) + ((next as any).expedition_passive && !next.hom_spent ? passiveModifiers((next as any).expedition_passive).tempo_flat ?? 0 : 0);
  next.status.tempo_bonus = 0;
  return { initiative: value, fighter: next };
}

/** Decisions contain only the acting player's choice, never a target or opponent action. */
export function validatePvpDecision(state: PvpCombatState, side: PvpSide, decision: PvpDecision): { ok: true } | PvpError {
  if (!state || state.battle_over || state.match_result || !state.fighters || (side !== "left" && side !== "right") || !decision || typeof decision !== "object" || Array.isArray(decision) || Object.keys(decision).some(k => !["turn", "spell_id", "switch_slot", "hom_action", "ultra"].includes(k))) return { error: "INVALID_DECISION" };
  const f = state.fighters[side];
  if (!f || !Array.isArray(f.spell_ids) || !Array.isArray(f.spells) || !f.spells.every(object) || !Array.isArray(f.weapons) || !object(f.spell_cooldowns) || !Number.isSafeInteger(decision.turn) || decision.turn !== state.turn + 1 || (decision.spell_id !== undefined) === (decision.switch_slot !== undefined) || (decision.ultra !== undefined && typeof decision.ultra !== "boolean") || (decision.hom_action !== undefined && !["hold", "attack", "sacrifice"].includes(decision.hom_action))) return { error: "INVALID_DECISION" };
  if (decision.spell_id !== undefined && (typeof decision.spell_id !== "string" || !f.spell_ids.includes(decision.spell_id) || !f.spells.some(s => s.id === decision.spell_id) || (f.spell_cooldowns[decision.spell_id] ?? 0) > 0)) return { error: "INVALID_DECISION" };
  if (decision.switch_slot !== undefined && (![1, 2].includes(decision.switch_slot) || decision.switch_slot === f.active_weapon_slot || !f.weapons[decision.switch_slot - 1] || decision.ultra)) return { error: "INVALID_DECISION" };
  if (decision.hom_action && decision.hom_action !== "hold" && !pvpHomReady(f)) return { error: "INVALID_DECISION" };
  if (decision.ultra && (state.battle_index !== 3 || state.wins.left !== 1 || state.wins.right !== 1 || state.sudden_death || f.ultra_used)) return { error: "INVALID_DECISION" };
  return { ok: true };
}

/** Resolve supported spell effects. RNG returns a uniform [0,1) value. */
export function resolvePvpExchange(state: PvpCombatState, leftDecision: PvpDecision, rightDecision: PvpDecision, rng: (turn: number, draw: number) => number): PvpError | { state: PvpCombatState; events: any[] } {
  if (!state || !Number.isSafeInteger(state.turn) || state.turn < 0 || !Number.isSafeInteger(state.round) || state.round < 1 || !Number.isSafeInteger(state.battle_index) || state.battle_index < 1 || !object(state.wins) || ![state.wins.left, state.wins.right].every(v => Number.isSafeInteger(v) && v >= 0 && v < 2) || typeof state.sudden_death !== "boolean" || typeof state.player_turn !== "boolean" || !object(state.types) || !object((state.types as any).effectiveness) || !Number.isSafeInteger(state.rng_counter) || state.rng_counter < 0 || (state as any).battle_over || state.match_result || state.fighters?.left?.hp <= 0 || state.fighters?.right?.hp <= 0 || "error" in validatePvpDecision(state, "left", leftDecision) || "error" in validatePvpDecision(state, "right", rightDecision) || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const decisions = { left: leftDecision, right: rightDecision };
  const supportedStatuses = new Set(["poison", "stun", "shield_pct", "atk_boost", "vuln_pct", "atk_down", "hom_stun", "reflect_pct", "tempo_bonus", "focus_next", "misalign_next", "poison_on_reflect", "hybrid_mark"]);
  for (const side of ["left", "right"] as const) {
    const f: any = state.fighters[side], d = decisions[side];
    const spell = f.spells.find((s: any) => s.id === d.spell_id);
    if (!object(f.status) || !object(f.item_fx) || !object(f.hom_synergy) || ![f.hp, f.max_hp, f.atk, f.def, f.hom_energy, f.hom_max_energy, f.hom_ready_at].every(number) || f.hp <= 0 || f.hp > f.max_hp || f.max_hp <= 0 || f.hom_energy < 0 || f.hom_energy > f.hom_max_energy || !Object.entries(f.spell_cooldowns).every(([id, value]) => typeof id === "string" && Number.isSafeInteger(value) && (value as number) >= 0) || !Object.entries(f.status).every(([key, value]) => key === "hybrid_mark" || (number(value) && (key === "tempo_bonus" || (value as number) >= 0))) || !object((state.types as any).effectiveness[f.type]) || !number((state.types as any).effectiveness[f.type][state.fighters[side === "left" ? "right" : "left"].type])) return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
    if (!["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].includes(f.type) || (d.spell_id !== undefined && (!spell || !number(spell.power_mult) || !number(spell.accuracy) || spell.accuracy < 0 || spell.accuracy > 1 || !Number.isSafeInteger(spell.cooldown_turns) || spell.cooldown_turns < 0 || !((spell.category === "attack" && spell.power_mult > 0) || (spell.category === "support" && spell.power_mult === 0)) || !Array.isArray(spell.effects) || spell.effects.some((e: any) => !object(e) || !supportedEffects.has(e.kind) || (e.kind === "physical_anomaly" && !validPhysicalAnomalySpell(spell)) || (STRATEGIC_EFFECTS.includes(e.kind) && !validStrategicStatusEffect(e)) || !["self", "enemy"].includes(e.target) || !number(e.value) || (e.kind !== "tempo_shift" && e.value < 0) || ["threshold", "max_heal", "second_value"].some(k => e[k] !== undefined && (!number(e[k]) || e[k] < 0)) || (e.threshold !== undefined && e.threshold > 1) || (e.kind === "hybrid_mark" && (!Number.isSafeInteger(e.value) || e.value < 1)) || (e.kind === "ward_convert" && (e.value > 1 || spell.category !== "attack"))))) || f.inspiration_pending || Object.keys(f.status).some(key => !supportedStatuses.has(key)) || (f.status.hybrid_mark !== undefined && (!object(f.status.hybrid_mark) || !["left", "right"].includes(f.status.hybrid_mark.owner) || !Number.isSafeInteger(f.status.hybrid_mark.remaining) || f.status.hybrid_mark.remaining < 1))) return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
  }
  if (!Array.isArray(state.strategic_delayed) || !Array.isArray(state.strategic_jams) || state.strategic_jams.length || state.strategic_delayed.some((e: any) => !object(e) || !["left", "right"].includes(e.actor) || !["left", "right"].includes(e.target) || e.actor === e.target || !Number.isSafeInteger(e.amount) || e.amount <= 0 || !Number.isSafeInteger(e.due_turn) || e.due_turn <= state.turn) || (state.physical_anomaly && (!object(state.physical_anomaly) || typeof state.physical_anomaly.id !== "string" || !["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].includes(state.physical_anomaly.favored_type) || !["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].includes(state.physical_anomaly.weakened_type) || state.physical_anomaly.favored_type === state.physical_anomaly.weakened_type || !Number.isSafeInteger(state.physical_anomaly.remaining_exchanges) || state.physical_anomaly.remaining_exchanges < 1 || state.physical_anomaly.remaining_exchanges > 3 || !Number.isSafeInteger(state.physical_anomaly.activated_exchange) || state.physical_anomaly.activated_exchange > state.turn))) return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
  for (const f of Object.values(state.fighters) as any[]) {
    if ((f.strategic_trap && (!object(f.strategic_trap) || !number(f.strategic_trap.value) || f.strategic_trap.value < 0 || f.strategic_trap.value > 0.5 || !Number.isSafeInteger(f.strategic_trap.activated_turn) || !Number.isSafeInteger(f.strategic_trap.expires_turn) || f.strategic_trap.expires_turn <= state.turn)) || (f.strategic_heal_suppression && (!object(f.strategic_heal_suppression) || !Number.isSafeInteger(f.strategic_heal_suppression.expires_turn) || f.strategic_heal_suppression.expires_turn <= state.turn))) return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
  }
  const next = structuredClone(state), events: any[] = [], turn = state.turn + 1;
  const vitriolCorrosionUsed = { left: 0, right: 0 };
  let counter = 0;
  const draw = () => { const v = rng(turn, counter++); if (!number(v) || v < 0 || v >= 1) throw new Error("INVALID_RNG"); return v; };
  const sides: PvpSide[] = ["left", "right"];
  const other = (side: PvpSide): PvpSide => side === "left" ? "right" : "left";
  const emit = (side: PvpSide, category: string, verb: string, extra: any = {}) => {
    const fighter = next.fighters[side];
    events.push({ turn, side, actor_side: side === "left" ? "player" : "enemy", actor: fighter.name, actor_kind: "entity", actor_color: side === "left" ? "69d7e8" : "f2a078", category, verb, ...extra });
  };
  const clearDefense = (f: any, field: string) => {
    f.status[field] = 0; delete f[`weapon_${field}`]; delete f[`other_${field}`];
    if (field === "shield_pct") { delete f.spell_ward; delete f.spell_ward_baseline; }
    else { delete f.hom_reflect_active; delete f.hom_other_reflect; }
  };
  const applyOther = (f: any, field: string, value: number) => {
    if (field === "reflect_pct" && f.hom_reflect_active) f.hom_other_reflect = Math.max(f.hom_other_reflect ?? 0, value);
    if (f[`weapon_${field}`] !== undefined) f[`other_${field}`] = Math.max(f[`other_${field}`] ?? 0, value);
    f.status[field] = Math.max(f.status[field] ?? 0, value);
  };
  const applyWeapon = (f: any, field: string, value: number) => {
    if (f[`weapon_${field}`] === undefined) f[`other_${field}`] = f.status[field] ?? 0;
    f[`weapon_${field}`] = Math.max(f[`weapon_${field}`] ?? 0, value);
    f.status[field] = Math.max(f[`other_${field}`], f[`weapon_${field}`]);
  };
  const dmg = (actor: PvpSide, target: PvpSide, amount: number, kind: string, spell: any) => {
    const victim = next.fighters[target]; victim.hp = Math.max(0, victim.hp - amount);
    emit(actor, "damage", " hits ", { kind, target: victim.name, target_side: target, target_color: target === "left" ? "69d7e8" : "f2a078", spell_id: spell.id, show_spell_link: false, damage: amount, hp: victim.hp, suffix: ` for ${amount}.` });
  };
  const strategicEvents = (entries: any[]) => {
    for (const entry of entries) {
      const side = (entry.actor ?? entry.target) as PvpSide;
      const { actor, target, ...rest } = entry;
      emit(side, "strategic", " triggers a strategic effect.", { ...rest, ...(target ? { target_side: target } : {}) });
    }
  };
  try {
    next.turn = turn;
    for (const side of sides) {
      const f = next.fighters[side];
      f.spell_hit_last_exchange = f.spell_hit_this_exchange; f.spell_hit_this_exchange = false;
      f.spell_neutralize_active = f.spell_neutralize_pending; f.spell_neutralize_pending = 0;
      if (decisions[side].ultra) f.ultra_used = true;
    }
    const firePassive = (side: PvpSide, event: any, poisonDamage = 0, attack: any = null) => {
      const owner: any = next.fighters[side], opponent: any = next.fighters[other(side)];
      if (!owner.hom_spent) applyTimedAwarePassive(owner, opponent, event, next.types, side, other(side), events, poisonDamage, attack);
    };
    const mods = (fighter: any) => fighter.expedition_passive && !fighter.hom_spent ? passiveModifiers(fighter.expedition_passive) : {};
    for (const side of sides) {
      const owner: any = next.fighters[side];
      if (owner.expedition_passive && !owner.hom_spent) {
        owner.expedition_passive = beginPassiveExchange(owner.expedition_passive, turn);
        firePassive(side, "before_exchange");
      }
    }
    for (const side of sides) {
      const owner: any = next.fighters[side], choice = decisions[side];
      const chosen = owner.spells.find((entry: any) => entry.id === choice.spell_id);
      if (!owner.hom_spent && owner.expedition_passive?.id === "luny" && (owner.status.stun ?? 0) <= 0 && chosen?.category === "attack" && chosen.power_mult > 0) firePassive(side, "before_attack", 0, chosen);
    }
    const l = pvpInitiative(next.fighters.left), r = pvpInitiative(next.fighters.right);
    next.fighters.left = l.fighter; next.fighters.right = r.fighter;
    const order = normalInitiativeOrder(l.initiative, r.initiative);
    for (const side of order) {
      const opponent = other(side), a: any = next.fighters[side], b: any = next.fighters[opponent], decision = decisions[side];
      if (a.hp <= 0 || b.hp <= 0) break;
      const act = () => {
      const spell = a.spells.find((s: any) => s.id === decision.spell_id);
      a.spell_cooldowns = normalActionCooldowns(a.spell_cooldowns, spell);
      if (decision.switch_slot !== undefined) {
        if (a.status.stun > 0) {
          a.status.stun--;
          emit(side, "debuff", " is stunned and cannot switch.", { kind: "stun" });
        } else {
          next.fighters[side] = refreshPvpWeapon(a, decision.switch_slot);
          emit(side, "switch", " switches weapons.", { kind: "switch", slot: decision.switch_slot });
          firePassive(side, "weapon_switched");
        }
        return;
      }
      const mark = b.status.hybrid_mark;
      const marked = !!mark && mark.owner === side && mark.remaining > 0;
      const poisonedBefore = b.status.poison > 0;
      if (marked) { mark.remaining--; if (mark.remaining <= 0) delete b.status.hybrid_mark; emit(side, "debuff", "'s mark approaches expiry.", {kind: "mark_tick", target_side: opponent, remaining: mark.remaining}); }
      emit(side, spell.category === "attack" && a.status.stun <= 0 ? "damage" : "buff", " uses ", { kind: "spell", spell_id: spell.id, spell_name: spell.name, spell_meta: { id: spell.id, context: { spell: structuredClone(spell), actual_damage: 0, direct_damage: 0, pierce: 0, dispel: 0, ultra: !!decision.ultra } }, suffix: ".", target_side: opponent });
      const spellContext = events[events.length - 1].spell_meta.context;
      if (a.status.stun > 0) { a.status.stun--; emit(side, "debuff", " is stunned and skips the spell.", { kind: "stun", spell_id: spell.id }); return; }
      let power = spell.power_mult;
      for (const effect of spell.effects) {
        if (effect.kind === "bonus_if_poisoned" && poisonedBefore) power *= 1 + effect.value;
        else if (effect.kind === "bonus_if_hit_last_exchange" && a.spell_hit_last_exchange) power *= 1 + effect.value;
        else if ((effect.kind === "bonus_if_low_hp" && a.hp < a.max_hp * (effect.threshold ?? 0.4)) || (effect.kind === "bonus_if_marked" && marked) || (effect.kind === "bonus_power_if_poisoned" && poisonedBefore) || (effect.kind === "bonus_if_shielded" && effectiveTimedDefense(a, "shield_pct") > 0) || (effect.kind === "bonus_power_if_hit_last_exchange" && a.spell_hit_last_exchange)) power += effect.value;
        else if (effect.kind === "pierce_ward") spellContext.pierce = effect.value;
        else if (effect.kind === "ward_dispel") spellContext.dispel = effect.value;
      }
      if (spell.category === "attack") {
      firePassive(side, "before_attack", 0, spell);
      const focus = a.status.focus_next ?? 0, misalign = a.status.misalign_next ?? 0;
      if (focus > 0 || misalign > 0) { delete a.status.focus_next; delete a.status.misalign_next; }
      const evasion = Math.min(1, (b.item_fx.evasion_pct ?? 0) + (mods(b).evasion_pct ?? 0));
      if (evasion > 0 && draw() < evasion) { emit(opponent, "miss", " evades.", { kind: "evade", target_side: side, spell_id: spell.id }); firePassive(opponent, "dodge"); if (a.expedition_passive && !a.hom_spent) { a.expedition_passive = finishPassiveAttack(recordPassiveSpellHit(a.expedition_passive, false)); firePassive(side, "spell_miss"); } return; }
      const accuracy = spell.accuracy + focus - misalign + (mods(a).accuracy_pct ?? 0);
      if (draw() >= Math.max(0, Math.min(1, accuracy))) { emit(side, "miss", " misses.", { kind: "miss", target_side: opponent, spell_id: spell.id }); if (a.expedition_passive && !a.hom_spent) { a.expedition_passive = finishPassiveAttack(recordPassiveSpellHit(a.expedition_passive, false)); firePassive(side, "spell_miss"); } return; }
      const as = a.hom_spent ? {} : a.hom_synergy, bs = b.hom_spent ? {} : b.hom_synergy;
      const mult = normalSpellMultiplier({ attacker_type: a.type, defender_type: b.type, spell_type: spell.type, primary_type: spell.primary_type, secondary_type: spell.secondary_type, effectiveness: (next.types as any).effectiveness, advantage_bonus: a.hom_spent ? 0 : (as.type_adv_bonus ?? 0) + (a.hom_bonus.favorable_type_bonus ?? 0), disadvantage_reduction: a.item_fx.disadvantage_reduction, attacker_neutralize: a.spell_neutralize_active, defender_neutralize: b.spell_neutralize_active, attacker_hom_neutralize: as.type_neutralize, defender_hom_neutralize: bs.type_neutralize });
      const amount = normalDirectDamage({ attack: a.atk + (mods(a).power_flat ?? 0), defense: b.def + (mods(b).guard_flat ?? 0), power, type_multiplier: mult, anomaly_multiplier: physicalAnomalyMultiplier(next.physical_anomaly, a.type), attack_down: a.status.atk_down, attack_boost: a.status.atk_boost, incoming_multiplier: bs.incoming_mult, vulnerability: b.status.vuln_pct, shield: effectiveTimedDefense(b, "shield_pct"), pierce: spellContext.pierce, dispel: spellContext.dispel, ultra: decision.ultra });
      if (a.status.atk_down > 0) emit(side, "debuff", " shakes off the weakness.", {kind: "status_consumed", status: "atk_down", spell_id: spell.id});
      if (a.status.atk_boost > 0) emit(side, "combo", " expends the surge.", {kind: "status_consumed", status: "atk_boost", spell_id: spell.id});
      if (b.status.vuln_pct > 0) emit(side, "combo", " exploits vulnerability.", {kind: "status_consumed", status: "vuln_pct", target_side: opponent, spell_id: spell.id});
      a.status.atk_down = 0; a.status.atk_boost = 0; b.status.vuln_pct = 0;
      if (b.status.shield_pct > 0) clearDefense(b, "shield_pct");
      spellContext.direct_damage = Math.min(b.hp, amount); spellContext.actual_damage += spellContext.direct_damage;
      dmg(side, opponent, amount, "damage", spell); events[events.length - 1].effectiveness = mult;
      if (a.expedition_passive && !a.hom_spent) a.expedition_passive = finishPassiveAttack(recordPassiveSpellHit(a.expedition_passive, true));
      if (spellContext.direct_damage > 0) firePassive(opponent, "damage_received");
      if (amount > 0) b.spell_hit_this_exchange = true;
      if (effectiveTimedDefense(b, "reflect_pct") > 0) {
        const ignored = (a.item_fx.ignore_reflect_chance ?? 0) > 0 && draw() < a.item_fx.ignore_reflect_chance;
        const reflected = ignored ? 0 : Math.round(amount * effectiveTimedDefense(b, "reflect_pct"));
        if (reflected > 0) { dmg(opponent, side, reflected, "reflect", spell); a.spell_hit_this_exchange = true; firePassive(side, "damage_received"); }
        if (!ignored && (b.status.poison_on_reflect ?? 0) > 0) { const previous = a.status.poison; a.status.poison = Math.max(previous, b.status.poison_on_reflect); recordPoisonChange(a, previous, typeof (b as any).poison_reflect_source === "string" ? (b as any).poison_reflect_source : null); }
        if (b.status.reflect_pct > 0) clearDefense(b, "reflect_pct"); delete b.status.poison_on_reflect; delete (b as any).poison_reflect_source;
      }
      for (const key of ["true_on_hit", "dot_true"]) {
        let value = Math.trunc(a.item_fx[key] ?? 0);
        if (key === "dot_true" && a.active_weapon?.id === "vitriol_vial") { value = Math.max(0, Math.min(value, 4 - vitriolCorrosionUsed[side])); vitriolCorrosionUsed[side] += value; }
        if (value > 0) { spellContext.actual_damage += Math.min(b.hp, value); dmg(side, opponent, value, key, spell); if (key === "dot_true" && a.item_fx.vuln_on_hit > 0) b.status.vuln_pct = Math.max(b.status.vuln_pct, a.item_fx.vuln_on_hit); }
      }
      const homDot = Math.max(0, Math.trunc(as.dot_true ?? 0)); if (homDot > 0) dmg(side, opponent, homDot, "hom_dot", spell);
      const proc = Math.floor(draw() * 0x100000000) % 100;
      if (a.type === "vitriol" && proc < 30) { const previous = b.status.poison; b.status.poison = 2; recordPoisonChange(b, previous, side); }
      if (a.type === "mercury" && proc < 20) b.status.stun = 1;
      if (a.type === "sulfur" && proc < 20) b.status.atk_down = Math.max(b.status.atk_down, 0.15);
      if (a.type === "sodium" && proc < 20) applyOther(a, "shield_pct", 0.12);
      if (a.type === "aether" && proc < 20) b.status.vuln_pct = Math.max(b.status.vuln_pct, 0.12);
      if (a.type === "gold" && proc < 20) { const before = a.hp; a.hp = Math.min(a.max_hp, a.hp + strategicHeal(a, 3)); if (a.hp !== before) emit(side, "heal", " restores 3 HP.", { kind: "elemental_heal", spell_id: spell.id, hp: a.hp, amount: a.hp - before }); }
      if (proc < (a.type === "vitriol" ? 30 : 20) && a.type !== "gold") emit(side, a.type === "sodium" ? "shield" : "debuff", " triggers an elemental effect.", {kind: "elemental_proc", spell_id: spell.id, target_side: a.type === "sodium" ? side : opponent, status: ({vitriol:"poison",mercury:"stun",sulfur:"atk_down",sodium:"shield_pct",aether:"vuln_pct"} as Record<string,string>)[a.type]});
      } else {
        if (draw() >= Math.max(0, Math.min(1, spell.accuracy + (mods(a).accuracy_pct ?? 0)))) { emit(side, "miss", "'s spell misses.", {kind: "miss", spell_id: spell.id}); firePassive(side, "spell_miss"); return; }
        emit(side, "buff", "'s spell succeeds.", {kind: "support_hit", spell_id: spell.id, show_spell_link: false});
      }
      if (spell.type === "hybrid" && marked) { delete b.status.hybrid_mark; emit(side, "combo", " consumes the hybrid mark.", {kind: "mark_consumed", target_side: opponent, spell_id: spell.id, show_spell_link: false}); }
      for (const effect of spell.effects) if (effect.kind === "ward_convert" && spell.category === "attack") {
        const ward = a.spell_ward ?? 0;
        if (ward > 0) {
          const baseline = a.spell_ward_baseline ?? 0;
          delete a.spell_ward; delete a.spell_ward_baseline;
          a.status.shield_pct = Math.max(baseline, a.weapon_shield_pct ?? 0);
          if (a.weapon_shield_pct !== undefined) a.other_shield_pct = baseline;
          const converted = Math.min(b.hp, Math.floor(b.max_hp * 0.2), Math.floor(a.max_hp * ward * effect.value));
          dmg(side, opponent, converted, "ward_convert", spell);
        }
      }
      for (const effect of spell.effects) {
        const targetSide: PvpSide = effect.target === "self" ? side : opponent;
        const recipient: any = next.fighters[targetSide];
        const kind: string = effect.kind;
        let value: number = effect.value;
        if (decision.ultra && ["heal", "recoil", "atk_boost", "atk_down", "shield", "reflect", "vuln", "poison", "hom_stun", "focus_next", "misalign_next", "tempo_shift", "hybrid_mark", "type_neutralize", "poison_on_reflect"].includes(kind)) {
          value *= 2;
          if (["atk_boost", "atk_down", "shield", "reflect", "vuln", "focus_next", "misalign_next", "type_neutralize"].includes(kind)) value = Math.max(0, Math.min(kind === "shield" || kind === "reflect" ? 0.95 : 1, value));
        }
        const award = (awardedTarget: PvpSide = targetSide) => {
          if (awardedTarget === side || a.inspiration_used_this_battle || a.inspiration >= 3) return;
          a.inspiration++; a.inspiration_pending = a.inspiration === 3;
          emit(side, "inspiration", ` gains inspiration (${a.inspiration}/3).`, {kind: "inspiration", source: kind, value: a.inspiration, target_side: awardedTarget, spell_id: spell.id, show_spell_link: false});
        };
        if (["bonus_if_poisoned", "bonus_if_hit_last_exchange", "bonus_if_low_hp", "bonus_if_marked", "bonus_power_if_poisoned", "bonus_if_shielded", "bonus_power_if_hit_last_exchange", "pierce_ward", "ward_dispel", "ward_convert"].includes(kind)) continue;
        if (kind === "physical_anomaly") {
          next.physical_anomaly = castPhysicalAnomaly(spell, turn);
          emit(side, "strategic", " creates an anomaly.", { kind: "physical_anomaly_cast", anomaly: structuredClone(next.physical_anomaly) });
        } else if (kind === "delayed_damage") {
          const ev: any[] = []; if (spell.category === "attack") queueDelayedDamage(next, side, opponent, value, spellContext.direct_damage, turn, ev); strategicEvents(ev);
        } else if (kind === "debuff_transfer" || kind === "buff_steal") {
          const ev: any[] = [];
          const previousPoison = b.status.poison;
          transferStrategicStatus(kind, a, b, side, opponent, { vuln: "vuln_pct", shield: "shield_pct", reflect: "reflect_pct" }, ev, (f, field) => { if (["shield_pct", "reflect_pct"].includes(field)) clearDefense(f, field); else f.status[field] = 0; }, (f, field, amount) => { if (["shield_pct", "reflect_pct"].includes(field)) applyOther(f, field, amount); else f.status[field] = Math.max(f.status[field] ?? 0, amount); });
          recordPoisonChange(b, previousPoison, side); recordPoisonChange(a, a.status.poison, null);
          strategicEvents(ev); if (kind === "debuff_transfer" && ev[0] && ev[0].value > ev[0].previous) award(opponent);
        } else if (kind === "cooldown_jam") {
          next.strategic_jams.push({ actor: side, target: opponent });
        } else if (kind === "counter_trap") {
          a.strategic_trap = { value, activated_turn: turn, expires_turn: turn + 2 };
          emit(side, "strategic", " arms a trap.", { kind: "counter_trap_armed", value, expires_turn: turn + 2 });
        } else if (kind === "heal_suppression") {
          b.strategic_heal_suppression = { expires_turn: turn + 2 };
          emit(side, "strategic", " suppresses healing.", { kind: "heal_suppression_applied", target_side: opponent, expires_turn: turn + 2 });
        } else if (kind === "hom_energy_siphon") {
          const amount = !a.hom_spent && !b.hom_spent && a.hom_id && b.hom_id ? Math.min(2, b.hom_energy, a.hom_max_energy - a.hom_energy) : 0;
          if (amount > 0) { a.hom_energy += amount; b.hom_energy -= amount; emit(side, "strategic", " siphons energy.", { kind, target_side: opponent, amount }); }
        } else if (kind === "recoil") {
          const amount = Math.trunc(value); if (recipient.hp > 0 && amount > 0) recipient.spell_hit_this_exchange = true;
          recipient.hp = Math.max(0, recipient.hp - amount);
          emit(targetSide, "damage", ` takes ${amount} recoil.`, {kind: "recoil", damage: amount, hp: recipient.hp, spell_id: spell.id, show_spell_link: false, source_side: side});
        } else if (kind === "life_leech" && !effect.health_drain) {
          const cap = Math.trunc(effect.max_heal ?? 0) * (decision.ultra ? 2 : 1);
          emit(targetSide, "heal", " siphons health.", {kind: "life_leech", spell_id: spell.id, show_spell_link: false, source_side: side});
          if (recipient.hp > 0) {
            const before = recipient.hp; recipient.hp = Math.min(recipient.max_hp, recipient.hp + strategicHeal(recipient, Math.min(cap, Math.floor(spellContext.actual_damage * value))));
            emit(targetSide, "heal", ` restores ${recipient.hp - before} HP from life leech.`, {kind: "life_leech_heal", amount: recipient.hp - before, hp: recipient.hp, spell_id: spell.id, show_spell_link: false, source_side: side});
          }
        } else if (kind === "consume_poison") {
          if (poisonedBefore) { recipient.status.poison = Math.max(0, Math.trunc(recipient.status.poison) - Math.trunc(value)); recordPoisonChange(recipient, recipient.status.poison, null); emit(side, "combo", " consumes poison.", {kind, target_side: targetSide, spell_id: spell.id, show_spell_link: false}); }
        } else if (kind === "hybrid_mark") {
          const before = JSON.stringify(recipient.status.hybrid_mark ?? {});
          recipient.status.hybrid_mark = {owner: side, remaining: Math.trunc(value)};
          emit(side, "debuff", " marks the target.", {kind, target_side: targetSide, value: structuredClone(recipient.status.hybrid_mark), spell_id: spell.id, show_spell_link: false});
          if (before !== JSON.stringify(recipient.status.hybrid_mark)) award();
        } else if (kind === "shield_by_order") {
          let shield = side === order[1] ? effect.second_value ?? value : value;
          if (decision.ultra) shield = Math.min(shield * 2, 0.95);
          if (recipient.spell_ward_baseline === undefined) recipient.spell_ward_baseline = recipient.status.shield_pct;
          recipient.spell_ward = Math.max(recipient.spell_ward ?? 0, shield); applyOther(recipient, "shield_pct", shield);
          emit(targetSide, "shield", " gains a shield.", {kind, value: shield, spell_id: spell.id, show_spell_link: false, source_side: side});
        } else if (kind === "life_leech" && effect.health_drain === true) {
          const shield = effectiveTimedDefense(b, "shield_pct");
          const incoming = b.hom_spent ? 1 : Math.max(0.1, Math.min(1, b.hom_synergy.incoming_mult ?? 1));
          const amount = drainHealth(a, b, Math.trunc(effect.max_heal ?? 0) * (decision.ultra ? 2 : 1), shield, incoming);
          if (b.status.shield_pct > 0) clearDefense(b, "shield_pct");
          emit(side, "damage", ` drains ${amount} HP.`, {kind: "damage", target_side: opponent, damage: amount, hp: b.hp, spell_id: spell.id});
          emit(side, "heal", ` restores ${amount} HP.`, {kind: "heal", amount, hp: a.hp, spell_id: spell.id});
          if (amount > 0) {
            b.spell_hit_this_exchange = true;
            firePassive(opponent, "damage_received");
            const reflect = effectiveTimedDefense(b, "reflect_pct");
            if (reflect > 0) {
              const ignored = (a.item_fx.ignore_reflect_chance ?? 0) > 0 && draw() < a.item_fx.ignore_reflect_chance;
              const reflected = ignored ? 0 : Math.min(a.hp, Math.round(amount * reflect));
              if (reflected > 0) { dmg(opponent, side, reflected, "reflect", spell); a.spell_hit_this_exchange = true; firePassive(side, "damage_received"); }
              if (!ignored && (b.status.poison_on_reflect ?? 0) > 0) { const previous = a.status.poison; a.status.poison = Math.max(previous, b.status.poison_on_reflect); recordPoisonChange(a, previous, typeof (b as any).poison_reflect_source === "string" ? (b as any).poison_reflect_source : null); }
              if (b.status.reflect_pct > 0) clearDefense(b, "reflect_pct");
              delete b.status.poison_on_reflect; delete (b as any).poison_reflect_source;
            }
          }
        } else if (["shield", "reflect"].includes(kind) && effect.duration_exchanges) {
          const field = kind === "shield" ? "shield_pct" : "reflect_pct";
          applyTimedDefense(recipient, field, value, turn, effect.duration_exchanges);
          emit(targetSide, "shield", ` gains ${kind}.`, {kind: "status_applied", status: field, value, spell_id: spell.id, source_side: side});
        } else if (kind === "heal") {
          const before = recipient.hp; recipient.hp = Math.min(recipient.max_hp, recipient.hp + strategicHeal(recipient, Math.trunc(value)));
          emit(targetSide, "heal", ` restores ${recipient.hp - before} HP.`, {kind: "heal", spell_id: spell.id, show_spell_link: false, hp: recipient.hp, amount: recipient.hp - before, source_side: side});
        } else if (kind === "cleanse_one") {
          const field = ["poison", "stun", "vuln_pct", "atk_down", "misalign_next"].find(k => (recipient.status[k] ?? 0) > 0);
          if (field) { recipient.status[field] = 0; if (field === "poison") recordPoisonChange(recipient, 0, null); }
          emit(targetSide, "buff", " cleanses one negative status.", {kind: "cleanse_one", status: field ?? null, spell_id: spell.id, show_spell_link: false, source_side: side});
        } else if (kind === "type_neutralize") {
          recipient.spell_neutralize_pending = Math.max(recipient.spell_neutralize_pending, value);
          emit(targetSide, "buff", " prepares type neutralization.", {kind, value: recipient.spell_neutralize_pending, spell_id: spell.id, show_spell_link: false, source_side: side});
        } else if (kind === "poison_on_reflect") {
          const previous = recipient.status.poison_on_reflect ?? 0; recipient.status.poison_on_reflect = Math.trunc(value); if (recipient.status.poison_on_reflect > previous) (recipient as any).poison_reflect_source = side;
          emit(targetSide, "shield", " prepares a toxic reflection.", {kind, value: recipient.status.poison_on_reflect, spell_id: spell.id, show_spell_link: false, source_side: side});
        } else if (kind === "tempo_shift") {
          const before = recipient.status.tempo_bonus ?? 0; recipient.status.tempo_bonus = value;
          emit(targetSide, "buff", "'s initiative shifts.", {kind, value, spell_id: spell.id, show_spell_link: false, source_side: side});
          if (value < 0 && value < before) award();
        } else {
          const field = ({shield: "shield_pct", reflect: "reflect_pct", vuln: "vuln_pct"} as Record<string,string>)[kind] ?? kind;
          const before = recipient.status[field] ?? 0;
          if (kind === "shield" || kind === "reflect") {
            if (kind === "shield") { if (recipient.spell_ward_baseline === undefined) recipient.spell_ward_baseline = before; recipient.spell_ward = Math.max(recipient.spell_ward ?? 0, value); }
            applyOther(recipient, field, value);
          } else recipient.status[field] = Math.max(before, value);
          if (field === "poison") recordPoisonChange(recipient, before, side);
          emit(targetSide, kind === "shield" || kind === "reflect" ? "shield" : kind === "atk_boost" || kind === "focus_next" ? "buff" : "debuff", ` gains ${kind}.`, {kind: "status_applied", status: field, value: recipient.status[field], previous: before, spell_id: spell.id, show_spell_link: false, source_side: side});
          if (["atk_down", "vuln", "poison", "hom_stun", "misalign_next"].includes(kind) && recipient.status[field] > before) award();
        }
      }
      if (spell.category === "attack") { const ev: any[] = []; strategicCounter(b, a, opponent, side, spellContext.direct_damage, turn, ev); strategicEvents(ev); }
      };
      act();
      const actor: any = next.fighters[side];
      if (actor.hp <= 0 || (b.hp <= 0 && decision.hom_action !== "sacrifice") || !pvpHomReady(actor)) continue;
      if (decision.hom_action === "sacrifice") {
        actor.hom_spent = true; actor.hom_energy = 0; delete actor.expedition_passive;
        if (actor.hom_reflect_active !== undefined) {
          actor.status.reflect_pct = Math.max(actor.hom_other_reflect ?? 0, actor.weapon_reflect_pct ?? 0);
          if (actor.other_reflect_pct !== undefined) actor.other_reflect_pct = actor.hom_other_reflect ?? 0;
          delete actor.hom_reflect_active; delete actor.hom_other_reflect;
        }
        const refreshed = refreshPvpWeapon(actor);
        const before = refreshed.hp; refreshed.hp = Math.min(refreshed.max_hp, refreshed.hp + strategicHeal(refreshed, 30));
        next.fighters[side] = refreshed;
        emit(side, "heal", " sacrifices its homunculus.", { kind: "hom_sacrifice", amount: refreshed.hp - before, hp: refreshed.hp });
      } else if (decision.hom_action === "attack") {
        const boosted = actor.hom_energy >= 6; actor.hom_energy = 0;
        if (actor.status.hom_stun > 0) { actor.status.hom_stun--; emit(side, "debuff", "'s homunculus is nullified.", { kind: "hom_stun" }); }
        else if ((mods(b).evasion_pct ?? 0) > 0 && draw() < Math.min(1, mods(b).evasion_pct)) { emit(opponent, "miss", " evades the homunculus.", { kind: "evade", target_side: side }); firePassive(opponent, "dodge"); }
        else if (draw() >= Math.max(0.6, Math.min(0.98, 0.95 - (actor.atk > b.def * 1.6 ? 0.08 : 0) - (actor.max_hp > b.max_hp ? Math.min(0.15, (actor.max_hp - b.max_hp) / actor.max_hp * 0.2) : 0)))) emit(side, "miss", "'s homunculus misses.", { kind: "hom_miss", target_side: opponent });
        else {
          const incoming = b.hom_spent ? 1 : Math.max(0.1, Math.min(1, b.hom_synergy.incoming_mult ?? 1));
          const factor = homunculusAttackMultiplierById(actor.hom_id, b.type, next.types, [actor.spell_neutralize_active ?? 0, b.spell_neutralize_active ?? 0, actor.hom_synergy?.type_neutralize ?? 0, b.hom_spent ? 0 : b.hom_synergy?.type_neutralize ?? 0]);
          const raw = Math.max(1, Math.round((actor.atk + (mods(actor).power_flat ?? 0)) * (boosted ? 0.6 : 0.4) * incoming * factor));
          const timedShield = (b as any).timed_defenses?.shield_pct?.value ?? 0;
          const amount = Math.max(0, Math.round(raw * (1 - timedShield)));
          b.hp = Math.max(0, b.hp - amount); b.spell_hit_this_exchange = true;
          if (amount > 0) firePassive(opponent, "damage_received");
          emit(side, "homunculus", " strikes.", { kind: "hom_attack", target_side: opponent, damage: amount, hp: b.hp, boosted });
          const timedReflect = (b as any).timed_defenses?.reflect_pct?.value ?? 0;
          if (timedReflect > 0) {
            const ignored = (actor.item_fx.ignore_reflect_chance ?? 0) > 0 && draw() < actor.item_fx.ignore_reflect_chance;
            const reflected = ignored ? 0 : Math.min(actor.hp, Math.round(amount * timedReflect));
            if (reflected > 0) { actor.hp -= reflected; firePassive(side, "damage_received"); emit(opponent, "damage", " reflects the homunculus strike.", {kind:"reflect", target_side:side, damage:reflected, hp:actor.hp}); }
          }
        }
      }
    }
    if (next.fighters.left.hp > 0 && next.fighters.right.hp > 0) for (const side of sides) {
      const f = next.fighters[side]; if (f.status.poison > 0) { const damage = Math.min(3, f.hp); const provenance = poisonTickMetadata(f, side, sides, damage, turn); f.status.poison--; f.hp -= damage; f.spell_hit_this_exchange = true; emit(side, "debuff", " suffers poison.", { kind: "poison", damage, hp: f.hp, ...provenance }); if (provenance.source && provenance.source !== side && damage > 0) { firePassive(provenance.source as PvpSide, "opponent_poison_damage", damage); firePassive(side, "damage_received"); } recordPoisonChange(f, f.status.poison, null); }
    }
    for (const side of sides) { const f: any = next.fighters[side]; if (f.expedition_passive) f.expedition_passive = finishPassiveExchange(f.expedition_passive); }
    for (const side of sides) { const f = next.fighters[side]; if (!f.hom_spent) f.hom_energy = Math.min(f.hom_max_energy, f.hom_energy + 1); f.spell_neutralize_active = 0; }
    // The shared helper also expires effects; defer that part until after jams.
    const expiry: Record<string, any> = {};
    for (const side of sides) {
      const f: any = next.fighters[side]; expiry[side] = { trap: f.strategic_trap, suppression: f.strategic_heal_suppression };
      delete f.strategic_trap; delete f.strategic_heal_suppression;
    }
    { const ev: any[] = []; finishStrategicExchange(next, next.fighters, turn, ev); strategicEvents(ev); }
    for (const side of sides) {
      const f: any = next.fighters[side];
      if (expiry[side].trap) f.strategic_trap = expiry[side].trap;
      if (expiry[side].suppression) f.strategic_heal_suppression = expiry[side].suppression;
    }
    for (const jam of next.strategic_jams) { const f = next.fighters[jam.target as PvpSide]; const ev: any[] = []; jamStrategicCooldown(f.spell_ids.map(id => f.spells.find(s => s.id === id)), f.spell_cooldowns, jam.actor, jam.target, ev); strategicEvents(ev); }
    next.strategic_jams = [];
    { const ev: any[] = []; finishStrategicExchange(next, next.fighters, turn, ev); strategicEvents(ev); }
    for (const side of sides) expireTimedDefenses(next.fighters[side], turn);
    next.physical_anomaly = tickPhysicalAnomaly(next.physical_anomaly, turn);
    if (next.fighters.left.hp <= 0 || next.fighters.right.hp <= 0) {
      const defeated = { left: next.fighters.left.hp <= 0, right: next.fighters.right.hp <= 0 };
      const outcome = normalBattleOutcome({ ...next.wins, battle_index: next.battle_index, sudden_death: next.sudden_death }, defeated);
      const battleResult = defeated.left && defeated.right ? "draw" : defeated.left ? "right" : "left";
      next.wins = outcome.wins; next.battle_index = outcome.battle_index; next.sudden_death = outcome.sudden_death;
      events.push({ turn, kind: "battle_result", result: battleResult, wins: structuredClone(next.wins) });
      if (outcome.result !== null) {
        next.battle_over = true; next.battle_result = battleResult; next.match_result = outcome.result;
        for (const side of sides) delete (next.fighters[side] as any).expedition_passive;
        for (const side of sides) { const f = next.fighters[side]; if (f.temporary_spell_id) { f.spell_ids = [...f.original_spell_ids]; f.spells = f.spells.filter(s => s.id !== f.temporary_spell_id || f.original_spell_ids.includes(s.id)); delete f.spell_cooldowns[f.temporary_spell_id]; } f.temporary_spell_id = ""; f.temporary_replaced_slot = -1; f.inspiration_pending = false; f.inspiration_offers = []; }
        events.push({ turn, kind: "match_result", result: outcome.result, wins: structuredClone(next.wins) });
      } else {
        const reset = startPvpBattle(next); reset.battle_result = battleResult;
        return { state: reset, events };
      }
    } else {
      for (const side of sides) {
        const f = next.fighters[side];
        if (f.inspiration_pending && !f.inspiration_used_this_battle) {
          if (!Array.isArray(f.inspiration_catalog)) return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
          const choices = f.inspiration_catalog.filter(s => !f.spell_ids.includes(s.id));
          if (choices.length < 3) return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
          f.inspiration_offers = [];
          for (let i = 0; i < 3; i++) f.inspiration_offers.push(choices.splice(Math.floor(draw() * choices.length), 1)[0].id);
          emit(side, "inspiration", " considers temporary spells.", { kind: "inspiration_offered" });
        }
      }
      next.player_turn = !next.player_turn;
      if (!next.player_turn) {
        next.round++;
        for (const side of sides) {
          const f: any = next.fighters[side], synergy = f.hom_spent ? {} : f.hom_synergy;
          const reflect = Math.max(0, Math.min(1, synergy.reflect_pct ?? 0));
          if (reflect > 0) { f.hom_other_reflect = f.status.reflect_pct; f.hom_reflect_active = reflect; if (f.weapon_reflect_pct !== undefined) f.other_reflect_pct = Math.max(f.other_reflect_pct ?? 0, reflect); f.status.reflect_pct = Math.max(f.status.reflect_pct, reflect); }
          if (f.item_fx.ward_pct > 0) applyWeapon(f, "shield_pct", f.item_fx.ward_pct);
          if (f.item_fx.reflect_pct > 0) applyWeapon(f, "reflect_pct", f.item_fx.reflect_pct);
        }
        if (next.round === 2 && next.fighters.left.hp !== next.fighters.right.hp) { const winner = next.fighters[next.fighters.left.hp > next.fighters.right.hp ? "left" : "right"]; if (winner.item_fx.tempo_on_win > 0) winner.status.tempo_bonus = winner.item_fx.tempo_on_win; }
      }
    }
    next.rng_counter = counter;
    return { state: next, events };
  } catch (err) { if (err instanceof Error && err.message === "INVALID_RNG") return { error: "INVALID_RNG" }; throw err; }
}

/** Resolve one private Inspiration choice without advancing the exchange. */
export function resolvePvpInspiration(state: PvpCombatState, side: PvpSide, decision: { kind: "decline" } | { kind: "choose"; spell_id: string }, rng: (turn: number, draw: number) => number): PvpError | { state: PvpCombatState; events: any[] } {
  if (!state || (state as any).match_result || !["left", "right"].includes(side) || typeof rng !== "function" || !object(decision)) return { error: "INVALID_DECISION" };
  const f = state.fighters?.[side];
  if (!f?.inspiration_pending || f.inspiration_used_this_battle || !Array.isArray(f.inspiration_offers) || f.inspiration_offers.length !== 3 || new Set(f.inspiration_offers).size !== 3) return { error: "INVALID_DECISION" };
  const keys = Object.keys(decision).sort().join(",");
  if (!(decision.kind === "decline" && keys === "kind") && !(decision.kind === "choose" && keys === "kind,spell_id" && f.inspiration_offers.includes(decision.spell_id))) return { error: "INVALID_DECISION" };
  const next = structuredClone(state), fighter = next.fighters[side], passiveEvents: any[] = [];
  if (decision.kind === "choose") {
    const spell = fighter.inspiration_catalog.find(s => s.id === decision.spell_id);
    if (!spell || fighter.spell_ids.includes(spell.id)) return { error: "INVALID_DECISION" };
    const roll = rng(next.turn, next.rng_counter); if (!number(roll) || roll < 0 || roll >= 1) return { error: "INVALID_RNG" };
    const slot = Math.floor(roll * 4); next.rng_counter++;
    fighter.spell_ids[slot] = spell.id; fighter.temporary_spell_id = spell.id; fighter.temporary_replaced_slot = slot;
    if (!fighter.spells.some(s => s.id === spell.id)) fighter.spells.push(structuredClone(spell));
    recordInspirationActivation(fighter, side, next.turn);
    if (!fighter.hom_spent) applyTimedAwarePassive(fighter, next.fighters[side === "left" ? "right" : "left"], "inspiration_activated", next.types, side, side === "left" ? "right" : "left", passiveEvents);
  } else fighter.inspiration = 0;
  fighter.inspiration_pending = false; fighter.inspiration_used_this_battle = true; fighter.inspiration_offers = [];
  return { state: next, events: [{ turn: next.turn, side, kind: decision.kind === "choose" ? "inspiration_chosen" : "inspiration_declined", ...(decision.kind === "choose" ? {activation: structuredClone((fighter as any).inspiration_activation)} : {}) }, ...passiveEvents] };
}

/** A view for a single player; offers and candidate catalogs are private. */
export function publicPvpCombatState(state: PvpCombatState, viewer: PvpSide): PvpCombatState {
  const result = structuredClone(state);
  for (const side of ["left", "right"] as const) {
    result.fighters[side].inspiration_catalog = [];
    if (side !== viewer) result.fighters[side].inspiration_offers = [];
  }
  return result;
}

/** Normal combat.gd battle-end scoring. */
export function normalBattleOutcome(score: { left: number; right: number; battle_index: number; sudden_death: boolean }, defeated: { left: boolean; right: boolean }): { wins: Record<PvpSide, number>; battle_index: number; sudden_death: boolean; result: PvpSide | "draw" | null } {
  if (!Number.isSafeInteger(score.left) || !Number.isSafeInteger(score.right) || score.left < 0 || score.right < 0 || !Number.isSafeInteger(score.battle_index) || score.battle_index < 1 || typeof score.sudden_death !== "boolean" || typeof defeated.left !== "boolean" || typeof defeated.right !== "boolean" || (!defeated.left && !defeated.right)) throw new Error("INVALID_BATTLE_OUTCOME");
  const wins = { left: score.left + Number(defeated.right && !defeated.left), right: score.right + Number(defeated.left && !defeated.right) };
  if (wins.left >= 2 || wins.right >= 2) return { wins, battle_index: score.battle_index, sudden_death: score.sudden_death, result: wins.left === wins.right ? "draw" : wins.left > wins.right ? "left" : "right" };
  if (score.battle_index >= 3) {
    if (wins.left === wins.right && !score.sudden_death) return { wins, battle_index: score.battle_index + 1, sudden_death: true, result: null };
    return { wins, battle_index: score.battle_index, sudden_death: score.sudden_death, result: wins.left === wins.right ? "draw" : wins.left > wins.right ? "left" : "right" };
  }
  return { wins, battle_index: score.battle_index + 1, sudden_death: score.sudden_death, result: null };
}

/** Normal combat.gd gives the left/player fighter priority on equal initiative. */
export function normalInitiativeOrder(left: number, right: number): [PvpSide, PvpSide] {
  if (!Number.isFinite(left) || !Number.isFinite(right)) throw new Error("INVALID_INITIATIVE");
  return left >= right ? ["left", "right"] : ["right", "left"];
}

/** Transcription of _spell_multiplier / _type_multiplier in combat.gd. */
export function normalSpellMultiplier(input: {
  attacker_type: string; defender_type: string; spell_type: string;
  primary_type?: string; secondary_type?: string;
  effectiveness: Record<string, Record<string, number>>;
  advantage_bonus?: number; disadvantage_reduction?: number;
  attacker_neutralize?: number; defender_neutralize?: number;
  attacker_hom_neutralize?: number; defender_hom_neutralize?: number;
}): number {
  if (input.spell_type === "universal") return 1;
  const relation = (type: string) => input.effectiveness[type]?.[input.defender_type] ?? 1;
  const advantage = Math.max(0, Math.min(0.5, input.advantage_bonus ?? 0));
  let multiplier: number;
  if (input.spell_type === "hybrid") {
    const factor = (type: string) => relation(type) > 1 ? 1.25 : relation(type) < 1 ? 0.8 : 1;
    multiplier = Math.max(0.8, Math.min(1.25, Math.pow(factor(input.primary_type ?? ""), 0.65) * Math.pow(factor(input.secondary_type ?? ""), 0.35)));
    if (multiplier > 1) multiplier += advantage;
  } else {
    const value = relation(input.attacker_type);
    multiplier = value > 1 ? 1.18 + advantage : value < 1 ? Math.min(0.84 + (input.disadvantage_reduction ?? 0), 1) : 1;
  }
  const neutralize = Math.max(input.attacker_neutralize ?? 0, input.defender_neutralize ?? 0, input.attacker_hom_neutralize ?? 0, input.defender_hom_neutralize ?? 0);
  return 1 + (multiplier - 1) * (1 - neutralize);
}

/** Direct-hit arithmetic from _attack_entity; does not apply statuses or HP. */
export function normalDirectDamage(input: {
  attack: number; defense: number; power: number; type_multiplier: number;
  attack_down?: number; attack_boost?: number; anomaly_multiplier?: number;
  incoming_multiplier?: number; vulnerability?: number; shield?: number;
  dispel?: number; pierce?: number; ultra?: boolean;
}): number {
  const round = (n: number) => n < 0 ? -Math.round(-n) : Math.round(n);
  const clamp = (n: number, low: number, high: number) => Math.max(low, Math.min(high, n));
  let attack = Math.trunc(input.attack);
  if ((input.attack_down ?? 0) > 0) attack = round(attack * (1 - input.attack_down!));
  if ((input.attack_boost ?? 0) > 0) attack = round(attack * (1 + input.attack_boost!));
  let damage = Math.max(1, round((attack - Math.trunc(input.defense * 0.5)) * input.type_multiplier * input.power * (input.anomaly_multiplier ?? 1)));
  damage = Math.max(1, round(damage * clamp(input.incoming_multiplier ?? 1, 0.1, 1)));
  if ((input.vulnerability ?? 0) > 0) damage = round(damage * (1 + input.vulnerability!));
  if ((input.shield ?? 0) > 0) damage = round(damage * (1 - input.shield! * (1 - clamp(input.dispel ?? 0, 0, 1)) * (1 - clamp(input.pierce ?? 0, 0, 1))));
  return input.ultra ? damage * 2 : damage;
}

/** Cooldowns tick when this fighter acts, before stun is checked. */
export function normalActionCooldowns(cooldowns: Record<string, number>, spell?: { id: string; cooldown_turns: number }): Record<string, number> {
  const next: Record<string, number> = {};
  for (const [id, value] of Object.entries(cooldowns)) {
    if (!Number.isSafeInteger(value) || value < 0) throw new Error("INVALID_COOLDOWN");
    next[id] = Math.max(0, value - 1);
  }
  if (spell) {
    if (!spell.id || !Number.isSafeInteger(spell.cooldown_turns) || spell.cooldown_turns < 0 || (cooldowns[spell.id] ?? 0) > 0) throw new Error("INVALID_COOLDOWN");
    next[spell.id] = spell.cooldown_turns;
  }
  return next;
}
