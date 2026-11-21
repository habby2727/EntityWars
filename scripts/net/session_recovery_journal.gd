extends RefCounted
class_name SessionRecoveryJournal

const VERSION := 1
const PREFIX := "user://session_recovery_"
const CONTEXT_KEYS := ["hunt_id", "rotation_key", "display_texture_id", "visual_zone_id"]
const PAYLOAD_KEYS := ["session_id", "run_id", "client_action_id", "expected_revision", "entity_id", "weapon_ids", "homunculus_id", "spell_ids", "mode", "decision"]
const DECISION_KEYS := ["kind", "spell_id", "target", "turn", "switch_slot", "hom_action", "blessing_id"]

var _owner := ""
var _path := ""

func set_identity(player_id: String) -> bool:
	if player_id.is_empty() or player_id.length() > 128:
		return false
	_owner = player_id
	_path = PREFIX + player_id.sha256_text() + ".json"
	return true

# An empty result means no journal; an error result must keep recovery locked.
func load_entry() -> Dictionary:
	if _path.is_empty():
		return {"error": "identity_required"}
	if not FileAccess.file_exists(_path):
		var directory := DirAccess.open("user://")
		if directory == null:
			return {"error": "journal_unreadable"}
		for filename in directory.get_files():
			if filename.begins_with("session_recovery_") and filename.ends_with(".json"):
				return {"error": "journal_owner_mismatch"}
		return {}
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return {"error": "journal_unreadable"}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK:
		return {"error": "invalid_journal"}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not _valid(parsed):
		return {"error": "invalid_journal"}
	return parsed

func save_entry(entry: Dictionary) -> bool:
	if entry.get("mode") != "hunt" or _path.is_empty() or not _valid(entry):
		return false
	var temp := _path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(entry))
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(_path)) == OK

func remove() -> bool:
	if _path.is_empty():
		return false
	return not FileAccess.file_exists(_path) or DirAccess.remove_absolute(ProjectSettings.globalize_path(_path)) == OK

func _valid(entry: Dictionary) -> bool:
	if not _only_keys(entry, ["version", "mode", "player_id", "session_id", "context", "pending_kind", "payload"]):
		return false
	if entry.size() != 7 or entry.get("version") != VERSION or entry.get("player_id") != _owner or entry.get("mode") not in ["hunt", "dungeon"]:
		return false
	if not _short_string(entry.get("session_id")) or not entry.get("context") is Dictionary or not entry.get("payload") is Dictionary:
		return false
	if not _only_keys(entry.context, CONTEXT_KEYS) or not _only_keys(entry.payload, PAYLOAD_KEYS):
		return false
	for value in entry.context.values():
		if not _scalar(value):
			return false
	var kind: Variant = entry.get("pending_kind")
	if kind not in ["", "loadout", "turn", "inspiration", "blessing", "next", "forfeit"]:
		return false
	if kind == "":
		return entry.payload.is_empty()
	if (entry.mode == "hunt" and kind in ["blessing", "next"]) or (entry.mode == "dungeon" and kind == "forfeit"):
		return false
	if not _short_string(entry.payload.get("client_action_id")):
		return false
	var id_key := "session_id" if entry.mode == "hunt" else "run_id"
	if entry.payload.get(id_key) != entry.session_id:
		return false
	if kind == "loadout":
		for key in ["entity_id", "weapon_ids", "homunculus_id", "spell_ids", "mode"]:
			if not entry.payload.has(key): return false
	elif kind != "forfeit":
		var revision: Variant = entry.payload.get("expected_revision")
		if not (revision is int or revision is float) or revision < 1 or floor(revision) != revision:
			return false
		if kind != "next" and not entry.payload.get("decision") is Dictionary:
			return false
	for key in entry.payload:
		var value: Variant = entry.payload[key]
		if key == "decision":
			if not value is Dictionary or not _only_keys(value, DECISION_KEYS):
				return false
			for decision_value in value.values():
				if not _scalar(decision_value):
					return false
		elif value is Array:
			if key not in ["weapon_ids", "spell_ids"] or value.size() > 4:
				return false
			for item in value:
				if not _scalar(item):
					return false
		elif not _scalar(value):
			return false
	return true

func _only_keys(data: Dictionary, allowed: Array) -> bool:
	for key in data:
		if key not in allowed:
			return false
	return true

func _short_string(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128

func _scalar(value: Variant) -> bool:
	return value == null or value is bool or value is int or value is float or (value is String and value.length() <= 128)
