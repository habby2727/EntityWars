extends RefCounted

static func xp_threshold(level: int) -> int:
	match clampi(level, 0, 10):
		0: return 0
		1: return 100
		2: return 300
		3: return 550
		_: return roundi(800.0 * pow(1.25, level - 1) - 700.0)

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

# Legacy combat companions are always owned; expedition ownership requires an
# authenticated snapshot with an explicit boolean grant.
static func collection_status(id: String, legacy: bool, progress: Dictionary, synced: bool) -> String:
	if legacy:
		return "owned"
	if not synced:
		return "unknown"
	var entry: Variant = progress.get(id, {})
	return "owned" if entry is Dictionary and entry.get("owned") is bool and entry.owned else "locked"

static func passive_text(hom: Dictionary) -> String:
	var passive: Variant = hom.get("passive", {})
	if not passive is Dictionary:
		return ""
	var descriptions: Variant = passive.get("description", {})
	if not descriptions is Dictionary:
		return ""
	var language := "es" if TranslationServer.get_locale().begins_with("es") else "en"
	return str(descriptions.get(language, ""))
