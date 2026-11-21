import { evaluateExpeditionPassive, type PassiveContext, type PassiveEvent } from "./expedition_passives";
import { recordPoisonChange } from "./combat_event_provenance";
import { strategicHeal } from "./strategic_effects";

// Staging-only state machine: no live combat path imports this module. The
// engines must provide authoritative, source-attributed events before enabling it.
type TemporaryKind = "power_flat" | "guard_flat" | "tempo_flat" | "accuracy_pct" | "evasion_pct";
type Duration = "current_attack" | "current_exchange" | "next_exchange";
type Modifier = { kind: TemporaryKind; amount: number; duration: Duration; exchange: number };
export type ExpeditionPassiveState = { id: string; level: number; exchange: number; markers: string[]; modifiers: Modifier[]; attacks_made: number; consecutive_spell_hits: number };
export type PassiveOutcome = { state: ExpeditionPassiveState; instant: {kind: string; target: string; amount: number}[]; activated: boolean };

export function newExpeditionPassiveState(id: string, level: number): ExpeditionPassiveState {
  // Validate identity and level against the single authoritative E3 catalog.
  evaluateExpeditionPassive(id, level, {exchange: 1, fighter: {hp: 1, max_hp: 1, shielded: false, consecutive_spell_hits: 0, attacks_made: 0}, target: {debuffed: false}, type_relation: "neutral", poison_damage: 0, applied_markers: []}, "before_exchange");
  return {id, level, exchange: 0, markers: [], modifiers: [], attacks_made: 0, consecutive_spell_hits: 0};
}

export function beginPassiveExchange(state: ExpeditionPassiveState, exchange: number): ExpeditionPassiveState {
  if (!Number.isSafeInteger(exchange) || exchange !== state.exchange + 1) throw new Error("INVALID_PASSIVE_EXCHANGE");
  const next = structuredClone(state);
  next.exchange = exchange;
  next.markers = [];
  next.modifiers = next.modifiers.filter(m => m.exchange >= exchange);
  return next;
}

export function triggerExpeditionPassive(state: ExpeditionPassiveState, event: PassiveEvent, context: Omit<PassiveContext, "exchange" | "applied_markers">): PassiveOutcome {
  if (state.exchange < 1) throw new Error("INVALID_PASSIVE_EXCHANGE");
  const next = structuredClone(state);
  const proposal = evaluateExpeditionPassive(next.id, next.level, {...context, exchange: next.exchange, applied_markers: next.markers, fighter: {...context.fighter, attacks_made: next.attacks_made, consecutive_spell_hits: next.consecutive_spell_hits}}, event);
  if (!proposal) return {state: next, instant: [], activated: false};
  next.markers.push(proposal.marker);
  const instant: PassiveOutcome["instant"] = [];
  for (const effect of proposal.effects) {
    if (effect.duration === "instant") { instant.push({kind: effect.kind, target: effect.target, amount: effect.amount}); continue; }
    const activeExchange = next.exchange + (effect.duration === "next_exchange" ? 1 : 0);
    // Replace the same passive modifier for the same activation window.
    next.modifiers = next.modifiers.filter(m => !(m.kind === effect.kind && m.exchange === activeExchange));
    next.modifiers.push({kind: effect.kind as TemporaryKind, amount: effect.amount, duration: effect.duration as Duration, exchange: activeExchange});
  }
  return {state: next, instant, activated: true};
}

export function passiveModifiers(state: ExpeditionPassiveState): Record<string, number> {
  const result: Record<string, number> = {};
  for (const modifier of state.modifiers) if (modifier.exchange === state.exchange) result[modifier.kind] = (result[modifier.kind] ?? 0) + modifier.amount;
  return result;
}

export function finishPassiveAttack(state: ExpeditionPassiveState): ExpeditionPassiveState {
  const next = structuredClone(state);
  next.attacks_made++;
  next.modifiers = next.modifiers.filter(m => !(m.exchange === next.exchange && m.duration === "current_attack"));
  return next;
}

export function recordPassiveSpellHit(state: ExpeditionPassiveState, hit: boolean): ExpeditionPassiveState {
  const next = structuredClone(state);
  next.consecutive_spell_hits = hit ? next.consecutive_spell_hits + 1 : 0;
  return next;
}

export function finishPassiveExchange(state: ExpeditionPassiveState): ExpeditionPassiveState {
  const next = structuredClone(state);
  next.modifiers = next.modifiers.filter(m => m.exchange > next.exchange);
  return next;
}

export function clearExpeditionPassive(state: ExpeditionPassiveState): ExpeditionPassiveState {
  return newExpeditionPassiveState(state.id, state.level);
}

/** Apply a server-recorded choice after its exchange has ended. */
export function triggerInspirationActivation(state: ExpeditionPassiveState, activation: {marker: string; actor: string; exchange: number; activates_at: number}, context: Omit<PassiveContext, "exchange" | "applied_markers">): PassiveOutcome {
  if (!activation || !activation.actor || activation.exchange !== state.exchange || activation.activates_at !== state.exchange + 1 || activation.marker !== `inspiration:${activation.actor}:${activation.exchange}`) throw new Error("INVALID_INSPIRATION_ACTIVATION");
  return triggerExpeditionPassive(state, "inspiration_activated", context);
}

/** Apply the shared passive proposal to a server-owned fighter and target. */
export function applyCombatPassive(fighter: any, target: any, event: PassiveEvent, types: any, actorId: string, targetId: string, events: any[], poisonDamage = 0): void {
  if (!fighter?.expedition_passive || !target || fighter.hp <= 0) return;
  const relation = types?.effectiveness?.[fighter.type]?.[target.element_type || target.type] ?? 1;
  const debuffs = ["poison", "stun", "vuln", "vuln_pct", "atk_down", "hom_stun", "misalign_next"];
  const context = {fighter: {hp: fighter.hp, max_hp: fighter.max_hp, shielded: (fighter.status?.shield_pct ?? fighter.status?.shield ?? 0) > 0, consecutive_spell_hits: 0, attacks_made: 0}, target: {debuffed: debuffs.some(key => (target.status?.[key] ?? 0) > 0)}, type_relation: relation > 1 ? "advantage" as const : relation < 1 ? "disadvantage" as const : "neutral" as const, poison_damage: poisonDamage};
  const result = triggerExpeditionPassive(fighter.expedition_passive, event, context);
  fighter.expedition_passive = result.state;
  if (!result.activated) return;
  events.push({kind: "hom_passive", actor: actorId, target: targetId, passive_id: result.state.id, trigger: event});
  for (const effect of result.instant) {
    if (effect.kind === "poison" && target.hp > 0) {
      const previous = target.status.poison ?? 0;
      target.status.poison = Math.max(previous, effect.amount);
      recordPoisonChange(target, previous, actorId);
      if (target.status.poison > previous) events.push({kind: "status_applied", actor: actorId, target: targetId, status: "poison", previous, value: target.status.poison, source: "hom_passive"});
    } else if (effect.kind === "heal" && fighter.hp > 0) {
      const amount = Math.min(strategicHeal(fighter, effect.amount), fighter.max_hp - fighter.hp);
      fighter.hp += amount;
      if (amount > 0) events.push({kind: "heal", actor: actorId, target: actorId, amount, hp: fighter.hp, source: "hom_passive"});
    }
  }
}
