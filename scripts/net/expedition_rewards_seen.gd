extends RefCounted

const LIMIT := 128

static func _path(owner: String) -> String:
	return "user://expedition_rewards_seen_%s.json" % owner.sha256_text()

static func _read(owner: String) -> Variant:
	if owner.is_empty(): return null
	var path := _path(owner)
	if not FileAccess.file_exists(path): return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32768: return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or data.get("owner") != owner or not data.get("ids") is Array or data.ids.size() > LIMIT: return null
	for id in data.ids:
		if not id is String or id.is_empty() or id.length() > 256: return null
	return data.ids

static func has_seen(owner: String, reward_id: String) -> bool:
	var ids: Variant = _read(owner)
	return ids is Array and reward_id in ids

static func mark_seen(owner: String, reward_id: String) -> bool:
	if reward_id.is_empty() or reward_id.length() > 256: return false
	var ids: Variant = _read(owner)
	if not ids is Array: return false
	if reward_id in ids: return true
	ids.append(reward_id)
	while ids.size() > LIMIT: ids.pop_front()
	var path := _path(owner)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"owner":owner, "ids":ids}))
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK
