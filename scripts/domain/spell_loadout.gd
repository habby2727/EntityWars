extends RefCounted

static func initial_ids(registry: DataRegistry, entity_id: String) -> Array:
	var entity: Dictionary = registry.entities.get(entity_id, {})
	var result := []
	for spell in registry.get_spells_for_type(str(entity.get("type", ""))):
		result.append(str(spell.id))
	return result

static func available_ids(registry: DataRegistry, entity_id: String, progress: Dictionary, allow_unlearned: bool = false) -> Array:
	var entity: Dictionary = registry.entities.get(entity_id, {})
	if entity.is_empty():
		return []
	var entity_type := str(entity.get("type", ""))
	var learned: Array = progress.get("learned_by_entity", {}).get(entity_id, [])
	var ids := initial_ids(registry, entity_id)
	for spell in registry.get_researchable_spells_for_type(entity_type):
		if spell.type in ["universal", "hybrid"] and (allow_unlearned or str(spell.id) in learned):
			ids.append(str(spell.id))
	return ids

static func valid(registry: DataRegistry, entity_id: String, progress: Dictionary, ids: Variant, allow_unlearned: bool = false) -> bool:
	if not ids is Array or ids.size() != 4:
		return false
	var available := available_ids(registry, entity_id, progress, allow_unlearned)
	var seen := {}
	for id in ids:
		if not id is String or id not in available or seen.has(id):
			return false
		seen[id] = true
	return true

static func repair(registry: DataRegistry, entity_id: String, progress: Dictionary, ids: Variant, allow_unlearned: bool = false) -> Array:
	var available := available_ids(registry, entity_id, progress, allow_unlearned)
	var result := []
	if ids is Array:
		for id in ids:
			if id is String and id in available and id not in result and result.size() < 4:
				result.append(id)
	for id in initial_ids(registry, entity_id):
		if result.size() == 4:
			break
		if id not in result:
			result.append(id)
	return result

static func saved_ids(registry: DataRegistry, state: Dictionary, mode: String, entity_id: String, seal: Dictionary = {}, require_authoritative: bool = false) -> Array:
	var progress: Dictionary = state.get("spell_progress", {})
	var equipped: Dictionary = progress.get("equipped_by_mode", {}).get(mode, {})
	var ids: Variant = equipped.get(entity_id)
	if ids == null and str(seal.get("entity_id", "")) == entity_id:
		ids = seal.get("spell_ids", [])
		if require_authoritative and ids is Array:
			var initial := initial_ids(registry, entity_id)
			ids = ids.filter(func(id): return id in initial)
	return repair(registry, entity_id, progress, ids)
