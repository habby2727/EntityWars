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
	return "owned" if _valid_expedition_progress(entry) else "locked"

static func _safe_nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 9007199254740991.0 and floor(float(value)) == float(value)

static func _valid_expedition_progress(entry: Variant) -> bool:
	if not entry is Dictionary or not entry.get("owned") is bool or not entry.owned:
		return false
	if not _safe_nonnegative_integer(entry.get("level")) or not _safe_nonnegative_integer(entry.get("xp")):
		return false
	var level := int(entry.level)
	var xp := int(entry.xp)
	if level > 10 or xp < xp_threshold(level) or (level < 10 and xp >= xp_threshold(level + 1)):
		return false
	if entry.has("mutation_id") and (not entry.mutation_id is String or level < 3 or not mutation_catalog().has(entry.mutation_id)):
		return false
	if entry.has("mutation_changed_at") and not _safe_nonnegative_integer(entry.mutation_changed_at):
		return false
	return true

static func passive_text(hom: Dictionary) -> String:
	var passive: Variant = hom.get("passive", {})
	if not passive is Dictionary:
		return ""
	var descriptions: Variant = passive.get("description", {})
	if not descriptions is Dictionary:
		return ""
	var language := "es" if TranslationServer.get_locale().begins_with("es") else "en"
	return str(descriptions.get(language, ""))
