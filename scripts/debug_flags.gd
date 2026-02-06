extends Node
class_name DebugFlags

const DEBUG_PATH := "user://debug.json"

var unlock_all_buildings: bool = false
var force_all_clickable: bool = false

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
