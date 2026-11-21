/** Metadata lives on server-owned fighters; numeric poison remains unchanged. */
export function recordPoisonChange(fighter: any, previous: number, source: string | null): void {
  const current = fighter?.status?.poison ?? 0;
  if (current <= 0) delete fighter.poison_source;
  else if (current > previous) fighter.poison_source = typeof source === "string" && source.length > 0 ? source : null;
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
