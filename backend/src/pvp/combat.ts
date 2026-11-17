/**
 * PvP groundwork only. Inputs and subsequent states must come from trusted server
 * storage; this module does not authenticate ownership or persist decisions.
 * Resolution deliberately fails closed until normal combat parity is implemented.
 */
export type PvpSide = "left" | "right";
export type PvpError = { error: "UNTRUSTED_SETUP" | "INVALID_DECISION" | "PVP_COMBAT_PARITY_UNAVAILABLE" };
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
  inspiration: number; inspiration_pending: boolean; inspiration_used_this_battle: boolean;
  temporary_spell_id: string; temporary_replaced_slot: number;
  spell_hit_this_exchange: boolean; spell_hit_last_exchange: boolean;
  spell_neutralize_pending: number; spell_neutralize_active: number;
};
export type PvpCombatState = { turn: number; round: number; player_turn: boolean; battle_index: number; wins: Record<PvpSide, number>; sudden_death: boolean; fighters: Record<PvpSide, PvpFighter>; types: unknown; physical_anomaly: any | null; strategic_delayed: any[]; strategic_jams: any[] };

const object = (x: any): x is Record<string, any> => x !== null && typeof x === "object" && !Array.isArray(x);
const number = (x: any) => typeof x === "number" && Number.isFinite(x);
const itemKeys = new Set(["power_flat", "guard_flat", "tempo_flat", "true_on_hit", "dot_true", "vuln_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"]);
const pctKeys = new Set(["ward_pct", "reflect_pct", "evasion_pct", "disadvantage_reduction", "ignore_reflect_chance", "vuln_on_hit"]);
const synergyKeys = new Set(["power_flat", "guard_flat", "tempo_flat", "type_adv_bonus", "type_neutralize", "incoming_mult", "reflect_pct", "dot_true", "item_effect_mult"]);
const statusInitial = () => ({ poison: 0, stun: 0, shield_pct: 0, atk_boost: 0, vuln_pct: 0, atk_down: 0, hom_stun: 0, reflect_pct: 0, tempo_bonus: 0 });
const validLevel = (v: any) => v === undefined || (Number.isInteger(v) && v >= 0 && v <= 10);
const validCatalog = (entries: unknown): entries is any[] => Array.isArray(entries) && entries.every(e => object(e) && typeof e.id === "string" && e.id.length > 0) && new Set(entries.map(e => e.id)).size === entries.length;

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
  const base: PvpFighter = structuredClone({ player_id: snapshot.player_id, entity, weapons: weapons.map(w => effectiveWeapon(w, itemProgress, catalogs)), homunculus: hom, spells, item_progress: itemProgress, homunculus_progress: homProgress, spell_progress: snapshot.spell_progress ?? {}, active_weapon_slot: 1, spell_cooldowns: {}, hom_energy: 0, hom_spent: hom === null, ultra_used: false, id: entity.id, name: entity.name, type: entity.type, hp: 0, max_hp: 0, atk: 0, def: 0, hom_id: hom?.id ?? "", hom_name: hom?.name ?? "", hom_max_energy: 6, hom_ready_at: 3, hom_synergy: synergy, hom_bonus, mutation, mods: { atk_flat: 0, def_flat: 0 }, item_fx: {}, active_weapon: null, status: statusInitial(), spell_ids: [...snapshot.spell_ids], original_spell_ids: [...snapshot.spell_ids], inspiration: 0, inspiration_pending: false, inspiration_used_this_battle: false, temporary_spell_id: "", temporary_replaced_slot: -1, spell_hit_this_exchange: false, spell_hit_last_exchange: false, spell_neutralize_pending: 0, spell_neutralize_active: 0 });
  const result = refreshPvpWeapon(base); result.hp = result.max_hp; return result;
}

/** Snapshots and catalogs must already be validated and owned by the server. */
export function createPvpCombatState(left: PvpSnapshot, right: PvpSnapshot, catalogs: PvpCatalogs): PvpCombatState | PvpError {
  if (!catalogs || ![catalogs.entities, catalogs.items, catalogs.spells, catalogs.homunculi].every(validCatalog) || (catalogs.mutations !== undefined && !validCatalog(catalogs.mutations)) || !object(catalogs.types) || !object(catalogs.types.effectiveness) || !left || !right || left.player_id === right.player_id) return { error: "UNTRUSTED_SETUP" };
  try {
    const l = fighter(left, catalogs), r = fighter(right, catalogs);
    if (!l || !r || !object(catalogs.types.effectiveness[l.type]) || !object(catalogs.types.effectiveness[r.type]) || !number(catalogs.types.effectiveness[l.type][r.type]) || !number(catalogs.types.effectiveness[r.type][l.type])) return { error: "UNTRUSTED_SETUP" };
    return { turn: 0, round: 1, player_turn: true, battle_index: 1, wins: { left: 0, right: 0 }, sudden_death: false, fighters: { left: l, right: r }, types: structuredClone(catalogs.types), physical_anomaly: null, strategic_delayed: [], strategic_jams: [] };
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
  if (f.temporary_spell_id) f.spell_ids = [...f.original_spell_ids];
  f.original_spell_ids = [...f.spell_ids];
  f.temporary_spell_id = ""; f.temporary_replaced_slot = -1;
  f.inspiration = 0; f.inspiration_pending = false; f.inspiration_used_this_battle = false;
  for (const key of ["strategic_trap", "strategic_heal_suppression", "spell_ward", "spell_ward_baseline", "hom_reflect_active", "hom_other_reflect", "weapon_shield_pct", "other_shield_pct", "weapon_reflect_pct", "other_reflect_pct"]) delete f[key];
  f.hom_energy = 0; f.hp = f.max_hp; f.spell_cooldowns = {}; f.status = statusInitial();
  f.spell_hit_this_exchange = false; f.spell_hit_last_exchange = false;
  f.spell_neutralize_pending = 0; f.spell_neutralize_active = 0;
  return f;
}

/** Start the next battle after the caller has recorded its score and battle index. */
export function startPvpBattle(state: PvpCombatState): PvpCombatState {
  const next: PvpCombatState & Record<string, any> = structuredClone(state);
  next.turn = 0; next.round = 1; next.player_turn = true; next.fighters.left = resetPvpFighter(next.fighters.left); next.fighters.right = resetPvpFighter(next.fighters.right);
  next.physical_anomaly = null; next.strategic_delayed = []; next.strategic_jams = [];
  return next;
}

export function pvpHomReady(fighter: PvpFighter): boolean {
  return !fighter.hom_spent && fighter.hom_energy >= fighter.hom_ready_at;
}

/** _initiative consumes tempo_bonus; return the new fighter without mutating input. */
export function pvpInitiative(fighter: PvpFighter): { initiative: number; fighter: PvpFighter } {
  const next = structuredClone(fighter);
  const value = 10 + (next.active_weapon?.effects?.tempo_flat?.[0] ?? 0) + (next.hom_spent ? 0 : next.hom_synergy.tempo_flat ?? 0) + (next.status.tempo_bonus ?? 0);
  next.status.tempo_bonus = 0;
  return { initiative: value, fighter: next };
}

/** Decisions contain only the acting player's choice, never a target or opponent action. */
export function validatePvpDecision(state: PvpCombatState, side: PvpSide, decision: PvpDecision): { ok: true } | PvpError {
  if (!state || !state.fighters || (side !== "left" && side !== "right") || !decision || typeof decision !== "object" || Array.isArray(decision) || Object.keys(decision).some(k => !["turn", "spell_id", "switch_slot", "hom_action", "ultra"].includes(k))) return { error: "INVALID_DECISION" };
  const f = state.fighters[side];
  if (!f || !Number.isSafeInteger(decision.turn) || decision.turn !== state.turn + 1 || (decision.spell_id !== undefined) === (decision.switch_slot !== undefined) || (decision.ultra !== undefined && typeof decision.ultra !== "boolean") || (decision.hom_action !== undefined && !["hold", "attack", "sacrifice"].includes(decision.hom_action))) return { error: "INVALID_DECISION" };
  if (decision.spell_id !== undefined && (typeof decision.spell_id !== "string" || !f.spells.some(s => s.id === decision.spell_id) || (f.spell_cooldowns[decision.spell_id] ?? 0) > 0)) return { error: "INVALID_DECISION" };
  if (decision.switch_slot !== undefined && (![1, 2].includes(decision.switch_slot) || decision.switch_slot === f.active_weapon_slot || !f.weapons[decision.switch_slot - 1] || decision.ultra)) return { error: "INVALID_DECISION" };
  if (decision.hom_action && decision.hom_action !== "hold" && !pvpHomReady(f)) return { error: "INVALID_DECISION" };
  if (decision.ultra && (state.battle_index !== 3 || state.wins.left !== 1 || state.wins.right !== 1 || state.sudden_death || f.ultra_used)) return { error: "INVALID_DECISION" };
  return { ok: true };
}

/** No partial combat result is returned until the resolver has parity. */
export function resolvePvpExchange(state: PvpCombatState, leftDecision: PvpDecision, rightDecision: PvpDecision, _rng: (turn: number, draw: number) => number): PvpError {
  if ("error" in validatePvpDecision(state, "left", leftDecision) || "error" in validatePvpDecision(state, "right", rightDecision) || typeof _rng !== "function") return { error: "INVALID_DECISION" };
  return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
}

/** Normal combat.gd battle-end scoring, not yet connected to resolution. */
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
    multiplier = value > 1 ? 1.12 + advantage : value < 1 ? Math.min(0.92 + (input.disadvantage_reduction ?? 0), 1) : 1;
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
