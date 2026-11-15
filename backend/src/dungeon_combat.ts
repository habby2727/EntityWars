import { createHmac } from "node:crypto";
import type { Database } from "bun:sqlite";

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
export function generateDungeonEnemy(seed: Uint8Array, runId: string, floor: number, catalogs: any, growth = { hp: 0.05, attack: 0.025, defense: 0.02 }, previous?: { hp: number; attack: number; defense: number }) {
  if (!(seed instanceof Uint8Array) || seed.length < 32 || typeof runId !== "string" || !runId || !Number.isSafeInteger(floor) || floor < 1 || floor > 1000 || !catalogs || !Array.isArray(catalogs.entities) || !Array.isArray(catalogs.homunculi) || !Array.isArray(catalogs.spells) || !growth || [growth.hp, growth.attack, growth.defense].some(v => typeof v !== "number" || !Number.isFinite(v) || v < 0 || v > 0.1)) throw new Error("INVALID_DUNGEON_SETUP");
  const draw = (domain: string) => createHmac("sha256", seed).update(JSON.stringify(["dungeon-enemy-v1", runId, floor, domain])).digest().readUInt32BE(0);
  const entities = [...catalogs.entities].filter(e => e && typeof e.id === "string" && typeof e.type === "string" && e.base_stats && [e.base_stats.hp, e.base_stats.power, e.base_stats.guard].every(v => Number.isSafeInteger(v) && v > 0)).sort((a, b) => a.id.localeCompare(b.id));
  const homunculi = [...catalogs.homunculi].filter(h => h && typeof h.id === "string").sort((a, b) => a.id.localeCompare(b.id));
  if (!entities.length || !homunculi.length) throw new Error("INVALID_DUNGEON_CATALOG");
  const entity = entities[draw("entity") % entities.length];
  const homunculus = homunculi[draw("homunculus") % homunculi.length];
  const candidates = catalogs.spells.filter(s => s && typeof s.id === "string" && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(entity.type))) && Array.isArray(s.effects) && s.effects.every((e: any) => DUNGEON_EFFECTS.has(e.kind)) && Number.isFinite(s.accuracy) && Number.isInteger(s.cooldown_turns) && s.cooldown_turns >= 0).sort((a, b) => a.id.localeCompare(b.id));
  const unique = [...new Map(candidates.map(s => [s.id, s])).values()] as any[];
  const advanced = unique.filter(s => s.type === "universal" || s.type === "hybrid");
  if (unique.length < 4 || !advanced.length) throw new Error("INVALID_DUNGEON_CATALOG");
  const attack = unique.filter(s => s.category === "attack" && s.cooldown_turns === 0 && s.power_mult > 0);
  if (!attack.length) throw new Error("INVALID_DUNGEON_CATALOG");
  const chosen = [attack[draw("basic") % attack.length]];
  const advancedChoices = advanced.filter(s => s.id !== chosen[0].id);
  if (!advancedChoices.length) throw new Error("INVALID_DUNGEON_CATALOG");
  chosen.push(advancedChoices[draw("advanced") % advancedChoices.length]);
  const remaining = unique.filter(s => s.id !== chosen[0].id);
  const advancedIndex = remaining.findIndex(s => s.id === chosen[1].id);
  remaining.splice(advancedIndex, 1);
  while (chosen.length < 4) chosen.push(remaining.splice(draw(`spell-${chosen.length}`) % remaining.length, 1)[0]);
  const scale = (base: number, rate: number) => Math.min(100000, Math.round(base * (1 + Math.min(floor - 1, 999) * rate)));
  if (previous && [previous.hp, previous.attack, previous.defense].some(v => !Number.isSafeInteger(v) || v < 0 || v >= 100000)) throw new Error("DUNGEON_DIFFICULTY_LIMIT");
  const hp = Math.max(scale(entity.base_stats.hp, growth.hp), (previous?.hp ?? -1) + 1);
  const npcAttack = Math.max(scale(entity.base_stats.power, growth.attack), (previous?.attack ?? -1) + 1);
  const defense = Math.max(scale(entity.base_stats.guard, growth.defense), (previous?.defense ?? -1) + 1);
  return { entity_id: entity.id, type: entity.type, homunculus_id: homunculus.id, homunculus_level: Math.min(10, Math.floor((floor - 1) / 3)), spell_ids: chosen.map(s => s.id), hp, attack: npcAttack, defense };
}

// Only public, committed state belongs here; the player's next decision is not an input.
export function chooseDungeonNpcSpell(floor: number, equippedIds: string[], spells: any[], cooldowns: Record<string, number>, npc: any, target: any, roll: number): string {
  if (!Number.isSafeInteger(floor) || floor < 1 || floor > 1000 || !Array.isArray(equippedIds) || equippedIds.length !== 4 || new Set(equippedIds).size !== 4 || !Array.isArray(spells) || !cooldowns || typeof cooldowns !== "object" || !npc || !target || typeof roll !== "number" || !Number.isFinite(roll) || roll < 0 || roll >= 1) throw new Error("INVALID_DUNGEON_DECISION");
  const legal = equippedIds.map(id => spells.find(s => s?.id === id)).filter(s => s && (s.type === npc.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(npc.type))) && Array.isArray(s.effects) && Number.isFinite(s.power_mult) && Number.isFinite(s.accuracy) && s.accuracy >= 0 && s.accuracy <= 1 && Number.isInteger(s.cooldown_turns) && s.cooldown_turns >= 0 && Number.isInteger(cooldowns[s.id] ?? 0) && (cooldowns[s.id] ?? 0) === 0);
  if (legal.length === 0) throw new Error("NO_AVAILABLE_DUNGEON_SPELL");
  if (floor <= 3) return legal[Math.floor(roll * legal.length)].id;
  const enemyStatus = target.status ?? {}, ownStatus = npc.status ?? {};
  const scored = legal.map(spell => {
    let score = spell.category === "attack" ? spell.power_mult * spell.accuracy * 100 : 20;
    for (const effect of spell.effects) {
      if (effect.kind === "heal" && npc.hp < npc.max_hp * 0.6) score += Math.min(effect.value ?? 0, npc.max_hp - npc.hp) * 3;
      if (effect.kind === "shield" && !(ownStatus.shield_pct > 0)) score += 35;
      if (effect.kind === "poison" && !(enemyStatus.poison > 0)) score += 35;
      if (effect.kind === "vuln" && effect.target === "enemy" && !(enemyStatus.vuln_pct > 0)) score += 25;
      if (floor >= 8 && ["bonus_if_poisoned", "bonus_power_if_poisoned", "consume_poison"].includes(effect.kind) && enemyStatus.poison > 0) score += 65;
      if (floor >= 8 && effect.kind === "bonus_if_shielded" && ownStatus.shield_pct > 0) score += 55;
      if (floor >= 15 && effect.kind === "atk_down" && !(enemyStatus.atk_down > 0)) score += 25;
    }
    if (floor >= 15 && enemyStatus.vuln_pct > 0 && spell.category === "attack") score += spell.power_mult * 20;
    return { id: spell.id, score };
  });
  const best = Math.max(...scored.map(s => s.score));
  const tied = scored.filter(s => s.score === best);
  return tied[Math.floor(roll * tied.length)].id;
}

const DUNGEON_EFFECTS = new Set(["atk_boost", "atk_down", "vuln", "shield", "heal", "poison", "bonus_if_poisoned"]);
const DUNGEON_ITEMS = new Set(["power_flat", "guard_flat"]);

// setup must be the result of server-side loadout validation, never client input.
export function createDungeonCombatState(setup: any, enemy: any, catalogs: any): any {
  if (!setup?.entity?.base_stats || !Array.isArray(setup.spell_ids) || setup.spell_ids.length !== 4 || new Set(setup.spell_ids).size !== 4 || !enemy || !catalogs || !Array.isArray(enemy.spell_ids) || enemy.spell_ids.length !== 4 || !Array.isArray(catalogs.spells) || !Array.isArray(catalogs.homunculi) || !catalogs.types?.effectiveness) return { error: "UNTRUSTED_SETUP" };
  const equipment = setup.weapons ?? [{ id: setup.item_id, effects: setup.itemEffects ?? {} }];
  if (equipment.filter((w: any) => w.id).length > 1) return { error: "UNSUPPORTED_MECHANIC" };
  const effects = equipment.find((w: any) => w.id)?.effects ?? setup.itemEffects ?? {};
  if (Object.entries(effects).some(([key, value]) => !DUNGEON_ITEMS.has(key) && value !== 0)) return { error: "UNSUPPORTED_MECHANIC" };
  const spells = [...setup.spell_ids, ...enemy.spell_ids].map(id => catalogs.spells.find((s: any) => s.id === id));
  if (spells.some(s => !s || !Array.isArray(s.effects) || s.effects.some((e: any) => !DUNGEON_EFFECTS.has(e.kind)))) return { error: "UNSUPPORTED_MECHANIC" };
  if (spells.some((s, i) => !(s.type === (i < 4 ? setup.entity.type : enemy.type) || (["universal", "hybrid"].includes(s.type) && s.eligible_types?.includes(i < 4 ? setup.entity.type : enemy.type))))) return { error: "UNTRUSTED_SETUP" };
  const hom = catalogs.homunculi.find((h: any) => h.id === enemy.homunculus_id);
  if (!hom || !Number.isInteger(enemy.homunculus_level) || enemy.homunculus_level < 0 || enemy.homunculus_level > 10 || [enemy.hp, enemy.attack, enemy.defense].some(v => !Number.isSafeInteger(v) || v < 1 || v > 100000)) return { error: "UNTRUSTED_SETUP" };
  const stats = setup.entity.base_stats, bonus = setup.bonuses ?? {};
  const npcHp = enemy.hp + (hom.buff_hp ?? 0) + enemy.homunculus_level;
  const player = { id: setup.entity.id, type: setup.entity.type, hp: stats.hp + (bonus.hp ?? 0), max_hp: stats.hp + (bonus.hp ?? 0), atk: stats.power + (bonus.atk ?? 0) + (effects.power_flat ?? 0), def: stats.guard + (bonus.def ?? 0) + (effects.guard_flat ?? 0), hom_id: setup.hom_id ?? null, hom_energy: 0, status: {}, cooldowns: {}, spell_ids: [...setup.spell_ids] };
  const npc = { id: enemy.entity_id, type: enemy.type, hp: npcHp, max_hp: npcHp, atk: enemy.attack + (hom.buff_atk ?? 0) + Math.floor(enemy.homunculus_level / 5), def: enemy.defense + (hom.buff_def ?? 0) + Math.floor(enemy.homunculus_level / 3), hom_id: hom.id, hom_energy: 0, status: {}, cooldowns: {}, spell_ids: [...enemy.spell_ids] };
  return { player, npc, spells: structuredClone(spells), types: structuredClone(catalogs.types), floor: enemy.floor ?? 1, turn: 0, rng_counter: 0, terminal_result: null };
}

export function resolveDungeonTurn(state: any, decision: any, rng: (turn: number, draw: number) => number): any {
  if (!state || state.terminal_result || !decision || typeof decision !== "object" || Object.keys(decision).some(k => !["turn", "spell_id", "hom_action"].includes(k)) || decision.turn !== state.turn + 1 || ![undefined, "hold", "attack"].includes(decision.hom_action) || typeof rng !== "function") return { error: "INVALID_DECISION" };
  const spell = state.spells.find((s: any) => s.id === decision.spell_id && state.player.spell_ids.includes(s.id));
  if (!spell || (state.player.cooldowns[spell.id] ?? 0) > 0 || (decision.hom_action === "attack" && (!state.player.hom_id || state.player.hom_energy < 3))) return { error: "INVALID_DECISION" };
  if (state.spells.some((s: any) => !Array.isArray(s.effects) || s.effects.some((e: any) => !DUNGEON_EFFECTS.has(e.kind)))) return { error: "UNSUPPORTED_MECHANIC" };
  const next = structuredClone(state), events: any[] = [];
  let counter = next.rng_counter;
  const draw = () => { const value = rng(decision.turn, counter++); if (!Number.isFinite(value) || value < 0 || value >= 1) throw new Error("INVALID_RNG"); return value; };
  let npcSpell: any;
  try {
    const npcId = chooseDungeonNpcSpell(next.floor, next.npc.spell_ids, next.spells, next.npc.cooldowns, next.npc, next.player, draw());
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
    if (chosen.category === "attack") {
      const relation = next.types.effectiveness[chosen.type]?.[target.type] ?? 1;
      const mult = relation > 1 ? 1.25 : relation < 1 ? 0.8 : 1;
      const poisonBonus = chosen.effects.find((e: any) => e.kind === "bonus_if_poisoned");
      const power = chosen.power_mult * (poisonBonus && target.status.poison > 0 ? 1 + poisonBonus.value : 1);
      let damage = Math.max(1, Math.round((actor.atk * (1 + (actor.status.atk_boost ?? 0) - (actor.status.atk_down ?? 0)) - Math.trunc(target.def * 0.5)) * mult * power * (1 + (target.status.vuln ?? 0))));
      if (target.status.shield > 0) { damage = Math.max(0, Math.round(damage * (1 - target.status.shield))); delete target.status.shield; }
      target.hp = Math.max(0, target.hp - damage); events.push({ kind: "damage", actor: who, amount: damage, hp: target.hp });
    }
    for (const e of chosen.effects) {
      if (e.kind === "bonus_if_poisoned") continue;
      const recipient = e.target === "self" ? actor : target;
      if (e.kind === "heal") recipient.hp = Math.min(recipient.max_hp, recipient.hp + e.value);
      else recipient.status[e.kind] = Math.max(recipient.status[e.kind] ?? 0, e.value);
    }
    if (actor.hom_id) actor.hom_energy = Math.min(6, actor.hom_energy + 1);
  };
  act(next.player, next.npc, spell, "player");
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
  next.turn++; next.rng_counter = counter;
  next.terminal_result = next.player.hp <= 0 ? "LOSS" : next.npc.hp <= 0 ? "WIN" : null;
  return { next_state: next, events, terminal_result: next.terminal_result };
}
