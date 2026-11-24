// Status names differ between Dungeon and Solo Hunt; callers provide the mapping.
export function transferStrategicStatus(kind: string, actor: any, target: any, actorId: string, targetId: string, fields: { vuln: string; shield: string; reflect: string }, events: any[], clear: (fighter: any, field: string) => void, apply: (fighter: any, field: string, value: number) => void): void {
  const negative = ["poison", fields.vuln, "atk_down"];
  const positive = ["atk_boost", fields.shield, fields.reflect];
  const source = kind === "debuff_transfer" ? actor : target;
  const destination = kind === "debuff_transfer" ? target : actor;
  const sourceId = kind === "debuff_transfer" ? actorId : targetId;
  const destinationId = kind === "debuff_transfer" ? targetId : actorId;
  const field = (kind === "debuff_transfer" ? negative : positive).find(key => (source.status[key] ?? 0) > 0);
  if (!field) {
    if (kind === "debuff_transfer") for (const name of ["burn", "lethargy"]) {
      const key = `${name}_effect`, effect = source[key];
      if (!effect) continue;
      delete source[key];
      if (!destination[key]) destination[key] = effect;
      events.push({ kind, actor: actorId, source: sourceId, target: destinationId, status: name, removed: 1, previous: destination[key] === effect ? 0 : 1, value: 1 });
      break;
    }
    return;
  }
  const old = source.status[field];
  const value = kind === "debuff_transfer" ? old : Math.min(0.2, old * 0.5);
  const previous = destination.status[field] ?? 0;
  const poisonEffect = field === "poison" && source.combat_rules_version === 2 ? structuredClone(source.poison_effect ?? null) : null;
  const poisonSource = field === "poison" ? source.poison_source ?? null : null;
  clear(source, field);
  apply(destination, field, value);
  if (field === "poison" && source.combat_rules_version === 2) {
    if (previous > 0) destination.status.poison = previous;
    else if (poisonEffect) { destination.poison_effect = poisonEffect; destination.poison_source = poisonSource; }
    destination.poison_transfer_pending = true;
  }
  events.push({ kind, actor: actorId, source: sourceId, target: destinationId, status: field, removed: old, previous, value: destination.status[field] ?? 0 });
}

export function validStrategicStatusEffect(effect: any): boolean {
  return effect && ((["debuff_transfer", "cooldown_jam"].includes(effect.kind) && effect.value === 1) || (["buff_steal", "heal_suppression"].includes(effect.kind) && effect.value === 0.5) || (effect.kind === "hom_energy_siphon" && effect.value === 2) || (["delayed_damage", "ward_convert", "counter_trap"].includes(effect.kind) && typeof effect.value === "number" && Number.isFinite(effect.value) && effect.value >= 0 && effect.value <= (effect.kind === "counter_trap" ? 0.5 : 1)));
}

export const STRATEGIC_EFFECTS = ["debuff_transfer", "buff_steal", "cooldown_jam", "hom_energy_siphon", "delayed_damage", "counter_trap", "ward_convert", "heal_suppression"];

export function queueDelayedDamage(state: any, actor: string, target: string, value: number, damage: number, turn: number, events: any[]): void {
  if (damage <= 0) return;
  const amount = Math.floor(damage * value);
  state.strategic_delayed ??= [];
  state.strategic_delayed = state.strategic_delayed.filter((entry: any) => entry.actor !== actor || entry.target !== target);
  if (amount > 0) state.strategic_delayed.push({ actor, target, amount, due_turn: turn + 1 });
  events.push({ kind: "delayed_damage_queued", actor, target, amount, due_turn: turn + 1 });
}

export function strategicCounter(defender: any, attacker: any, defenderId: string, attackerId: string, damage: number, turn: number, events: any[]): void {
  const trap = defender.strategic_trap;
  if (!trap || turn <= trap.activated_turn || turn > trap.expires_turn || damage <= 0) return;
  delete defender.strategic_trap;
  const amount = Math.min(attacker.hp, Math.floor(attacker.max_hp * 0.2), Math.floor(damage * trap.value));
  attacker.hp -= amount;
  events.push({ kind: "counter_trap_triggered", actor: defenderId, target: attackerId, amount, hp: attacker.hp });
}

export function strategicHeal(fighter: any, amount: number): number {
  return fighter.strategic_heal_suppression ? Math.floor(amount * 0.5) : amount;
}

export function finishStrategicExchange(state: any, fighters: Record<string, any>, turn: number, events: any[]): void {
  const remaining: any[] = [];
  for (const entry of state.strategic_delayed ?? []) {
    if (entry.due_turn > turn) { remaining.push(entry); continue; }
    const target = fighters[entry.target];
    if (target && target.hp > 0) {
      const amount = Math.min(target.hp, entry.amount);
      target.hp -= amount;
      events.push({ kind: "delayed_damage", actor: entry.actor, target: entry.target, amount, hp: target.hp });
    }
  }
  state.strategic_delayed = remaining;
  for (const [id, fighter] of Object.entries(fighters) as [string, any][]) {
    for (const [field, kind] of [["strategic_trap", "counter_trap_expired"], ["strategic_heal_suppression", "heal_suppression_expired"]]) {
      if (fighter[field]?.expires_turn <= turn) { delete fighter[field]; events.push({ kind, target: id }); }
    }
  }
}

export function jamStrategicCooldown(spells: any[], cooldowns: Record<string, number>, actor: string, target: string, events: any[]): void {
  const eligible = spells.filter(s => s && s.id !== "basic_attack" && Number.isFinite(s.power_mult) && s.power_mult >= 0 && Number.isInteger(s.cooldown_turns) && s.cooldown_turns > 0)
    .sort((a, b) => b.power_mult - a.power_mult || a.id.localeCompare(b.id));
  const chosen = eligible[0];
  if (!chosen) return;
  const previous = cooldowns[chosen.id] ?? 0;
  const value = Math.min(4, previous + 1);
  if (value <= previous) return;
  cooldowns[chosen.id] = value;
  events.push({ kind: "cooldown_jam", actor, target, spell_id: chosen.id, previous, value });
}
