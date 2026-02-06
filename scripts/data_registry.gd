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
	var f = FileAccess.open(path, FileAccess.ModeFlags.READ as FileAccess.ModeFlags)
	if f == null:
		return
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	# JSON.parse_string may return a JSONParseResult object or a Dictionary
	# depending on environment; handle both safely.
	var parse_error_code: int = OK
	var parsed_result = null
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("error"):
			parse_error_code = int(parsed.get("error", ERR_PARSE_ERROR))
		else:
			parse_error_code = OK
		parsed_result = parsed.get("result", parsed)
	else:
		# Assume JSONParseResult-like with .error and .result
		parse_error_code = int(parsed.error)
		parsed_result = parsed.result
	if parse_error_code != OK:
		return
	var data = parsed_result
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
