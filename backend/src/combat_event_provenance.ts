/** Metadata lives on server-owned fighters; numeric poison remains unchanged. */
export function recordPoisonChange(fighter: any, previous: number, source: string | null): void {
  let current = fighter?.status?.poison ?? 0;
  let transferred = false;
  if (fighter?.combat_rules_version === 2) {
    if (fighter.poison_transfer_pending) {
      transferred = true;
      delete fighter.poison_transfer_pending;
    } else if ((source !== null || current > previous) && current > 0) {
      if (previous > 0) fighter.status.poison = current = previous;
      else {
        fighter.status.poison = current = 3;
        const exchange = fighter.combat_exchange ?? 0;
        const applied_exchange = fighter.poison_last_tick === exchange ? exchange + 1 : exchange;
        fighter.poison_effect = { stage: 0, applied_exchange, expires_exchange: applied_exchange + 2, source };
      }
    }
    if (current <= 0) delete fighter.poison_effect;
  }
  if (current <= 0) delete fighter.poison_source;
  else if (!transferred && current > previous) fighter.poison_source = typeof source === "string" && source.length > 0 ? source : null;
}

/** Legacy sessions have no rules version and retain their fixed three-HP ticks. */
export function poisonTickDamage(fighter: any): number {
  if (fighter?.combat_rules_version !== 2) return 3;
  fighter.poison_last_tick = fighter.combat_exchange;
  const applied_exchange = fighter.combat_exchange ?? 0;
  const effect = fighter.poison_effect ??= { stage: 0, applied_exchange, expires_exchange: applied_exchange + 2, source: fighter.poison_source ?? null };
  const stage = Math.max(0, Math.min(2, Math.trunc(effect.stage ?? 0)));
  effect.stage = stage + 1;
  return Math.max(1, Math.round(fighter.max_hp * [0.025, 0.05, 0.06][stage]));
}

export function poisonTickMetadata(fighter: any, victim: string, validSources: readonly string[], actualDamage: number, exchange: number) {
  const source = typeof fighter?.poison_source === "string" && validSources.includes(fighter.poison_source) ? fighter.poison_source : null;
  return { source, victim, actual_damage: actualDamage, exchange };
}

/** A persisted marker prevents duplicate processing of the same victim tick. */
export function resolveOpponentPoisonDamage(tick: {source: string | null; victim: string; actual_damage: number; exchange: number}, owner: string, markers: readonly string[]) {
  if (!owner || tick.source !== owner || tick.victim === owner || !tick.victim || !Number.isSafeInteger(tick.actual_damage) || tick.actual_damage <= 0 || !Number.isSafeInteger(tick.exchange) || tick.exchange < 1 || !Array.isArray(markers)) return null;
  const marker = `poison:${tick.exchange}:${tick.victim}`;
  return markers.includes(marker) ? null : {marker, amount: tick.actual_damage};
}

/** Called only after a successful server-validated choice. */
export function recordInspirationActivation(fighter: any, actor: string, exchange: number) {
  if (!fighter || !actor || !Number.isSafeInteger(exchange) || exchange < 0) throw new Error("INVALID_INSPIRATION_ACTIVATION");
  const activation = { marker: `inspiration:${actor}:${exchange}`, actor, exchange, activates_at: exchange + 1 };
  fighter.inspiration_activation = activation;
  return structuredClone(activation);
}
