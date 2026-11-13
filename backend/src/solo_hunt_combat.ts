import { createHmac } from "node:crypto";

export const PARITY_GAPS = ["Equipment, forge and homunculi", "Spell effects and elemental passive procs", "Boss AI, shield, minions, power turn and fury retaliation", "Authoritative selection persistence, turn concurrency and settlement"] as const;
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
  const fighter = (e: any, hpMult = 1, atkMult = 1) => ({ id: e.id, type: e.type, hp: Math.round(e.base_stats.hp * hpMult), max_hp: Math.round(e.base_stats.hp * hpMult), atk: Math.round(e.base_stats.power * atkMult), def: e.base_stats.guard, status: {} });
  return { player: fighter(setup.entity), boss: fighter(setup.bossEntity, setup.boss.hp_mult, setup.boss.attack_mult), boss_id: setup.boss.id, boss_intent: "Strike", spell_ids: [...setup.spell_ids], spells: structuredClone(setup.spells), types: structuredClone(setup.types), cooldowns: {}, turn: 0, rng_counter: 0, terminal_result: null };
}

export function resolveCombatTurn(state: any, decision: any, rng: (turn: number, draw: number) => number): any {
  if (!state || state.terminal_result || !decision || Object.keys(decision).some(k => !["turn", "spell_id", "target"].includes(k)) || decision.turn !== state.turn + 1 || decision.target !== "boss" || !state.spell_ids?.includes(decision.spell_id) || (state.cooldowns?.[decision.spell_id] ?? 0) > 0 || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const spell = state.spells.find((s: any) => s.id === decision.spell_id);
  if (!spell || spell.type !== state.player.type || spell.category !== "attack" || !Array.isArray(spell.effects) || spell.effects.length !== 0 || Object.keys(state.player.status ?? {}).length > 0 || Object.keys(state.boss.status ?? {}).length > 0 || state.boss_intent !== "Strike" || state.boss.hp < state.boss.max_hp * 0.5) return { error: "UNSUPPORTED_MECHANIC" };
  const next = structuredClone(state), events: any[] = [];
  let counter = next.rng_counter;
  const draw = () => { const n = rng(next.turn + 1, counter++); if (!Number.isFinite(n) || n < 0 || n >= 1) throw new Error("Invalid RNG draw"); return n; };
  const hit = (a: any, d: any, accuracy: number, power: number, actor: string) => {
    let acc = accuracy - (a.atk > d.def * 1.6 ? 0.08 : 0);
    if (a.max_hp > d.max_hp) acc -= Math.min(0.15, (a.max_hp - d.max_hp) / a.max_hp * 0.2);
    if (draw() >= Math.max(0, Math.min(1, acc))) { events.push({ actor, kind: "miss" }); return; }
    const relation = next.types?.effectiveness?.[a.type]?.[d.type] ?? 1;
    const mult = relation > 1 ? 1.12 : relation < 1 ? 0.92 : 1;
    const damage = Math.max(1, Math.round((a.atk - Math.trunc(d.def * 0.5)) * mult * power));
    d.hp = Math.max(0, d.hp - damage);
    events.push({ actor, kind: "damage", damage });
    // Godot rolls an elemental passive after every successful hit. Reject the
    // entire immutable turn if that unsupported passive would activate.
    const passiveChance = a.type === "vitriol" ? 0.30 : 0.20;
    if (["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].includes(a.type) && draw() < passiveChance) throw new Error("UNSUPPORTED_MECHANIC");
  };
  try {
    for (const key of Object.keys(next.cooldowns)) next.cooldowns[key] = Math.max(0, next.cooldowns[key] - 1);
    next.cooldowns[spell.id] = spell.cooldown_turns;
    hit(next.player, next.boss, spell.accuracy, spell.power_mult, "player");
    if (next.boss.hp > 0) {
      const ratio = next.boss.hp / next.boss.max_hp;
      hit(next.boss, next.player, 0.9, ratio > 0.7 ? 1 : ratio > 0.4 ? 1.2 : ratio > 0.15 ? 1.4 : 1.6, "boss");
    }
  } catch (error) { if (error instanceof Error && error.message === "UNSUPPORTED_MECHANIC") return { error: "UNSUPPORTED_MECHANIC" }; throw error; }
  next.turn++;
  next.rng_counter = counter;
  next.terminal_result = next.player.hp <= 0 ? "LOSS" : next.boss.hp <= 0 ? "WIN" : null;
  return { next_state: next, events, terminal_result: next.terminal_result };
}
