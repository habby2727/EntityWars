extends RefCounted

static func _path(owner: String) -> String:
	return "user://expedition_pending_%s.json" % owner.sha256_text()

static func load_pending(owner: String) -> Dictionary:
	if owner.is_empty(): return {"error": "identity_required"}
	var path := _path(owner)
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16384: return {"error": "invalid_journal"}
	var entry: Variant = JSON.parse_string(file.get_as_text())
	if not entry is Dictionary or entry.get("owner") != owner or entry.get("kind") not in ["start", "select", "turn", "inspiration"] or not entry.get("payload") is Dictionary or str(entry.payload.get("client_action_id", "")).is_empty():
		return {"error": "invalid_journal"}
	if entry.kind in ["turn", "inspiration"]:
		var revision: Variant = entry.payload.get("expected_revision")
		if str(entry.payload.get("run_id", "")).is_empty() or not (revision is int or revision is float) or revision < 1 or floor(revision) != revision or not entry.payload.get("decision") is Dictionary:
			return {"error": "invalid_journal"}
	return entry

static func save_pending(owner: String, kind: String, payload: Dictionary) -> bool:
	if owner.is_empty() or kind not in ["start", "select", "turn", "inspiration"] or not load_pending(owner).is_empty(): return false
	var path := _path(owner)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"owner": owner, "kind": kind, "payload": payload}))
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

static func clear(owner: String) -> bool:
	if owner.is_empty(): return false
	var path := _path(owner)
	return not FileAccess.file_exists(path) or DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
