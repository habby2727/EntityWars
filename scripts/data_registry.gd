extends Node
class_name DataRegistry

var entities := {}
var homunculi := {}
var items := {}
var techniques := {}
var spells := {}

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
	_load_spells(base + "spells.json")

func _load_spells(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("DataRegistry: Cannot read spells: %s" % path)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_warning("DataRegistry: Invalid spells JSON: %s" % path)
		return
	var records: Variant = parser.data.get("spells")
	if not records is Array or records.size() != 64:
		push_warning("DataRegistry: Expected 64 spells")
		return
	var counts := {"sulfur": 0, "mercury": 0, "sodium": 0, "aether": 0, "vitriol": 0, "gold": 0}
	var loaded := {}
	var universals := 0
	var pairs := {}
	for spell in records:
		if not spell is Dictionary:
			push_warning("DataRegistry: Invalid spell")
			return
		var id: Variant = spell.get("id")
		var spell_type: Variant = spell.get("type")
		var power: Variant = spell.get("power_mult")
		var accuracy: Variant = spell.get("accuracy")
		var cooldown: Variant = spell.get("cooldown_turns")
		if not id is String or id.is_empty() or loaded.has(id) or not spell_type is String or (not counts.has(spell_type) and spell_type not in ["universal", "hybrid"]) or not spell.get("name") is String or spell.name.is_empty() or not spell.get("desc") is String or spell.desc.is_empty():
			push_warning("DataRegistry: Invalid spell identity")
			return
		if spell.get("category") not in ["attack", "support"] or not (power is int or power is float) or power < 0 or not (accuracy is int or accuracy is float) or accuracy < 0 or accuracy > 1 or not (cooldown is int or cooldown is float) or cooldown < 0 or cooldown != floor(cooldown) or not spell.get("effects") is Array:
			push_warning("DataRegistry: Invalid spell statistics: %s" % id)
			return
		for effect in spell.effects:
			if not effect is Dictionary or effect.get("kind") not in ["vuln", "atk_boost", "atk_down", "shield", "hom_stun", "heal", "reflect", "type_neutralize", "poison", "bonus_if_poisoned", "bonus_if_hit_last_exchange", "cleanse_one", "pierce_ward", "focus_next", "life_leech", "misalign_next", "tempo_shift", "bonus_if_low_hp", "recoil", "hybrid_mark", "bonus_if_marked", "bonus_power_if_poisoned", "bonus_if_shielded", "consume_poison", "bonus_power_if_hit_last_exchange", "shield_by_order", "ward_dispel", "poison_on_reflect"] or effect.get("target") not in ["self", "enemy"] or not (effect.get("value") is int or effect.get("value") is float) or (effect.value < 0 and effect.kind != "tempo_shift"):
				push_warning("DataRegistry: Invalid spell effect: %s" % id)
				return
		if counts.has(spell_type):
			counts[spell_type] += 1
		else:
			var eligible: Variant = spell.get("eligible_types")
			var level: Variant = spell.get("tower_level_required")
			if not eligible is Array or not (level is int or level is float) or level < 1 or level > 10 or level != floor(level) or not spell.get("research_cost") is Dictionary or int(spell.get("research_time_sec", 0)) <= 0:
				push_warning("DataRegistry: Invalid spell research data: %s" % id)
				return
			var unique := {}
			for eligible_type in eligible:
				if not eligible_type is String or not counts.has(eligible_type) or unique.has(eligible_type):
					push_warning("DataRegistry: Invalid spell eligibility: %s" % id)
					return
				unique[eligible_type] = true
			if spell_type == "universal":
				if unique.size() != 6:
					return
				universals += 1
			else:
				var primary: String = str(spell.get("primary_type", ""))
				var secondary: String = str(spell.get("secondary_type", ""))
				if unique.size() != 2 or primary == secondary or not unique.has(primary) or not unique.has(secondary):
					return
				var pair := [primary, secondary]
				pair.sort()
				var pair_key := ":".join(pair)
				pairs[pair_key] = int(pairs.get(pair_key, 0)) + 1
		loaded[id] = spell.duplicate(true)
	for spell_type in counts:
		if counts[spell_type] != 4:
			push_warning("DataRegistry: Expected four spells for %s" % spell_type)
			return
	if universals != 10 or pairs.size() != 15:
		push_warning("DataRegistry: Invalid universal or hybrid spell count")
		return
	for pair in pairs:
		if pairs[pair] != 2:
			push_warning("DataRegistry: Expected two spells per hybrid pair")
			return
	spells = loaded

func get_spells_for_type(spell_type: String) -> Array:
	var result := []
	for spell in spells.values():
		if spell.type == spell_type:
			result.append(spell.duplicate(true))
	return result

func get_researchable_spells_for_type(spell_type: String) -> Array:
	var result := []
	for spell in spells.values():
		if spell.type == spell_type or spell_type in spell.get("eligible_types", []):
			result.append(spell.duplicate(true))
	return result

func get_spell_by_id(id: String) -> Dictionary:
	return spells.get(id, {}).duplicate(true)

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
