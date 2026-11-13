extends RefCounted

static func level_for(item_id: String, progress: Dictionary) -> int:
	var entry: Variant = progress.get(item_id, {})
	if not entry is Dictionary:
		return 0
	return clampi(int(entry.get("level", 0)), 0, 10)

static func effective_item(item: Dictionary, progress: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}
	var result := item.duplicate(true)
	var level := level_for(str(item.get("id", "")), progress)
	result["forge_level"] = level
	var effects: Dictionary = result.get("effects", {})
	var baselines: Dictionary = result.get("base_effects", {})
	for key in effects:
		var value: Variant = effects.get(key)
		if value is Array and not value.is_empty():
			if level == 0 and value.size() == 10 and baselines.has(key):
				effects[key] = [baselines[key]]
			else:
				effects[key] = [value[clampi(level - 1, 0, value.size() - 1)]]
	return result
