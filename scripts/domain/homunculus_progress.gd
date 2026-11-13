extends RefCounted

static func mutation_catalog() -> Dictionary:
	var result := {}
	var file := FileAccess.open("res://data/static/mutations.json", FileAccess.READ)
	if file:
		var data: Variant = JSON.parse_string(file.get_as_text())
		if data is Dictionary and data.get("mutations", []) is Array:
			for entry in data.mutations:
				if entry is Dictionary and entry.get("id") is String:
					result[entry.id] = entry
	return result

static func effective_bonuses(homunculus: Dictionary, progress: Dictionary) -> Dictionary:
	var entry: Variant = progress.get(str(homunculus.get("id", "")), {})
	if not entry is Dictionary:
		entry = {}
	var level := clampi(int(entry.get("level", 0)), 0, 10)
	var result := {"hp_flat": int(homunculus.get("buff_hp", 0)) + level, "power_flat": int(homunculus.get("buff_atk", 0)) + int(level / 5.0), "guard_flat": int(homunculus.get("buff_def", 0)) + int(level / 3.0)}
	var mutation: Variant = mutation_catalog().get(str(entry.get("mutation_id", "")), {})
	if mutation is Dictionary and mutation.get("effects", {}) is Dictionary:
		for key in mutation.get("effects", {}):
			var amount: Variant = mutation.effects[key]
			if key in ["hp_flat", "power_flat", "guard_flat", "favorable_type_bonus"] and (amount is int or amount is float) and is_finite(float(amount)):
				result[key] = result.get(key, 0) + amount
	return result
