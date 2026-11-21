import { newExpeditionPassiveState, beginPassiveExchange, applyCombatPassive, passiveModifiers, finishPassiveAttack, finishPassiveExchange, recordPassiveSpellHit } from "./expedition_passive_state";
import { homunculusAttackMultiplierById } from "./homunculus_catalog";
import { recordPoisonChange, poisonTickMetadata, recordInspirationActivation } from "./combat_event_provenance";
import { createHmac } from "node:crypto";
import type { Database } from "bun:sqlite";
import { castPhysicalAnomaly, physicalAnomalyMultiplier, tickPhysicalAnomaly, validPhysicalAnomalySpell } from "./physical_anomaly";
import { STRATEGIC_EFFECTS, finishStrategicExchange, jamStrategicCooldown, queueDelayedDamage, strategicCounter, strategicHeal, transferStrategicStatus, validStrategicStatusEffect } from "./strategic_effects";

export function dungeonSeason(timeMs: number): string {
  if (!Number.isSafeInteger(timeMs) || timeMs < 0) throw new Error("INVALID_DUNGEON_TIME");
  const date = new Date(timeMs);
  if (!Number.isFinite(date.getTime()) || date.getUTCFullYear() > 9999) throw new Error("INVALID_DUNGEON_TIME");
  return `${String(date.getUTCFullYear()).padStart(4, "0")}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

// The caller must authenticate the player before returning these stored results.
export function dungeonLeaderboard(db: Database, season: string, playerId: string) {
  if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(season) || typeof playerId !== "string" || !playerId || playerId.length > 256) throw new Error("INVALID_DUNGEON_LEADERBOARD");
  const ranking = `WITH ranked AS (
    SELECT b.player_id, p.display_name, b.cleared_floor, b.total_turns, b.achieved_at,
      ROW_NUMBER() OVER (ORDER BY b.cleared_floor DESC, b.total_turns ASC, b.achieved_at ASC, b.player_id ASC) AS rank
    FROM dungeon_monthly_best b JOIN players p ON p.player_id = b.player_id WHERE b.season = ?
  )`;
  const leaders = db.query(`${ranking} SELECT * FROM ranked ORDER BY rank LIMIT 50`).all(season);
  const player = db.query(`${ranking} SELECT * FROM ranked WHERE player_id = ?`).get(season, playerId) ?? null;
  return { season, leaders, player };
}

// This module only constructs an enemy. It does not verify or settle combat.
export function generateDungeonEncounter(seed: Uint8Array, runId: string, floor: number, enabled: boolean) {
  if (!enabled || floor < 5 || floor % 10 === 0) return null;
  const draw = (domain: string) => createHmac("sha256", seed).update(JSON.stringify(["dungeon-encounter-v1", runId, floor, domain])).digest().readUInt32BE(0);
  if (draw("chance") >= Math.floor(0x100000000 * 0.1)) return null;
  return [
    { kind: "corrupted_fog", label: "CORRUPTED FOG", hint: "Player starts vulnerable by 10%." },
    { kind: "crystal_bastion", label: "CRYSTAL BASTION", hint: "Enemy starts with a 15% shield." },
    { kind: "arcane_instability", label: "ARCANE INSTABILITY", hint: "Both fighters start with 10% attack boost." },
  ][draw("variant") % 3];
}
export function generateDungeonEnemy(seed: Uint8Array, runId: string, floor: number, catalogs: any, growth = { hp: 0.04, attack: 0.025, defense: 0.015 }, previous?: { hp: number; attack: number; defense: number; entity_id?: string; homunculus_id?: string; spell_ids?: string[] }, elitesEnabled = false, tacticsEnabled = false, trackBase = elitesEnabled) {
  if (!(seed instanceof Uint8Array) || seed.length < 32 || typeof runId !== "string" || !runId || !Number.isSafeInteger(floor) || floor < 1 || floor > 1000 || !catalogs || !Array.isArray(catalogs.entities) || !Array.isArray(catalogs.homunculi) || !Array.isArray(catalogs.spells) || !growth || [growth.hp, growth.attack, growth.defense].some(v => typeof v !== "number" || !Number.isFinite(v) || v < 0 || v > 0.1)) throw new Error("INVALID_DUNGEON_SETUP");
  const draw = (domain: string) => createHmac("sha256", seed).update(JSON.stringify(["dungeon-enemy-v1", runId, floor, domain])).digest().readUInt32BE(0);
  const entities = [...catalogs.entities].filter(e => e && typeof e.id === "string" && typeof e.type === "string" && e.base_stats && [e.base_stats.hp, e.base_stats.power, e.base_stats.guard].every(v => Number.isSafeInteger(v) && v > 0)).sort((a, b) => a.id.localeCompare(b.id));
  const homunculi = [...catalogs.homunculi].filter(h => h && typeof h.id === "string").sort((a, b) => a.id.localeCompare(b.id));
  if (!entities.length || !homunculi.length) throw new Error("INVALID_DUNGEON_CATALOG");
  const otherEntities = entities.filter(e => e.id !== previous?.entity_id);
  const otherHomunculi = homunculi.filter(h => h.id !== previous?.homunculus_id);
  const entityChoices = otherEntities.length ? otherEntities : entities;
  const homChoices = otherHomunculi.length ? otherHomunculi : homunculi;
  const entity = entityChoices[draw("entity") % entityChoices.length];
  const homunculus = homChoices[draw("homunculus") % homChoices.length];
  const candidates = catalogs.spells.filter(s => s && typeof s.id === "string" && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(entity.type) && Number.isInteger(s.tower_level_required) && s.research_cost && Number.isInteger(s.research_time_sec) && s.research_time_sec > 0)) && Array.isArray(s.effects) && s.effects.every((e: any) => DUNGEON_GENERATED_EFFECTS.has(e.kind) && validEffect(e) && (e.kind !== "physical_anomaly" || validPhysicalAnomalySpell(s))) && Number.isFinite(s.accuracy) && Number.isInteger(s.cooldown_turns) && s.cooldown_turns >= 0).sort((a, b) => a.id.localeCompare(b.id));
  const unique = [...new Map(candidates.map(s => [s.id, s])).values()] as any[];
  const advanced = unique.filter(s => s.type === "universal" || s.type === "hybrid");
  if (unique.length < 4 || !advanced.length) throw new Error("INVALID_DUNGEON_CATALOG");
  const attack = unique.filter(s => s.category === "attack" && s.cooldown_turns === 0 && s.power_mult > 0);
  if (!attack.length) throw new Error("INVALID_DUNGEON_CATALOG");
  const chosen = [attack[draw("basic") % attack.length]];
  if (floor >= 8) {
    const pairs: any[][] = [];
    for (const setup of unique) for (const follow of unique) {
      if (setup.id === follow.id || setup.id === chosen[0].id || follow.id === chosen[0].id) continue;
      const has = (s: any, k: string, target?: string) => s.effects.some((e: any) => e.kind === k && (!target || e.target === target));
      if ((has(setup, "poison", "enemy") && has(follow, "bonus_if_poisoned")) || (has(setup, "shield", "self") && has(follow, "ward_convert")) || (has(setup, "vuln", "enemy") && follow.category === "attack" && follow.power_mult >= 0.9)) pairs.push([setup, follow]);
    }
    const usable = pairs.filter(pair => pair.some(s => ["universal", "hybrid"].includes(s.type)));
    if (usable.length) chosen.push(...usable[draw("combo") % usable.length]);
  }
  const advancedChoices = advanced.filter(s => s.id !== chosen[0].id);
  if (!advancedChoices.length) throw new Error("INVALID_DUNGEON_CATALOG");
  if (chosen.length === 1) chosen.push(advancedChoices[draw("advanced") % advancedChoices.length]);
  const remaining = unique.filter(s => !chosen.some(c => c.id === s.id));
  while (chosen.length < 4) chosen.push(remaining.splice(draw(`spell-${chosen.length}`) % remaining.length, 1)[0]);
  if (previous?.spell_ids && chosen.every(s => previous.spell_ids!.includes(s.id))) {
    const alternatives = remaining.filter(s => !previous.spell_ids!.includes(s.id));
    if (alternatives.length) chosen[3] = alternatives[draw("variety") % alternatives.length];
  }
  const scale = (base: number, rate: number) => Math.min(90000, Math.round(base * Math.pow(1 + rate, floor - 1)));
  if (previous && [previous.hp, previous.attack, previous.defense].some(v => !Number.isSafeInteger(v) || v < 0 || v >= 100000)) throw new Error("DUNGEON_DIFFICULTY_LIMIT");
  const hp = Math.max(scale(entity.base_stats.hp, growth.hp), (previous?.hp ?? -1) + 1);
  const npcAttack = Math.max(scale(entity.base_stats.power, growth.attack), (previous?.attack ?? -1) + 1);
  const defense = Math.max(scale(entity.base_stats.guard, growth.defense), (previous?.defense ?? -1) + 1);
  const base = { hp, attack: npcAttack, defense };
  const variants = [
    { kind: "bulwark", label: "BULWARK", modifiers: { hp: 1.2, attack: 1, defense: 1.12 } },
    { kind: "reaver", label: "REAVER", modifiers: { hp: 1.12, attack: 1.1, defense: 1 } },
    { kind: "alchemist", label: "ALCHEMIST", modifiers: { hp: 1.15, attack: 1.05, defense: 1.05 } },
  ];
  const elite = elitesEnabled && floor % 10 === 0 ? variants[draw("elite") % variants.length] : null;
  const effective = elite ? Object.fromEntries(Object.entries(base).map(([key, value]) => [key, Math.min(99999, Math.round(value * elite.modifiers[key as keyof typeof base]))])) : base;
  const personalities = ["AGGRESSIVE", "DEFENSIVE", "OPPORTUNIST", "ALCHEMIST"];
  const npc_personality = elite ? ({ bulwark: "DEFENSIVE", reaver: "AGGRESSIVE", alchemist: "ALCHEMIST" } as Record<string, string>)[elite.kind] : personalities[draw("personality") % personalities.length];
  return { entity_id: entity.id, type: entity.type, homunculus_id: homunculus.id, homunculus_level: Math.min(10, Math.floor((floor - 1) / 3)), spell_ids: chosen.map(s => s.id), ...effective, ...(trackBase ? { base_stats: base, elite } : {}), ...(tacticsEnabled ? { npc_personality } : {}) };
}

export function dungeonPreviousBase(combat: any, homunculi: any[]): { hp: number; attack: number; defense: number } | null {
  const base = combat.npc_base_stats;
  if (!base) return null;
  if (![base.hp, base.attack, base.defense].every((n: unknown) => Number.isSafeInteger(n) && (n as number) >= 0)) throw new Error("INVALID_DUNGEON_BASE");
  if (combat.npc_base_stats_version === 2) return { hp: base.hp, attack: base.attack, defense: base.defense };
  if (combat.npc_base_stats_version !== undefined || !Number.isSafeInteger(combat.floor) || combat.floor < 1 || combat.floor > 1000) throw new Error("INVALID_DUNGEON_BASE");
  const hom = homunculi.find((h: any) => h.id === combat.npc?.hom_id);
  if (!hom) throw new Error("INVALID_DUNGEON_BASE");
  const level = Math.min(10, Math.floor((combat.floor - 1) / 3));
  const result = { hp: base.hp - (hom.buff_hp ?? 0) - level, attack: base.attack - (hom.buff_atk ?? 0) - Math.floor(level / 5), defense: base.defense - (hom.buff_def ?? 0) - Math.floor(level / 3) };
  if (Object.values(result).some(n => !Number.isSafeInteger(n) || n < 1)) throw new Error("INVALID_DUNGEON_BASE");
  return result;
}

// Only public, committed state belongs here; the player's next decision is not an input.
export function chooseDungeonNpcSpell(floor: number, equippedIds: string[], spells: any[], cooldowns: Record<string, number>, npc: any, target: any, roll: number, context: any = {}): string {
  if (!Number.isSafeInteger(floor) || floor < 1 || floor > 1000 || !Array.isArray(equippedIds) || equippedIds.length !== 4 || new Set(equippedIds).size !== 4 || !Array.isArray(spells) || !cooldowns || typeof cooldowns !== "object" || !npc || !target || typeof roll !== "number" || !Number.isFinite(roll) || roll < 0 || roll >= 1) throw new Error("INVALID_DUNGEON_DECISION");
  const legal = equippedIds.map(id => spells.find(s => s?.id === id)).filter(s => s && (s.type === npc.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(npc.type))) && Array.isArray(s.effects) && s.effects.every((e: any) => validEffect(e) && (e.kind !== "physical_anomaly" || validPhysicalAnomalySpell(s))) && Number.isFinite(s.power_mult) && Number.isFinite(s.accuracy) && s.accuracy >= 0 && s.accuracy <= 1 && Number.isInteger(s.cooldown_turns) && s.cooldown_turns >= 0 && Number.isInteger(cooldowns[s.id] ?? 0) && (cooldowns[s.id] ?? 0) === 0);
  if (legal.length === 0) throw new Error("NO_AVAILABLE_DUNGEON_SPELL");
  if (floor <= 3) return legal[Math.floor(roll * legal.length)].id;
  const enemyStatus = target.status ?? {}, ownStatus = npc.status ?? {};
  const allMoves = equippedIds.map(id => spells.find(s => s?.id === id)).filter(Boolean);
  const has = (s: any, kind: string) => s.effects.some((e: any) => e.kind === kind);
  const poisonFollow = allMoves.some(s => has(s, "bonus_if_poisoned") && (cooldowns[s.id] ?? 0) <= 1);
  const wardFollow = allMoves.some(s => has(s, "ward_convert") && (cooldowns[s.id] ?? 0) <= 1);
  const estimate = (s: any) => {
    const relation = context.types?.effectiveness?.[s.type]?.[target.type] ?? 1;
    let typeMultiplier = relation > 1 ? 1.25 : relation < 1 ? 0.8 : 1;
    if (context.personality && s.type === "hybrid") {
      const factor = (type: string) => { const value = context.types?.effectiveness?.[type]?.[target.type] ?? 1; return value > 1 ? 1.25 : value < 1 ? 0.8 : 1; };
      typeMultiplier = Math.max(0.8, Math.min(1.25, Math.pow(factor(s.primary_type), 0.65) * Math.pow(factor(s.secondary_type), 0.35)));
    } else if (context.personality && s.type === "universal") typeMultiplier = 1;
    const poison = s.effects.find((e: any) => e.kind === "bonus_if_poisoned");
    const power = s.power_mult * (poison && enemyStatus.poison > 0 ? 1 + poison.value : 1);
    const base = Math.max(1, Math.round(((npc.atk ?? 0) * (1 + (ownStatus.atk_boost ?? 0) - (ownStatus.atk_down ?? 0)) - Math.trunc((target.def ?? 0) * 0.5)) * typeMultiplier * physicalAnomalyMultiplier(context.anomaly, npc.type) * power * (1 + (enemyStatus.vuln ?? 0))));
    return enemyStatus.shield > 0 ? Math.max(0, Math.round(base * (1 - enemyStatus.shield))) : base;
  };
  const lethalAvailable = legal.some(s => s.category === "attack" && estimate(s) >= target.hp && s.accuracy > 0);
  const scored = legal.map(spell => {
    let score = spell.category === "attack" ? spell.power_mult * spell.accuracy * 100 : 20;
    if (lethalAvailable && spell.category === "attack" && estimate(spell) >= target.hp) score += 1000;
    for (const effect of spell.effects) {
      if (effect.kind === "heal") score += npc.hp < npc.max_hp * 0.6 ? Math.min(effect.value ?? 0, npc.max_hp - npc.hp) * 3 : -70;
      if (effect.kind === "shield" && !(ownStatus.shield > 0)) score += 35 + (floor >= 8 && wardFollow ? 75 : 0);
      if (effect.kind === "poison" && effect.target === "enemy" && !(enemyStatus.poison > 0)) score += 35 + (floor >= 8 && poisonFollow ? 80 : 0);
      if (effect.kind === "vuln" && effect.target === "enemy" && !(enemyStatus.vuln > 0)) score += 25;
      if (floor >= 8 && ["bonus_if_poisoned", "bonus_power_if_poisoned", "consume_poison"].includes(effect.kind) && enemyStatus.poison > 0) score += 65;
      if (floor >= 8 && ["bonus_if_shielded", "ward_convert"].includes(effect.kind) && ownStatus.shield > 0) score += 90;
      if (effect.kind === "counter_trap") score += npc.strategic_trap ? -100 : 20;
      if (effect.kind === "hom_energy_siphon") score += npc.hom_id && target.hom_id && target.hom_energy > 0 && npc.hom_energy < 6 ? 25 : -60;
      if (effect.kind === "physical_anomaly") {
        const anomaly = context.anomaly;
        const proposed = effect.favored_type === undefined ? spell : effect;
        score += proposed.favored_type === npc.type ? 30 : 0;
        score += proposed.weakened_type === target.type ? 30 : 0;
        score -= proposed.favored_type === target.type ? 60 : 0;
        score -= proposed.weakened_type === npc.type ? 60 : 0;
        if (anomaly?.favored_type === proposed.favored_type && anomaly?.weakened_type === proposed.weakened_type) score -= 120;
        else if (anomaly?.favored_type === npc.type || anomaly?.weakened_type === target.type) score -= 80;
      }
      if (effect.kind === "cooldown_jam" && floor >= 15) score += (target.spell_ids ?? []).some((id: string) => (target.cooldowns?.[id] ?? 0) === 0 && spells.some(s => s.id === id && s.cooldown_turns > 0 && s.power_mult >= 1)) ? 35 : 0;
      if (floor >= 15 && effect.kind === "atk_down" && !(enemyStatus.atk_down > 0)) score += 25;
    }
    if (floor >= 15 && enemyStatus.vuln > 0 && spell.category === "attack") score += spell.power_mult * 20;
    if (floor >= 8 && spell.category === "support" && npc.hp < npc.max_hp * 0.3 && !has(spell, "heal")) score -= 35;
    const personality = context.personality;
    if (personality) {
      const attack = spell.category === "attack", injured = npc.hp < npc.max_hp, shielded = ownStatus.shield > 0;
      const usefulHeal = spell.effects.some((e: any) => e.kind === "heal" && e.target === "self" && injured);
      const usefulShield = spell.effects.some((e: any) => e.kind === "shield" && e.target === "self" && !shielded);
      if (spell.category === "support" && has(spell, "heal") && !injured) score -= 1000;
      if (personality === "AGGRESSIVE" && attack) score += 35 + Math.round(25 * spell.accuracy);
      if (personality === "DEFENSIVE") { if (usefulHeal && npc.hp < npc.max_hp * 0.8) score += 60; else if (usefulShield && npc.hp < npc.max_hp * 0.8) score += 45; else if (attack && (!injured || shielded)) score += 35; }
      if (personality === "OPPORTUNIST") {
        if (attack && (enemyStatus.poison > 0 && spell.effects.some((e: any) => ["bonus_if_poisoned", "bonus_power_if_poisoned", "consume_poison"].includes(e.kind)) || enemyStatus.hybrid_mark?.owner === "npc" || enemyStatus.vuln > 0 || target.hp < target.max_hp * 0.35)) score += 60;
        if (spell.category === "support" && spell.effects.some((e: any) => ["poison", "vuln"].includes(e.kind) && e.target === "enemy") && !allMoves.some((s: any) => s.id !== spell.id && s.category === "attack" && (cooldowns[s.id] ?? 0) <= 1)) score -= 120;
      }
      if (personality === "ALCHEMIST") {
        const availableFollow = (kind: string) => allMoves.some((s: any) => s.id !== spell.id && (cooldowns[s.id] ?? 0) <= 1 && has(s, kind));
        const combo = spell.effects.some((e: any) => e.kind === "poison" && e.target === "enemy" && !(enemyStatus.poison > 0) && availableFollow("bonus_if_poisoned") || e.kind === "shield" && e.target === "self" && !shielded && availableFollow("ward_convert"));
        if (spell.category === "support" && spell.effects.some((e: any) => e.kind === "poison" && e.target === "enemy") && !combo) score -= 120;
        const strategic = spell.effects.some((e: any) => ["vuln", "atk_down", "cooldown_jam"].includes(e.kind) && e.target === "enemy" && !(enemyStatus[e.kind] > 0));
        const anomaly = spell.effects.some((e: any) => e.kind === "physical_anomaly") && spell.favored_type === npc.type && !(context.anomaly?.favored_type === spell.favored_type && context.anomaly?.weakened_type === spell.weakened_type);
        if (combo || anomaly) score += 60; else if (strategic) score += 30;
      }
    }
    return { id: spell.id, score };
  });
  const best = Math.max(...scored.map(s => s.score));
  const tied = scored.filter(s => s.score === best);
  return tied[Math.floor(roll * tied.length)].id;
}

const DUNGEON_GENERATED_EFFECTS = new Set(["atk_boost", "atk_down", "vuln", "shield", "reflect", "heal", "poison", "bonus_if_poisoned", "physical_anomaly", ...STRATEGIC_EFFECTS]);
const DUNGEON_EFFECTS = new Set([...DUNGEON_GENERATED_EFFECTS, "hom_stun", "type_neutralize", "bonus_if_hit_last_exchange", "cleanse_one", "pierce_ward", "focus_next", "life_leech", "misalign_next", "tempo_shift", "bonus_if_low_hp", "recoil", "hybrid_mark", "bonus_if_marked", "bonus_power_if_poisoned", "bonus_if_shielded", "consume_poison", "bonus_power_if_hit_last_exchange", "ward_dispel", "shield_by_order", "poison_on_reflect"]);
const validEffect = (e: any) => e && DUNGEON_EFFECTS.has(e.kind) && ["self", "enemy"].includes(e.target) && typeof e.value === "number" && Number.isFinite(e.value) && (e.value >= 0 || e.kind === "tempo_shift") && ["threshold", "max_heal", "second_value"].every(k => e[k] === undefined || (typeof e[k] === "number" && Number.isFinite(e[k]) && e[k] >= 0)) && (!STRATEGIC_EFFECTS.includes(e.kind) || validStrategicStatusEffect(e));
const DUNGEON_ITEMS = new Set(["power_flat", "guard_flat", "true_on_hit", "dot_true", "vuln_on_hit", "tempo_flat", "evasion_pct", "ward_pct", "reflect_pct", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"]);

export function dungeonEliteTrait(state: any) {
  if (state.elite_traits_enabled !== true || state.elites_enabled !== true || !Number.isInteger(state.floor) || state.floor % 10 !== 0) return null;
  const traits: Record<string, any> = { bulwark: { trait: "aegis_protocol", label: "AEGIS PROTOCOL", status: "shield", value: 0.15, target: "npc", hint: "At 70% HP or below, gains 15% shield." }, reaver: { trait: "bloodrush", label: "BLOODRUSH", status: "atk_boost", value: 0.15, target: "npc", hint: "At 50% HP or below, gains 15% attack for the next spell hit." }, alchemist: { trait: "catalytic_exposure", label: "CATALYTIC EXPOSURE", status: "vuln", value: 0.12, target: "player", hint: "A damaging spell hit can apply 12% vulnerability." } };
  const kind = state.elite?.kind, trait = traits[kind];
  const expected: Record<string, number[]> = { bulwark: [1.2, 1, 1.12], reaver: [1.12, 1.1, 1], alchemist: [1.15, 1.05, 1.05] };
  const modifiers = state.elite?.modifiers;
  return trait && state.elite?.label === kind.toUpperCase() && modifiers && [modifiers.hp, modifiers.attack, modifiers.defense].every((value, i) => value === expected[kind][i]) ? trait : null;
}

function dungeonInspirationCandidates(type: string, equipped: string[], spells: any[]): any[] {
  const seen = new Set<string>();
  return spells.filter(s => s && typeof s.id === "string" && !seen.has(s.id) && !equipped.includes(s.id) && (s.type === type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(type))) && ["attack", "support"].includes(s.category) && Number.isFinite(s.power_mult) && (s.category === "attack" ? s.power_mult > 0 : s.power_mult === 0) && Number.isFinite(s.accuracy) && s.accuracy >= 0 && s.accuracy <= 1 && Number.isInteger(s.cooldown_turns) && s.cooldown_turns >= 0 && Array.isArray(s.effects) && s.effects.every((e: any) => validEffect(e) && (e.kind !== "physical_anomaly" || validPhysicalAnomalySpell(s))) && !!seen.add(s.id));
}

export function hydrateDungeonInspiration(state: any, spells: any[]): boolean {
  if (!state?.player || !state?.npc || !Array.isArray(spells)) return false;
  for (const who of ["player", "npc"]) {
    const fighter = state[who];
    if (!Array.isArray(fighter.spell_ids) || fighter.spell_ids.length !== 4 || typeof fighter.type !== "string") return false;
    const candidates = dungeonInspirationCandidates(fighter.type, fighter.original_spell_ids ?? fighter.spell_ids, spells);
    if (candidates.length < 3) return false;
    state.inspiration_catalog ??= {};
    state.inspiration_catalog[who] = candidates;
    fighter.inspiration ??= 0; fighter.inspiration_pending ??= false; fighter.inspiration_used ??= false;
    fighter.inspiration_offers ??= []; fighter.original_spell_ids ??= [...fighter.spell_ids];
    fighter.temporary_spell_id ??= null; fighter.temporary_replaced_slot ??= null;
  }
  state.inspiration_catalog_version = 2;
  return true;
}

function restoreDungeonInspiration(state: any, fighter: any): void {
  if (fighter.temporary_spell_id) {
    delete fighter.cooldowns[fighter.temporary_spell_id];
    fighter.spell_ids = [...fighter.original_spell_ids];
    const id = fighter.temporary_spell_id;
    if (!state.player.spell_ids.includes(id) && !state.npc.spell_ids.includes(id)) state.spells = state.spells.filter((s: any) => s.id !== id);
  }
  fighter.inspiration_pending = false; fighter.inspiration_offers = []; fighter.temporary_spell_id = null; fighter.temporary_replaced_slot = null;
}

// setup must be the result of server-side loadout validation, never client input.
export function createDungeonCombatState(setup: any, enemy: any, catalogs: any, previousActiveSlot = 0): any {
  if (!setup?.entity?.base_stats || !Array.isArray(setup.spell_ids) || setup.spell_ids.length !== 4 || new Set(setup.spell_ids).size !== 4 || !enemy || !catalogs || !Array.isArray(enemy.spell_ids) || enemy.spell_ids.length !== 4 || !Array.isArray(catalogs.spells) || !Array.isArray(catalogs.homunculi) || !catalogs.types?.effectiveness) return { error: "UNTRUSTED_SETUP" };
  const equipment = setup.weapons ?? [{ id: setup.item_id, effects: setup.itemEffects ?? {} }, { id: null, effects: {} }];
  if (!Array.isArray(equipment) || equipment.length !== 2 || equipment.some((w: any) => !w || !w.effects || Object.entries(w.effects).some(([key, value]) => !DUNGEON_ITEMS.has(key) && value !== 0))) return { error: "UNSUPPORTED_MECHANIC" };
  const factor = Math.max(0, Math.min(2, setup.hom_id ? setup.hom_synergy?.item_effect_mult ?? 1 : 1));
  const weapons = equipment.map((w: any) => ({ id: w.id ?? null, effects: Object.fromEntries(Object.entries(w.effects).map(([key, value]) => [key, (value as number) * factor])) }));
  const activeSlot = [1, 2].includes(previousActiveSlot) && weapons[previousActiveSlot - 1]?.id ? previousActiveSlot : weapons[0].id ? 1 : weapons[1].id ? 2 : 0;
  const effects = activeSlot ? weapons[activeSlot - 1].effects : {};
  const spells = [...setup.spell_ids, ...enemy.spell_ids].map(id => catalogs.spells.find((s: any) => s.id === id));
  if (spells.some(s => !s || !Array.isArray(s.effects) || s.effects.some((e: any) => !validEffect(e) || (e.kind === "physical_anomaly" && !validPhysicalAnomalySpell(s))))) return { error: "UNSUPPORTED_MECHANIC" };
  if (spells.some((s, i) => !(s.type === (i < 4 ? setup.entity.type : enemy.type) || (["universal", "hybrid"].includes(s.type) && s.eligible_types?.includes(i < 4 ? setup.entity.type : enemy.type))))) return { error: "UNTRUSTED_SETUP" };
  const hom = catalogs.homunculi.find((h: any) => h.id === enemy.homunculus_id);
  if (!hom || !Number.isInteger(enemy.homunculus_level) || enemy.homunculus_level < 0 || enemy.homunculus_level > 10 || [enemy.hp, enemy.attack, enemy.defense].some(v => !Number.isSafeInteger(v) || v < 1 || v > 100000)) return { error: "UNTRUSTED_SETUP" };
  if (enemy.base_stats && [enemy.base_stats.hp, enemy.base_stats.attack, enemy.base_stats.defense].some(v => !Number.isSafeInteger(v) || v < 1 || v > 100000)) return { error: "UNTRUSTED_SETUP" };
  const stats = setup.entity.base_stats, bonus = setup.bonuses ?? {};
  const npcTempo = catalogs.entities?.find((entity: any) => entity.id === enemy.entity_id)?.base_stats?.tempo ?? 10;
  const npcHp = enemy.hp + (hom.buff_hp ?? 0) + enemy.homunculus_level;
  const player: any = { id: setup.entity.id, type: setup.entity.type, tempo: stats.tempo ?? 10, hp: stats.hp + (bonus.hp ?? 0), max_hp: stats.hp + (bonus.hp ?? 0), atk: stats.power + (bonus.atk ?? 0) + Math.trunc(effects.power_flat ?? 0), def: stats.guard + (bonus.def ?? 0) + Math.trunc(effects.guard_flat ?? 0), hom_id: setup.hom_id ?? null, hom_energy: 0, status: {}, cooldowns: {}, spell_ids: [...setup.spell_ids] };
  if (setup.hom_passive_level !== undefined) player.expedition_passive = newExpeditionPassiveState(setup.hom_id, setup.hom_passive_level);
  const npc = { id: enemy.entity_id, type: enemy.type, tempo: npcTempo, hp: npcHp, max_hp: npcHp, atk: enemy.attack + (hom.buff_atk ?? 0) + Math.floor(enemy.homunculus_level / 5), def: enemy.defense + (hom.buff_def ?? 0) + Math.floor(enemy.homunculus_level / 3), hom_id: hom.id, hom_energy: 0, status: {}, cooldowns: {}, spell_ids: [...enemy.spell_ids] };
  if (!enemy.elite && enemy.special_encounter?.kind === "corrupted_fog") Object.assign(player.status, { vuln: 0.1 });
  if (!enemy.elite && enemy.special_encounter?.kind === "crystal_bastion") Object.assign(npc.status, { shield: 0.15 });
  if (!enemy.elite && enemy.special_encounter?.kind === "arcane_instability") { Object.assign(player.status, { atk_boost: 0.1 }); Object.assign(npc.status, { atk_boost: 0.1 }); }
  if (enemy.elite) { npc.hp = npc.max_hp = Math.min(99999, npc.max_hp); npc.atk = Math.min(99999, npc.atk); npc.def = Math.min(99999, npc.def); }
  const inspirationCatalog = { player: dungeonInspirationCandidates(player.type, player.spell_ids, catalogs.spells), npc: dungeonInspirationCandidates(npc.type, npc.spell_ids, catalogs.spells) };
  if (inspirationCatalog.player.length < 3 || inspirationCatalog.npc.length < 3) return { error: "UNSUPPORTED_MECHANIC" };
  for (const fighter of [player, npc]) Object.assign(fighter, { inspiration: 0, inspiration_pending: false, inspiration_used: false, inspiration_offers: [], original_spell_ids: [...fighter.spell_ids], temporary_spell_id: null, temporary_replaced_slot: null });
  return { player, npc, ...(!enemy.elite && enemy.special_encounter ? { special_encounter: structuredClone(enemy.special_encounter) } : {}), ...(enemy.base_stats ? { npc_base_stats: structuredClone(enemy.base_stats), npc_base_stats_version: 2, elite: enemy.elite ?? null } : {}), ...(enemy.npc_personality ? { npc_personality: enemy.npc_personality } : {}), inspiration_catalog: structuredClone(inspirationCatalog), inspiration_catalog_version: 2, weapons, active_weapon_slot: activeSlot, item_id: activeSlot ? weapons[activeSlot - 1].id : null, item_effects: effects, hom_tempo: setup.hom_tempo ?? 0, hom_synergy: structuredClone(setup.hom_id ? setup.hom_synergy ?? {} : {}), hom_advantage: setup.hom_id ? setup.hom_advantage ?? 0 : 0, weapon_defenses: {}, other_defenses: {}, spells: structuredClone(spells), types: structuredClone(catalogs.types), floor: enemy.floor ?? 1, turn: 0, rng_counter: 0, terminal_result: null, physical_anomaly: null };
}

export function createDungeonBlessing(seed: Uint8Array, runId: string, floor: number, hasHom: boolean): any {
  if (floor < 3 || floor % 3 !== 0) return null;
  const tier = Math.min(7, Math.floor(floor / 3));
  const offers = ["elemental_surge", hasHom ? "homunculus_resonance" : "player_shield", "toxin_ward"];
  for (let i = offers.length - 1; i > 0; i--) {
    const draw = createHmac("sha256", seed).update(JSON.stringify(["dungeon-blessing-v1", runId, floor, i])).digest().readUInt32BE(0);
    const j = draw % (i + 1); [offers[i], offers[j]] = [offers[j], offers[i]];
  }
  return { tier, offers, pending: true, selected: null, spell_count: 0, procs: 0, poison_remainder: 0, shield_used: false };
}

export function publicDungeonBlessing(blessing: any): any {
  if (!blessing) return null;
  const tier = blessing.tier, pct = Math.min(10, 4 + tier), ward = Math.min(50, 20 + 5 * (tier - 1));
  const metadata: Record<string, any> = {
    elemental_surge: { id: "elemental_surge", name: "Elemental Surge", description: `Direct elemental spell damage +${pct}%.` },
    homunculus_resonance: { id: "homunculus_resonance", name: "Homunculus Resonance", description: `+1 hom energy after ${tier < 3 ? 3 : 2} successful spells, up to ${tier < 5 ? 1 : 2} times this floor.` },
    player_shield: { id: "player_shield", name: "Protective Ward", description: `Reduce one incoming direct hit by ${pct}%.` },
    toxin_ward: { id: "toxin_ward", name: "Toxin Ward", description: `Poison tick damage reduced by ${ward}%, minimum 1 damage.` },
  };
  return { tier, pending: blessing.pending, offers: blessing.pending ? blessing.offers.map((id: string) => metadata[id]) : [], selected: blessing.selected ? metadata[blessing.selected] : null };
}

export function resolveDungeonBlessing(state: any, decision: any): any {
  const b = state?.blessing;
  if (!state || state.terminal_result || !b?.pending || !decision || typeof decision !== "object" || Array.isArray(decision) || Object.keys(decision).sort().join(",") !== "blessing_id" || typeof decision.blessing_id !== "string" || !b.offers.includes(decision.blessing_id)) return { error: "INVALID_DECISION" };
  const next = structuredClone(state); next.blessing.pending = false; next.blessing.selected = decision.blessing_id;
  return { next_state: next, events: [{ kind: "blessing_selected", actor: "player", blessing_id: decision.blessing_id }] };
}

export function resolveDungeonTurn(state: any, decision: any, rng: (turn: number, draw: number) => number): any {
  if (!state || state.terminal_result || state.blessing?.pending || state.player?.inspiration_pending || !decision || typeof decision !== "object" || Object.keys(decision).some(k => !["turn", "spell_id", "hom_action", "switch_slot"].includes(k)) || decision.turn !== state.turn + 1 || ![undefined, "hold", "attack"].includes(decision.hom_action) || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const switching = decision.switch_slot !== undefined;
  if (switching && (decision.spell_id !== undefined || decision.hom_action !== undefined || ![1, 2].includes(decision.switch_slot) || decision.switch_slot === state.active_weapon_slot || !state.weapons?.[decision.switch_slot - 1]?.id)) return { error: "INVALID_DECISION" };
  const spell = switching ? null : state.spells.find((s: any) => s.id === decision.spell_id && state.player.spell_ids.includes(s.id));
  if (!switching && (!spell || (state.player.cooldowns[spell.id] ?? 0) > 0 || (decision.hom_action === "attack" && (!state.player.hom_id || state.player.hom_energy < 3)))) return { error: "INVALID_DECISION" };
  if (state.spells.some((s: any) => !Array.isArray(s.effects) || s.effects.some((e: any) => !validEffect(e) || (e.kind === "physical_anomaly" && !validPhysicalAnomalySpell(s))))) return { error: "UNSUPPORTED_MECHANIC" };
  const next = structuredClone(state), events: any[] = [];
  const firePassive = (event: any, poisonDamage = 0, attack: any = null) => applyCombatPassive(next.player, next.npc, event, next.types, "player", "npc", events, poisonDamage, attack);
  const modifiers = () => next.player.expedition_passive ? passiveModifiers(next.player.expedition_passive) : {};
  if (next.player.expedition_passive) {
    next.player.expedition_passive = beginPassiveExchange(next.player.expedition_passive, decision.turn);
    firePassive("before_exchange");
  }
  let vitriolCorrosionUsed = 0;
  for (const fighter of [next.player, next.npc]) {
    fighter.spell_hit_last_exchange = fighter.spell_hit_this_exchange ?? false;
    fighter.spell_hit_this_exchange = false;
    fighter.spell_neutralize_active = fighter.spell_neutralize_pending ?? 0;
    fighter.spell_neutralize_pending = 0;
  }
  next.weapon_defenses ??= {}; next.other_defenses ??= {};
  const pendingJams: { target: any; actor: string; targetId: string }[] = [];
  let counter = next.rng_counter;
  const draw = () => { const value = rng(decision.turn, counter++); if (!Number.isFinite(value) || value < 0 || value >= 1) throw new Error("INVALID_RNG"); return value; };
  let npcSpell: any;
  try {
    const npcId = chooseDungeonNpcSpell(next.floor, next.npc.spell_ids, next.spells, next.npc.cooldowns, next.npc, next.player, draw(), { anomaly: next.physical_anomaly, delayed: next.strategic_delayed, types: next.types, personality: next.tactics_enabled === true ? next.npc_personality : undefined });
    npcSpell = next.spells.find((s: any) => s.id === npcId);
  } catch (err) {
    if (!(err instanceof Error) || err.message !== "NO_AVAILABLE_DUNGEON_SPELL") throw err;
    npcSpell = { id: "basic_attack", type: next.npc.type, category: "attack", accuracy: 0.9, power_mult: 1, cooldown_turns: 0, effects: [] };
  }
  const clearDefense = (fighter: any, field: string) => {
    delete fighter.status[field];
    if (fighter === next.player) { delete next.weapon_defenses[field]; delete next.other_defenses[field]; }
  };
  const applyDefense = (fighter: any, field: string, value: number) => {
    if (fighter === next.player && next.weapon_defenses[field] !== undefined) next.other_defenses[field] = Math.max(next.other_defenses[field] ?? 0, value);
    fighter.status[field] = Math.max(fighter.status[field] ?? 0, value);
  };
  const awardInspiration = (actor: any, who: string, source: string) => {
    if (actor.inspiration_used || actor.inspiration_pending || actor.inspiration >= 3) return;
    actor.inspiration = Math.min(3, (actor.inspiration ?? 0) + 1);
    events.push({ kind: "inspiration", actor: who, value: actor.inspiration, source });
  };
  const triggerEliteTrait = (timing: string, directDamage = 0) => {
    const trait = dungeonEliteTrait(next);
    if (!trait || next.elite_trait_used || next.player.hp <= 0 || next.npc.hp <= 0) return;
    if (timing === "hit" ? trait.trait !== "catalytic_exposure" || directDamage <= 0 : trait.trait === "catalytic_exposure" || next.npc.hp > next.npc.max_hp * (trait.trait === "aegis_protocol" ? 0.7 : 0.5)) return;
    const recipient = next[trait.target], previous = recipient.status[trait.status] ?? 0;
    if (previous >= trait.value) return;
    recipient.status[trait.status] = trait.value; next.elite_trait_used = true;
    events.push({ kind: "elite_trait_triggered", actor: "npc", target: trait.target, trait: trait.trait, label: trait.label });
    events.push({ kind: "status_applied", actor: "npc", target: trait.target, status: trait.status, previous, value: trait.value, source: "elite" });
  };
  const act = (actor: any, target: any, chosen: any, who: string) => {
    if (actor.hp <= 0 || target.hp <= 0) return;
    actor.cooldowns[chosen.id] = chosen.cooldown_turns + 1;
    if (chosen.category === "attack" && who === "npc" && (next.item_effects?.evasion_pct ?? 0) + (modifiers().evasion_pct ?? 0) > 0 && draw() < Math.min(1, (next.item_effects?.evasion_pct ?? 0) + (modifiers().evasion_pct ?? 0))) { events.push({ kind: "evade", actor: "player", target: "npc" }); firePassive("dodge"); return; }
    const poisonedBefore = (target.status.poison ?? 0) > 0;
    const mark = target.status.hybrid_mark;
    const marked = mark?.owner === who && mark.remaining > 0;
    if (marked && --mark.remaining <= 0) delete target.status.hybrid_mark;
    if (chosen.category === "attack" && who === "player") firePassive("before_attack", 0, chosen);
    let accuracy = chosen.accuracy;
    if (chosen.category === "attack") {
      accuracy = Math.max(0, Math.min(1, accuracy + (actor.status.focus_next ?? 0) - (actor.status.misalign_next ?? 0) + (who === "player" ? modifiers().accuracy_pct ?? 0 : 0)));
      delete actor.status.focus_next; delete actor.status.misalign_next;
    } else if (who === "player") accuracy = Math.max(0, Math.min(1, accuracy + (modifiers().accuracy_pct ?? 0)));
    const hit = draw() < accuracy;
    events.push({ kind: "spell", actor: who, spell_id: chosen.id, hit });
    if (who === "player" && chosen.category === "attack" && actor.expedition_passive) {
      actor.expedition_passive = recordPassiveSpellHit(actor.expedition_passive, hit);
      if (!hit) { actor.expedition_passive = finishPassiveAttack(actor.expedition_passive); firePassive("spell_miss"); }
    }
    if (!hit) { if (who === "player" && chosen.category !== "attack") firePassive("spell_miss"); return; }
    let directDamage = 0, unblessedDirectDamage = 0;
    const previousWard = actor === next.player && next.weapon_defenses.shield !== undefined ? next.other_defenses.shield ?? 0 : actor.status.shield ?? 0;
    if (chosen.category === "attack") {
      const relation = next.types.effectiveness[chosen.type]?.[target.type] ?? 1;
      let mult = relation > 1 ? 1.18 : relation < 1 ? 0.84 : 1;
      if (chosen.type === "hybrid") {
        const factor = (type: string) => { const value = next.types.effectiveness[type]?.[target.type] ?? 1; return value > 1 ? 1.25 : value < 1 ? 0.8 : 1; };
        mult = Math.max(0.8, Math.min(1.25, Math.pow(factor(chosen.primary_type), 0.65) * Math.pow(factor(chosen.secondary_type), 0.35)));
      } else if (chosen.type === "universal") mult = 1;
      if (who === "player" && chosen.type === actor.type && relation < 1) mult = Math.min(1, mult + (next.item_effects?.disadvantage_reduction ?? 0));
      if (who === "player" && chosen.type !== "universal" && mult > 1) mult += next.hom_advantage ?? 0;
      if (chosen.type !== "universal") mult = 1 + (mult - 1) * (1 - Math.max(actor.spell_neutralize_active ?? 0, target.spell_neutralize_active ?? 0, next.hom_synergy?.type_neutralize ?? 0));
      const poisonBonus = chosen.effects.find((e: any) => e.kind === "bonus_if_poisoned");
      let power = chosen.power_mult * (poisonBonus && poisonedBefore ? 1 + poisonBonus.value : 1);
      for (const effect of chosen.effects) {
        if (effect.kind === "bonus_if_hit_last_exchange" && actor.spell_hit_last_exchange) power *= 1 + effect.value;
        if ((effect.kind === "bonus_power_if_poisoned" && poisonedBefore) || (effect.kind === "bonus_if_shielded" && actor.status.shield > 0) || (effect.kind === "bonus_if_low_hp" && actor.hp < actor.max_hp * (effect.threshold ?? 0.4)) || (effect.kind === "bonus_power_if_hit_last_exchange" && actor.spell_hit_last_exchange) || (effect.kind === "bonus_if_marked" && marked)) power += effect.value;
      }
      const base = ((actor.atk + (who === "player" ? modifiers().power_flat ?? 0 : 0)) * (1 + (actor.status.atk_boost ?? 0) - (actor.status.atk_down ?? 0)) - Math.trunc((target.def + (who === "npc" ? modifiers().guard_flat ?? 0 : 0)) * 0.5)) * mult * physicalAnomalyMultiplier(next.physical_anomaly, actor.type) * (1 + (target.status.vuln ?? 0));
      for (const [fighter, id, fields] of [[actor, who, ["atk_boost", "atk_down"]], [target, who === "player" ? "npc" : "player", ["vuln"]]] as const) {
        for (const status of fields) {
          const previous = fighter.status[status] ?? 0;
          if (previous > 0) { delete fighter.status[status]; events.push({ kind: "status_consumed", target: id, status, previous, remaining: 0 }); }
        }
      }
      const shield = target.status.shield ?? 0;
      const baseline = Math.min(target.hp, shield > 0 ? Math.max(0, Math.round(Math.max(1, Math.round(base * chosen.power_mult)) * (1 - shield))) : Math.max(1, Math.round(base * chosen.power_mult)));
      let unblessedDamage = Math.max(1, Math.round(base * power));
      let damage = Math.max(1, Math.round(base * power * (who === "player" && next.blessing?.selected === "elemental_surge" && ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold", "hybrid"].includes(chosen.type) ? 1 + Math.min(10, 4 + next.blessing.tier) / 100 : 1)));
      if (who === "npc") { const incoming = Math.max(0.1, Math.min(1, next.hom_synergy?.incoming_mult ?? 1)); damage = Math.max(1, Math.round(damage * incoming)); unblessedDamage = Math.max(1, Math.round(unblessedDamage * incoming)); }
      if (who === "npc" && next.blessing?.selected === "player_shield" && !next.blessing.shield_used) { damage = Math.max(1, Math.round(damage * (1 - Math.min(10, 4 + next.blessing.tier) / 100))); next.blessing.shield_used = true; }
      if (target.status.shield > 0) {
        const dispel = Math.max(0, Math.min(1, chosen.effects.find((e: any) => e.kind === "ward_dispel")?.value ?? 0));
        const pierce = Math.max(0, Math.min(1, chosen.effects.find((e: any) => e.kind === "pierce_ward")?.value ?? 0));
        unblessedDamage = Math.max(0, Math.round(unblessedDamage * (1 - target.status.shield * (1 - dispel) * (1 - pierce))));
        damage = Math.max(0, Math.round(damage * (1 - target.status.shield * (1 - dispel) * (1 - pierce)))); clearDefense(target, "shield");
      }
      directDamage = Math.min(target.hp, damage); unblessedDirectDamage = who === "player" && next.blessing?.selected === "elemental_surge" ? Math.min(target.hp, unblessedDamage) : directDamage;
      target.hp = Math.max(0, target.hp - damage); if (who === "npc" && directDamage > 0) firePassive("damage_received"); if (directDamage > 0) target.spell_hit_this_exchange = true; events.push({ kind: "damage", actor: who, amount: damage, hp: target.hp, target_status: structuredClone(target.status) });
      if ((target.status.reflect ?? 0) > 0) {
        const ignored = who === "player" && (next.item_effects?.ignore_reflect_chance ?? 0) > 0 && draw() < Math.min(1, next.item_effects.ignore_reflect_chance);
        const amount = ignored ? 0 : Math.min(actor.hp, Math.round((who === "player" && next.blessing?.selected === "elemental_surge" ? unblessedDamage : damage) * target.status.reflect));
        actor.hp -= amount;
        if (who === "player" && amount > 0) firePassive("damage_received");
        clearDefense(target, "reflect");
        if (amount > 0) actor.spell_hit_this_exchange = true;
        const poison = target.status.poison_on_reflect ?? 0;
        if (!ignored && poison > 0) { const previous = actor.status.poison ?? 0; actor.status.poison = Math.max(previous, poison); recordPoisonChange(actor, previous, typeof target.poison_reflect_source === "string" ? target.poison_reflect_source : null); if (actor.status.poison > previous) events.push({ kind: "status_applied", actor: who === "player" ? "npc" : "player", target: who, status: "poison", previous, value: actor.status.poison, source: "poison_on_reflect" }); }
        delete target.status.poison_on_reflect; delete target.poison_reflect_source;
        events.push({ kind: "reflect", actor: who === "player" ? "npc" : "player", target: who, amount, hp: actor.hp, ignored });
      }
      if (who === "player") {
        for (const key of ["true_on_hit", "dot_true"]) {
          let amount = Math.min(target.hp, Math.max(0, Math.trunc(next.item_effects?.[key] ?? 0)));
          if (key === "dot_true" && next.item_id === "vitriol_vial") { amount = Math.min(amount, 4 - vitriolCorrosionUsed); vitriolCorrosionUsed += amount; }
          if (amount > 0) { target.hp -= amount; events.push({ kind: key, actor: who, target: "npc", amount, hp: target.hp }); }
        }
        if ((next.item_effects?.dot_true ?? 0) > 0 && (next.item_effects?.vuln_on_hit ?? 0) > 0) target.status.vuln = Math.max(target.status.vuln ?? 0, Math.min(1, next.item_effects.vuln_on_hit));
        const homDot = Math.min(target.hp, Math.max(0, Math.trunc(next.hom_synergy?.dot_true ?? 0)));
        if (homDot > 0) { target.hp -= homDot; events.push({ kind: "hom_dot", actor: who, target: "npc", amount: homDot, hp: target.hp }); }
      }
      if (poisonBonus && target.status.poison > 0 && directDamage > baseline) events.push({ kind: "combo_trigger", actor: who, target: who === "player" ? "npc" : "player", source_spell_id: chosen.id, prerequisite: "poison", actual_bonus_damage: directDamage - baseline, resulting_status: { poison: target.status.poison } });
    }
    if (chosen.type === "hybrid" && marked) delete target.status.hybrid_mark;
    const conversion = chosen.effects.find((e: any) => e.kind === "ward_convert");
    if (chosen.category === "attack" && conversion && previousWard > 0) {
      if (actor === next.player && next.weapon_defenses.shield !== undefined) { delete next.other_defenses.shield; actor.status.shield = next.weapon_defenses.shield; }
      else delete actor.status.shield;
      const amount = Math.min(target.hp, Math.floor(target.max_hp * 0.2), Math.floor(actor.max_hp * previousWard * conversion.value));
      target.hp -= amount;
      events.push({ kind: "ward_convert", actor: who, target: who === "player" ? "npc" : "player", shield: previousWard, amount, hp: target.hp });
    }
    for (const e of chosen.effects) {
      if (["bonus_if_poisoned", "bonus_if_hit_last_exchange", "bonus_if_low_hp", "bonus_power_if_poisoned", "bonus_if_shielded", "bonus_power_if_hit_last_exchange", "bonus_if_marked", "pierce_ward", "ward_dispel"].includes(e.kind)) continue;
      if (e.kind === "physical_anomaly") { next.physical_anomaly = castPhysicalAnomaly(chosen, decision.turn); events.push({ kind: "physical_anomaly_cast", actor: who, anomaly: structuredClone(next.physical_anomaly) }); continue; }
      if (e.kind === "debuff_transfer" || e.kind === "buff_steal") {
        const previousEvents = events.length;
        const previousPoison = target.status.poison ?? 0;
        transferStrategicStatus(e.kind, actor, target, who, who === "player" ? "npc" : "player", { vuln: "vuln", shield: "shield", reflect: "reflect" }, events, clearDefense, applyDefense);
        recordPoisonChange(target, previousPoison, who);
        recordPoisonChange(actor, actor.status.poison ?? 0, null);
        const changed = events[previousEvents];
        if (e.kind === "debuff_transfer" && changed && ["poison", "vuln", "atk_down"].includes(changed.status) && changed.value > changed.previous) awardInspiration(actor, who, e.kind);
        continue;
      }
      if (e.kind === "cooldown_jam") { pendingJams.push({ target, actor: who, targetId: who === "player" ? "npc" : "player" }); continue; }
      if (e.kind === "hom_energy_siphon") {
        const amount = actor.hom_id && target.hom_id ? Math.min(2, target.hom_energy, 6 - actor.hom_energy) : 0;
        if (amount > 0) { target.hom_energy -= amount; actor.hom_energy += amount; events.push({ kind: "hom_energy_siphon", actor: who, target: who === "player" ? "npc" : "player", amount, actor_energy: actor.hom_energy, target_energy: target.hom_energy }); }
        continue;
      }
      if (e.kind === "delayed_damage") { if (chosen.category === "attack") queueDelayedDamage(next, who, who === "player" ? "npc" : "player", e.value, unblessedDirectDamage, decision.turn, events); continue; }
      if (e.kind === "ward_convert") continue;
      if (e.kind === "counter_trap") { actor.strategic_trap = { value: e.value, activated_turn: decision.turn, expires_turn: decision.turn + 2 }; events.push({ kind: "counter_trap_armed", actor: who, target: who, value: e.value, expires_turn: decision.turn + 2 }); continue; }
      if (e.kind === "heal_suppression") { target.strategic_heal_suppression = { expires_turn: decision.turn + 2 }; events.push({ kind: "heal_suppression_applied", actor: who, target: who === "player" ? "npc" : "player", value: e.value, expires_turn: decision.turn + 2 }); continue; }
      const recipient = e.target === "self" ? actor : target;
      const recipientId = recipient === next.player ? "player" : "npc";
      if (e.kind === "type_neutralize") { recipient.spell_neutralize_pending = Math.max(recipient.spell_neutralize_pending ?? 0, e.value); continue; }
      if (e.kind === "cleanse_one") { for (const field of ["poison", "stun", "vuln", "atk_down", "misalign_next"]) if ((recipient.status[field] ?? 0) > 0) { events.push({ kind: "status_cleansed", actor: who, target: recipientId, status: field, previous: recipient.status[field] }); delete recipient.status[field]; if (field === "poison") recordPoisonChange(recipient, 0, null); break; } continue; }
      if (e.kind === "recoil") { const amount = Math.min(recipient.hp, Math.trunc(e.value)); recipient.hp -= amount; if (amount > 0) recipient.spell_hit_this_exchange = true; events.push({ kind: "recoil", actor: who, target: recipientId, amount, hp: recipient.hp }); continue; }
      if (e.kind === "consume_poison") { if (poisonedBefore) { recipient.status.poison = Math.max(0, (recipient.status.poison ?? 0) - Math.trunc(e.value)); recordPoisonChange(recipient, recipient.status.poison, null); } continue; }
      if (e.kind === "life_leech") { const before = recipient.hp; if (before > 0) recipient.hp = Math.min(recipient.max_hp, before + strategicHeal(recipient, Math.min(e.max_heal ?? 0, Math.floor(directDamage * e.value)))); if (recipient.hp > before) events.push({ kind: "heal", actor: who, target: recipientId, amount: recipient.hp - before, hp: recipient.hp }); continue; }
      if (e.kind === "hybrid_mark") { const before = JSON.stringify(recipient.status.hybrid_mark ?? {}); recipient.status.hybrid_mark = { owner: who, remaining: Math.trunc(e.value) }; if (before !== JSON.stringify(recipient.status.hybrid_mark) && recipient === target) awardInspiration(actor, who, e.kind); events.push({ kind: "status_applied", actor: who, target: recipientId, status: "hybrid_mark", value: structuredClone(recipient.status.hybrid_mark) }); continue; }
      if (e.kind === "tempo_shift") { const previous = recipient.status.tempo_bonus ?? 0; recipient.status.tempo_bonus = e.value; if (recipient === target && e.value < 0 && e.value < previous) awardInspiration(actor, who, e.kind); events.push({ kind: "status_applied", actor: who, target: recipientId, status: "tempo_bonus", previous, value: e.value }); continue; }
      if (e.kind === "shield_by_order") { applyDefense(recipient, "shield", (who === "player") === playerFirst ? e.value : e.second_value ?? e.value); continue; }
      if (e.kind === "heal") {
        const before = recipient.hp;
        if (before > 0) recipient.hp = Math.min(recipient.max_hp, before + strategicHeal(recipient, e.value));
        if (recipient.hp > before) events.push({ kind: "heal", actor: who, target: recipientId, amount: recipient.hp - before, hp: recipient.hp, spell_id: chosen.id });
      } else {
        const previous = recipient.status[e.kind] ?? 0;
        if (["shield", "reflect"].includes(e.kind)) applyDefense(recipient, e.kind, e.value);
        else recipient.status[e.kind] = Math.max(previous, e.value);
        if (e.kind === "poison") recordPoisonChange(recipient, previous, who);
        if (e.kind === "poison_on_reflect" && recipient.status[e.kind] > previous) recipient.poison_reflect_source = who;
        if (recipient.status[e.kind] !== previous) events.push({ kind: "status_applied", actor: who, target: recipientId, status: e.kind, previous, value: recipient.status[e.kind], spell_id: chosen.id });
        if (recipient === target && ["poison", "vuln", "atk_down", "hom_stun", "misalign_next"].includes(e.kind) && recipient.status[e.kind] > previous) awardInspiration(actor, who, e.kind);
      }
    }
    if (who === "player" && chosen.category === "attack" && actor.expedition_passive) actor.expedition_passive = finishPassiveAttack(actor.expedition_passive);
    if (chosen.category === "attack") strategicCounter(target, actor, who === "player" ? "npc" : "player", who, unblessedDirectDamage, decision.turn, events);
    if (who === "npc" && chosen.category === "attack") triggerEliteTrait("hit", directDamage);
    if (actor.hom_id) actor.hom_energy = Math.min(6, actor.hom_energy + 1);
    if (who === "player" && actor.hom_id && next.blessing?.selected === "homunculus_resonance") {
      const b = next.blessing, threshold = b.tier < 3 ? 3 : 2, limit = b.tier < 5 ? 1 : 2;
      if (b.procs < limit && ++b.spell_count >= threshold) { b.spell_count = 0; b.procs++; const before = actor.hom_energy; actor.hom_energy = Math.min(6, actor.hom_energy + 1); events.push({ kind: "blessing_energy", actor: who, amount: actor.hom_energy - before, energy: actor.hom_energy }); }
    }
  };
  const playerAction = () => {
  if (switching) {
    const old = next.item_effects ?? {}, weapon = next.weapons[decision.switch_slot - 1];
    for (const field of ["shield", "reflect"]) if (next.weapon_defenses[field] !== undefined) {
      if ((next.other_defenses[field] ?? 0) > 0) next.player.status[field] = next.other_defenses[field]; else delete next.player.status[field];
      delete next.weapon_defenses[field]; delete next.other_defenses[field];
    }
    next.player.atk += Math.trunc(weapon.effects.power_flat ?? 0) - Math.trunc(old.power_flat ?? 0);
    next.player.def += Math.trunc(weapon.effects.guard_flat ?? 0) - Math.trunc(old.guard_flat ?? 0);
    next.active_weapon_slot = decision.switch_slot; next.item_id = weapon.id; next.item_effects = weapon.effects;
    events.push({ kind: "switch", actor: "player", slot: decision.switch_slot, item_id: weapon.id }); firePassive("weapon_switched");
  } else act(next.player, next.npc, spell, "player");
  if (decision.hom_action === "attack" && next.player.hp > 0 && next.npc.hp > 0) { if (next.player.status.hom_stun > 0) { next.player.status.hom_stun--; events.push({ kind: "status_consumed", target: "player", status: "hom_stun", remaining: next.player.status.hom_stun }); } else if (draw() < 0.95) { const factor = homunculusAttackMultiplierById(next.player.hom_id, next.npc.type, next.types, [next.player.spell_neutralize_active ?? 0, next.npc.spell_neutralize_active ?? 0, next.hom_synergy?.type_neutralize ?? 0]); let damage = Math.max(1, Math.round((next.player.atk + (modifiers().power_flat ?? 0)) * (next.player.hom_energy >= 6 ? 0.6 : 0.4) * factor)); if (next.npc.status.shield > 0) { damage = Math.max(0, Math.round(damage * (1 - next.npc.status.shield))); delete next.npc.status.shield; } next.npc.hp = Math.max(0, next.npc.hp - damage); events.push({ kind: "hom_attack", actor: "player", amount: damage, hp: next.npc.hp }); } else events.push({ kind: "hom_miss", actor: "player" }); next.player.hom_energy = 0; }
  };
  const npcAction = () => {
  act(next.npc, next.player, npcSpell, "npc");
  if (next.npc.hom_id && next.npc.hom_energy >= 3 && next.npc.hp > 0 && next.player.hp > 0) {
    if (next.npc.status.hom_stun > 0) {
      next.npc.status.hom_stun--; events.push({ kind: "status_consumed", target: "npc", status: "hom_stun", remaining: next.npc.status.hom_stun });
    } else if ((next.item_effects?.evasion_pct ?? 0) + (modifiers().evasion_pct ?? 0) > 0 && draw() < Math.min(1, (next.item_effects?.evasion_pct ?? 0) + (modifiers().evasion_pct ?? 0))) {
      events.push({ kind: "evade", actor: "player", target: "npc" }); firePassive("dodge");
    } else if (draw() < 0.95) {
      let damage = Math.max(1, Math.round(next.npc.atk * (next.npc.hom_energy >= 6 ? 0.6 : 0.4) * Math.max(0.1, Math.min(1, next.hom_synergy?.incoming_mult ?? 1))));
      if (next.blessing?.selected === "player_shield" && !next.blessing.shield_used) { damage = Math.max(1, Math.round(damage * (1 - Math.min(10, 4 + next.blessing.tier) / 100))); next.blessing.shield_used = true; }
      if (next.player.status.shield > 0) { damage = Math.max(0, Math.round(damage * (1 - next.player.status.shield))); clearDefense(next.player, "shield"); }
      next.player.hp = Math.max(0, next.player.hp - damage);
      if (damage > 0) firePassive("damage_received");
      events.push({ kind: "hom_attack", actor: "npc", amount: damage, hp: next.player.hp });
    } else events.push({ kind: "hom_miss", actor: "npc" });
    next.npc.hom_energy = 0;
  }
  };
  if (!switching && next.player.expedition_passive?.id === "luny" && (next.player.status.stun ?? 0) <= 0 && spell.category === "attack" && spell.power_mult > 0) firePassive("before_attack", 0, spell);
  const playerFirst = (next.player.tempo ?? 10) + (next.item_effects?.tempo_flat ?? 0) + (next.hom_tempo ?? 0) + (modifiers().tempo_flat ?? 0) + (next.player.status.tempo_bonus ?? 0) >= (next.npc.tempo ?? 10) + (next.npc.status.tempo_bonus ?? 0);
  delete next.player.status.tempo_bonus; delete next.npc.status.tempo_bonus;
  if (playerFirst) { playerAction(); npcAction(); } else { npcAction(); if (next.player.hp > 0 && next.npc.hp > 0) playerAction(); }
  for (const fighter of [next.player, next.npc]) {
    if (fighter.hp > 0 && fighter.status.poison > 0) { let tick = 3; if (fighter === next.player && next.blessing?.selected === "toxin_ward") { const b = next.blessing, mitigation = 3 * Math.min(50, 20 + 5 * (b.tier - 1)) + b.poison_remainder; const prevented = Math.min(2, Math.floor(mitigation / 100)); b.poison_remainder = mitigation % 100; tick -= prevented; } const amount = Math.min(tick, fighter.hp); const victim = fighter === next.player ? "player" : "npc"; const provenance = poisonTickMetadata(fighter, victim, ["player", "npc"], amount, decision.turn); fighter.hp -= amount; fighter.spell_hit_this_exchange = true; fighter.status.poison--; events.push({ kind: "poison", target: fighter.id, side: victim, amount, hp: fighter.hp, remaining: fighter.status.poison, ...provenance }); if (provenance.source === "player" && victim === "npc" && amount > 0) firePassive("opponent_poison_damage", amount); if (provenance.source === "npc" && victim === "player" && amount > 0) firePassive("damage_received"); recordPoisonChange(fighter, fighter.status.poison, null); }
    for (const id of Object.keys(fighter.cooldowns)) fighter.cooldowns[id] = Math.max(0, fighter.cooldowns[id] - 1);
  }
  finishStrategicExchange(next, { player: next.player, npc: next.npc }, decision.turn, events);
  triggerEliteTrait("end");
  for (const jam of pendingJams) jamStrategicCooldown(jam.target.spell_ids.map((id: string) => next.spells.find((s: any) => s.id === id)), jam.target.cooldowns, jam.actor, jam.targetId, events);
  next.turn++; next.rng_counter = counter;
  if (next.player.hp > 0 && next.npc.hp > 0 && next.turn % 2 === 1) {
    const homReflect = Math.max(0, Math.min(1, next.hom_synergy?.reflect_pct ?? 0));
    if (homReflect > 0) { applyDefense(next.player, "reflect", homReflect); events.push({ kind: "status_applied", actor: "player", target: "player", status: "reflect", value: next.player.status.reflect, source: "homunculus" }); }
    for (const [effect, field] of [["ward_pct", "shield"], ["reflect_pct", "reflect"]]) {
      const value = Math.max(0, Math.min(1, next.item_effects?.[effect] ?? 0));
      if (value > 0) {
        if (next.weapon_defenses[field] === undefined) next.other_defenses[field] = next.player.status[field] ?? 0;
        next.weapon_defenses[field] = Math.max(next.weapon_defenses[field] ?? 0, value);
        next.player.status[field] = Math.max(next.other_defenses[field] ?? 0, next.weapon_defenses[field]);
        events.push({ kind: "status_applied", actor: "player", target: "player", status: field, value: next.player.status[field], source: "weapon" });
      }
    }
    if (next.turn === 1 && next.player.hp > next.npc.hp && (next.item_effects?.tempo_on_win ?? 0) > 0) next.player.status.tempo_bonus = next.item_effects.tempo_on_win;
  }
  next.terminal_result = next.player.hp <= 0 ? "LOSS" : next.npc.hp <= 0 ? "WIN" : null;
  if (next.terminal_result) {
    delete next.player.expedition_passive;
    next.strategic_delayed = [];
    for (const fighter of [next.player, next.npc]) { delete fighter.strategic_trap; delete fighter.strategic_heal_suppression; restoreDungeonInspiration(next, fighter); }
  } else {
    for (const who of ["npc", "player"]) {
      const fighter = next[who];
      if (fighter.hp <= 0 || fighter.inspiration_used || fighter.inspiration_pending || fighter.inspiration < 3) continue;
      const choices = (next.inspiration_catalog?.[who] ?? []).filter((s: any) => !fighter.spell_ids.includes(s.id));
      if (choices.length < 3) return { error: "UNSUPPORTED_MECHANIC" };
      fighter.inspiration_offers = [];
      for (let i = 0; i < 3; i++) fighter.inspiration_offers.push(choices.splice(Math.floor(draw() * choices.length), 1)[0].id);
      fighter.inspiration_pending = true;
      events.push({ kind: "inspiration_offered", actor: who, ...(who === "player" ? { offers: [...fighter.inspiration_offers] } : {}) });
      if (who === "npc") {
        const selected = fighter.inspiration_offers[Math.floor(draw() * 3)];
        const slot = Math.floor(draw() * 4);
        const chosen = next.inspiration_catalog.npc.find((s: any) => s.id === selected);
        fighter.spell_ids[slot] = selected; fighter.temporary_spell_id = selected; fighter.temporary_replaced_slot = slot;
        if (!next.spells.some((s: any) => s.id === selected)) next.spells.push(structuredClone(chosen));
        fighter.inspiration_used = true; fighter.inspiration_pending = false; fighter.inspiration_offers = [];
        events.push({ kind: "inspiration_chosen", actor: who, spell_id: selected, slot, activation: recordInspirationActivation(fighter, who, next.turn) });
      }
    }
  }
  if (next.player.expedition_passive) next.player.expedition_passive = finishPassiveExchange(next.player.expedition_passive);
  next.rng_counter = counter;
  next.physical_anomaly = next.terminal_result ? null : tickPhysicalAnomaly(next.physical_anomaly, next.turn);
  return { next_state: next, events, terminal_result: next.terminal_result };
}

export function resolveDungeonInspiration(state: any, decision: any, rng: (turn: number, draw: number) => number): any {
  const fighter = state?.player;
  if (!state || state.terminal_result || state.blessing?.pending || !fighter?.inspiration_pending || fighter.inspiration_used || !Array.isArray(fighter.inspiration_offers) || fighter.inspiration_offers.length !== 3 || !decision || typeof decision !== "object" || Array.isArray(decision) || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const keys = Object.keys(decision).sort().join(",");
  if (!(decision.kind === "decline" && keys === "kind") && !(decision.kind === "choose" && keys === "kind,spell_id" && typeof decision.spell_id === "string" && fighter.inspiration_offers.includes(decision.spell_id))) return { error: "INVALID_DECISION" };
  const next = structuredClone(state), p = next.player, events: any[] = [];
  if (decision.kind === "choose") {
    const spell = next.inspiration_catalog?.player?.find((s: any) => s.id === decision.spell_id);
    if (!spell || !dungeonInspirationCandidates(p.type, p.spell_ids, [spell]).length) return { error: "INVALID_DECISION" };
    const roll = rng(next.turn, next.rng_counter);
    if (!Number.isFinite(roll) || roll < 0 || roll >= 1) throw new Error("INVALID_RNG");
    const slot = Math.floor(roll * 4); next.rng_counter++;
    p.spell_ids[slot] = spell.id; p.temporary_spell_id = spell.id; p.temporary_replaced_slot = slot;
    if (!next.spells.some((s: any) => s.id === spell.id)) next.spells.push(structuredClone(spell));
    events.push({ kind: "inspiration_chosen", actor: "player", spell_id: spell.id, slot, activation: recordInspirationActivation(p, "player", next.turn) });
    applyCombatPassive(p, next.npc, "inspiration_activated", next.types, "player", "npc", events);
  } else events.push({ kind: "inspiration_declined", actor: "player" });
  p.inspiration_used = true; p.inspiration_pending = false; p.inspiration_offers = [];
  return { next_state: next, events };
}
