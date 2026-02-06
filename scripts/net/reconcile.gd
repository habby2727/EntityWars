extends RefCounted
class_name Reconcile

const STATE_PATH := "user://player_state.json"

var _state: Dictionary = {}
var _queue: PendingQueue = null

func _init(queue: PendingQueue = null) -> void:
	_queue = queue
	load_cached_state()

func load_cached_state() -> Dictionary:
	_state = {}
	if not FileAccess.file_exists(STATE_PATH):
		return _state
	var f = FileAccess.open(STATE_PATH, FileAccess.READ)
	if f == null:
		push_error("Reconcile: Failed to open %s" % STATE_PATH)
		return _state
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	var data = _unwrap_parse(parsed)
	if typeof(data) == TYPE_DICTIONARY:
		_state = data
	return _state

func save_cached_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	var f = FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Reconcile: Failed to write %s" % STATE_PATH)
		return
	f.store_string(JSON.stringify(_state))
	f.close()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func apply_server_state(server_state: Dictionary, applied_action_id: String = "") -> void:
	if typeof(server_state) != TYPE_DICTIONARY:
		push_error("Reconcile: Server state is invalid.")
		return
	save_cached_state(server_state)
	if _queue != null and applied_action_id != "":
		_queue.remove_by_id(applied_action_id)
		_queue.save()

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
