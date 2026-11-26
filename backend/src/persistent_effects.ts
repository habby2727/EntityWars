export type PersistentStatus = "burn" | "lethargy";

export function validChance(effect: any): boolean {
  if (["burn", "lethargy"].includes(effect?.kind) && (effect.target !== "enemy" || effect.value !== 1 || typeof effect.chance !== "number")) return false;
  return effect?.chance === undefined || (typeof effect.chance === "number" && Number.isFinite(effect.chance) && effect.chance >= 0 && effect.chance <= 1);
}

export function statusActive(fighter: any, kind: PersistentStatus, turn: number): boolean {
  const status = fighter?.[`${kind}_effect`];
  return !!status && status.applied_exchange < turn && turn <= status.expires_exchange;
}

export function validPersistentFighter(fighter: any, version: number | undefined, turn: number): boolean {
  if (version !== 2) return true;
  const remaining = fighter?.status?.poison;
  if (remaining !== undefined && (!Number.isSafeInteger(remaining) || remaining < 0 || remaining > 3)) return false;
  for (const kind of ["burn", "lethargy"] as const) {
    const effect = fighter?.[`${kind}_effect`];
    if (effect && (typeof effect.source !== "string" || !Number.isSafeInteger(effect.applied_exchange) || !Number.isSafeInteger(effect.expires_exchange) || effect.applied_exchange > turn || effect.expires_exchange !== effect.applied_exchange + 2 || effect.expires_exchange <= turn)) return false;
  }
  const poison = fighter?.poison_effect;
  return !poison || (Number.isSafeInteger(poison.stage) && poison.stage >= 0 && poison.stage <= 2 && Number.isSafeInteger(poison.applied_exchange) && poison.applied_exchange <= turn + 1 && (poison.expires_exchange === undefined || poison.expires_exchange === poison.applied_exchange + 2) && (poison.source === null || typeof poison.source === "string"));
}

export function validPendingDrains(state: any, sources: readonly string[], targets: readonly string[]): boolean {
  if (state?.combat_rules_version !== 2 || state.pending_drains === undefined) return true;
  return Array.isArray(state.pending_drains) && state.pending_drains.every((entry: any) => entry && sources.includes(entry.source) && targets.includes(entry.target) && entry.source !== entry.target && Number.isSafeInteger(entry.due_exchange) && entry.due_exchange > state.turn);
}

export function applyPersistentStatus(fighter: any, kind: PersistentStatus, source: string, turn: number): boolean {
  const key = `${kind}_effect`, previous = fighter[key];
  if (previous && previous.expires_exchange >= turn) return false;
  fighter[key] = { source, applied_exchange: turn, expires_exchange: turn + 2 };
  return true;
}

export function expirePersistentStatuses(fighter: any, turn: number): PersistentStatus[] {
  const expired: PersistentStatus[] = [];
  for (const kind of ["burn", "lethargy"] as const) {
    const key = `${kind}_effect`;
    if (fighter?.[key]?.expires_exchange <= turn) { delete fighter[key]; expired.push(kind); }
  }
  return expired;
}

export function cleansePersistentStatus(fighter: any): PersistentStatus | null {
  for (const kind of ["burn", "lethargy"] as const) {
    if (fighter?.[`${kind}_effect`]) { delete fighter[`${kind}_effect`]; return kind; }
  }
  return null;
}
