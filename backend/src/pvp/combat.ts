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
export type PvpCatalogs = { entities: any[]; items: any[]; spells: any[]; homunculi: any[]; types: unknown };
export type PvpDecision = { turn: number; spell_id?: string; switch_slot?: 1 | 2; hom_action?: "hold" | "attack" | "sacrifice"; ultra?: boolean };
export type PvpFighter = {
  player_id: string; entity: any; weapons: (any | null)[]; homunculus: any | null; spells: any[];
  item_progress: unknown; homunculus_progress: unknown; spell_progress: unknown;
  active_weapon_slot: 1 | 2; spell_cooldowns: Record<string, number>;
  hom_energy: number; hom_spent: boolean; ultra_used: boolean;
};
export type PvpCombatState = { turn: number; battle_index: number; wins: Record<PvpSide, number>; sudden_death: boolean; fighters: Record<PvpSide, PvpFighter>; types: unknown };

function fighter(snapshot: PvpSnapshot, catalogs: PvpCatalogs): PvpFighter | null {
  if (!snapshot || typeof snapshot.player_id !== "string" || !snapshot.player_id || typeof snapshot.entity_id !== "string" || !Array.isArray(snapshot.weapon_ids) || snapshot.weapon_ids.length !== 2 || !Array.isArray(snapshot.spell_ids) || snapshot.spell_ids.length !== 4 || new Set(snapshot.spell_ids).size !== 4 || !snapshot.spell_ids.every(id => typeof id === "string" && id.length > 0) || !(snapshot.homunculus_id === null || typeof snapshot.homunculus_id === "string")) return null;
  const entity = catalogs.entities.find(e => e.id === snapshot.entity_id);
  if (!entity || typeof entity.type !== "string") return null;
  const weapons = snapshot.weapon_ids.map(id => id === null ? null : catalogs.items.find(i => i.id === id && i.slot === "build"));
  if (weapons.some(w => w === undefined) || (snapshot.weapon_ids[0] !== null && snapshot.weapon_ids[0] === snapshot.weapon_ids[1])) return null;
  const hom = snapshot.homunculus_id === null ? null : catalogs.homunculi.find(h => h.id === snapshot.homunculus_id);
  if (hom === undefined) return null;
  const spells = snapshot.spell_ids.map(id => catalogs.spells.find(s => s.id === id && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(entity.type)))));
  if (spells.some(s => !s)) return null;
  return structuredClone({ player_id: snapshot.player_id, entity, weapons, homunculus: hom, spells, item_progress: snapshot.item_progress ?? {}, homunculus_progress: snapshot.homunculus_progress ?? {}, spell_progress: snapshot.spell_progress ?? {}, active_weapon_slot: 1 as const, spell_cooldowns: {}, hom_energy: 0, hom_spent: hom === null, ultra_used: false });
}

/** Snapshots and catalogs must already be validated and owned by the server. */
export function createPvpCombatState(left: PvpSnapshot, right: PvpSnapshot, catalogs: PvpCatalogs): PvpCombatState | PvpError {
  if (!catalogs || ![catalogs.entities, catalogs.items, catalogs.spells, catalogs.homunculi].every(Array.isArray) || catalogs.types == null || !left || !right || left.player_id === right.player_id) return { error: "UNTRUSTED_SETUP" };
  const l = fighter(left, catalogs), r = fighter(right, catalogs);
  if (!l || !r) return { error: "UNTRUSTED_SETUP" };
  return { turn: 0, battle_index: 1, wins: { left: 0, right: 0 }, sudden_death: false, fighters: { left: l, right: r }, types: structuredClone(catalogs.types) };
}

/** Decisions contain only the acting player's choice, never a target or opponent action. */
export function validatePvpDecision(state: PvpCombatState, side: PvpSide, decision: PvpDecision): { ok: true } | PvpError {
  if (!state || !state.fighters || (side !== "left" && side !== "right") || !decision || typeof decision !== "object" || Array.isArray(decision) || Object.keys(decision).some(k => !["turn", "spell_id", "switch_slot", "hom_action", "ultra"].includes(k))) return { error: "INVALID_DECISION" };
  const f = state.fighters[side];
  if (!f || !Number.isSafeInteger(decision.turn) || decision.turn !== state.turn + 1 || (decision.spell_id !== undefined) === (decision.switch_slot !== undefined) || (decision.ultra !== undefined && typeof decision.ultra !== "boolean") || (decision.hom_action !== undefined && !["hold", "attack", "sacrifice"].includes(decision.hom_action))) return { error: "INVALID_DECISION" };
  if (decision.spell_id !== undefined && (typeof decision.spell_id !== "string" || !f.spells.some(s => s.id === decision.spell_id) || (f.spell_cooldowns[decision.spell_id] ?? 0) > 0)) return { error: "INVALID_DECISION" };
  if (decision.switch_slot !== undefined && (![1, 2].includes(decision.switch_slot) || decision.switch_slot === f.active_weapon_slot || !f.weapons[decision.switch_slot - 1] || decision.ultra)) return { error: "INVALID_DECISION" };
  if (decision.hom_action && decision.hom_action !== "hold" && (f.hom_spent || f.hom_energy < 3)) return { error: "INVALID_DECISION" };
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
