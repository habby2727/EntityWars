extends RefCounted
class_name PendingQueue

const FILE_PATH := "user://pending_actions.json"

var _actions: Array = []

func load() -> void:
	_actions.clear()
	if not FileAccess.file_exists(FILE_PATH):
		return
	var f = FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		push_error("PendingQueue: Failed to open %s" % FILE_PATH)
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	var data = _unwrap_parse(parsed)
	if typeof(data) == TYPE_DICTIONARY and data.has("actions"):
		data = data.get("actions")
	if typeof(data) != TYPE_ARRAY:
		return
	for entry in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("client_action_id"):
			continue
		_actions.append(entry)

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

func save() -> void:
	var f = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("PendingQueue: Failed to write %s" % FILE_PATH)
		return
	var payload = {"actions": _actions}
	f.store_string(JSON.stringify(payload))
	f.close()

func size() -> int:
	return _actions.size()

func to_array() -> Array:
	return _actions.duplicate(true)

func enqueue(action: Dictionary) -> void:
	var id = str(action.get("client_action_id", ""))
	if id == "":
		return
	for existing in _actions:
		if typeof(existing) == TYPE_DICTIONARY and str(existing.get("client_action_id", "")) == id:
			return
	_actions.append(action)

func peek() -> Dictionary:
	if _actions.is_empty():
		return {}
	return _actions[0]

func pop_next() -> Dictionary:
	if _actions.is_empty():
		return {}
	var item = _actions[0]
	_actions.remove_at(0)
	return item

func remove_by_id(action_id: String) -> void:
	if action_id == "":
		return
	var filtered: Array = []
	for entry in _actions:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("client_action_id", "")) == action_id:
			continue
		filtered.append(entry)
	_actions = filtered

func contains_id(action_id: String) -> bool:
	if action_id == "":
		return false
	for entry in _actions:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("client_action_id", "")) == action_id:
			return true
	return false
