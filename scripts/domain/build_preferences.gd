extends RefCounted
class_name BuildPreferences

const VERSION := 1
const PREFIX := "user://build_preferences_"
const KEYS := ["entity_id", "homunculus_id", "equip_1", "equip_2", "side_1", "side_2", "attack_tech", "defense_tech"]

static func path_for(player_id: String) -> String:
	return PREFIX + player_id.sha256_text() + ".json" if not player_id.is_empty() else ""

static func seal_path(player_id: String, mode: String) -> String:
	return "user://seal_%s_%s.json" % [mode, player_id.sha256_text()] if not player_id.is_empty() else "user://seal_%s.json" % mode

static func load_for(player_id: String) -> Dictionary:
	var path := path_for(player_id)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16384:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("version") != VERSION or parsed.get("player_id") != player_id or not parsed.get("build") is Dictionary:
		return {}
	var result := {}
	for key in KEYS:
		var value: Variant = parsed.build.get(key)
		if value is String and value.length() <= 128:
			result[key] = value
	return result

static func save_for(player_id: String, build: Dictionary) -> bool:
	var path := path_for(player_id)
	if path.is_empty() or player_id.length() > 128:
		return false
	var clean := {}
	for key in KEYS:
		var value: Variant = build.get(key, "")
		if not value is String or value.length() > 128:
			return false
		clean[key] = value
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": VERSION, "player_id": player_id, "build": clean}))
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(path)) == OK
