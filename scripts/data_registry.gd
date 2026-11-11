extends Node
class_name DataRegistry

var entities := {}
var homunculi := {}
var items := {}
var techniques := {}

func _init() -> void:
	# Initialize defaults immediately so this script works when instantiated
	# via `MyScript.new()` (not necessarily added to scene tree).
	_load_defaults()
	# Try to load JSON data; non-fatal if files missing.
	load_all()

func load_all() -> void:
	# Attempt to load JSON files from the data/ folder; fall back to defaults.
	var base = "res://data/"
	_load_json_file(base + "entities.json", "entities")
	_load_json_file(base + "homunculi.json", "homunculi")
	_load_json_file(base + "items.json", "items")
	_load_json_file(base + "techniques.json", "techniques")

func _load_json_file(path: String, key: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("DataRegistry: Missing data file: %s" % path)
		return
	var f = FileAccess.open(path, FileAccess.ModeFlags.READ as FileAccess.ModeFlags)
	if f == null:
		push_warning("DataRegistry: Cannot read data file: %s" % path)
		return
	var text = f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		push_warning("DataRegistry: Invalid JSON in %s at line %s: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return
	var data = parser.data
	if not data is Dictionary:
		push_warning("DataRegistry: Expected an object in %s" % path)
		return
	var fields = ["attack", "defense"] if key == "techniques" else [key]
	for field in fields:
		var records = data.get(field)
		if not records is Array:
			push_warning("DataRegistry: Missing or invalid %s array in %s" % [field, path])
			return
		var ids := {}
		for record in records:
			if not record is Dictionary or not record.get("id") is String or record.id == "" or ids.has(record.id):
				push_warning("DataRegistry: Invalid or duplicate ID in %s (%s)" % [path, field])
				return
			ids[record.id] = true
	match key:
		"entities":
			entities = {}
			for e in data.get("entities", []):
				if typeof(e) == TYPE_DICTIONARY and e.has("id"):
					var ent = e.duplicate(true)
					ent["name"] = _clean_name(str(ent.get("name", ent.get("id", ""))))
					entities[ent["id"]] = ent
		"homunculi":
			homunculi = {}
			for h in data.get("homunculi", []):
				if typeof(h) == TYPE_DICTIONARY and h.has("id"):
					var hom = h.duplicate(true)
					hom["name"] = _clean_name(str(hom.get("name", hom.get("id", ""))))
					homunculi[hom["id"]] = hom
		"items":
			items = {}
			for it in data.get("items", []):
				if typeof(it) == TYPE_DICTIONARY and it.has("id"):
					var item = it.duplicate(true)
					item["name"] = _clean_name(str(item.get("name", item.get("id", ""))))
					items[item["id"]] = item
		"techniques":
			techniques = {}
			# keep attack/defense arrays as lists under techniques
			techniques["attack"] = data.get("attack", [])
			techniques["defense"] = data.get("defense", [])

func _load_defaults():
	entities = {
		"sulfur": {"id": "sulfur", "name": "Sulfur", "type": "sulfur"},
		"mercury": {"id": "mercury", "name": "Mercury", "type": "mercury"},
		"sodium": {"id": "sodium", "name": "Sodium", "type": "sodium"},
		"aether": {"id": "aether", "name": "Aether", "type": "aether"},
		"vitriol": {"id": "vitriol", "name": "Vitriol", "type": "vitriol"},
		"gold": {"id": "gold", "name": "Gold", "type": "gold"}
	}
	homunculi = {
		"hom_fire": {"id": "hom_fire", "name": "Fireling"},
		"hom_earth": {"id": "hom_earth", "name": "Golem"},
		"hom_air": {"id": "hom_air", "name": "Sylph"},
		"hom_water": {"id": "hom_water", "name": "Undine"}
	}
	items = {}
	techniques = {"attack": [], "defense": []}

func get_data(key: String, default_value: Variant = null) -> Variant:
	match key:
		"entities":
			return entities
		"homunculi":
			return homunculi
		"items":
			return items
		"techniques":
			return techniques
		_:
			return default_value

func get_entities() -> Dictionary:
	return entities

func get_homunculi() -> Dictionary:
	return homunculi

func get_items() -> Dictionary:
	return items

func get_attack_techniques() -> Array:
	return techniques.get("attack", [])

func get_defense_techniques() -> Array:
	return techniques.get("defense", [])


func _clean_name(s: String) -> String:
	var out := s.strip_edges()
	out = out.replace("(TEMP)", "")
	out = out.replace("(Temp)", "")
	out = out.replace("TEMP", "")
	out = out.replace("temp", "")
	return out.strip_edges()
