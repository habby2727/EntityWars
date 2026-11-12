extends RefCounted
class_name Reconcile

const STATE_PATH := "user://player_state.json"

var _state: Dictionary = {}
var _queue: PendingQueue = null
var _file_path := ""
var _identity := ""

func set_identity(player_id: String) -> bool:
	if player_id.is_empty() or player_id.length() > 128:
		return false
	_identity = player_id
	_file_path = "user://player_state_%s.json" % player_id.sha256_text()
	if _queue != null:
		_queue.set_identity(player_id)
	load_cached_state()
	return true

func clear_identity() -> void:
	_identity = ""
	_file_path = ""
	_state.clear()

func _init(queue: PendingQueue = null) -> void:
	_queue = queue

func load_cached_state() -> Dictionary:
	_state = {}
	if _file_path.is_empty():
		return _state
	if not FileAccess.file_exists(_file_path):
		return _state
	var f = FileAccess.open(_file_path, FileAccess.READ)
	if f == null:
		push_error("Reconcile: Failed to open %s" % _file_path)
		return _state
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	var data = _unwrap_parse(parsed)
	if typeof(data) == TYPE_DICTIONARY and (_identity.is_empty() or str(data.get("player_id", "")) == _identity):
		_state = data
	return _state

func save_cached_state(state: Dictionary) -> void:
	if _file_path.is_empty():
		return
	if not _identity.is_empty() and str(state.get("player_id", "")) != _identity:
		push_error("Reconcile: Refusing to save state for another identity.")
		return
	_state = state.duplicate(true)
	var f = FileAccess.open(_file_path, FileAccess.WRITE)
	if f == null:
		push_error("Reconcile: Failed to write %s" % _file_path)
		return
	f.store_string(JSON.stringify(_state))
	f.close()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func apply_server_state(server_state: Dictionary, applied_action_id: String = "") -> bool:
	if typeof(server_state) != TYPE_DICTIONARY:
		push_error("Reconcile: Server state is invalid.")
		return false
	var current_id := str(_state.get("player_id", ""))
	var incoming_id := str(server_state.get("player_id", ""))
	if incoming_id.is_empty():
		return false
	if not _identity.is_empty() and incoming_id != _identity:
		return false
	if _queue != null and applied_action_id != "":
		_queue.remove_by_id(applied_action_id)
		_queue.save()
	if current_id == incoming_id and _state.has("state_revision"):
		if not server_state.has("state_revision") or int(server_state.state_revision) < int(_state.state_revision):
			return false
		if int(server_state.state_revision) == int(_state.state_revision):
			return true
	save_cached_state(server_state)
	return true

func _unwrap_parse(parsed: Variant) -> Variant:
	if parsed == null:
		return null
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("error") and int(parsed.get("error", ERR_PARSE_ERROR)) != OK:
			return null
		return parsed.get("result", parsed)
	if typeof(parsed) == TYPE_OBJECT:
		if int(parsed.error) != OK:
			return null
		return parsed.result
	return parsed
