const TYPES = new Set(["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"]);

export type PhysicalAnomaly = { id: string; favored_type: string; weakened_type: string; remaining_exchanges: number; activated_exchange: number };

export function validPhysicalAnomalySpell(spell: any): boolean {
  if (!spell || typeof spell.id !== "string" || !/^[a-z][a-z0-9_]{0,63}$/.test(spell.id) || spell.category !== "support" || spell.power_mult !== 0 || !Array.isArray(spell.effects)) return false;
  const effects = spell.effects.filter((e: any) => e?.kind === "physical_anomaly");
  if (effects.length !== 1 || effects[0].target !== "self" || effects[0].value !== 1) return false;
  const metadata = effects[0].favored_type === undefined ? spell : effects[0];
  return TYPES.has(metadata.favored_type) && TYPES.has(metadata.weakened_type) && metadata.favored_type !== metadata.weakened_type && metadata.outgoing_bonus === 0.15 && metadata.outgoing_penalty === 0.15 && metadata.duration_exchanges === 3;
}

export function castPhysicalAnomaly(spell: any, exchange: number): PhysicalAnomaly {
  if (!validPhysicalAnomalySpell(spell) || !Number.isSafeInteger(exchange) || exchange < 1) throw new Error("INVALID_PHYSICAL_ANOMALY");
  const effect = spell.effects.find((e: any) => e.kind === "physical_anomaly");
  const metadata = effect.favored_type === undefined ? spell : effect;
  return { id: spell.id, favored_type: metadata.favored_type, weakened_type: metadata.weakened_type, remaining_exchanges: 3, activated_exchange: exchange };
}

export function physicalAnomalyMultiplier(anomaly: PhysicalAnomaly | null | undefined, attackerType: string): number {
  if (!anomaly) return 1;
  return anomaly.favored_type === attackerType ? 1.15 : anomaly.weakened_type === attackerType ? 0.85 : 1;
}

export function tickPhysicalAnomaly(anomaly: PhysicalAnomaly | null | undefined, exchange: number): PhysicalAnomaly | null {
  if (!anomaly) return null;
  if (anomaly.activated_exchange >= exchange) return anomaly;
  return anomaly.remaining_exchanges <= 1 ? null : { ...anomaly, remaining_exchanges: anomaly.remaining_exchanges - 1 };
}
