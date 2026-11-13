import { createHmac } from "node:crypto";

export const PARITY_GAPS = ["Normal Bo3 Ultraturn", "Boss AI, shield, minions, power turn and fury retaliation", "Authoritative selection persistence, turn concurrency and settlement"] as const;
export type CombatError = { error: "UNTRUSTED_SETUP" | "UNSUPPORTED_MECHANIC" | "INVALID_DECISION" };
const validated = new WeakMap<object, any>();
const SUPPORTED_EFFECTS = new Set(["atk_boost", "atk_down", "vuln", "shield", "reflect", "heal", "hom_stun", "poison", "type_neutralize", "bonus_if_poisoned", "bonus_if_hit_last_exchange", "cleanse_one", "bonus_if_low_hp", "recoil", "bonus_power_if_poisoned", "bonus_if_shielded", "consume_poison", "bonus_power_if_hit_last_exchange", "pierce_ward", "ward_dispel", "focus_next", "misalign_next", "life_leech", "hybrid_mark", "bonus_if_marked", "poison_on_reflect", "tempo_shift", "shield_by_order"]);

function castableSpell(spell: any, element: string): boolean {
  if (!spell || typeof spell.id !== "string" || !/^[a-z][a-z0-9_]{0,63}$/.test(spell.id) || !(spell.type === element || (["universal", "hybrid"].includes(spell.type) && Array.isArray(spell.eligible_types) && spell.eligible_types.includes(element))) || !["attack", "support"].includes(spell.category) || typeof spell.power_mult !== "number" || !Number.isFinite(spell.power_mult) || spell.power_mult < 0 || typeof spell.accuracy !== "number" || !Number.isFinite(spell.accuracy) || spell.accuracy < 0 || spell.accuracy > 1 || !Number.isSafeInteger(spell.cooldown_turns) || spell.cooldown_turns < 0 || !Array.isArray(spell.effects)) return false;
  const elements = ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"];
  if (spell.type === "hybrid" && (!elements.includes(spell.primary_type) || !elements.includes(spell.secondary_type) || spell.primary_type === spell.secondary_type)) return false;
  if ((spell.category === "attack" && spell.power_mult <= 0) || (spell.category === "support" && spell.power_mult !== 0)) return false;
  return spell.effects.every((e: any) => e && SUPPORTED_EFFECTS.has(e.kind) && ["self", "enemy"].includes(e.target) && typeof e.value === "number" && Number.isFinite(e.value) && (e.kind === "tempo_shift" || e.value >= 0) && ["threshold", "max_heal", "second_value"].every(key => e[key] === undefined || (typeof e[key] === "number" && Number.isFinite(e[key]) && e[key] >= 0)) && (e.threshold === undefined || e.threshold <= 1));
}

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
  for (const id of selection.weapon_ids) if (id != null && id !== "" && !catalogs.items?.some((v: any) => v.id === id && v.slot === "build")) return { error: "UNTRUSTED_SETUP" };
  if (selection.homunculus_id && !catalogs.homunculi?.some((v: any) => v.id === selection.homunculus_id)) return { error: "UNTRUSTED_SETUP" };
  const defaults = catalogs.spells.filter((s: any) => s.type === entity.type).map((s: any) => s.id);
  const learned = snapshot.spell_progress?.learned_by_entity?.[entity.id] ?? [];
  const equipped = snapshot.spell_progress?.equipped_by_mode?.[selection.mode]?.[entity.id] ?? defaults;
  if (!Array.isArray(learned) || !Array.isArray(equipped) || JSON.stringify(equipped) !== JSON.stringify(selection.spell_ids) || selection.spell_ids.some((id: string) => !catalogs.spells.some((s: any) => s.id === id && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && s.eligible_types?.includes(entity.type) && learned.includes(id)))))) return { error: "UNTRUSTED_SETUP" };
  if (selection.spell_ids.some((id: string) => !castableSpell(catalogs.spells.find((s: any) => s.id === id), entity.type))) return { error: "UNSUPPORTED_MECHANIC" };
  if (selection.weapon_ids[0] && selection.weapon_ids[0] === selection.weapon_ids[1]) return { error: "UNTRUSTED_SETUP" };
  const seenCandidates = new Set<string>();
  const inspirationCatalog = catalogs.spells.filter((spell: any) => {
    if (!(spell?.type === entity.type || (spell?.type === "hybrid" && spell.primary_type === entity.type)) || !castableSpell(spell, entity.type) || selection.spell_ids.includes(spell.id) || seenCandidates.has(spell.id)) return false;
    seenCandidates.add(spell.id);
    return true;
  });
  if (inspirationCatalog.length < 3) return { error: "UNSUPPORTED_MECHANIC" };
  if (boss.tier !== "common") return { error: "UNSUPPORTED_MECHANIC" };
  if (selection.weapon_ids[1]) {
    const first = buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: [selection.weapon_ids[0], null] }, catalogs);
    if (first.error) return first;
    const second = buildTrustedCombatSetup(snapshot, { ...selection, weapon_ids: [selection.weapon_ids[1], null] }, catalogs);
    if (second.error) return second;
    const base = validated.get(first), other = validated.get(second);
    const combined = { ...base, weapons: [{ id: base.item_id, effects: base.itemEffects }, { id: other.item_id, effects: other.itemEffects }] };
    validated.set(combined, structuredClone(combined));
    return Object.freeze(combined);
  }
  const item = selection.weapon_ids[0] ? catalogs.items.find((v: any) => v.id === selection.weapon_ids[0]) : null;
  const itemProgress = snapshot.item_progress?.[selection.weapon_ids[0]] ?? {};
  const homProgress = snapshot.homunculus_progress?.[selection.homunculus_id] ?? {};
  if (typeof itemProgress !== "object" || Array.isArray(itemProgress) || typeof homProgress !== "object" || Array.isArray(homProgress)) return { error: "UNTRUSTED_SETUP" };
  const validLevel = (v: any) => v === undefined || (Number.isInteger(v) && v >= 0 && v <= 10);
  if (!validLevel(itemProgress.level) || !validLevel(homProgress.level)) return { error: "UNTRUSTED_SETUP" };
  const itemLevel = Math.max(0, Math.min(10, Number.isFinite(Number(itemProgress.level)) ? Math.trunc(Number(itemProgress.level)) : 0));
  const homLevel = Math.max(0, Math.min(10, Number.isFinite(Number(homProgress.level)) ? Math.trunc(Number(homProgress.level)) : 0));
  const itemEffects: Record<string, number> = {};
  if (item) for (const [key, value] of Object.entries(item.effects) as [string, any][]) {
    if (!["power_flat", "guard_flat", "tempo_flat", "true_on_hit", "dot_true", "vuln_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"].includes(key) || !Array.isArray(value) || !value.length || value.some((v: any) => typeof v !== "number" || !Number.isFinite(v))) return { error: "UNSUPPORTED_MECHANIC" };
    itemEffects[key] = itemLevel === 0 && value.length === 10 && key in (item.base_effects ?? {}) ? item.base_effects[key] : value[Math.max(0, Math.min(itemLevel - 1, value.length - 1))];
  }
  if (item && itemProgress.traits !== undefined && !Array.isArray(itemProgress.traits)) return { error: "UNTRUSTED_SETUP" };
  if (item && (itemProgress.specialization || itemProgress.traits?.length)) {
    const pool = catalogs.balance?.forge_trait_pool?.[itemProgress.specialization];
    const traits = itemProgress.traits;
    if (!pool || !Array.isArray(traits) || traits.length !== 3 || new Set(traits.map((t: any) => t?.id)).size !== 3) return { error: "UNTRUSTED_SETUP" };
    let allocated = 0;
    for (const trait of traits) {
      if (!trait || !Object.hasOwn(pool, trait.id) || !Number.isInteger(trait.points) || trait.points < 0 || trait.points > 4 || (allocated += trait.points) > itemLevel) return { error: "UNTRUSTED_SETUP" };
      if (!["power_flat", "guard_flat", "tempo_flat", "true_on_hit", "dot_true", "vuln_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"].includes(trait.id) || typeof pool[trait.id] !== "number" || !Number.isFinite(pool[trait.id]) || pool[trait.id] <= 0) return { error: "UNSUPPORTED_MECHANIC" };
      if (trait.points > 0) itemEffects[trait.id] = (itemEffects[trait.id] ?? 0) + pool[trait.id] * trait.points;
    }
  }
  if (item && itemProgress.fusion) {
    const donor = itemProgress.fusion.donor_id;
    const imprint = catalogs.balance?.forge_fusion_imprints?.[donor];
    const donorLevel = snapshot.item_progress?.[donor]?.level;
    if (typeof itemProgress.fusion !== "object" || Array.isArray(itemProgress.fusion) || Object.keys(itemProgress.fusion).some(key => key !== "donor_id") || typeof donor !== "string" || donor === item.id || !catalogs.items.some((entry: any) => entry.id === donor) || itemLevel < 3 || !Number.isInteger(donorLevel) || donorLevel < 3 || donorLevel > 10 || !imprint || Object.keys(imprint).length !== 1) return { error: "UNTRUSTED_SETUP" };
    for (const [key, amount] of Object.entries(imprint) as [string, any][]) {
      if (!["true_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "dot_true", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"].includes(key) || typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) return { error: "UNSUPPORTED_MECHANIC" };
      itemEffects[key] = (itemEffects[key] ?? 0) + amount;
    }
  }
  for (const key of ["ward_pct", "reflect_pct", "evasion_pct", "disadvantage_reduction", "ignore_reflect_chance", "vuln_on_hit"]) if (key in itemEffects) itemEffects[key] = Math.max(0, Math.min(1, itemEffects[key]));
  const hom = selection.homunculus_id ? catalogs.homunculi.find((v: any) => v.id === selection.homunculus_id) : null;
  if (homProgress.mutation_id !== undefined && typeof homProgress.mutation_id !== "string") return { error: "UNTRUSTED_SETUP" };
  const mutation = homProgress.mutation_id ? catalogs.mutations?.find((v: any) => v.id === homProgress.mutation_id) : null;
  if (homProgress.mutation_id && !mutation) return { error: "UNTRUSTED_SETUP" };
  if (mutation && Object.entries(mutation.effects ?? {}).some(([key, value]) => !["hp_flat", "power_flat", "guard_flat", "favorable_type_bonus"].includes(key) || typeof value !== "number" || !Number.isFinite(value))) return { error: "UNSUPPORTED_MECHANIC" };
  const synergy = hom?.per_type?.[entity.type] ?? {};
  if (Object.entries(synergy).some(([key, value]) => !["power_flat", "guard_flat", "tempo_flat", "type_adv_bonus", "type_neutralize", "incoming_mult", "reflect_pct", "dot_true", "item_effect_mult"].includes(key) || typeof value !== "number" || !Number.isFinite(value))) return { error: "UNSUPPORTED_MECHANIC" };
  const bonuses = { hp: (hom ? hom.buff_hp + homLevel : 0) + (mutation?.effects.hp_flat ?? 0), atk: (hom ? hom.buff_atk + Math.trunc(homLevel / 5) : 0) + (synergy.power_flat ?? 0) + (mutation?.effects.power_flat ?? 0), def: (hom ? hom.buff_def + Math.trunc(homLevel / 3) : 0) + (synergy.guard_flat ?? 0) + (mutation?.effects.guard_flat ?? 0) };
  const result = { entity: structuredClone(entity), bossEntity: structuredClone(bossEntity), boss: structuredClone(boss), spells: structuredClone(selection.spell_ids.map((id: string) => catalogs.spells.find((s: any) => s.id === id))), inspiration_catalog: structuredClone(inspirationCatalog), spell_ids: [...selection.spell_ids], types: structuredClone(catalogs.types), revision: snapshot.state_revision, itemEffects, item_id: item?.id ?? null, hom_id: hom?.id ?? null, hom_tempo: synergy.tempo_flat ?? 0, hom_synergy: structuredClone(synergy), hom_advantage: Math.max(0, Math.min(0.5, (synergy.type_adv_bonus ?? 0) + (mutation?.effects.favorable_type_bonus ?? 0))), bonuses };
  validated.set(result, structuredClone(result));
  return Object.freeze(result);
}

export function createCombatState(setup: any): any {
  if (!setup || !validated.has(setup)) return { error: "UNTRUSTED_SETUP" };
  setup = validated.get(setup);
  const fighter = (e: any, hpMult = 1, atkMult = 1) => ({ id: e.id, type: e.type, hp: Math.round(e.base_stats.hp * hpMult), max_hp: Math.round(e.base_stats.hp * hpMult), atk: Math.round(e.base_stats.power * atkMult), def: e.base_stats.guard, status: {}, spell_hit_this_exchange: false, spell_hit_last_exchange: false, inspiration: 0, inspiration_pending: false, inspiration_used_this_battle: false });
  const player = fighter(setup.entity);
  const weapons = setup.weapons ?? [{ id: setup.item_id, effects: setup.itemEffects }, { id: null, effects: {} }];
  const activeSlot = weapons[0].id ? 1 : weapons[1].id ? 2 : 1;
  const active = weapons[activeSlot - 1];
  const activeEffects = scaleWeapon(active.effects, setup.hom_id ? setup.hom_synergy.item_effect_mult : 1);
  player.atk += setup.bonuses.atk + Math.trunc(activeEffects.power_flat ?? 0);
  player.def += setup.bonuses.def + Math.trunc(activeEffects.guard_flat ?? 0);
  player.max_hp += setup.bonuses.hp;
  player.hp = player.max_hp;
  return { player, boss: fighter(setup.bossEntity, setup.boss.hp_mult, setup.boss.attack_mult), boss_id: setup.boss.id, boss_intent: "Strike", spell_ids: [...setup.spell_ids], original_spell_ids: [...setup.spell_ids], spells: structuredClone(setup.spells), inspiration_catalog: structuredClone(setup.inspiration_catalog), inspiration_offers: [], temporary_spell_id: null, temporary_replaced_slot: null, types: structuredClone(setup.types), weapons: structuredClone(weapons), active_weapon_slot: activeSlot, item_id: active.id, item_effects: activeEffects, weapon_defenses: {}, other_defenses: {}, hom_id: setup.hom_id, hom_bonuses: setup.bonuses, hom_synergy: setup.hom_synergy, hom_advantage: setup.hom_advantage, hom_tempo: setup.hom_tempo, hom_spent: !setup.hom_id, hom_energy: 0, cooldowns: {}, turn: 0, rng_counter: 0, terminal_result: null };
}

function scaleWeapon(effects: Record<string, number>, multiplier: number = 1): Record<string, number> {
  const factor = Math.max(0, Math.min(2, multiplier ?? 1));
  return Object.fromEntries(Object.entries(effects).map(([key, value]) => [key, value * factor]));
}

export function resolveCombatTurn(state: any, decision: any, rng: (turn: number, draw: number) => number): any {
  const switching = decision?.switch_slot !== undefined;
  if (!state || state.terminal_result || state.player?.inspiration_pending || !decision || Object.keys(decision).some(k => !["turn", "spell_id", "target", "hom_action", "switch_slot"].includes(k)) || ![undefined, "hold", "attack", "sacrifice"].includes(decision.hom_action) || (decision.hom_action && decision.hom_action !== "hold" && (state.hom_spent || !state.hom_id || state.hom_energy < 3)) || decision.turn !== state.turn + 1 || typeof rng !== "function") return { error: "INVALID_DECISION" };
  if (switching ? (decision.spell_id !== undefined || decision.target !== undefined || ![1, 2].includes(decision.switch_slot) || decision.switch_slot === state.active_weapon_slot || !state.weapons?.[decision.switch_slot - 1]?.id) : (decision.target !== "boss" || !state.spell_ids?.includes(decision.spell_id) || (state.cooldowns?.[decision.spell_id] ?? 0) > 0)) return { error: "INVALID_DECISION" };
  const spell = state.spells.find((s: any) => s.id === decision.spell_id);
  const supportedStatus = new Set(["atk_boost", "atk_down", "vuln_pct", "shield_pct", "reflect_pct", "hom_stun", "stun", "poison", "focus_next", "misalign_next", "hybrid_mark", "poison_on_reflect", "tempo_bonus"]);
  if ((!switching && !castableSpell(spell, state.player.type)) || [state.player, state.boss].some(f => Object.keys(f.status ?? {}).some(k => !supportedStatus.has(k))) || state.boss_intent !== "Strike" || state.boss.hp < state.boss.max_hp * 0.5) return { error: "UNSUPPORTED_MECHANIC" };
  const next = structuredClone(state), events: any[] = [];
  next.weapon_defenses ??= {};
  next.other_defenses ??= {};
  const otherDefense = (fighter: any, field: string, value: number) => {
    if (fighter === next.player && field === "reflect_pct" && next.hom_reflect_active !== undefined) next.hom_other_reflect = Math.max(next.hom_other_reflect ?? 0, value);
    if (fighter === next.player && next.weapon_defenses[field] !== undefined) next.other_defenses[field] = Math.max(next.other_defenses[field] ?? 0, value);
    fighter.status[field] = Math.max(fighter.status[field] ?? 0, value);
  };
  const clearDefense = (fighter: any, field: string) => {
    delete fighter.status[field];
    if (fighter === next.player) { delete next.weapon_defenses[field]; delete next.other_defenses[field]; }
    if (fighter === next.player && field === "reflect_pct") { delete next.hom_reflect_active; delete next.hom_other_reflect; }
  };
  for (const fighter of [next.player, next.boss]) {
    fighter.spell_hit_last_exchange = fighter.spell_hit_this_exchange ?? false;
    fighter.spell_hit_this_exchange = false;
    fighter.spell_neutralize_active = fighter.spell_neutralize_pending ?? 0;
    fighter.spell_neutralize_pending = 0;
  }
  let counter = next.rng_counter;
  let actualDamage = 0;
  let accuracyFocus = 0, accuracyMisalign = 0;
  const draw = () => { const n = rng(next.turn + 1, counter++); if (!Number.isFinite(n) || n < 0 || n >= 1) throw new Error("Invalid RNG draw"); return n; };
  const award = (kind: string) => {
    if (!next.player.inspiration_used_this_battle && next.player.inspiration < 3) {
      next.player.inspiration++;
      next.player.inspiration_pending = next.player.inspiration === 3;
      events.push({ actor: "player", kind: "inspiration", source: kind, value: next.player.inspiration });
    }
  };
  const hit = (a: any, d: any, accuracy: number, power: number, actor: string) => {
    if (actor === "boss" && (next.item_effects?.evasion_pct ?? 0) > 0 && draw() < next.item_effects.evasion_pct) { events.push({ actor: "player", kind: "evade" }); return false; }
    let acc = accuracy - (a.atk > d.def * 1.6 ? 0.08 : 0);
    if (a.max_hp > d.max_hp) acc -= Math.min(0.15, (a.max_hp - d.max_hp) / a.max_hp * 0.2);
    if (accuracyFocus > 0) acc = Math.min(0.99, acc + accuracyFocus);
    if (accuracyMisalign > 0) acc = Math.max(0.55, acc - accuracyMisalign);
    if (draw() >= Math.max(0, Math.min(1, acc))) { events.push({ actor, kind: "miss" }); return false; }
    const relation = next.types?.effectiveness?.[a.type]?.[d.type] ?? 1;
    let baseMult = relation > 1 ? 1.12 : relation < 1 ? 0.92 : 1;
    if (actor === "player" && spell.type === a.type && relation < 1) baseMult = Math.min(1, baseMult + (next.item_effects?.disadvantage_reduction ?? 0));
    if (actor === "player" && spell.type === "universal") baseMult = 1;
    if (actor === "player" && spell.type === "hybrid") {
      const factor = (type: string) => { const value = next.types?.effectiveness?.[type]?.[d.type] ?? 1; return value > 1 ? 1.25 : value < 1 ? 0.8 : 1; };
      baseMult = Math.max(0.8, Math.min(1.25, Math.pow(factor(spell.primary_type), 0.65) * Math.pow(factor(spell.secondary_type), 0.35)));
    }
    if (actor === "player" && spell.type !== "universal" && baseMult > 1 && !next.hom_spent) baseMult += next.hom_advantage ?? 0;
    const neutralize = Math.max(a.spell_neutralize_active ?? 0, d.spell_neutralize_active ?? 0, next.hom_spent ? 0 : next.hom_synergy?.type_neutralize ?? 0);
    const mult = actor === "player" && spell.type === "universal" ? 1 : 1 + (baseMult - 1) * (1 - neutralize);
    let atk = a.atk;
    if (a.status.atk_down > 0) { atk = Math.round(atk * (1 - a.status.atk_down)); delete a.status.atk_down; }
    if (a.status.atk_boost > 0) { atk = Math.round(atk * (1 + a.status.atk_boost)); delete a.status.atk_boost; }
    let damage = Math.max(1, Math.round((atk - Math.trunc(d.def * 0.5)) * mult * power));
    if (actor === "boss" && !next.hom_spent) damage = Math.max(1, Math.round(damage * Math.max(0.1, Math.min(1, next.hom_synergy?.incoming_mult ?? 1))));
    if (d.status.vuln_pct > 0) { damage = Math.round(damage * (1 + d.status.vuln_pct)); delete d.status.vuln_pct; }
    if (d.status.shield_pct > 0) {
      const dispel = actor === "player" ? Math.max(0, Math.min(1, spell.effects.find((e: any) => e.kind === "ward_dispel")?.value ?? 0)) : 0;
      const pierce = actor === "player" ? Math.max(0, Math.min(1, spell.effects.find((e: any) => e.kind === "pierce_ward")?.value ?? 0)) : 0;
      damage = Math.round(damage * (1 - d.status.shield_pct * (1 - dispel) * (1 - pierce)));
      clearDefense(d, "shield_pct");
    }
    if (actor === "player") actualDamage = Math.min(d.hp, damage);
    d.hp = Math.max(0, d.hp - damage);
    if (damage > 0) d.spell_hit_this_exchange = true;
    events.push({ actor, kind: "damage", damage });
    if (d.status.reflect_pct > 0) {
      const ignored = actor === "player" && (next.item_effects?.ignore_reflect_chance ?? 0) > 0 && draw() < next.item_effects.ignore_reflect_chance;
      const reflected = ignored ? 0 : Math.round(damage * d.status.reflect_pct);
      a.hp = Math.max(0, a.hp - reflected);
      if (reflected > 0) a.spell_hit_this_exchange = true;
      clearDefense(d, "reflect_pct");
      if (!ignored && (d.status.poison_on_reflect ?? 0) > 0) a.status.poison = Math.max(a.status.poison ?? 0, d.status.poison_on_reflect);
      delete d.status.poison_on_reflect;
      events.push({ actor: actor === "player" ? "boss" : "player", kind: "reflect", damage: reflected });
    }
    if (actor === "player" && (next.item_effects?.true_on_hit ?? 0) > 0) {
      const bonus = Math.trunc(next.item_effects.true_on_hit);
      actualDamage += Math.min(d.hp, bonus);
      d.hp = Math.max(0, d.hp - bonus);
      events.push({ actor, kind: "true_damage", damage: bonus });
    }
    if (actor === "player" && (next.item_effects?.dot_true ?? 0) > 0) {
      const bonus = Math.trunc(next.item_effects.dot_true);
      actualDamage += Math.min(d.hp, bonus);
      d.hp = Math.max(0, d.hp - bonus);
      events.push({ actor, kind: "corrosion", damage: bonus });
      if ((next.item_effects.vuln_on_hit ?? 0) > 0) d.status.vuln_pct = Math.max(d.status.vuln_pct ?? 0, next.item_effects.vuln_on_hit);
    }
    if (actor === "player" && !next.hom_spent && (next.hom_synergy?.dot_true ?? 0) > 0) {
      const damage = Math.trunc(next.hom_synergy.dot_true);
      d.hp = Math.max(0, d.hp - damage);
      events.push({ actor: "player", kind: "hom_corrosion", damage });
    }
    const passiveChance = a.type === "vitriol" ? 0.30 : 0.20;
    if (["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].includes(a.type) && draw() < passiveChance) {
      if (a.type === "sulfur") d.status.atk_down = Math.max(d.status.atk_down ?? 0, 0.15);
      if (a.type === "mercury") d.status.stun = 1;
      if (a.type === "sodium") otherDefense(a, "shield_pct", 0.12);
      if (a.type === "aether") d.status.vuln_pct = Math.max(d.status.vuln_pct ?? 0, 0.12);
      if (a.type === "vitriol") d.status.poison = 2;
      if (a.type === "gold" && a.hp > 0) a.hp = Math.min(a.max_hp, a.hp + 3);
      events.push({ actor, kind: "elemental_proc", type: a.type });
    }
    return true;
  };
  try {
    const playerFirst = (next.player.status.tempo_bonus ?? 0) + (next.item_effects?.tempo_flat ?? 0) + (next.hom_spent ? 0 : next.hom_tempo ?? 0) >= (next.boss.status.tempo_bonus ?? 0);
    delete next.player.status.tempo_bonus;
    delete next.boss.status.tempo_bonus;
    const bossAction = () => {
      const ratio = next.boss.hp / next.boss.max_hp;
      if (next.boss.status.stun > 0) next.boss.status.stun--;
      else {
        accuracyFocus = 0;
        accuracyMisalign = 0;
        hit(next.boss, next.player, 0.9, ratio > 0.7 ? 1 : ratio > 0.4 ? 1.2 : ratio > 0.15 ? 1.4 : 1.6, "boss");
      }
    };
    if (!playerFirst) bossAction();
    if (next.player.hp > 0 && next.boss.hp > 0) {
    for (const key of Object.keys(next.cooldowns)) next.cooldowns[key] = Math.max(0, next.cooldowns[key] - 1);
    if (switching) {
      if (next.player.status.stun > 0) next.player.status.stun--;
      else {
        for (const field of ["shield_pct", "reflect_pct"]) if (next.weapon_defenses[field] !== undefined) {
          next.player.status[field] = next.other_defenses[field] ?? 0;
          delete next.weapon_defenses[field];
          delete next.other_defenses[field];
        }
        const old = next.item_effects;
        const weapon = next.weapons[decision.switch_slot - 1];
        const effects = scaleWeapon(weapon.effects, next.hom_spent ? 1 : next.hom_synergy?.item_effect_mult);
        next.player.atk += Math.trunc(effects.power_flat ?? 0) - Math.trunc(old.power_flat ?? 0);
        next.player.def += Math.trunc(effects.guard_flat ?? 0) - Math.trunc(old.guard_flat ?? 0);
        next.player.hp = Math.min(next.player.hp, next.player.max_hp);
        next.active_weapon_slot = decision.switch_slot;
        next.item_id = weapon.id;
        next.item_effects = effects;
        events.push({ actor: "player", kind: "switch", slot: decision.switch_slot });
      }
    } else {
    next.cooldowns[spell.id] = spell.cooldown_turns;
    let success = false;
    const poisonedBefore = (next.boss.status.poison ?? 0) > 0;
    const mark = next.boss.status.hybrid_mark;
    const marked = mark?.owner === "player" && mark.remaining > 0;
    if (marked && --mark.remaining <= 0) delete next.boss.status.hybrid_mark;
    if (next.player.status.stun > 0) { next.player.status.stun--; }
    else if (spell.category === "attack" && spell.power_mult > 0) {
      accuracyFocus = next.player.status.focus_next ?? 0;
      accuracyMisalign = next.player.status.misalign_next ?? 0;
      delete next.player.status.focus_next;
      delete next.player.status.misalign_next;
      let power = spell.power_mult;
      for (const effect of spell.effects) if (effect.kind === "bonus_if_poisoned" && (next.boss.status.poison ?? 0) > 0) power *= 1 + effect.value;
      for (const effect of spell.effects) if (effect.kind === "bonus_if_hit_last_exchange" && next.player.spell_hit_last_exchange) power *= 1 + effect.value;
      for (const effect of spell.effects) {
        if (effect.kind === "bonus_power_if_poisoned" && poisonedBefore) power += effect.value;
        if (effect.kind === "bonus_if_shielded" && (next.player.status.shield_pct ?? 0) > 0) power += effect.value;
        if (effect.kind === "bonus_if_low_hp" && next.player.hp < next.player.max_hp * (effect.threshold ?? 0.4)) power += effect.value;
        if (effect.kind === "bonus_power_if_hit_last_exchange" && next.player.spell_hit_last_exchange) power += effect.value;
        if (effect.kind === "bonus_if_marked" && marked) power += effect.value;
      }
      success = hit(next.player, next.boss, spell.accuracy, power, "player");
    }
    else success = draw() < spell.accuracy;
    if (success && spell.type === "hybrid" && marked) delete next.boss.status.hybrid_mark;
    if (success) for (const effect of spell.effects) {
      const recipient = effect.target === "self" ? next.player : next.boss;
      if (["bonus_if_poisoned", "bonus_if_hit_last_exchange", "bonus_if_low_hp", "bonus_power_if_poisoned", "bonus_if_shielded", "bonus_power_if_hit_last_exchange", "bonus_if_marked", "pierce_ward", "ward_dispel"].includes(effect.kind)) continue;
      if (effect.kind === "hybrid_mark") { const before = JSON.stringify(recipient.status.hybrid_mark ?? {}); recipient.status.hybrid_mark = { owner: "player", remaining: Math.trunc(effect.value) }; if (recipient === next.boss && before !== JSON.stringify(recipient.status.hybrid_mark)) award(effect.kind); continue; }
      if (effect.kind === "tempo_shift") { const before = recipient.status.tempo_bonus ?? 0; recipient.status.tempo_bonus = effect.value; if (recipient === next.boss && effect.value < 0 && effect.value < before) award(effect.kind); continue; }
      if (effect.kind === "shield_by_order") { otherDefense(recipient, "shield_pct", playerFirst ? effect.value : effect.second_value ?? effect.value); continue; }
      if (effect.kind === "poison_on_reflect") { recipient.status.poison_on_reflect = Math.trunc(effect.value); continue; }
      if (effect.kind === "life_leech") { if (recipient.hp > 0) recipient.hp = Math.min(recipient.max_hp, recipient.hp + Math.min(effect.max_heal ?? 0, Math.floor(actualDamage * effect.value))); continue; }
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
        const before = recipient.status[field] ?? 0;
        if (["shield_pct", "reflect_pct"].includes(field)) otherDefense(recipient, field, effect.value);
        else recipient.status[field] = Math.max(recipient.status[field] ?? 0, effect.value);
        if (recipient === next.boss && ["atk_down", "vuln", "poison", "hom_stun", "misalign_next"].includes(effect.kind) && recipient.status[field] > before) award(effect.kind);
      }
    }
    }
    if (next.player.hp > 0 && decision.hom_action === "sacrifice" && !next.hom_spent) {
      if (next.hom_reflect_active !== undefined) {
        const independent = next.hom_other_reflect ?? 0;
        if (next.weapon_defenses.reflect_pct !== undefined) next.other_defenses.reflect_pct = independent;
        next.player.status.reflect_pct = Math.max(independent, next.weapon_defenses.reflect_pct ?? 0);
        delete next.hom_reflect_active;
        delete next.hom_other_reflect;
      }
      const oldEffects = next.item_effects;
      const unscaled = scaleWeapon(next.weapons[next.active_weapon_slot - 1].effects);
      next.player.atk += Math.trunc(unscaled.power_flat ?? 0) - Math.trunc(oldEffects.power_flat ?? 0);
      next.player.def += Math.trunc(unscaled.guard_flat ?? 0) - Math.trunc(oldEffects.guard_flat ?? 0);
      next.item_effects = unscaled;
      next.hom_spent = true;
      next.hom_energy = 0;
      next.player.atk -= next.hom_bonuses.atk;
      next.player.def -= next.hom_bonuses.def;
      next.player.max_hp -= next.hom_bonuses.hp;
      next.player.hp = Math.min(next.player.max_hp, Math.min(next.player.hp, next.player.max_hp) + 30);
      events.push({ actor: "player", kind: "hom_sacrifice" });
    } else if (next.player.hp > 0 && next.boss.hp > 0 && decision.hom_action === "attack" && !next.hom_spent) {
      const boosted = next.hom_energy >= 6;
      next.hom_energy = 0;
      if (next.player.status.hom_stun > 0) next.player.status.hom_stun--;
      else {
        let accuracy = 0.95 - (next.player.atk > next.boss.def * 1.6 ? 0.08 : 0);
        if (next.player.max_hp > next.boss.max_hp) accuracy -= Math.min(0.15, (next.player.max_hp - next.boss.max_hp) / next.player.max_hp * 0.2);
        if (draw() < Math.max(0.6, Math.min(0.98, accuracy))) {
          const damage = Math.max(1, Math.round(next.player.atk * (boosted ? 0.6 : 0.4)));
          next.boss.hp = Math.max(0, next.boss.hp - damage);
          next.boss.spell_hit_this_exchange = true;
          events.push({ actor: "player", kind: "hom_damage", damage });
        } else events.push({ actor: "player", kind: "hom_miss" });
      }
    }
    }
    if (playerFirst && next.boss.hp > 0 && next.player.hp > 0) bossAction();
    if (next.player.hp > 0 && next.boss.hp > 0) for (const fighter of [next.player, next.boss]) if (fighter.status.poison > 0) { fighter.status.poison--; fighter.hp = Math.max(0, fighter.hp - 2); fighter.spell_hit_this_exchange = true; }
    if (next.hom_id && !next.hom_spent) next.hom_energy = Math.min(6, next.hom_energy + 1);
  } catch (error) { if (error instanceof Error && error.message === "UNSUPPORTED_MECHANIC") return { error: "UNSUPPORTED_MECHANIC" }; throw error; }
  next.turn++;
  if (next.player.hp > 0 && next.boss.hp > 0 && next.turn % 2 === 1) {
    const homReflect = next.hom_spent ? 0 : Math.max(0, Math.min(1, next.hom_synergy?.reflect_pct ?? 0));
    if (homReflect > 0) {
      const independent = next.hom_reflect_active !== undefined ? next.hom_other_reflect ?? 0 : next.weapon_defenses.reflect_pct !== undefined ? next.other_defenses.reflect_pct ?? 0 : next.player.status.reflect_pct ?? 0;
      next.hom_other_reflect = independent;
      next.hom_reflect_active = homReflect;
      otherDefense(next.player, "reflect_pct", homReflect);
      next.hom_other_reflect = independent;
    }
    for (const [effect, status] of [["ward_pct", "shield_pct"], ["reflect_pct", "reflect_pct"]]) {
      const value = next.item_effects?.[effect] ?? 0;
      if (value > 0) {
        if (next.weapon_defenses[status] === undefined) next.other_defenses[status] = next.player.status[status] ?? 0;
        next.weapon_defenses[status] = Math.max(next.weapon_defenses[status] ?? 0, value);
        next.player.status[status] = Math.max(next.other_defenses[status], next.weapon_defenses[status]);
      }
    }
    if (next.turn === 1 && next.player.hp > next.boss.hp && (next.item_effects?.tempo_on_win ?? 0) > 0) next.player.status.tempo_bonus = next.item_effects.tempo_on_win;
  }
  for (const fighter of [next.player, next.boss]) fighter.spell_neutralize_active = 0;
  next.terminal_result = next.player.hp <= 0 ? "LOSS" : next.boss.hp <= 0 ? "WIN" : null;
  if (next.terminal_result) Object.assign(next, restoreInspiration(next));
  else if (next.player.inspiration_pending) {
    const unique = new Set<string>();
    const options = next.inspiration_catalog.filter((s: any) => !next.spell_ids.includes(s.id) && !unique.has(s.id) && !!unique.add(s.id));
    if (options.length < 3) return { error: "UNSUPPORTED_MECHANIC" };
    next.inspiration_offers = [];
    for (let i = 0; i < 3; i++) {
      const value = rng(next.turn, counter++);
      if (!Number.isFinite(value) || value < 0 || value >= 1) throw new Error("Invalid RNG draw");
      next.inspiration_offers.push(options.splice(Math.floor(value * options.length), 1)[0].id);
    }
  }
  next.rng_counter = counter;
  return { next_state: next, events, terminal_result: next.terminal_result };
}

// Pure cleanup for terminal/forfeit handling; permanent progression is external.
export function restoreInspiration(state: any): any {
  const result = structuredClone(state);
  if (Array.isArray(result.original_spell_ids)) result.spell_ids = [...result.original_spell_ids];
  if (result.temporary_spell_id) result.spells = result.spells.filter((s: any) => s.id !== result.temporary_spell_id || result.original_spell_ids.includes(s.id));
  if (result.temporary_spell_id && !result.original_spell_ids.includes(result.temporary_spell_id)) delete result.cooldowns[result.temporary_spell_id];
  result.temporary_spell_id = null;
  result.temporary_replaced_slot = null;
  result.inspiration_offers = [];
  result.player.inspiration = 0;
  result.player.inspiration_pending = false;
  return result;
}

export function resolveInspirationDecision(state: any, decision: any, rng: (turn: number, draw: number) => number): any {
  if (!state || state.terminal_result || !state.player?.inspiration_pending || state.player.inspiration_used_this_battle || !Array.isArray(state.inspiration_offers) || state.inspiration_offers.length !== 3 || !decision || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const keys = Object.keys(decision).sort().join(",");
  if (!(decision.kind === "decline" && keys === "kind") && !(decision.kind === "choose" && keys === "kind,spell_id" && typeof decision.spell_id === "string" && state.inspiration_offers.includes(decision.spell_id))) return { error: "INVALID_DECISION" };
  const next = structuredClone(state);
  if (decision.kind === "choose") {
    const spell = next.inspiration_catalog.find((entry: any) => entry.id === decision.spell_id);
    if (!spell || !castableSpell(spell, next.player.type) || !(spell.type === next.player.type || (spell.type === "hybrid" && spell.primary_type === next.player.type)) || next.spell_ids.includes(spell.id)) return { error: "INVALID_DECISION" };
    const random = rng(next.turn, next.rng_counter);
    if (!Number.isFinite(random) || random < 0 || random >= 1) throw new Error("Invalid RNG draw");
    const slot = Math.floor(random * 4);
    next.rng_counter++;
    next.spell_ids[slot] = spell.id;
    if (!next.spells.some((entry: any) => entry.id === spell.id)) next.spells.push(structuredClone(spell));
    next.temporary_spell_id = spell.id;
    next.temporary_replaced_slot = slot;
  } else next.player.inspiration = 0;
  next.player.inspiration_pending = false;
  next.player.inspiration_used_this_battle = true;
  next.inspiration_offers = [];
  return { next_state: next };
}
