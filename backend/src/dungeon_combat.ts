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
export function generateDungeonEnemy(seed: Uint8Array, runId: string, floor: number, catalogs: any, growth = { hp: 0.04, attack: 0.025, defense: 0.015 }, previous?: { hp: number; attack: number; defense: number; entity_id?: string; homunculus_id?: string; spell_ids?: string[] }) {
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
  const candidates = catalogs.spells.filter(s => s && typeof s.id === "string" && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(entity.type) && Number.isInteger(s.tower_level_required) && s.research_cost && Number.isInteger(s.research_time_sec) && s.research_time_sec > 0)) && Array.isArray(s.effects) && s.effects.every((e: any) => validEffect(e) && (e.kind !== "physical_anomaly" || validPhysicalAnomalySpell(s))) && Number.isFinite(s.accuracy) && Number.isInteger(s.cooldown_turns) && s.cooldown_turns >= 0).sort((a, b) => a.id.localeCompare(b.id));
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
  return { entity_id: entity.id, type: entity.type, homunculus_id: homunculus.id, homunculus_level: Math.min(10, Math.floor((floor - 1) / 3)), spell_ids: chosen.map(s => s.id), hp, attack: npcAttack, defense };
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
    const typeMultiplier = relation > 1 ? 1.25 : relation < 1 ? 0.8 : 1;
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
    return { id: spell.id, score };
  });
  const best = Math.max(...scored.map(s => s.score));
  const tied = scored.filter(s => s.score === best);
  return tied[Math.floor(roll * tied.length)].id;
}

const DUNGEON_EFFECTS = new Set(["atk_boost", "atk_down", "vuln", "shield", "heal", "poison", "bonus_if_poisoned", "physical_anomaly", ...STRATEGIC_EFFECTS]);
const validEffect = (e: any) => e && DUNGEON_EFFECTS.has(e.kind) && (!STRATEGIC_EFFECTS.includes(e.kind) || validStrategicStatusEffect(e));
const DUNGEON_ITEMS = new Set(["power_flat", "guard_flat", "true_on_hit", "dot_true", "vuln_on_hit"]);

// setup must be the result of server-side loadout validation, never client input.
export function createDungeonCombatState(setup: any, enemy: any, catalogs: any): any {
  if (!setup?.entity?.base_stats || !Array.isArray(setup.spell_ids) || setup.spell_ids.length !== 4 || new Set(setup.spell_ids).size !== 4 || !enemy || !catalogs || !Array.isArray(enemy.spell_ids) || enemy.spell_ids.length !== 4 || !Array.isArray(catalogs.spells) || !Array.isArray(catalogs.homunculi) || !catalogs.types?.effectiveness) return { error: "UNTRUSTED_SETUP" };
  const equipment = setup.weapons ?? [{ id: setup.item_id, effects: setup.itemEffects ?? {} }, { id: null, effects: {} }];
  if (!Array.isArray(equipment) || equipment.length !== 2 || equipment.some((w: any) => !w || !w.effects || Object.entries(w.effects).some(([key, value]) => !DUNGEON_ITEMS.has(key) && value !== 0))) return { error: "UNSUPPORTED_MECHANIC" };
  const factor = Math.max(0, Math.min(2, setup.hom_id ? setup.hom_synergy?.item_effect_mult ?? 1 : 1));
  const weapons = equipment.map((w: any) => ({ id: w.id ?? null, effects: Object.fromEntries(Object.entries(w.effects).map(([key, value]) => [key, (value as number) * factor])) }));
  const activeSlot = weapons[0].id ? 1 : weapons[1].id ? 2 : 0;
  const effects = activeSlot ? weapons[activeSlot - 1].effects : {};
  const spells = [...setup.spell_ids, ...enemy.spell_ids].map(id => catalogs.spells.find((s: any) => s.id === id));
  if (spells.some(s => !s || !Array.isArray(s.effects) || s.effects.some((e: any) => !validEffect(e) || (e.kind === "physical_anomaly" && !validPhysicalAnomalySpell(s))))) return { error: "UNSUPPORTED_MECHANIC" };
  if (spells.some((s, i) => !(s.type === (i < 4 ? setup.entity.type : enemy.type) || (["universal", "hybrid"].includes(s.type) && s.eligible_types?.includes(i < 4 ? setup.entity.type : enemy.type))))) return { error: "UNTRUSTED_SETUP" };
  const hom = catalogs.homunculi.find((h: any) => h.id === enemy.homunculus_id);
  if (!hom || !Number.isInteger(enemy.homunculus_level) || enemy.homunculus_level < 0 || enemy.homunculus_level > 10 || [enemy.hp, enemy.attack, enemy.defense].some(v => !Number.isSafeInteger(v) || v < 1 || v > 100000)) return { error: "UNTRUSTED_SETUP" };
  const stats = setup.entity.base_stats, bonus = setup.bonuses ?? {};
  const npcHp = enemy.hp + (hom.buff_hp ?? 0) + enemy.homunculus_level;
  const player = { id: setup.entity.id, type: setup.entity.type, hp: stats.hp + (bonus.hp ?? 0), max_hp: stats.hp + (bonus.hp ?? 0), atk: stats.power + (bonus.atk ?? 0) + (effects.power_flat ?? 0), def: stats.guard + (bonus.def ?? 0) + (effects.guard_flat ?? 0), hom_id: setup.hom_id ?? null, hom_energy: 0, status: {}, cooldowns: {}, spell_ids: [...setup.spell_ids] };
  const npc = { id: enemy.entity_id, type: enemy.type, hp: npcHp, max_hp: npcHp, atk: enemy.attack + (hom.buff_atk ?? 0) + Math.floor(enemy.homunculus_level / 5), def: enemy.defense + (hom.buff_def ?? 0) + Math.floor(enemy.homunculus_level / 3), hom_id: hom.id, hom_energy: 0, status: {}, cooldowns: {}, spell_ids: [...enemy.spell_ids] };
  return { player, npc, weapons, active_weapon_slot: activeSlot, item_id: activeSlot ? weapons[activeSlot - 1].id : null, item_effects: effects, spells: structuredClone(spells), types: structuredClone(catalogs.types), floor: enemy.floor ?? 1, turn: 0, rng_counter: 0, terminal_result: null, physical_anomaly: null };
}

export function resolveDungeonTurn(state: any, decision: any, rng: (turn: number, draw: number) => number): any {
  if (!state || state.terminal_result || !decision || typeof decision !== "object" || Object.keys(decision).some(k => !["turn", "spell_id", "hom_action", "switch_slot"].includes(k)) || decision.turn !== state.turn + 1 || ![undefined, "hold", "attack"].includes(decision.hom_action) || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const switching = decision.switch_slot !== undefined;
  if (switching && (decision.spell_id !== undefined || decision.hom_action !== undefined || ![1, 2].includes(decision.switch_slot) || decision.switch_slot === state.active_weapon_slot || !state.weapons?.[decision.switch_slot - 1]?.id)) return { error: "INVALID_DECISION" };
  const spell = switching ? null : state.spells.find((s: any) => s.id === decision.spell_id && state.player.spell_ids.includes(s.id));
  if (!switching && (!spell || (state.player.cooldowns[spell.id] ?? 0) > 0 || (decision.hom_action === "attack" && (!state.player.hom_id || state.player.hom_energy < 3)))) return { error: "INVALID_DECISION" };
  if (state.spells.some((s: any) => !Array.isArray(s.effects) || s.effects.some((e: any) => !validEffect(e) || (e.kind === "physical_anomaly" && !validPhysicalAnomalySpell(s))))) return { error: "UNSUPPORTED_MECHANIC" };
  const next = structuredClone(state), events: any[] = [];
  const pendingJams: { target: any; actor: string; targetId: string }[] = [];
  let counter = next.rng_counter;
  const draw = () => { const value = rng(decision.turn, counter++); if (!Number.isFinite(value) || value < 0 || value >= 1) throw new Error("INVALID_RNG"); return value; };
  let npcSpell: any;
  try {
    const npcId = chooseDungeonNpcSpell(next.floor, next.npc.spell_ids, next.spells, next.npc.cooldowns, next.npc, next.player, draw(), { anomaly: next.physical_anomaly, delayed: next.strategic_delayed, types: next.types });
    npcSpell = next.spells.find((s: any) => s.id === npcId);
  } catch (err) {
    if (!(err instanceof Error) || err.message !== "NO_AVAILABLE_DUNGEON_SPELL") throw err;
    npcSpell = { id: "basic_attack", type: next.npc.type, category: "attack", accuracy: 0.9, power_mult: 1, cooldown_turns: 0, effects: [] };
  }
  const act = (actor: any, target: any, chosen: any, who: string) => {
    if (actor.hp <= 0 || target.hp <= 0) return;
    actor.cooldowns[chosen.id] = chosen.cooldown_turns + 1;
    const hit = draw() < chosen.accuracy;
    events.push({ kind: "spell", actor: who, spell_id: chosen.id, hit });
    if (!hit) return;
    let directDamage = 0;
    const previousWard = actor.status.shield ?? 0;
    if (chosen.category === "attack") {
      const relation = next.types.effectiveness[chosen.type]?.[target.type] ?? 1;
      const mult = relation > 1 ? 1.25 : relation < 1 ? 0.8 : 1;
      const poisonBonus = chosen.effects.find((e: any) => e.kind === "bonus_if_poisoned");
      const power = chosen.power_mult * (poisonBonus && target.status.poison > 0 ? 1 + poisonBonus.value : 1);
      const base = (actor.atk * (1 + (actor.status.atk_boost ?? 0) - (actor.status.atk_down ?? 0)) - Math.trunc(target.def * 0.5)) * mult * physicalAnomalyMultiplier(next.physical_anomaly, actor.type) * (1 + (target.status.vuln ?? 0));
      const shield = target.status.shield ?? 0;
      const baseline = Math.min(target.hp, shield > 0 ? Math.max(0, Math.round(Math.max(1, Math.round(base * chosen.power_mult)) * (1 - shield))) : Math.max(1, Math.round(base * chosen.power_mult)));
      let damage = Math.max(1, Math.round(base * power));
      if (target.status.shield > 0) { damage = Math.max(0, Math.round(damage * (1 - target.status.shield))); delete target.status.shield; }
      directDamage = Math.min(target.hp, damage);
      target.hp = Math.max(0, target.hp - damage); events.push({ kind: "damage", actor: who, amount: damage, hp: target.hp });
      if (who === "player") {
        for (const key of ["true_on_hit", "dot_true"]) {
          const amount = Math.min(target.hp, Math.max(0, Math.trunc(next.item_effects?.[key] ?? 0)));
          if (amount > 0) { target.hp -= amount; events.push({ kind: key, actor: who, target: "npc", amount, hp: target.hp }); }
        }
        if ((next.item_effects?.dot_true ?? 0) > 0 && (next.item_effects?.vuln_on_hit ?? 0) > 0) target.status.vuln = Math.max(target.status.vuln ?? 0, Math.min(1, next.item_effects.vuln_on_hit));
      }
      if (poisonBonus && target.status.poison > 0 && directDamage > baseline) events.push({ kind: "combo_trigger", actor: who, target: who === "player" ? "npc" : "player", source_spell_id: chosen.id, prerequisite: "poison", actual_bonus_damage: directDamage - baseline, resulting_status: { poison: target.status.poison } });
    }
    const conversion = chosen.effects.find((e: any) => e.kind === "ward_convert");
    if (chosen.category === "attack" && conversion && previousWard > 0) {
      delete actor.status.shield;
      const amount = Math.min(target.hp, Math.floor(target.max_hp * 0.2), Math.floor(actor.max_hp * previousWard * conversion.value));
      target.hp -= amount;
      events.push({ kind: "ward_convert", actor: who, target: who === "player" ? "npc" : "player", shield: previousWard, amount, hp: target.hp });
    }
    for (const e of chosen.effects) {
      if (e.kind === "bonus_if_poisoned") continue;
      if (e.kind === "physical_anomaly") { next.physical_anomaly = castPhysicalAnomaly(chosen, decision.turn); events.push({ kind: "physical_anomaly_cast", actor: who, anomaly: structuredClone(next.physical_anomaly) }); continue; }
      if (e.kind === "debuff_transfer" || e.kind === "buff_steal") {
        transferStrategicStatus(e.kind, actor, target, who, who === "player" ? "npc" : "player", { vuln: "vuln", shield: "shield", reflect: "reflect" }, events, (fighter, field) => { delete fighter.status[field]; }, (fighter, field, value) => { fighter.status[field] = Math.max(fighter.status[field] ?? 0, value); });
        continue;
      }
      if (e.kind === "cooldown_jam") { pendingJams.push({ target, actor: who, targetId: who === "player" ? "npc" : "player" }); continue; }
      if (e.kind === "hom_energy_siphon") {
        const amount = actor.hom_id && target.hom_id ? Math.min(2, target.hom_energy, 6 - actor.hom_energy) : 0;
        if (amount > 0) { target.hom_energy -= amount; actor.hom_energy += amount; events.push({ kind: "hom_energy_siphon", actor: who, target: who === "player" ? "npc" : "player", amount, actor_energy: actor.hom_energy, target_energy: target.hom_energy }); }
        continue;
      }
      if (e.kind === "delayed_damage") { if (chosen.category === "attack") queueDelayedDamage(next, who, who === "player" ? "npc" : "player", e.value, directDamage, decision.turn, events); continue; }
      if (e.kind === "ward_convert") continue;
      if (e.kind === "counter_trap") { actor.strategic_trap = { value: e.value, activated_turn: decision.turn, expires_turn: decision.turn + 2 }; events.push({ kind: "counter_trap_armed", actor: who, target: who, value: e.value, expires_turn: decision.turn + 2 }); continue; }
      if (e.kind === "heal_suppression") { target.strategic_heal_suppression = { expires_turn: decision.turn + 2 }; events.push({ kind: "heal_suppression_applied", actor: who, target: who === "player" ? "npc" : "player", value: e.value, expires_turn: decision.turn + 2 }); continue; }
      const recipient = e.target === "self" ? actor : target;
      if (e.kind === "heal") recipient.hp = Math.min(recipient.max_hp, recipient.hp + strategicHeal(recipient, e.value));
      else recipient.status[e.kind] = Math.max(recipient.status[e.kind] ?? 0, e.value);
    }
    if (chosen.category === "attack") strategicCounter(target, actor, who === "player" ? "npc" : "player", who, directDamage, decision.turn, events);
    if (actor.hom_id) actor.hom_energy = Math.min(6, actor.hom_energy + 1);
  };
  if (switching) {
    const old = next.item_effects ?? {}, weapon = next.weapons[decision.switch_slot - 1];
    next.player.atk += Math.trunc(weapon.effects.power_flat ?? 0) - Math.trunc(old.power_flat ?? 0);
    next.player.def += Math.trunc(weapon.effects.guard_flat ?? 0) - Math.trunc(old.guard_flat ?? 0);
    next.active_weapon_slot = decision.switch_slot; next.item_id = weapon.id; next.item_effects = weapon.effects;
    events.push({ kind: "switch", actor: "player", slot: decision.switch_slot, item_id: weapon.id });
  } else act(next.player, next.npc, spell, "player");
  if (decision.hom_action === "attack" && next.player.hp > 0 && next.npc.hp > 0) { if (draw() < 0.95) { let damage = Math.max(1, Math.round(next.player.atk * (next.player.hom_energy >= 6 ? 0.6 : 0.4))); if (next.npc.status.shield > 0) { damage = Math.max(0, Math.round(damage * (1 - next.npc.status.shield))); delete next.npc.status.shield; } next.npc.hp = Math.max(0, next.npc.hp - damage); events.push({ kind: "hom_attack", actor: "player", amount: damage, hp: next.npc.hp }); } else events.push({ kind: "hom_miss", actor: "player" }); next.player.hom_energy = 0; }
  act(next.npc, next.player, npcSpell, "npc");
  if (next.npc.hom_id && next.npc.hom_energy >= 3 && next.npc.hp > 0 && next.player.hp > 0) {
    if (draw() < 0.95) {
      let damage = Math.max(1, Math.round(next.npc.atk * (next.npc.hom_energy >= 6 ? 0.6 : 0.4)));
      if (next.player.status.shield > 0) { damage = Math.max(0, Math.round(damage * (1 - next.player.status.shield))); delete next.player.status.shield; }
      next.player.hp = Math.max(0, next.player.hp - damage);
      events.push({ kind: "hom_attack", actor: "npc", amount: damage, hp: next.player.hp });
    } else events.push({ kind: "hom_miss", actor: "npc" });
    next.npc.hom_energy = 0;
  }
  for (const fighter of [next.player, next.npc]) {
    if (fighter.hp > 0 && fighter.status.poison > 0) { fighter.hp = Math.max(0, fighter.hp - 2); fighter.status.poison--; events.push({ kind: "poison", target: fighter.id, hp: fighter.hp }); }
    for (const id of Object.keys(fighter.cooldowns)) fighter.cooldowns[id] = Math.max(0, fighter.cooldowns[id] - 1);
  }
  finishStrategicExchange(next, { player: next.player, npc: next.npc }, decision.turn, events);
  for (const jam of pendingJams) jamStrategicCooldown(jam.target.spell_ids.map((id: string) => next.spells.find((s: any) => s.id === id)), jam.target.cooldowns, jam.actor, jam.targetId, events);
  next.turn++; next.rng_counter = counter;
  next.terminal_result = next.player.hp <= 0 ? "LOSS" : next.npc.hp <= 0 ? "WIN" : null;
  if (next.terminal_result) { next.strategic_delayed = []; for (const fighter of [next.player, next.npc]) { delete fighter.strategic_trap; delete fighter.strategic_heal_suppression; } }
  next.physical_anomaly = next.terminal_result ? null : tickPhysicalAnomaly(next.physical_anomaly, next.turn);
  return { next_state: next, events, terminal_result: next.terminal_result };
}
