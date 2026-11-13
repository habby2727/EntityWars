extends Node
class_name DebugFlags

const DEBUG_PATH := "user://debug.json"
const LAB_DEBUG_STATE_PATH := "user://lab_debug_state.json"

var unlock_all_buildings: bool = false
var force_all_clickable: bool = false

func load_lab_state() -> Dictionary:
	if not unlock_all_buildings or not FileAccess.file_exists(LAB_DEBUG_STATE_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAB_DEBUG_STATE_PATH))
	return parsed if parsed is Dictionary else {}

func save_lab_state(state: Dictionary) -> bool:
	if not unlock_all_buildings:
		return false
	var file = FileAccess.open(LAB_DEBUG_STATE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("DebugFlags: Cannot save local lab state.")
		return false
	file.store_string(JSON.stringify(state))
	var error = file.get_error()
	file.close()
	if error != OK:
		push_warning("DebugFlags: Failed to write local lab state.")
		return false
	return true

func lab_cooldown_active(state: Dictionary, building_id: String) -> bool:
	var cooldowns = state.get("debug_cooldowns", {})
	return cooldowns is Dictionary and float(cooldowns.get(building_id, 0.0)) > Time.get_unix_time_from_system()

func start_lab_cooldown(state: Dictionary, building_id: String) -> void:
	var cooldowns = state.get("debug_cooldowns", {})
	if not cooldowns is Dictionary:
		cooldowns = {}
	cooldowns[building_id] = Time.get_unix_time_from_system() + 1.0
	state["debug_cooldowns"] = cooldowns

func claim_lab_production(state: Dictionary, db: StaticDB, collect: bool = true) -> Dictionary:
	if not unlock_all_buildings:
		return {}
	var lab: Dictionary = state.get("lab", {})
	var buildings: Dictionary = lab.get("buildings", {})
	var reactor: Dictionary = buildings.get("essence_reactor", {})
	var level := int(reactor.get("level", 0))
	if level <= 0:
		return {}
	var storage: Dictionary = buildings.get("storage_vault", {})
	var reactor_route := str(reactor.get("route", "stable"))
	if reactor_route.is_empty():
		reactor_route = "stable"
	var storage_route := str(storage.get("route", ""))
	var hq_path := str(lab.get("hqPath", "Scientific"))
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	var runtime: Dictionary = reactor.get("runtime", {})
	var engine := ProductionEngine.new()
	engine.set_building_state("essence_reactor", float(runtime.get("stored_output", 0)), int(runtime.get("last_tick", now)))
	var balance := ProductionEngine.balance_for_server(db.balance)
	var boosts: Dictionary = lab.get("runtime", {}).get("boosts", {})
	var overclock := int(boosts.get("volatile_overclock", {}).get("expires_at", 0)) > now
	var mutagen := int(boosts.get("mutagen_surge", {}).get("expires_at", 0)) > now
	if overclock:
		var output_mult := float(db.get_balance("overclock_output_mult", 1.25))
		balance["reactor_base_rate"] = float(db.get_balance("reactor_base_rate", 1.0)) * output_mult
		balance["reactor_rate_per_level"] = float(db.get_balance("reactor_rate_per_level", 0.2)) * output_mult
	if overclock or mutagen:
		var loss_mult := (float(db.get_balance("overclock_loss_mult", 1.25)) if overclock else 1.0) * (float(db.get_balance("mutagen_failure_mult", 1.2)) if mutagen else 1.0)
		balance["volatile_loss_chance"] = float(db.get_balance("volatile_loss_chance", 0.25)) * loss_mult
	if mutagen:
		balance["mutagenic_rare_base_chance"] = float(db.get_balance("mutagenic_rare_base_chance", 0.08)) * float(db.get_balance("mutagen_rare_mult", 1.5))
	var cap_ms := int(float(db.get_balance("offline_cap_hours", 12)) * 3600000.0)
	if cap_ms > 0 and now - int(runtime.get("last_tick", now)) > cap_ms:
		engine.set_building_state("essence_reactor", float(runtime.get("stored_output", 0)), now - cap_ms)
	var accumulation := engine.accumulate("essence_reactor", now, level, reactor_route, storage_route, hq_path, balance, now)
	var reactor_state := engine.get_building_state("essence_reactor")
	var directive: Dictionary = lab.get("runtime", {}).get("directive", {})
	if str(directive.get("id", "")) == "production":
		var end := int(reactor_state.get("last_tick", now))
		var start := end - int(float(accumulation.get("delta_seconds", 0)) * 1000)
		var overlap := maxi(0, mini(end, int(directive.get("ends_at", 0))) - maxi(start, int(directive.get("starts_at", 0))))
		var seconds := float(accumulation.get("delta_seconds", 0))
		if seconds > 0:
			reactor_state["stored_output"] = float(reactor_state.get("stored_output", 0)) + float(accumulation.get("produced", 0)) * (float(overlap) / (seconds * 1000.0)) * (float(db.get_balance("hq_directive_production_mult", 1.1)) - 1.0)
			engine.set_building_state("essence_reactor", reactor_state.stored_output, end)
	if not collect:
		reactor["runtime"] = engine.get_building_state("essence_reactor")
		buildings["essence_reactor"] = reactor
		lab["buildings"] = buildings
		state["lab"] = lab
		return {"accrued": true}
	var capacity := Capacity.compute_total_capacity(int(storage.get("level", 0)), storage_route, hq_path, balance)
	var result := engine.claim("essence_reactor", capacity, reactor_route, storage_route, hq_path, balance)
	reactor["runtime"] = engine.get_building_state("essence_reactor")
	buildings["essence_reactor"] = reactor
	lab["buildings"] = buildings
	state["lab"] = lab
	var wallet: Dictionary = state.get("wallet", {})
	for resource in result.get("grants", {}):
		wallet[resource] = int(wallet.get(resource, 0)) + int(floor(float(result.grants[resource])))
	state["wallet"] = wallet
	var lab_runtime: Dictionary = lab.get("runtime", {})
	var overcharge: Dictionary = lab_runtime.get("reactor_overcharge", {"progress": 0, "last_used_at": 0})
	overcharge["progress"] = mini(int(db.get_balance("reactor_overcharge_threshold", 300)), int(overcharge.get("progress", 0)) + int(result.get("grants", {}).get("essence", 0)))
	lab_runtime["reactor_overcharge"] = overcharge
	lab["runtime"] = lab_runtime
	state["lab"] = lab
	return result

func _init() -> void:
	_load_flags()

func reload() -> void:
	_load_flags()

func _load_flags() -> void:
	unlock_all_buildings = false
	force_all_clickable = false
	_apply_from_balance()
	_apply_from_file()

func _apply_from_balance() -> void:
	var db := StaticDB.new()
	var section = db.get_balance("debug", {})
	db.free()
	if typeof(section) != TYPE_DICTIONARY:
		return
	_apply_dict(section)

func _apply_from_file() -> void:
	if not FileAccess.file_exists(DEBUG_PATH):
		return
	var f = FileAccess.open(DEBUG_PATH, FileAccess.READ)
	if f == null:
		push_warning("DebugFlags: Failed to open %s." % DEBUG_PATH)
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("DebugFlags: debug.json must contain a Dictionary.")
		return
	_apply_dict(parsed)

func _apply_dict(values: Dictionary) -> void:
	if values.has("unlock_all_buildings"):
		unlock_all_buildings = bool(values.get("unlock_all_buildings"))
	if values.has("force_all_clickable"):
		force_all_clickable = bool(values.get("force_all_clickable"))
