import { createDungeonCombatState, expeditionSpellSupported, resolveDungeonTurn, resolveDungeonInspiration } from "./dungeon_combat";
import { expeditionDraw, expeditionEnemies } from "./expeditions_rules";

/** setup must be produced by buildTrustedCombatSetup from server-owned player data. */
export function buildExpeditionEnemy(seed: Uint8Array, encounterKey: string, depth: number, capturable: boolean, setup: any, catalogs: any) {
  if (!encounterKey || !Number.isSafeInteger(depth) || depth < 1 || typeof capturable !== "boolean" || !setup?.entity?.base_stats || !Array.isArray(setup.spells) || !Array.isArray(setup.spell_ids) || !Array.isArray(catalogs?.spells)) throw new Error("INVALID_EXPEDITION_SETUP");
  const draw = (label: string) => expeditionDraw(seed, JSON.stringify([encounterKey, depth, label]), 0);
  const enemy = expeditionEnemies[Math.floor(draw("enemy") * expeditionEnemies.length)];
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
  return { combat_mode: "expedition", entity_id: enemy.id, name: enemy.name, type: enemy.types[0], types: [...enemy.types], texture: enemy.texture, preview_texture: enemy.preview_texture, capturable, floor: depth, homunculus_id: null, homunculus_level: 0, hp: Math.max(1, Math.round(hp * (capturable ? 0.85 : 0.75) * growth)), attack: Math.max(1, Math.round(attack * (0.60 + Math.min(0.15, spellQuality * 0.1)) * threat)), defense: Math.max(1, Math.round(defense * 0.82 * threat)), spell_ids: selected.map(s => s.id), npc_personality: capturable ? "ALCHEMIST" : "OPPORTUNIST" };
}

export function createExpeditionCombatState(setup: any, enemy: any, catalogs: any, previousActiveSlot = 0) {
  if (enemy?.combat_mode !== "expedition") return { error: "UNTRUSTED_SETUP" };
  const manifest = expeditionEnemies.find(e => e.id === enemy.entity_id);
  if (!manifest || JSON.stringify(manifest.types) !== JSON.stringify(enemy.types) || enemy.texture !== manifest.texture || enemy.preview_texture !== manifest.preview_texture) return { error: "UNTRUSTED_SETUP" };
  const state = createDungeonCombatState(setup, enemy, catalogs, previousActiveSlot);
  if (!state.error) { state.tactics_enabled = true; state.combat_mode = "expedition"; state.npc.texture = manifest.texture; state.npc.preview_texture = manifest.preview_texture; state.npc.capturable = enemy.capturable; }
  return state;
}
export function resolveExpeditionTurn(state: any, decision: any, rng: (turn: number, draw: number) => number) {
  return state?.combat_mode === "expedition" ? resolveDungeonTurn(state, decision, rng) : { error: "UNTRUSTED_SETUP" };
}
export function resolveExpeditionInspiration(state: any, decision: any, rng: (turn: number, draw: number) => number) {
  return state?.combat_mode === "expedition" ? resolveDungeonInspiration(state, decision, rng) : { error: "UNTRUSTED_SETUP" };
}
