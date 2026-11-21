extends RefCounted

# Remove only obsolete Expedition journals; Hunt and Dungeon journals are separate.
static func clear_legacy() -> void:
	var directory := DirAccess.open("user://")
	if directory == null: return
	for filename in directory.get_files():
		if filename.begins_with("expedition_pending_") and (filename.ends_with(".json") or filename.ends_with(".json.tmp")):
			directory.remove(filename)
