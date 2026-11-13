import { readFileSync } from "fs";
import { resolve } from "path";

type Spell = {
	id: string;
	type: string;
	eligible_types?: string[];
	tower_level_required?: number;
	research_cost?: Record<string, number>;
	research_time_sec?: number;
};
type Project = { entity_id: string; spell_id: string; started_at: number; completes_at: number };
export type SpellProgress = { learned_by_entity: Record<string, string[]>; active_research: Project | null; equipped_by_mode: Record<string, Record<string, string[]>> };

function readCatalog(file: string, key: string): any[] {
	try {
		const data = JSON.parse(readFileSync(resolve(import.meta.dir, "..", "..", "data", file), "utf8"));
		return Array.isArray(data[key]) ? data[key] : [];
	} catch (error) {
		console.warn(`[spells] Cannot load ${file}`, error);
		return [];
	}
}

const entities = new Map<string, string>();
for (const entity of readCatalog("entities.json", "entities")) {
	if (typeof entity?.id === "string" && typeof entity?.type === "string") entities.set(entity.id, entity.type);
}
const spells = new Map<string, Spell>();
for (const spell of readCatalog("spells.json", "spells")) {
	if (typeof spell?.id === "string" && typeof spell?.type === "string" && !spells.has(spell.id)) spells.set(spell.id, spell);
}

function isResearchable(entityId: string, spellId: string): boolean {
	const type = entities.get(entityId);
	const spell = spells.get(spellId);
	return !!type && !!spell && (spell.type === "universal" || spell.type === "hybrid") &&
		Array.isArray(spell.eligible_types) && spell.eligible_types.includes(type);
}

export function featuredSpellIds(type: string, towerLevel: number, now: number, rotationSeconds = 86400): string[] {
	const index = ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"].indexOf(type);
	if (index < 0 || !Number.isFinite(now) || !Number.isFinite(rotationSeconds) || rotationSeconds <= 0) return [];
	const candidates = [...spells.values()].filter(spell => (spell.type === "universal" || spell.type === "hybrid") && Array.isArray(spell.eligible_types) && spell.eligible_types.includes(type) && Number.isInteger(spell.tower_level_required) && spell.tower_level_required! >= 1 && spell.tower_level_required! <= towerLevel).map(spell => spell.id).sort();
	if (!candidates.length) return [];
	const day = Math.floor(now / (rotationSeconds * 1000));
	const start = ((day + index * 7) % candidates.length + candidates.length) % candidates.length;
	const step = Math.max(1, Math.floor(candidates.length / 3));
	return Array.from({ length: Math.min(3, candidates.length) }, (_, k) => candidates[(start + k * step) % candidates.length]);
}

function validLoadout(entityId: string, ids: unknown, learned: Record<string, string[]>): ids is string[] {
	const type = entities.get(entityId);
	if (!type || !Array.isArray(ids) || ids.length !== 4 || ids.some(id => typeof id !== "string") || new Set(ids).size !== 4) return false;
	return ids.every(id => {
		const spell = spells.get(id);
		return !!spell && (spell.type === type || (isResearchable(entityId, id) && (learned[entityId] ?? []).includes(id)));
	});
}

export function normalizeSpellProgress(raw: any): SpellProgress {
	const learned: Record<string, string[]> = {};
	const source = raw?.learned_by_entity;
	if (source && typeof source === "object" && !Array.isArray(source)) {
		for (const [entityId, values] of Object.entries(source)) {
			if (!entities.has(entityId) || !Array.isArray(values)) continue;
			learned[entityId] = [...new Set(values.filter((id): id is string => typeof id === "string" && isResearchable(entityId, id)))].slice(0, 20);
		}
	}
	const project = raw?.active_research;
	let active: Project | null = null;
	if (project && typeof project.entity_id === "string" && typeof project.spell_id === "string" &&
		isResearchable(project.entity_id, project.spell_id) && Number.isFinite(project.started_at) &&
		Number.isFinite(project.completes_at) && project.started_at >= 0 && project.completes_at >= project.started_at &&
		!learned[project.entity_id]?.includes(project.spell_id)) {
		active = { entity_id: project.entity_id, spell_id: project.spell_id, started_at: project.started_at, completes_at: project.completes_at };
	}
	const equipped: Record<string, Record<string, string[]>> = { attack: {}, defense: {} };
	for (const mode of ["attack", "defense"]) {
		const entries = raw?.equipped_by_mode?.[mode];
		if (!entries || typeof entries !== "object" || Array.isArray(entries)) continue;
		for (const [entityId, ids] of Object.entries(entries)) {
			if (validLoadout(entityId, ids, learned)) equipped[mode][entityId] = [...ids];
		}
	}
	return { learned_by_entity: learned, active_research: active, equipped_by_mode: equipped };
}

export function setSpellLoadout(state: any, payload: any): string | null {
	const mode = typeof payload?.mode === "string" ? payload.mode : "";
	const entityId = typeof payload?.entity_id === "string" ? payload.entity_id : "";
	if (mode !== "attack" && mode !== "defense") return "Invalid loadout mode.";
	if (!validLoadout(entityId, payload?.spell_ids, state.spell_progress.learned_by_entity)) return "Invalid or unlearned spell loadout.";
	state.spell_progress.equipped_by_mode[mode][entityId] = [...payload.spell_ids];
	return null;
}

export function startSpellResearch(state: any, payload: any, now: number, resources: Set<string>, balance: Record<string, unknown> = {}): string | null {
	const entityId = typeof payload?.entity_id === "string" ? payload.entity_id : "";
	const spellId = typeof payload?.spell_id === "string" ? payload.spell_id : "";
	if (!isResearchable(entityId, spellId)) return "Unknown or incompatible entity and spell.";
	const progress: SpellProgress = state.spell_progress;
	if (progress.learned_by_entity[entityId]?.includes(spellId)) return "Spell already learned.";
	if (progress.active_research) return "Spell research already in progress.";
	if ((progress.learned_by_entity[entityId]?.length ?? 0) >= 20) return "Entity spell limit reached.";
	const spell = spells.get(spellId)!;
	if (!Number.isInteger(spell.tower_level_required) || (spell.tower_level_required ?? 0) < 1 ||
		!Number.isInteger(spell.research_time_sec) || (spell.research_time_sec ?? 0) <= 0 ||
		!spell.research_cost || typeof spell.research_cost !== "object" || Array.isArray(spell.research_cost) || Object.keys(spell.research_cost).length === 0) return "Invalid spell research data.";
	if ((state.lab.buildings.ultrahit_tower?.level ?? 0) < spell.tower_level_required!) return "Spell Tower level too low.";
	const discount = balance.spell_featured_discount_pct ?? 0.2;
	const rotation = balance.spell_featured_rotation_seconds ?? 86400;
	if (typeof discount !== "number" || !Number.isFinite(discount) || discount < 0 || discount > 1 || typeof rotation !== "number" || !Number.isFinite(rotation) || rotation <= 0) return "Invalid featured research configuration.";
	const featured = featuredSpellIds(entities.get(entityId)!, state.lab.buildings.ultrahit_tower?.level ?? 0, now, rotation).includes(spellId);
	const cost: Record<string, number> = {};
	for (const [id, amount] of Object.entries(spell.research_cost)) {
		if (!resources.has(id) || !Number.isSafeInteger(amount) || amount < 0) return "Invalid spell research cost.";
		cost[id] = featured && amount > 0 ? Math.max(1, Math.ceil(amount * (1 - discount))) : amount;
		if ((state.wallet[id] ?? 0) < cost[id]) return "Insufficient resources.";
	}
	for (const [id, amount] of Object.entries(cost)) state.wallet[id] -= amount;
	progress.active_research = { entity_id: entityId, spell_id: spellId, started_at: now, completes_at: now + spell.research_time_sec! * 1000 };
	return null;
}

export function claimSpellResearch(state: any, payload: any, now: number): string | null {
	const entityId = typeof payload?.entity_id === "string" ? payload.entity_id : "";
	const spellId = typeof payload?.spell_id === "string" ? payload.spell_id : "";
	if (!isResearchable(entityId, spellId)) return "Unknown or incompatible entity and spell.";
	const progress: SpellProgress = state.spell_progress;
	if (progress.learned_by_entity[entityId]?.includes(spellId)) return null;
	const active = progress.active_research;
	if (!active || active.entity_id !== entityId || active.spell_id !== spellId) return "Spell research mismatch.";
	if (active.completes_at > now) return "Spell research not complete.";
	const learned = progress.learned_by_entity[entityId] ?? [];
	if (learned.length >= 20) return "Entity spell limit reached.";
	progress.learned_by_entity[entityId] = [...learned, spellId];
	progress.active_research = null;
	return null;
}
