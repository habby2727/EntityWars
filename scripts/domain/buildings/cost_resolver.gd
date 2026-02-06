extends RefCounted
class_name CostResolver

const BUILDINGS_PATH := "res://data/static/buildings.json"
const DEFAULT_HQ_COST_MULT := {
	"scientific": 0.95,
	"chaotic": 1.05,
	"industrial": 1.0
}

var _buildings: Dictionary = {}
var _balance: Dictionary = {}

func _init(buildings_data: Dictionary = {}, balance: Dictionary = {}) -> void:
	_balance = balance.duplicate(true)
	if buildings_data.size() > 0:
		_buildings = buildings_data.duplicate(true)
	else:
		_buildings = _load_buildings()

func set_balance(balance: Dictionary) -> void:
	_balance = balance.duplicate(true)

func get_building(building_id: String) -> Dictionary:
	return _buildings.get(building_id, {})

func get_cost_for_level(building_id: String, level: int) -> Dictionary:
	var entry = _buildings.get(building_id, null)
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var costs = entry.get("costs", null)
	if typeof(costs) != TYPE_DICTIONARY:
		return {}
	var key = str(int(level))
	if not costs.has(key):
		return {}
	var cost_entry = costs[key]
	if typeof(cost_entry) != TYPE_DICTIONARY:
		return {}
	return cost_entry

func resolve_upgrade_cost(
	building_id: String,
	current_level: int,
	hq_level: int,
	hq_path: String,
	hq_rules: HqRules = null
) -> Dictionary:
	var target_level = int(current_level) + 1
	if hq_rules != null and not hq_rules.can_upgrade(building_id, current_level, hq_level):
		return {"ok": false, "error": "cap"}
	var base_cost = get_cost_for_level(building_id, target_level)
	if base_cost.is_empty():
		return {"ok": false, "error": "missing_cost"}
	var mult = _get_hq_cost_mult(hq_path)
	var out: Dictionary = {}
	for key in base_cost.keys():
		var value = base_cost[key]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			continue
		out[key] = int(floor(float(value) * mult))
	return {"ok": true, "target_level": target_level, "multiplier": mult, "cost": out}

func _get_hq_cost_mult(hq_path: String) -> float:
	var key = _norm_key(hq_path)
	var map = _balance.get("hq_cost_mult", DEFAULT_HQ_COST_MULT)
	if typeof(map) == TYPE_DICTIONARY and map.has(key):
		var value = map[key]
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return float(value)
	return float(DEFAULT_HQ_COST_MULT.get(key, 1.0))

func _load_buildings() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(BUILDINGS_PATH):
		push_error("CostResolver: Missing buildings.json at %s" % BUILDINGS_PATH)
		return out
	var f = FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	if f == null:
		push_error("CostResolver: Failed to open %s" % BUILDINGS_PATH)
		return out
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	var data = null
	if parsed == null:
		push_error("CostResolver: Invalid JSON in %s" % BUILDINGS_PATH)
		return out
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("error"):
			push_error("CostResolver: Invalid JSON in %s" % BUILDINGS_PATH)
			return out
		data = parsed.get("result", parsed)
	else:
		if int(parsed.error) != OK:
			push_error("CostResolver: Invalid JSON in %s" % BUILDINGS_PATH)
			return out
		data = parsed.result
	if typeof(data) != TYPE_DICTIONARY or not data.has("buildings"):
		push_error("CostResolver: buildings.json missing 'buildings' array")
		return out
	var list = data.get("buildings", [])
	if typeof(list) != TYPE_ARRAY:
		push_error("CostResolver: buildings.json 'buildings' must be array")
		return out
	for entry in list:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id = str(entry.get("id", ""))
		if id == "":
			continue
		out[id] = entry
	return out

func _norm_key(value: String) -> String:
	return value.strip_edges().to_lower()
