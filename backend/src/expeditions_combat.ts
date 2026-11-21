import { createDungeonCombatState, expeditionSpellSupported, resolveDungeonTurn, resolveDungeonInspiration } from "./dungeon_combat";
import { expeditionDraw, expeditionEnemies, expeditionCaptures } from "./expeditions_rules";

const ITEM_EFFECTS = new Set(["power_flat", "guard_flat", "tempo_flat", "true_on_hit", "dot_true", "vuln_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"]);

/** Catalog-only effects; no player forge traits or fusion are transferred. */
export function expeditionItemEffects(item: any, level: number): Record<string, number> {
  if (!item || typeof item.id !== "string" || !item.id || item.slot !== "build" || !Number.isInteger(level) || level < 0 || level > 10 || !item.effects || typeof item.effects !== "object" || Array.isArray(item.effects)) throw new Error("INVALID_EXPEDITION_ITEM");
  const result: Record<string, number> = {};
  for (const [key, values] of Object.entries(item.effects) as [string, any][]) {
    if (!ITEM_EFFECTS.has(key) || !Array.isArray(values) || !values.length || values.some(v => typeof v !== "number" || !Number.isFinite(v) || v < 0)) throw new Error("INVALID_EXPEDITION_ITEM");
    const value = level === 0 && values.length === 10 && key in (item.base_effects ?? {}) ? item.base_effects[key] : values[Math.min(Math.max(0, level - 1), values.length - 1)];
    if (typeof value !== "number" || !Number.isFinite(value) || value < 0) throw new Error("INVALID_EXPEDITION_ITEM");
    result[key] = value;
  }
  if (!Object.keys(result).length || Object.entries(item.base_effects ?? {}).some(([key,value]) => !ITEM_EFFECTS.has(key) || !Object.hasOwn(item.effects, key) || typeof value !== "number" || !Number.isFinite(value) || value < 0)) throw new Error("INVALID_EXPEDITION_ITEM");
  return result;
}

function chooseNpcItem(seed: Uint8Array, key: string, setup: any, npcSpells: any[], npcTypes: string[], hom: any, personality: string, catalogs: any, level: number) {
  const items = catalogs.items?.filter((item: any) => item.slot === "build") ?? [];
  if (items.length !== 8 || new Set(items.map((item: any) => item.id)).size !== 8) throw new Error("INVALID_EXPEDITION_ITEM_CATALOG");
  const spells = setup.spells ?? [];
  const attacks = spells.filter((s: any) => s.category === "attack");
  const offense = attacks.reduce((sum: number, s: any) => sum + Math.max(0, s.power_mult ?? 0) * (s.accuracy ?? 0), 0) / Math.max(1, spells.length);
  const has = (list: any[], effect: string) => list.some(s => s.effects?.some((e: any) => e.kind === effect));
  const playerItems = (setup.weapons ?? [{id: setup.item_id, effects: setup.itemEffects ?? {}}]).filter((w: any) => w?.id);
  const effectMax = (name: string) => Math.max(0, ...playerItems.map((w: any) => w.effects?.[name] ?? 0));
  const playerReflect = has(spells, "reflect") || effectMax("reflect_pct") > 0 || (setup.hom_synergy?.reflect_pct ?? 0) > 0;
  const defensive = has(spells, "shield") || has(spells, "heal") || effectMax("guard_flat") > 1 || effectMax("ward_pct") > 0;
  const tempoPressure = Math.max(0, Math.min(1, ((setup.entity.base_stats.tempo ?? 10) + effectMax("tempo_flat") + (setup.hom_tempo ?? 0) - 10) / 20));
  const hasDisadvantage = npcTypes.some((t: string) => (catalogs.types.effectiveness[t]?.[setup.entity.type] ?? 1) < 1);
  const passive = catalogs.homunculi?.find((entry: any) => entry.id === hom.id)?.passive;
  const synergy = has(npcSpells, "poison") || has(npcSpells, "vuln") || passive?.event === "before_attack" || passive?.effects?.some((effect: any) => ["poison", "vuln", "power_flat"].includes(effect.kind));
  const ranked = items.map((item: any) => {
    const fx = expeditionItemEffects(item, level);
    const score = 1 + (fx.evasion_pct ?? 0) * (4 + offense * 5) + (fx.ward_pct ?? 0) * (3 + offense * 5) + (fx.reflect_pct ?? 0) * (2 + offense * 6) + (fx.ignore_reflect_chance ?? 0) * (playerReflect ? 7 : 0.4) + (fx.guard_flat ?? 0) * (0.08 + offense * 0.08) + (fx.true_on_hit ?? 0) * (defensive ? 0.65 : 0.22) + (fx.dot_true ?? 0) * (defensive || synergy ? 0.5 : 0.2) + (fx.vuln_on_hit ?? 0) * (synergy ? 4 : 1) + (fx.tempo_flat ?? 0) * (0.08 + tempoPressure * 0.42) + (fx.tempo_on_win ?? 0) * (0.06 + tempoPressure * 0.35) + (fx.disadvantage_reduction ?? 0) * (hasDisadvantage ? 4 : 0.3) + (fx.power_flat ?? 0) * (personality === "OPPORTUNIST" ? 0.12 : 0.07);
    return {item, effects: fx, score};
  }).sort((a: any, b: any) => b.score - a.score || a.item.id.localeCompare(b.item.id));
  const pool = ranked.filter((v: any, i: number) => i < 4 && v.score >= ranked[0].score * 0.7);
  const choice = pool[Math.floor(expeditionDraw(seed, JSON.stringify(["npc-item", key]), 0) * pool.length)];
  return {item_id: choice.item.id, item_level: level, item_effects: choice.effects};
}

/** setup must be produced by buildTrustedCombatSetup from server-owned player data. */
export function buildExpeditionEnemy(seed: Uint8Array, encounterKey: string, depth: number, capturable: boolean, setup: any, catalogs: any, enemyId?: string, homId?: string, npcItemLevel = 0) {
  if (!encounterKey || !Number.isSafeInteger(depth) || depth < 1 || typeof capturable !== "boolean" || !setup?.entity?.base_stats || !Array.isArray(setup.spells) || !Array.isArray(setup.spell_ids) || !Array.isArray(catalogs?.spells)) throw new Error("INVALID_EXPEDITION_SETUP");
  const draw = (label: string) => expeditionDraw(seed, JSON.stringify([encounterKey, depth, label]), 0);
  const enemy = enemyId === undefined ? expeditionEnemies[Math.floor(draw("enemy") * expeditionEnemies.length)] : expeditionEnemies.find(e => e.id === enemyId);
  if (!enemy) throw new Error("INVALID_EXPEDITION_ENEMY");
  const hom = homId === undefined ? expeditionCaptures[Math.floor(draw("homunculus") * expeditionCaptures.length)] : expeditionCaptures.find(h => h.id === homId);
  if (!hom) throw new Error("INVALID_EXPEDITION_HOMUNCULUS");
  const candidates = catalogs.spells.filter((s: any) => expeditionSpellSupported(s, enemy.types)).sort((a: any, b: any) => a.id.localeCompare(b.id));
  const basic = candidates.filter((s: any) => s.category === "attack" && s.cooldown_turns === 0 && s.power_mult > 0);
  if (!basic.length) throw new Error("INVALID_EXPEDITION_SPELL_CATALOG");
  const relation = (type: string) => catalogs.types?.effectiveness?.[type]?.[setup.entity.type] ?? 1;
  const pick = (list: any[], label: string) => list[Math.floor(draw(label) * list.length)];
  const preferredBasic = [...basic].sort((a, b) => relation(b.type) - relation(a.type));
  const bestRelation = relation(preferredBasic[0].type);
  const selected = [pick(preferredBasic.filter(s => relation(s.type) === bestRelation), "basic")];
  const has = (spell: any, kind: string, target?: string) => spell.effects.some((effect: any) => effect.kind === kind && (!target || effect.target === target));
  const pairs: any[][] = [];
  for (const a of candidates) for (const b of candidates) {
    if (a.id === b.id || selected.some(s => s.id === a.id || s.id === b.id)) continue;
    if ((has(a, "poison", "enemy") && ["bonus_if_poisoned", "bonus_power_if_poisoned", "consume_poison"].some(k => has(b, k))) || (has(a, "shield", "self") && ["ward_convert", "bonus_if_shielded"].some(k => has(b, k))) || (has(a, "hybrid_mark", "enemy") && has(b, "bonus_if_marked")) || (has(a, "vuln", "enemy") && b.category === "attack" && b.power_mult >= 0.9)) pairs.push([a, b]);
  }
  const advancedPairs = pairs.filter(pair => pair.some(s => s.type === "hybrid"));
  const markPairs = advancedPairs.filter(pair => has(pair[0], "hybrid_mark") && has(pair[1], "bonus_if_marked"));
  if (pairs.length) selected.push(...pick(markPairs.length ? markPairs : advancedPairs.length ? advancedPairs : pairs, "combo"));
  const remaining = () => candidates.filter((s: any) => !selected.some(x => x.id === s.id));
  if (selected.length < 4) {
    const advanced = remaining().filter((s: any) => ["hybrid", "universal"].includes(s.type));
    if (advanced.length) selected.push(pick(advanced, "advanced"));
  }
  while (selected.length < 4) {
    const available = remaining();
    if (!available.length) throw new Error("INVALID_EXPEDITION_SPELL_CATALOG");
    selected.push(pick(available, `spell-${selected.length}`));
  }
  const base = setup.entity.base_stats, bonus = setup.bonuses ?? {};
  const weapons = Array.isArray(setup.weapons) ? setup.weapons.filter((w: any) => w.id).map((w: any) => w.effects) : [setup.itemEffects ?? {}];
  const factor = Math.max(0, Math.min(2, setup.hom_id ? setup.hom_synergy?.item_effect_mult ?? 1 : 1));
  // Account for either switchable weapon without stacking both weapons' stats.
  const weaponPower = Math.max(0, ...weapons.map((w: any) => w?.power_flat ?? 0));
  const weaponGuard = Math.max(0, ...weapons.map((w: any) => w?.guard_flat ?? 0));
  const hp = base.hp + (bonus.hp ?? 0), attack = base.power + (bonus.atk ?? 0) + Math.trunc(weaponPower * factor), defense = base.guard + (bonus.def ?? 0) + Math.trunc(weaponGuard * factor);
  if (![hp, attack, defense].every(v => Number.isFinite(v) && v > 0)) throw new Error("INVALID_EXPEDITION_SETUP");
  const spellQuality = setup.spells.reduce((sum: number, s: any) => sum + (s.category === "attack" ? Math.min(1.5, s.power_mult * s.accuracy) : 0.65), 0) / 4;
  const growth = 1 + Math.min(0.55, Math.log2(depth) * 0.035);
  const threat = (capturable ? 1.12 : 1) * growth;
  const personality = capturable ? "ALCHEMIST" : "OPPORTUNIST";
  const equipment = chooseNpcItem(seed, encounterKey, setup, selected, enemy.types, hom, personality, catalogs, npcItemLevel);
  // Reserve item flats inside the existing target budget, rather than stacking them on top.
  const attackBudget = Math.max(1, Math.round(attack * (0.60 + Math.min(0.15, spellQuality * 0.1)) * threat));
  const defenseBudget = Math.max(1, Math.round(defense * 0.82 * threat));
  const item_power_allocated = Math.trunc(equipment.item_effects.power_flat ?? 0);
  const item_guard_allocated = Math.trunc(equipment.item_effects.guard_flat ?? 0);
  return { ...equipment, item_power_allocated, item_guard_allocated, combat_mode: "expedition", entity_id: enemy.id, name: enemy.name, type: enemy.types[0], types: [...enemy.types], texture: enemy.texture, preview_texture: enemy.preview_texture, capturable, floor: depth, homunculus_id: hom.id, homunculus_level: Math.min(10, Math.floor((depth - 1) / 3)), hp: Math.max(1, Math.round(hp * (capturable ? 0.85 : 0.75) * growth)), attack: attackBudget, defense: defenseBudget, spell_ids: selected.map(s => s.id), npc_personality: personality };
}

export function createExpeditionCombatState(setup: any, enemy: any, catalogs: any, previousActiveSlot = 0) {
  if (enemy?.combat_mode !== "expedition") return { error: "UNTRUSTED_SETUP" };
  const manifest = expeditionEnemies.find(e => e.id === enemy.entity_id);
  if (!manifest || JSON.stringify(manifest.types) !== JSON.stringify(enemy.types) || enemy.texture !== manifest.texture || enemy.preview_texture !== manifest.preview_texture) return { error: "UNTRUSTED_SETUP" };
  const item = catalogs.items?.find((entry: any) => entry.id === enemy.item_id && entry.slot === "build");
  let effects: Record<string, number>;
  try { effects = expeditionItemEffects(item, enemy.item_level); } catch { return {error:"UNTRUSTED_SETUP"}; }
  if (JSON.stringify(Object.entries(effects).sort()) !== JSON.stringify(Object.entries(enemy.item_effects ?? {}).sort())) return {error:"UNTRUSTED_SETUP"};
  if (![enemy.item_power_allocated, enemy.item_guard_allocated].every(Number.isSafeInteger) || enemy.item_power_allocated !== Math.trunc(effects.power_flat ?? 0) || enemy.item_guard_allocated !== Math.trunc(effects.guard_flat ?? 0)) return {error:"UNTRUSTED_SETUP"};
  const state = createDungeonCombatState(setup, enemy, catalogs, previousActiveSlot);
  if (!state.error) { const hom = expeditionCaptures.find(h => h.id === enemy.homunculus_id)!; state.npc.item_id = item.id; state.npc.item_level = enemy.item_level; state.npc.item_effects = effects; state.npc.weapons = [{id:item.id, level:enemy.item_level}]; state.tactics_enabled = true; state.combat_mode = "expedition"; state.npc.texture = manifest.texture; state.npc.preview_texture = manifest.preview_texture; state.npc.capturable = enemy.capturable; state.npc.hom_type = hom.type; state.npc.hom_texture = hom.combat_texture; }
  return state;
}
export function resolveExpeditionTurn(state: any, decision: any, rng: (turn: number, draw: number) => number) {
  return state?.combat_mode === "expedition" ? resolveDungeonTurn(state, decision, rng) : { error: "UNTRUSTED_SETUP" };
}
export function resolveExpeditionInspiration(state: any, decision: any, rng: (turn: number, draw: number) => number) {
  return state?.combat_mode === "expedition" ? resolveDungeonInspiration(state, decision, rng) : { error: "UNTRUSTED_SETUP" };
}
