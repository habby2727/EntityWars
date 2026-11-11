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
