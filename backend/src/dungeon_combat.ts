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
export function generateDungeonEnemy(seed: Uint8Array, runId: string, floor: number, catalogs: any, growth = { hp: 0.05, attack: 0.025, defense: 0.02 }) {
  if (!(seed instanceof Uint8Array) || seed.length < 32 || typeof runId !== "string" || !runId || !Number.isSafeInteger(floor) || floor < 1 || floor > 1000 || !catalogs || !Array.isArray(catalogs.entities) || !Array.isArray(catalogs.homunculi) || !Array.isArray(catalogs.spells) || !growth || [growth.hp, growth.attack, growth.defense].some(v => typeof v !== "number" || !Number.isFinite(v) || v < 0 || v > 0.1)) throw new Error("INVALID_DUNGEON_SETUP");
  const draw = (domain: string) => createHmac("sha256", seed).update(JSON.stringify(["dungeon-enemy-v1", runId, floor, domain])).digest().readUInt32BE(0);
  const entities = [...catalogs.entities].filter(e => e && typeof e.id === "string" && typeof e.type === "string" && e.base_stats && [e.base_stats.hp, e.base_stats.power, e.base_stats.guard].every(v => Number.isSafeInteger(v) && v > 0)).sort((a, b) => a.id.localeCompare(b.id));
  const homunculi = [...catalogs.homunculi].filter(h => h && typeof h.id === "string").sort((a, b) => a.id.localeCompare(b.id));
  if (!entities.length || !homunculi.length) throw new Error("INVALID_DUNGEON_CATALOG");
  const entity = entities[draw("entity") % entities.length];
  const homunculus = homunculi[draw("homunculus") % homunculi.length];
  const candidates = catalogs.spells.filter(s => s && typeof s.id === "string" && (s.type === entity.type || (["universal", "hybrid"].includes(s.type) && Array.isArray(s.eligible_types) && s.eligible_types.includes(entity.type))) && Array.isArray(s.effects) && Number.isFinite(s.accuracy) && Number.isInteger(s.cooldown_turns) && s.cooldown_turns >= 0).sort((a, b) => a.id.localeCompare(b.id));
  const unique = [...new Map(candidates.map(s => [s.id, s])).values()] as any[];
  const advanced = unique.filter(s => s.type === "universal" || s.type === "hybrid");
  if (unique.length < 4 || !advanced.length) throw new Error("INVALID_DUNGEON_CATALOG");
  const chosen = [advanced[draw("advanced") % advanced.length]];
  const remaining = unique.filter(s => s.id !== chosen[0].id);
  while (chosen.length < 4) chosen.push(remaining.splice(draw(`spell-${chosen.length}`) % remaining.length, 1)[0]);
  const scale = (base: number, rate: number) => Math.min(100000, Math.round(base * (1 + Math.min(floor - 1, 999) * rate)));
  return { entity_id: entity.id, type: entity.type, homunculus_id: homunculus.id, homunculus_level: Math.min(10, Math.floor((floor - 1) / 3)), spell_ids: chosen.map(s => s.id), hp: scale(entity.base_stats.hp, growth.hp), attack: scale(entity.base_stats.power, growth.attack), defense: scale(entity.base_stats.guard, growth.defense) };
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
