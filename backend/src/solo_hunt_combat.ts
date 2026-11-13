import { createHmac } from "node:crypto";

export const PARITY_GAPS = ["Equipment, forge and homunculi", "Other spell effects and inspiration from status changes", "Boss AI, shield, minions, power turn and fury retaliation", "Authoritative selection persistence, turn concurrency and settlement"] as const;
export type CombatError = { error: "UNTRUSTED_SETUP" | "UNSUPPORTED_MECHANIC" | "INVALID_DECISION" };
const validated = new WeakMap<object, any>();

export function deterministicDraw(secret: Uint8Array, sessionId: string, turn: number, draw: number): number {
  if (secret.length < 32 || !sessionId || !Number.isSafeInteger(turn) || turn < 0 || !Number.isSafeInteger(draw) || draw < 0) throw new Error("Invalid server RNG input");
  return createHmac("sha256", secret).update(JSON.stringify(["solo-hunt-v1", sessionId, turn, draw])).digest().readUInt32BE(0) / 0x100000000;
}

// The caller must obtain snapshot and catalogs from trusted server storage. B4.1
// does not persist validated selections or the boss entity; B4.2B must do so.
export function buildTrustedCombatSetup(snapshot: any, selection: any, catalogs: any): any {
  if (!snapshot || typeof snapshot.player_id !== "string" || !Number.isSafeInteger(snapshot.state_revision) || snapshot.state_revision < 0 || !selection || !catalogs || Object.keys(selection).some(k => !["entity_id", "weapon_ids", "homunculus_id", "spell_ids", "mode"].includes(k))) return { error: "UNTRUSTED_SETUP" };
  const entity = catalogs.entities?.find((v: any) => v.id === selection.entity_id);
  const bossEntity = catalogs.entities?.find((v: any) => v.id === snapshot.boss_entity_id);
  const boss = catalogs.bosses?.find((v: any) => v.id === snapshot.boss_id);
  if (!entity || !bossEntity || !boss || !Array.isArray(selection.weapon_ids) || selection.weapon_ids.length !== 2 || !Array.isArray(selection.spell_ids) || selection.spell_ids.length !== 4 || new Set(selection.spell_ids).size !== 4 || !["attack", "defense"].includes(selection.mode)) return { error: "UNTRUSTED_SETUP" };
  for (const id of selection.weapon_ids) if (id != null && id !== "" && !catalogs.items?.some((v: any) => v.id === id)) return { error: "UNTRUSTED_SETUP" };
  if (selection.homunculus_id && !catalogs.homunculi?.some((v: any) => v.id === selection.homunculus_id)) return { error: "UNTRUSTED_SETUP" };
  const defaults = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
  const learned = snapshot.spell_progress?.learned_by_entity?.[entity.id] ?? [];
  const equipped = snapshot.spell_progress?.equipped_by_mode?.[selection.mode]?.[entity.id] ?? defaults;
  if (!Array.isArray(learned) || !Array.isArray(equipped) || JSON.stringify(equipped) !== JSON.stringify(selection.spell_ids) || selection.spell_ids.some((id: string) => !catalogs.spells.some((s: any) => s.id === id && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && s.eligible_types?.includes(entity.type) && learned.includes(id)))))) return { error: "UNTRUSTED_SETUP" };
  if (selection.weapon_ids.some((id: any) => id != null && id !== "") || selection.homunculus_id || boss.tier !== "common") return { error: "UNSUPPORTED_MECHANIC" };
  const result = { entity: structuredClone(entity), bossEntity: structuredClone(bossEntity), boss: structuredClone(boss), spells: structuredClone(catalogs.spells.filter((s: any) => selection.spell_ids.includes(s.id))), spell_ids: [...selection.spell_ids], types: structuredClone(catalogs.types), revision: snapshot.state_revision };
  validated.set(result, structuredClone(result));
  return Object.freeze(result);
}

export function createCombatState(setup: any): any {
  if (!setup || !validated.has(setup)) return { error: "UNTRUSTED_SETUP" };
  setup = validated.get(setup);
  const fighter = (e: any, hpMult = 1, atkMult = 1) => ({ id: e.id, type: e.type, hp: Math.round(e.base_stats.hp * hpMult), max_hp: Math.round(e.base_stats.hp * hpMult), atk: Math.round(e.base_stats.power * atkMult), def: e.base_stats.guard, status: {}, spell_hit_this_exchange: false, spell_hit_last_exchange: false });
  return { player: fighter(setup.entity), boss: fighter(setup.bossEntity, setup.boss.hp_mult, setup.boss.attack_mult), boss_id: setup.boss.id, boss_intent: "Strike", spell_ids: [...setup.spell_ids], spells: structuredClone(setup.spells), types: structuredClone(setup.types), cooldowns: {}, turn: 0, rng_counter: 0, terminal_result: null };
}

export function resolveCombatTurn(state: any, decision: any, rng: (turn: number, draw: number) => number): any {
  if (!state || state.terminal_result || !decision || Object.keys(decision).some(k => !["turn", "spell_id", "target"].includes(k)) || decision.turn !== state.turn + 1 || decision.target !== "boss" || !state.spell_ids?.includes(decision.spell_id) || (state.cooldowns?.[decision.spell_id] ?? 0) > 0 || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const spell = state.spells.find((s: any) => s.id === decision.spell_id);
  const supportedEffects = new Set(["atk_boost", "atk_down", "vuln", "shield", "reflect", "heal", "hom_stun", "poison", "type_neutralize", "bonus_if_poisoned", "bonus_if_hit_last_exchange", "cleanse_one", "bonus_if_low_hp", "recoil", "bonus_power_if_poisoned", "bonus_if_shielded", "consume_poison", "bonus_power_if_hit_last_exchange"]);
  const supportedStatus = new Set(["atk_boost", "atk_down", "vuln_pct", "shield_pct", "reflect_pct", "hom_stun", "stun", "poison"]);
  if (!spell || !(spell.type === state.player.type || (["universal", "hybrid"].includes(spell.type) && spell.eligible_types?.includes(state.player.type))) || !Array.isArray(spell.effects) || spell.effects.some((e: any) => !supportedEffects.has(e.kind)) || [state.player, state.boss].some(f => Object.keys(f.status ?? {}).some(k => !supportedStatus.has(k))) || state.boss_intent !== "Strike" || state.boss.hp < state.boss.max_hp * 0.5) return { error: "UNSUPPORTED_MECHANIC" };
  const next = structuredClone(state), events: any[] = [];
  for (const fighter of [next.player, next.boss]) {
    fighter.spell_hit_last_exchange = fighter.spell_hit_this_exchange ?? false;
    fighter.spell_hit_this_exchange = false;
    fighter.spell_neutralize_active = fighter.spell_neutralize_pending ?? 0;
    fighter.spell_neutralize_pending = 0;
  }
  let counter = next.rng_counter;
  const draw = () => { const n = rng(next.turn + 1, counter++); if (!Number.isFinite(n) || n < 0 || n >= 1) throw new Error("Invalid RNG draw"); return n; };
  const hit = (a: any, d: any, accuracy: number, power: number, actor: string) => {
    let acc = accuracy - (a.atk > d.def * 1.6 ? 0.08 : 0);
    if (a.max_hp > d.max_hp) acc -= Math.min(0.15, (a.max_hp - d.max_hp) / a.max_hp * 0.2);
    if (draw() >= Math.max(0, Math.min(1, acc))) { events.push({ actor, kind: "miss" }); return false; }
    const relation = next.types?.effectiveness?.[a.type]?.[d.type] ?? 1;
    let baseMult = relation > 1 ? 1.12 : relation < 1 ? 0.92 : 1;
    if (actor === "player" && spell.type === "universal") baseMult = 1;
    if (actor === "player" && spell.type === "hybrid") {
      const factor = (type: string) => { const value = next.types?.effectiveness?.[type]?.[d.type] ?? 1; return value > 1 ? 1.25 : value < 1 ? 0.8 : 1; };
      baseMult = Math.max(0.8, Math.min(1.25, Math.pow(factor(spell.primary_type), 0.65) * Math.pow(factor(spell.secondary_type), 0.35)));
    }
    const neutralize = Math.max(a.spell_neutralize_active ?? 0, d.spell_neutralize_active ?? 0);
    const mult = actor === "player" && spell.type === "universal" ? 1 : 1 + (baseMult - 1) * (1 - neutralize);
    let atk = a.atk;
    if (a.status.atk_down > 0) { atk = Math.round(atk * (1 - a.status.atk_down)); delete a.status.atk_down; }
    if (a.status.atk_boost > 0) { atk = Math.round(atk * (1 + a.status.atk_boost)); delete a.status.atk_boost; }
    let damage = Math.max(1, Math.round((atk - Math.trunc(d.def * 0.5)) * mult * power));
    if (d.status.vuln_pct > 0) { damage = Math.round(damage * (1 + d.status.vuln_pct)); delete d.status.vuln_pct; }
    if (d.status.shield_pct > 0) { damage = Math.round(damage * (1 - d.status.shield_pct)); delete d.status.shield_pct; }
    d.hp = Math.max(0, d.hp - damage);
    if (damage > 0) d.spell_hit_this_exchange = true;
    events.push({ actor, kind: "damage", damage });
    if (d.status.reflect_pct > 0) {
      const reflected = Math.round(damage * d.status.reflect_pct);
      a.hp = Math.max(0, a.hp - reflected);
      if (reflected > 0) a.spell_hit_this_exchange = true;
      delete d.status.reflect_pct;
      events.push({ actor: actor === "player" ? "boss" : "player", kind: "reflect", damage: reflected });
    }
    const passiveChance = a.type === "vitriol" ? 0.30 : 0.20;
    if (["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].includes(a.type) && draw() < passiveChance) {
      if (a.type === "sulfur") d.status.atk_down = Math.max(d.status.atk_down ?? 0, 0.15);
      if (a.type === "mercury") d.status.stun = 1;
      if (a.type === "sodium") a.status.shield_pct = Math.max(a.status.shield_pct ?? 0, 0.12);
      if (a.type === "aether") d.status.vuln_pct = Math.max(d.status.vuln_pct ?? 0, 0.12);
      if (a.type === "vitriol") d.status.poison = 2;
      if (a.type === "gold" && a.hp > 0) a.hp = Math.min(a.max_hp, a.hp + 3);
      events.push({ actor, kind: "elemental_proc", type: a.type });
    }
    return true;
  };
  try {
    for (const key of Object.keys(next.cooldowns)) next.cooldowns[key] = Math.max(0, next.cooldowns[key] - 1);
    next.cooldowns[spell.id] = spell.cooldown_turns;
    let success = false;
    const poisonedBefore = (next.boss.status.poison ?? 0) > 0;
    if (next.player.status.stun > 0) { next.player.status.stun--; }
    else if (spell.category === "attack" && spell.power_mult > 0) {
      let power = spell.power_mult;
      for (const effect of spell.effects) if (effect.kind === "bonus_if_poisoned" && (next.boss.status.poison ?? 0) > 0) power *= 1 + effect.value;
      for (const effect of spell.effects) if (effect.kind === "bonus_if_hit_last_exchange" && next.player.spell_hit_last_exchange) power *= 1 + effect.value;
      for (const effect of spell.effects) {
        if (effect.kind === "bonus_power_if_poisoned" && poisonedBefore) power += effect.value;
        if (effect.kind === "bonus_if_shielded" && (next.player.status.shield_pct ?? 0) > 0) power += effect.value;
        if (effect.kind === "bonus_if_low_hp" && next.player.hp < next.player.max_hp * (effect.threshold ?? 0.4)) power += effect.value;
        if (effect.kind === "bonus_power_if_hit_last_exchange" && next.player.spell_hit_last_exchange) power += effect.value;
      }
      success = hit(next.player, next.boss, spell.accuracy, power, "player");
    }
    else success = draw() < spell.accuracy;
    if (success) for (const effect of spell.effects) {
      const recipient = effect.target === "self" ? next.player : next.boss;
      if (["bonus_if_poisoned", "bonus_if_hit_last_exchange", "bonus_if_low_hp", "bonus_power_if_poisoned", "bonus_if_shielded", "bonus_power_if_hit_last_exchange"].includes(effect.kind)) continue;
      if (effect.kind === "cleanse_one") {
        for (const field of ["poison", "stun", "vuln_pct", "atk_down", "misalign_next"]) if ((recipient.status[field] ?? 0) > 0) { recipient.status[field] = 0; break; }
        continue;
      }
      if (effect.kind === "recoil") { if (recipient.hp > 0 && effect.value > 0) recipient.spell_hit_this_exchange = true; recipient.hp = Math.max(0, recipient.hp - Math.trunc(effect.value)); continue; }
      if (effect.kind === "consume_poison") { if (poisonedBefore) recipient.status.poison = Math.max(0, (recipient.status.poison ?? 0) - Math.trunc(effect.value)); continue; }
      if (effect.kind === "type_neutralize") {
        recipient.spell_neutralize_pending = Math.max(recipient.spell_neutralize_pending ?? 0, effect.value);
      } else if (effect.kind === "heal") {
        if (recipient.hp > 0) recipient.hp = Math.min(recipient.max_hp, recipient.hp + Math.trunc(effect.value));
      } else {
        const field = ({ vuln: "vuln_pct", shield: "shield_pct", reflect: "reflect_pct" } as Record<string, string>)[effect.kind] ?? effect.kind;
        recipient.status[field] = Math.max(recipient.status[field] ?? 0, effect.value);
      }
    }
    if (next.boss.hp > 0 && next.player.hp > 0) {
      const ratio = next.boss.hp / next.boss.max_hp;
      if (next.boss.status.stun > 0) next.boss.status.stun--;
      else hit(next.boss, next.player, 0.9, ratio > 0.7 ? 1 : ratio > 0.4 ? 1.2 : ratio > 0.15 ? 1.4 : 1.6, "boss");
    }
    if (next.player.hp > 0 && next.boss.hp > 0) for (const fighter of [next.player, next.boss]) if (fighter.status.poison > 0) { fighter.status.poison--; fighter.hp = Math.max(0, fighter.hp - 2); fighter.spell_hit_this_exchange = true; }
  } catch (error) { if (error instanceof Error && error.message === "UNSUPPORTED_MECHANIC") return { error: "UNSUPPORTED_MECHANIC" }; throw error; }
  next.turn++;
  for (const fighter of [next.player, next.boss]) fighter.spell_neutralize_active = 0;
  next.rng_counter = counter;
  next.terminal_result = next.player.hp <= 0 ? "LOSS" : next.boss.hp <= 0 ? "WIN" : null;
  return { next_state: next, events, terminal_result: next.terminal_result };
}
