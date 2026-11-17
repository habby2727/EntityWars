/**
 * PvP groundwork only. Inputs and subsequent states must come from trusted server
 * storage; this module does not authenticate ownership or persist decisions.
 * Basic spell effects are supported; unimplemented actions fail closed.
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
  base.name = displayName(base.name); base.hom_name = displayName(base.hom_name);
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
  if (decision.spell_id !== undefined && (typeof decision.spell_id !== "string" || !f.spell_ids.includes(decision.spell_id) || !f.spells.some(s => s.id === decision.spell_id) || (f.spell_cooldowns[decision.spell_id] ?? 0) > 0)) return { error: "INVALID_DECISION" };
  if (decision.switch_slot !== undefined && (![1, 2].includes(decision.switch_slot) || decision.switch_slot === f.active_weapon_slot || !f.weapons[decision.switch_slot - 1] || decision.ultra)) return { error: "INVALID_DECISION" };
  if (decision.hom_action && decision.hom_action !== "hold" && !pvpHomReady(f)) return { error: "INVALID_DECISION" };
  if (decision.ultra && (state.battle_index !== 3 || state.wins.left !== 1 || state.wins.right !== 1 || state.sudden_death || f.ultra_used)) return { error: "INVALID_DECISION" };
  return { ok: true };
}

/** Resolve attacks and basic spell effects. RNG returns a uniform [0,1) value. */
export function resolvePvpExchange(state: PvpCombatState, leftDecision: PvpDecision, rightDecision: PvpDecision, rng: (turn: number, draw: number) => number): PvpError | { state: PvpCombatState; events: any[] } {
  if (!state || (state as any).battle_over || state.fighters?.left?.hp <= 0 || state.fighters?.right?.hp <= 0 || "error" in validatePvpDecision(state, "left", leftDecision) || "error" in validatePvpDecision(state, "right", rightDecision) || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const decisions = { left: leftDecision, right: rightDecision };
  const supportedStatuses = new Set(["poison", "stun", "shield_pct", "atk_boost", "vuln_pct", "atk_down", "hom_stun", "reflect_pct", "tempo_bonus", "focus_next", "misalign_next", "poison_on_reflect"]);
  const supportedEffects = new Set(["heal", "shield", "reflect", "atk_boost", "atk_down", "vuln", "poison", "hom_stun", "type_neutralize", "focus_next", "misalign_next", "tempo_shift", "cleanse_one", "poison_on_reflect"]);
  for (const side of ["left", "right"] as const) {
    const f: any = state.fighters[side], d = decisions[side];
    const spell = f.spells.find((s: any) => s.id === d.spell_id);
    if (d.switch_slot !== undefined || (d.hom_action && d.hom_action !== "hold") || !["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].includes(f.type) || !spell || !((spell.category === "attack" && spell.power_mult > 0) || (spell.category === "support" && spell.power_mult === 0)) || !Array.isArray(spell.effects) || spell.effects.some((e: any) => !object(e) || !supportedEffects.has(e.kind) || !["self", "enemy"].includes(e.target) || !number(e.value) || (e.kind !== "tempo_shift" && e.value < 0)) || f.inspiration_pending || f.strategic_trap || f.strategic_heal_suppression || Object.keys(f.status).some(key => !supportedStatuses.has(key))) return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
  }
  if (state.physical_anomaly || state.strategic_delayed?.length || state.strategic_jams?.length) return { error: "PVP_COMBAT_PARITY_UNAVAILABLE" };
  const next = structuredClone(state), events: any[] = [], turn = state.turn + 1;
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
  try {
    next.turn = turn;
    for (const side of sides) {
      const f = next.fighters[side];
      f.spell_hit_last_exchange = f.spell_hit_this_exchange; f.spell_hit_this_exchange = false;
      f.spell_neutralize_active = f.spell_neutralize_pending; f.spell_neutralize_pending = 0;
      if (decisions[side].ultra) f.ultra_used = true;
    }
    const l = pvpInitiative(next.fighters.left), r = pvpInitiative(next.fighters.right);
    next.fighters.left = l.fighter; next.fighters.right = r.fighter;
    const order = normalInitiativeOrder(l.initiative, r.initiative);
    for (const side of order) {
      const opponent = other(side), a: any = next.fighters[side], b: any = next.fighters[opponent], decision = decisions[side];
      if (a.hp <= 0 || b.hp <= 0) break;
      const spell = a.spells.find((s: any) => s.id === decision.spell_id);
      a.spell_cooldowns = normalActionCooldowns(a.spell_cooldowns, spell);
      emit(side, spell.category === "attack" && a.status.stun <= 0 ? "damage" : "buff", " uses ", { kind: "spell", spell_id: spell.id, spell_name: spell.name, spell_meta: { id: spell.id, context: { spell: structuredClone(spell), actual_damage: 0, direct_damage: 0, pierce: 0, dispel: 0, ultra: !!decision.ultra } }, suffix: ".", target_side: opponent });
      const spellContext = events[events.length - 1].spell_meta.context;
      if (a.status.stun > 0) { a.status.stun--; emit(side, "debuff", " is stunned and skips the spell.", { kind: "stun", spell_id: spell.id }); continue; }
      if (spell.category === "attack") {
      const focus = a.status.focus_next ?? 0, misalign = a.status.misalign_next ?? 0;
      if (focus > 0 || misalign > 0) { delete a.status.focus_next; delete a.status.misalign_next; }
      if ((b.item_fx.evasion_pct ?? 0) > 0 && draw() < b.item_fx.evasion_pct) { emit(opponent, "miss", " evades.", { kind: "evade", target_side: side, spell_id: spell.id }); continue; }
      let accuracy = spell.accuracy;
      if (a.atk > b.def * 1.6) accuracy -= 0.08;
      if (a.max_hp > b.max_hp && a.max_hp > 0) accuracy -= Math.max(0, Math.min(0.15, (a.max_hp - b.max_hp) / a.max_hp * 0.2));
      if (focus > 0) accuracy = Math.min(0.99, accuracy + focus);
      if (misalign > 0) accuracy = Math.max(0.55, accuracy - misalign);
      if (draw() >= Math.max(0, Math.min(1, accuracy))) { emit(side, "miss", " misses.", { kind: "miss", target_side: opponent, spell_id: spell.id }); continue; }
      const as = a.hom_spent ? {} : a.hom_synergy, bs = b.hom_spent ? {} : b.hom_synergy;
      const mult = normalSpellMultiplier({ attacker_type: a.type, defender_type: b.type, spell_type: spell.type, primary_type: spell.primary_type, secondary_type: spell.secondary_type, effectiveness: (next.types as any).effectiveness, advantage_bonus: a.hom_spent ? 0 : (as.type_adv_bonus ?? 0) + (a.hom_bonus.favorable_type_bonus ?? 0), disadvantage_reduction: a.item_fx.disadvantage_reduction, attacker_neutralize: a.spell_neutralize_active, defender_neutralize: b.spell_neutralize_active, attacker_hom_neutralize: as.type_neutralize, defender_hom_neutralize: bs.type_neutralize });
      const amount = normalDirectDamage({ attack: a.atk, defense: b.def, power: spell.power_mult, type_multiplier: mult, attack_down: a.status.atk_down, attack_boost: a.status.atk_boost, incoming_multiplier: bs.incoming_mult, vulnerability: b.status.vuln_pct, shield: b.status.shield_pct, ultra: decision.ultra });
      if (a.status.atk_down > 0) emit(side, "debuff", " shakes off the weakness.", {kind: "status_consumed", status: "atk_down", spell_id: spell.id});
      if (a.status.atk_boost > 0) emit(side, "combo", " expends the surge.", {kind: "status_consumed", status: "atk_boost", spell_id: spell.id});
      if (b.status.vuln_pct > 0) emit(side, "combo", " exploits vulnerability.", {kind: "status_consumed", status: "vuln_pct", target_side: opponent, spell_id: spell.id});
      a.status.atk_down = 0; a.status.atk_boost = 0; b.status.vuln_pct = 0;
      if (b.status.shield_pct > 0) clearDefense(b, "shield_pct");
      spellContext.direct_damage = Math.min(b.hp, amount); spellContext.actual_damage += spellContext.direct_damage;
      dmg(side, opponent, amount, "damage", spell); events[events.length - 1].effectiveness = mult;
      if (amount > 0) b.spell_hit_this_exchange = true;
      if (b.status.reflect_pct > 0) {
        const ignored = (a.item_fx.ignore_reflect_chance ?? 0) > 0 && draw() < a.item_fx.ignore_reflect_chance;
        const reflected = ignored ? 0 : Math.round(amount * b.status.reflect_pct);
        if (reflected > 0) { dmg(opponent, side, reflected, "reflect", spell); a.spell_hit_this_exchange = true; }
        if (!ignored && (b.status.poison_on_reflect ?? 0) > 0) a.status.poison = Math.max(a.status.poison, b.status.poison_on_reflect);
        clearDefense(b, "reflect_pct"); delete b.status.poison_on_reflect;
      }
      for (const key of ["true_on_hit", "dot_true"]) {
        const value = Math.trunc(a.item_fx[key] ?? 0);
        if (value > 0) { spellContext.actual_damage += Math.min(b.hp, value); dmg(side, opponent, value, key, spell); if (key === "dot_true" && a.item_fx.vuln_on_hit > 0) b.status.vuln_pct = Math.max(b.status.vuln_pct, a.item_fx.vuln_on_hit); }
      }
      const homDot = Math.max(0, Math.trunc(as.dot_true ?? 0)); if (homDot > 0) dmg(side, opponent, homDot, "hom_dot", spell);
      const proc = Math.floor(draw() * 0x100000000) % 100;
      if (a.type === "vitriol" && proc < 30) b.status.poison = 2;
      if (a.type === "mercury" && proc < 20) b.status.stun = 1;
      if (a.type === "sulfur" && proc < 20) b.status.atk_down = Math.max(b.status.atk_down, 0.15);
      if (a.type === "sodium" && proc < 20) applyOther(a, "shield_pct", 0.12);
      if (a.type === "aether" && proc < 20) b.status.vuln_pct = Math.max(b.status.vuln_pct, 0.12);
      if (a.type === "gold" && proc < 20) { const before = a.hp; a.hp = Math.min(a.max_hp, a.hp + 3); if (a.hp !== before) emit(side, "heal", " restores 3 HP.", { kind: "elemental_heal", spell_id: spell.id, hp: a.hp, amount: a.hp - before }); }
      if (proc < (a.type === "vitriol" ? 30 : 20) && a.type !== "gold") emit(side, a.type === "sodium" ? "shield" : "debuff", " triggers an elemental effect.", {kind: "elemental_proc", spell_id: spell.id, target_side: a.type === "sodium" ? side : opponent, status: ({vitriol:"poison",mercury:"stun",sulfur:"atk_down",sodium:"shield_pct",aether:"vuln_pct"} as Record<string,string>)[a.type]});
      } else {
        if (draw() >= spell.accuracy) { emit(side, "miss", "'s spell misses.", {kind: "miss", spell_id: spell.id}); continue; }
        emit(side, "buff", "'s spell succeeds.", {kind: "support_hit", spell_id: spell.id, show_spell_link: false});
      }
      for (const effect of spell.effects) {
        const targetSide: PvpSide = effect.target === "self" ? side : opponent;
        const recipient: any = next.fighters[targetSide];
        const kind: string = effect.kind;
        let value: number = effect.value;
        if (decision.ultra && kind !== "cleanse_one") {
          value *= 2;
          if (["atk_boost", "atk_down", "shield", "reflect", "vuln", "focus_next", "misalign_next", "type_neutralize"].includes(kind)) value = Math.max(0, Math.min(kind === "shield" || kind === "reflect" ? 0.95 : 1, value));
        }
        const award = () => {
          if (targetSide === side || a.inspiration_used_this_battle || a.inspiration >= 3) return;
          a.inspiration++; a.inspiration_pending = a.inspiration === 3;
          emit(side, "inspiration", ` gains inspiration (${a.inspiration}/3).`, {kind: "inspiration", source: kind, value: a.inspiration, target_side: targetSide, spell_id: spell.id, show_spell_link: false});
        };
        if (kind === "heal") {
          const before = recipient.hp; recipient.hp = Math.min(recipient.max_hp, recipient.hp + Math.trunc(value));
          emit(targetSide, "heal", ` restores ${recipient.hp - before} HP.`, {kind: "heal", spell_id: spell.id, show_spell_link: false, hp: recipient.hp, amount: recipient.hp - before, source_side: side});
        } else if (kind === "cleanse_one") {
          const field = ["poison", "stun", "vuln_pct", "atk_down", "misalign_next"].find(k => (recipient.status[k] ?? 0) > 0);
          if (field) recipient.status[field] = 0;
          emit(targetSide, "buff", " cleanses one negative status.", {kind: "cleanse_one", status: field ?? null, spell_id: spell.id, show_spell_link: false, source_side: side});
        } else if (kind === "type_neutralize") {
          recipient.spell_neutralize_pending = Math.max(recipient.spell_neutralize_pending, value);
          emit(targetSide, "buff", " prepares type neutralization.", {kind, value: recipient.spell_neutralize_pending, spell_id: spell.id, show_spell_link: false, source_side: side});
        } else if (kind === "poison_on_reflect") {
          recipient.status.poison_on_reflect = Math.trunc(value);
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
          emit(targetSide, kind === "shield" || kind === "reflect" ? "shield" : kind === "atk_boost" || kind === "focus_next" ? "buff" : "debuff", ` gains ${kind}.`, {kind: "status_applied", status: field, value: recipient.status[field], previous: before, spell_id: spell.id, show_spell_link: false, source_side: side});
          if (["atk_down", "vuln", "poison", "hom_stun", "misalign_next"].includes(kind) && recipient.status[field] > before) award();
        }
      }
    }
    if (next.fighters.left.hp > 0 && next.fighters.right.hp > 0) for (const side of sides) {
      const f = next.fighters[side]; if (f.status.poison > 0) { f.status.poison--; f.hp = Math.max(0, f.hp - 2); f.spell_hit_this_exchange = true; emit(side, "debuff", " suffers poison.", { kind: "poison", damage: 2, hp: f.hp }); }
    }
    for (const side of sides) { const f = next.fighters[side]; if (!f.hom_spent) f.hom_energy = Math.min(f.hom_max_energy, f.hom_energy + 1); f.spell_neutralize_active = 0; }
    if (next.fighters.left.hp <= 0 || next.fighters.right.hp <= 0) {
      (next as any).battle_over = true;
      (next as any).battle_result = next.fighters.left.hp <= 0 && next.fighters.right.hp <= 0 ? "draw" : next.fighters.left.hp <= 0 ? "right" : "left";
    } else {
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
    return { state: next, events };
  } catch (err) { if (err instanceof Error && err.message === "INVALID_RNG") return { error: "INVALID_RNG" }; throw err; }
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
