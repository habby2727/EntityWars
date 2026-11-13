extends RefCounted
class_name ExperimentCatalog

static func get_all() -> Array:
	var file := FileAccess.open("res://data/static/experiments.json", FileAccess.READ)
	if file == null:
		return []
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data.get("experiments", []).duplicate(true) if data is Dictionary and data.get("experiments", []) is Array else []

static func get_by_id(experiment_id: String) -> Dictionary:
	for entry in get_all():
		if entry is Dictionary and str(entry.get("id", "")) == experiment_id:
			return entry
	return {}
