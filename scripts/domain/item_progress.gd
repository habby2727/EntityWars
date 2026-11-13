extends RefCounted

static var _trait_pool: Dictionary = {}
static var _fusion_imprints: Dictionary = {}
static var _pool_loaded := false

static func trait_pool() -> Dictionary:
	if not _pool_loaded:
		_pool_loaded = true
		var file := FileAccess.open("res://data/static/balance.json", FileAccess.READ)
		if file:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data is Dictionary and data.get("balance", {}) is Dictionary:
				var pool: Variant = data.balance.get("forge_trait_pool", {})
				if pool is Dictionary:
					_trait_pool = pool
				var imprints: Variant = data.balance.get("forge_fusion_imprints", {})
				if imprints is Dictionary:
					_fusion_imprints = imprints
	return _trait_pool

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
	var entry: Variant = progress.get(str(item.get("id", "")), {})
	if not entry is Dictionary:
		return result
	var path := str(entry.get("specialization", ""))
	var pool: Variant = trait_pool().get(path, {}) if path in ["aggressive", "defensive", "technical"] else {}
	var traits: Variant = entry.get("traits", [])
	if not pool is Dictionary or not traits is Array or traits.size() != 3:
		traits = []
	var seen := {}
	var allocated := 0
	for trait_entry in traits:
		if not trait_entry is Dictionary or not trait_entry.get("id") is String:
			continue
		var id: String = trait_entry.id
		var raw_points: Variant = trait_entry.get("points")
		if not (raw_points is int or raw_points is float) or not is_finite(float(raw_points)) or float(raw_points) != floorf(float(raw_points)):
			continue
		var points := int(raw_points)
		var bonus: Variant = pool.get(id)
		if seen.has(id) or points < 0 or points > 4 or allocated + points > level or not (bonus is float or bonus is int) or not is_finite(float(bonus)) or float(bonus) <= 0:
			continue
		seen[id] = true
		allocated += points
		if points == 0:
			continue
		_add_effect(effects, id, float(bonus) * points)
	var fusion: Variant = entry.get("fusion", {})
	if fusion is Dictionary and fusion.get("donor_id") is String:
		var donor: String = fusion.donor_id
		var imprint: Variant = _fusion_imprints.get(donor, {})
		if donor != str(item.get("id", "")) and imprint is Dictionary and imprint.size() == 1:
			for id in imprint:
				var amount: Variant = imprint[id]
				if id in ["true_on_hit", "evasion_pct", "ward_pct", "reflect_pct", "dot_true", "disadvantage_reduction", "tempo_on_win", "ignore_reflect_chance"] and (amount is int or amount is float) and is_finite(float(amount)) and float(amount) > 0:
					_add_effect(effects, id, float(amount))
	return result

static func _add_effect(effects: Dictionary, id: String, amount: float) -> void:
	var existing: Variant = effects.get(id, [0])
	if not existing is Array or existing.is_empty() or not (existing[0] is int or existing[0] is float):
		return
	var total: float = float(existing[0]) + amount
	if id in ["ward_pct", "reflect_pct", "evasion_pct", "disadvantage_reduction", "ignore_reflect_chance", "vuln_on_hit"]:
		total = clampf(total, 0.0, 1.0)
	effects[id] = [total]
