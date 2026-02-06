extends RefCounted
class_name HqRules

const DEFAULT_RULES := {
	"lab_th": {"unlock": 1, "max": 10, "cap_per_hq": 1},
	"essence_reactor": {"unlock": 1, "max": 10, "cap_per_hq": 1},
	"storage_vault": {"unlock": 1, "max": 10, "cap_per_hq": 1},
	"build_forge": {"unlock": 1, "max": 10, "cap_per_hq": 1},
	"homunculus_vat": {"unlock": 2, "max": 10, "cap_per_hq": 1},
	"ultrahit_tower": {"unlock": 2, "max": 10, "cap_per_hq": 1},
	"experiment_chamber": {"unlock": 3, "max": 10, "cap_per_hq": 1},
	"arcane_archives": {"unlock": 3, "max": 10, "cap_per_hq": 1},
	"sync_nexus": {"unlock": 4, "max": 10, "cap_per_hq": 1},
	"anomaly_containment": {"unlock": 5, "max": 10, "cap_per_hq": 1},
	"trade_hall": {"unlock": 2, "max": 10, "cap_per_hq": 1},
	"world_gate": {"unlock": 6, "max": 10, "cap_per_hq": 1}
}

static func is_unlocked(building_id: String, hq_level: int, rules: Dictionary = DEFAULT_RULES) -> bool:
	return max(0, int(hq_level)) >= get_unlock_level(building_id, rules)

static func get_unlock_level(building_id: String, rules: Dictionary = DEFAULT_RULES) -> int:
	var rule = _get_rule(building_id, rules)
	return int(rule.get("unlock", 1))

static func get_max_level(building_id: String, rules: Dictionary = DEFAULT_RULES) -> int:
	var rule = _get_rule(building_id, rules)
	return int(rule.get("max", 10))

static func get_cap(building_id: String, hq_level: int, rules: Dictionary = DEFAULT_RULES) -> int:
	var rule = _get_rule(building_id, rules)
	var max_level = int(rule.get("max", 10))
	if building_id == "lab_th":
		return max_level
	var cap_per_hq = int(rule.get("cap_per_hq", 1))
	var cap = max(0, int(hq_level)) * max(1, cap_per_hq)
	return min(max_level, cap)

static func can_upgrade(building_id: String, current_level: int, hq_level: int, rules: Dictionary = DEFAULT_RULES) -> bool:
	if not is_unlocked(building_id, hq_level, rules):
		return false
	var cap = get_cap(building_id, hq_level, rules)
	return int(current_level) < cap

static func _get_rule(building_id: String, rules: Dictionary) -> Dictionary:
	if typeof(rules) == TYPE_DICTIONARY and rules.has(building_id):
		var rule = rules[building_id]
		if typeof(rule) == TYPE_DICTIONARY:
			return rule
	return {"unlock": 1, "max": 10, "cap_per_hq": 1}
