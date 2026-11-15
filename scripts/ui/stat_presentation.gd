extends RefCounted

const PERCENT_EFFECTS := ["vuln", "atk_boost", "atk_down", "shield", "reflect", "type_neutralize", "bonus_if_poisoned", "bonus_if_hit_last_exchange", "pierce_ward", "focus_next", "life_leech", "misalign_next", "bonus_if_low_hp", "hybrid_bonus", "bonus_if_marked", "bonus_power_if_poisoned", "bonus_if_shielded", "bonus_power_if_hit_last_exchange", "shield_by_order", "ward_dispel", "delayed_damage", "buff_steal", "counter_trap", "ward_convert", "heal_suppression", "type_adv_bonus", "favorable_type_bonus", "disadvantage_reduction", "ignore_reflect_chance", "vuln_on_hit"]

static func number(value: float) -> String:
	var text := "%.4f" % value
	while text.ends_with("0"):
		text = text.trim_suffix("0")
	return text.trim_suffix(".")

static func percent(value: float) -> String:
	return number(value * 100.0) + "%"

static func effect_value(kind: String, value: Variant, field: String = "value") -> String:
	if not (value is int or value is float):
		return str(value)
	if field == "threshold" or (field in ["value", "second_value"] and (kind in PERCENT_EFFECTS or kind.ends_with("_pct") or kind.ends_with("_chance") or kind.ends_with("_mult"))):
		return percent(float(value))
	return number(float(value))

static func stat_value(key: String, value: Variant) -> String:
	if value is Array:
		var parts: Array[String] = []
		for entry in value:
			parts.append(stat_value(key, entry))
		return ", ".join(parts)
	return effect_value(key, value)
