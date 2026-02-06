extends RefCounted
class_name Capacity

const DEFAULT_BASE_CAPACITY := 1000
const DEFAULT_PER_LEVEL := 250
const DEFAULT_ROUTE_MULTIPLIERS := {
	"compact": 1.0,
	"reactive": 1.1,
	"sealed": 0.9
}
const DEFAULT_HQ_MULTIPLIERS := {
	"scientific": 1.05,
	"chaotic": 1.0,
	"industrial": 1.1
}

static func compute_total_capacity(
	storage_level: int,
	storage_route: String,
	hq_path: String,
	balance: Dictionary = {}
) -> int:
	var base = _get_number(balance, "storage_base_capacity", DEFAULT_BASE_CAPACITY)
	var per_level = _get_number(balance, "storage_capacity_per_level", DEFAULT_PER_LEVEL)
	var level = max(0, int(storage_level))
	var route_mults = balance.get("storage_route_capacity_mult", DEFAULT_ROUTE_MULTIPLIERS)
	var hq_mults = balance.get("hq_capacity_mult", DEFAULT_HQ_MULTIPLIERS)
	var route_key = _norm_key(storage_route)
	var hq_key = _norm_key(hq_path)
	var route_mult = _get_mult(route_mults, route_key, 1.0)
	var hq_mult = _get_mult(hq_mults, hq_key, 1.0)
	var total = (base + per_level * level) * route_mult * hq_mult
	return int(floor(max(0.0, total)))

static func _get_number(balance: Dictionary, key: String, default_value: float) -> float:
	if balance.has(key):
		var value = balance[key]
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return float(value)
	return float(default_value)

static func _get_mult(map: Dictionary, key: String, default_value: float) -> float:
	if typeof(map) == TYPE_DICTIONARY and map.has(key):
		var value = map[key]
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return float(value)
	return float(default_value)

static func _norm_key(value: String) -> String:
	return value.strip_edges().to_lower()
