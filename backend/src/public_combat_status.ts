import { statusActive } from "./persistent_effects";

/** Public view of the defenses effective for the next exchange. Never mutates combat state. */
export function publicCombatStatus(fighter: any, turn: number): { status: Record<string, any>; defense_presentation: Record<string, { value: number; remaining: number }>; persistent_statuses: Record<string, any>; passive_modifiers: { kind: string; amount: number; duration: string; remaining: number }[] } {
  const status = { ...(fighter?.status ?? {}) };
  const timed_defenses: Record<string, { value: number; remaining: number }> = {};
  for (const field of ["shield", "shield_pct", "reflect", "reflect_pct"]) {
    const defense = fighter?.timed_defenses?.[field];
    if (!defense || !Number.isFinite(defense.value) || defense.value <= 0 || !Number.isSafeInteger(defense.expires_turn)) continue;
    const remaining = Math.max(0, defense.expires_turn - turn);
    if (remaining === 0) continue;
    status[field] = Math.max(Number.isFinite(status[field]) ? status[field] : 0, defense.value);
    timed_defenses[field] = { value: defense.value, remaining };
  }
  if (statusActive(fighter, "burn", turn + 1)) for (const field of ["shield", "shield_pct", "reflect", "reflect_pct"]) if (field in status) status[field] = 0;
  const persistent_statuses: Record<string, any> = {};
  if ((status.poison ?? 0) > 0 && fighter?.poison_effect) persistent_statuses.poison = { stage: Math.min(3, Math.max(1, (fighter.poison_effect.stage ?? 0) + 1)), remaining: status.poison };
  for (const kind of ["burn", "lethargy"]) {
    const effect = fighter?.[`${kind}_effect`];
    if (effect && Number.isSafeInteger(effect.expires_exchange) && effect.expires_exchange > turn) persistent_statuses[kind] = { remaining: effect.expires_exchange - turn };
  }
  const passive_modifiers = (fighter?.expedition_passive?.modifiers ?? []).filter((modifier: any) => modifier && ["power_flat", "guard_flat", "tempo_flat", "accuracy_pct", "evasion_pct"].includes(modifier.kind) && Number.isFinite(modifier.amount) && Number.isSafeInteger(modifier.exchange) && modifier.exchange > turn).map((modifier: any) => ({kind:modifier.kind, amount:modifier.amount, duration:modifier.duration, remaining:modifier.exchange - turn}));
  return { status, defense_presentation: timed_defenses, persistent_statuses, passive_modifiers };
}

export function publicIncomingDrains(combat: any, target: string): { remaining: number }[] {
  return (combat?.pending_drains ?? []).filter((entry: any) => entry?.target === target && Number.isSafeInteger(entry.due_exchange) && entry.due_exchange > combat.turn).map((entry: any) => ({ remaining: entry.due_exchange - combat.turn }));
}
