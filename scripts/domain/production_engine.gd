extends RefCounted
class_name ProductionEngine

# Client-side estimates only; backend is authoritative for production/claim.
const DEFAULT_OFFLINE_CAP_HOURS := 12.0
const DEFAULT_REACTOR_BASE_RATE := 1.0
const DEFAULT_REACTOR_RATE_PER_LEVEL := 0.2
const DEFAULT_REACTOR_ROUTE_OUTPUT_MULT := {
	"stable": 0.8,
	"volatile": 1.35,
	"mutagenic": 0.65
}
const DEFAULT_STORAGE_ROUTE_OUTPUT_MULT := {
	"reactive": 1.05
}
const DEFAULT_VOLATILE_LOSS_CHANCE := 0.25
const DEFAULT_VOLATILE_LOSS_PCT := 0.3
const DEFAULT_COMPACT_LOSS_MULT := 0.5
const DEFAULT_SEALED_RARE_MULT := 1.25
const DEFAULT_MUTAGENIC_RARE_CHANCE := 0.08
const DEFAULT_MUTAGENIC_RARE_CAP := 0.25
const DEFAULT_HQ_OUTPUT_MULT := {
	"scientific": 1.05,
	"chaotic": 1.0,
	"industrial": 0.95
}
const DEFAULT_HQ_RARE_MULT := {
	"scientific": 0.9,
	"chaotic": 1.1,
	"industrial": 0.85
}
const DEFAULT_HQ_RISK_MULT := {
	"scientific": 0.9,
	"chaotic": 1.1,
	"industrial": 0.85
}

var buildings: Dictionary = {}

static func balance_for_server(balance: Dictionary) -> Dictionary:
	var adjusted := balance.duplicate(true)
	var hq_mults: Dictionary = balance.get("route_multipliers", balance.get("hq_output_mult", {}))
	var normalized := {}
	for key in ["scientific", "chaotic", "industrial"]:
		normalized[key] = float(hq_mults.get(key, 1.0))
	adjusted["route_multipliers"] = normalized
	return adjusted

func _init(state: Dictionary = {}) -> void:
	buildings = state.duplicate(true)

func get_state() -> Dictionary:
	return buildings

func set_state(state: Dictionary) -> void:
	buildings = state.duplicate(true)

func set_building_state(building_id: String, stored_output: float, last_tick_ms: int) -> void:
	buildings[building_id] = {
		"stored_output": max(0.0, float(stored_output)),
		"last_tick": int(last_tick_ms)
	}

func get_building_state(building_id: String) -> Dictionary:
	return _ensure_building(building_id, 0)

func accumulate(
	building_id: String,
	now_ms: int,
	level: int,
	route: String,
	storage_route: String,
	hq_path: String,
	balance: Dictionary = {},
	server_time_ms: int = -1
) -> Dictionary:
	var current_ms = int(server_time_ms) if server_time_ms >= 0 else int(now_ms)
	var state = _ensure_building(building_id, current_ms)
	var last_tick = int(state.get("last_tick", current_ms))
	var delta_ms = current_ms - last_tick
	if delta_ms < 0:
		delta_ms = 0
	var unverified := false
	var cap_hours = _get_number(balance, "offline_cap_hours", DEFAULT_OFFLINE_CAP_HOURS)
	var cap_ms = int(cap_hours * 3600.0 * 1000.0)
	if server_time_ms < 0:
		var max_ms = min(cap_ms, 3600 * 1000)
		if delta_ms > max_ms:
			delta_ms = max_ms
		if delta_ms > 0:
			unverified = true
	else:
		if cap_ms > 0 and delta_ms > cap_ms:
			delta_ms = cap_ms
	if delta_ms <= 0:
		return {
			"produced": 0.0,
			"delta_seconds": 0.0,
			"unverified": unverified,
			"stored_output": float(state.get("stored_output", 0.0))
		}
	var rate = _compute_output_rate(level, route, storage_route, hq_path, balance)
	var produced = rate * (float(delta_ms) / 1000.0)
	var stored = max(0.0, float(state.get("stored_output", 0.0)) + produced)
	state["stored_output"] = stored
	state["last_tick"] = last_tick + delta_ms
	return {
		"produced": produced,
		"delta_seconds": float(delta_ms) / 1000.0,
		"unverified": unverified,
		"stored_output": stored
	}

func claim(
	building_id: String,
	capacity: float,
	route: String,
	storage_route: String,
	hq_path: String,
	balance: Dictionary = {},
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var state = _ensure_building(building_id, 0)
	var available = max(0.0, float(state.get("stored_output", 0.0)))
	var cap = max(0.0, float(capacity))
	var claimable = min(available, cap)
	var loss := 0.0
	var volatile_failed := false
	if _norm_key(route) == "volatile" and claimable > 0.0:
		var loss_chance = _get_number(balance, "volatile_loss_chance", DEFAULT_VOLATILE_LOSS_CHANCE)
		loss_chance *= _get_hq_risk_mult(hq_path, balance)
		loss_chance = clamp(loss_chance, 0.0, 1.0)
		if _roll(rng, loss_chance):
			volatile_failed = true
			var loss_pct = _get_number(balance, "volatile_loss_pct", DEFAULT_VOLATILE_LOSS_PCT)
			if _norm_key(storage_route) == "compact":
				loss_pct *= _get_number(balance, "compact_loss_mult", DEFAULT_COMPACT_LOSS_MULT)
			loss_pct = clamp(loss_pct, 0.0, 1.0)
			loss = claimable * loss_pct
	var claimed = max(0.0, claimable - loss)
	state["stored_output"] = max(0.0, available - claimable)
	var grants := {"essence": claimed}
	var rare_granted := 0
	if _norm_key(route) == "mutagenic" and claimed > 0.0:
		var rare_chance = get_mutagenic_rare_chance(storage_route, hq_path, balance)
		if _roll(rng, rare_chance):
			rare_granted = 1
			grants["arcane_shard"] = 1
	return {
		"claimed": claimed,
		"lost": loss,
		"volatile_failed": volatile_failed,
		"rare_granted": rare_granted,
		"remainder": float(state.get("stored_output", 0.0)),
		"grants": grants
	}

func get_mutagenic_rare_chance(storage_route: String, hq_path: String, balance: Dictionary = {}) -> float:
	var chance = _get_number(balance, "mutagenic_rare_base_chance", DEFAULT_MUTAGENIC_RARE_CHANCE)
	if _norm_key(storage_route) == "sealed":
		chance *= _get_number(balance, "sealed_rare_mult", DEFAULT_SEALED_RARE_MULT)
	chance *= _get_hq_rare_mult(hq_path, balance)
	var cap = _get_number(balance, "mutagenic_rare_cap", DEFAULT_MUTAGENIC_RARE_CAP)
	return clamp(chance, 0.0, cap)

func _compute_output_rate(
	level: int,
	route: String,
	storage_route: String,
	hq_path: String,
	balance: Dictionary
) -> float:
	var base = _get_number(balance, "reactor_base_rate", DEFAULT_REACTOR_BASE_RATE)
	var per_level = _get_number(balance, "reactor_rate_per_level", DEFAULT_REACTOR_RATE_PER_LEVEL)
	var lvl = max(0, int(level))
	var rate = base + per_level * lvl
	var route_mults = balance.get("reactor_route_output_mult", DEFAULT_REACTOR_ROUTE_OUTPUT_MULT)
	rate *= _get_mult(route_mults, _norm_key(route), 1.0)
	var storage_mults = balance.get("storage_route_output_mult", DEFAULT_STORAGE_ROUTE_OUTPUT_MULT)
	rate *= _get_mult(storage_mults, _norm_key(storage_route), 1.0)
	rate *= _get_hq_output_mult(hq_path, balance)
	return max(0.0, rate)

func _get_hq_output_mult(hq_path: String, balance: Dictionary) -> float:
	var key = _norm_key(hq_path)
	var route_mults = balance.get("route_multipliers", null)
	if typeof(route_mults) == TYPE_DICTIONARY:
		return _get_mult(route_mults, key, _get_mult(DEFAULT_HQ_OUTPUT_MULT, key, 1.0))
	var hq_mults = balance.get("hq_output_mult", DEFAULT_HQ_OUTPUT_MULT)
	return _get_mult(hq_mults, key, 1.0)

func _get_hq_rare_mult(hq_path: String, balance: Dictionary) -> float:
	var key = _norm_key(hq_path)
	var hq_mults = balance.get("hq_rare_mult", DEFAULT_HQ_RARE_MULT)
	return _get_mult(hq_mults, key, 1.0)

func _get_hq_risk_mult(hq_path: String, balance: Dictionary) -> float:
	var key = _norm_key(hq_path)
	var hq_mults = balance.get("hq_risk_mult", DEFAULT_HQ_RISK_MULT)
	return _get_mult(hq_mults, key, 1.0)

func _roll(rng: RandomNumberGenerator, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return rng.randf() < chance

func _ensure_building(building_id: String, now_ms: int) -> Dictionary:
	if not buildings.has(building_id):
		buildings[building_id] = {
			"stored_output": 0.0,
			"last_tick": int(now_ms)
		}
	var state: Dictionary = buildings[building_id]
	if not state.has("stored_output"):
		state["stored_output"] = 0.0
	if not state.has("last_tick"):
		state["last_tick"] = int(now_ms)
	return state

func _get_number(balance: Dictionary, key: String, default_value: float) -> float:
	if balance.has(key):
		var value = balance[key]
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return float(value)
	return float(default_value)

func _get_mult(map: Dictionary, key: String, default_value: float) -> float:
	if typeof(map) == TYPE_DICTIONARY and map.has(key):
		var value = map[key]
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			return float(value)
	return float(default_value)

func _norm_key(value: String) -> String:
	return value.strip_edges().to_lower()
