extends Node
class_name StaticDB

const STATIC_DIR := "res://data/static/"

const REQUIRED_RESOURCE_IDS := [
	"essence",
	"core",
	"arcane_shard",
	"living_catalyst",
	"chaos_cell",
	"time_crystal",
	"primordial_sigil"
]
const REQUIRED_BUILDING_IDS := [
	"lab_th",
	"essence_reactor",
	"storage_vault",
	"build_forge",
	"homunculus_vat",
	"ultrahit_tower",
	"experiment_chamber",
	"arcane_archives",
	"sync_nexus",
	"anomaly_containment",
	"trade_hall",
	"world_gate"
]
const REQUIRED_RESEARCH_IDS := [
	"archive_basics",
	"trade_jobs",
	"world_zones",
	"sync_theory",
	"anomaly_theory",
	"experiment_cooldown",
	"storage_protocols",
	"reactor_notes",
	"arcane_catalog",
	"gateway_studies"
]
const REQUIRED_HQ_PATHS := ["Scientific", "Chaotic", "Industrial"]
const REQUIRED_BALANCE_KEYS := {
	"tick_seconds": "number",
	"offline_cap_hours": "number",
	"reactor_base_rate": "number",
	"reactor_rate_per_level": "number",
	"reactor_route_output_mult": "dict",
	"storage_route_output_mult": "dict",
	"route_multipliers": "dict",
	"hq_output_mult": "dict",
	"storage_base_capacity": "number",
	"storage_capacity_per_level": "number",
	"storage_route_capacity_mult": "dict",
	"hq_capacity_mult": "dict",
	"hq_cost_mult": "dict",
	"volatile_loss_chance": "number",
	"volatile_loss_pct": "number",
	"compact_loss_mult": "number",
	"sealed_rare_mult": "number",
	"mutagenic_rare_base_chance": "number",
	"mutagenic_rare_cap": "number",
	"hq_rare_mult": "dict",
	"hq_risk_mult": "dict",
	"overclock_output_mult": "number",
	"overclock_loss_mult": "number",
	"mutagen_rare_mult": "number",
	"mutagen_failure_mult": "number",
	"world_gate_cooldown_seconds": "number",
	"trade_hall_fee_pct": "number",
	"market_fee_bps": "number"
}
const DEFAULT_BALANCE := {
	"tick_seconds": 1,
	"offline_cap_hours": 12,
	"reactor_base_rate": 1.0,
	"reactor_rate_per_level": 0.2,
	"reactor_route_output_mult": {
		"stable": 0.8,
		"volatile": 1.35,
		"mutagenic": 0.65
	},
	"storage_route_output_mult": {
		"reactive": 1.05
	},
	"route_multipliers": {
		"Scientific": 1.0,
		"Chaotic": 1.1,
		"Industrial": 1.05
	},
	"hq_output_mult": {
		"scientific": 1.05,
		"chaotic": 1.0,
		"industrial": 0.95
	},
	"storage_base_capacity": 1000,
	"storage_capacity_per_level": 250,
	"storage_route_capacity_mult": {
		"compact": 1.0,
		"reactive": 1.1,
		"sealed": 0.9
	},
	"hq_capacity_mult": {
		"scientific": 1.05,
		"chaotic": 1.0,
		"industrial": 1.1
	},
	"hq_cost_mult": {
		"scientific": 0.95,
		"chaotic": 1.05,
		"industrial": 1.0
	},
	"volatile_loss_chance": 0.25,
	"volatile_loss_pct": 0.3,
	"compact_loss_mult": 0.5,
	"sealed_rare_mult": 1.25,
	"mutagenic_rare_base_chance": 0.08,
	"mutagenic_rare_cap": 0.25,
	"hq_rare_mult": {
		"scientific": 0.9,
		"chaotic": 1.1,
		"industrial": 0.85
	},
	"hq_risk_mult": {
		"scientific": 0.9,
		"chaotic": 1.1,
		"industrial": 0.85
	},
	"overclock_output_mult": 1.25,
	"overclock_loss_mult": 1.25,
	"mutagen_rare_mult": 1.5,
	"mutagen_failure_mult": 1.2,
	"world_gate_cooldown_seconds": 3600,
	"trade_hall_fee_pct": 0.05,
	"market_fee_bps": 200
}

var resources: Dictionary = {}
var buildings: Dictionary = {}
var mutations: Dictionary = {}
var zones: Dictionary = {}
var bosses: Dictionary = {}
var balance: Dictionary = {}
var research: Dictionary = {}

func _init() -> void:
	load_all()

func load_all() -> void:
	resources = _load_resources()
	buildings = _load_buildings()
	mutations = _load_mutations()
	zones = _load_zones()
	bosses = _load_bosses()
	balance = _load_balance()
	research = _load_research()

func get_resource(id: String) -> Dictionary:
	return resources.get(id, {})

func get_building(id: String) -> Dictionary:
	return buildings.get(id, {})

func get_balance(key: String, default_value: Variant = null) -> Variant:
	return balance.get(key, default_value)

func list_buildings() -> Array:
	var ids: Array = buildings.keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		out.append(buildings[id])
	return out

func validate_all() -> bool:
	var ok := true
	load_all()
	for req_id in REQUIRED_RESOURCE_IDS:
		if not resources.has(req_id):
			push_error("StaticDB.validate_all: Missing resource id '%s'." % req_id)
			ok = false
	for req_id in REQUIRED_BUILDING_IDS:
		if not buildings.has(req_id):
			push_error("StaticDB.validate_all: Missing building id '%s'." % req_id)
			ok = false
	for req_id in REQUIRED_RESEARCH_IDS:
		if not research.has(req_id):
			push_error("StaticDB.validate_all: Missing research id '%s'." % req_id)
			ok = false
	for key in REQUIRED_BALANCE_KEYS.keys():
		if not balance.has(key):
			push_error("StaticDB.validate_all: Missing balance key '%s'." % key)
			ok = false
	return ok

func get_research(id: String) -> Dictionary:
	return research.get(id, {})

func list_research() -> Array:
	var ids: Array = research.keys()
	ids.sort()
	var out: Array = []
	for id in ids:
		out.append(research[id])
	return out

func _load_resources() -> Dictionary:
	var data = _load_json(STATIC_DIR + "resources.json", "resources")
	if typeof(data) != TYPE_DICTIONARY:
		push_error("StaticDB: resources.json root must be a Dictionary.")
		return {}
	if not data.has("resources"):
		push_error("StaticDB: resources.json missing 'resources' array.")
		return {}
	var out = _validate_list("resources", data.get("resources"), ["id", "name"], REQUIRED_RESOURCE_IDS, {
		"id": TYPE_STRING,
		"name": TYPE_STRING
	})
	for id in out.keys():
		var entry: Dictionary = out[id]
		if typeof(entry.get("display_name")) != TYPE_STRING:
			entry["display_name"] = str(entry.get("name", id))
			push_warning("StaticDB: resource '%s' missing display_name; using name." % id)
	return out

func _load_buildings() -> Dictionary:
	var data = _load_json(STATIC_DIR + "buildings.json", "buildings")
	if typeof(data) != TYPE_DICTIONARY:
		push_error("StaticDB: buildings.json root must be a Dictionary.")
		return {}
	var hq_paths = data.get("hq_paths", null)
	if typeof(hq_paths) != TYPE_ARRAY:
		push_error("StaticDB: buildings.json missing 'hq_paths' array.")
	else:
		for path in hq_paths:
			if typeof(path) != TYPE_STRING:
				push_error("StaticDB: buildings.json hq_paths must be strings.")
				break
		for req in REQUIRED_HQ_PATHS:
			if not hq_paths.has(req):
				push_error("StaticDB: buildings.json missing HQ path '%s'." % req)
	if not data.has("buildings"):
		push_error("StaticDB: buildings.json missing 'buildings' array.")
		return {}
	var out = _validate_list("buildings", data.get("buildings"), ["id", "name", "routes"], REQUIRED_BUILDING_IDS, {
		"id": TYPE_STRING,
		"name": TYPE_STRING,
		"routes": TYPE_ARRAY
	})
	for id in out.keys():
		var entry: Dictionary = out[id]
		if typeof(entry.get("routes")) != TYPE_ARRAY:
			push_error("StaticDB: building '%s' routes must be an array." % id)
			entry["routes"] = []
		if typeof(entry.get("unlock_hq")) != TYPE_INT:
			entry["unlock_hq"] = int(entry.get("unlock_hq", 1))
		if typeof(entry.get("display_name")) != TYPE_STRING:
			entry["display_name"] = str(entry.get("name", id))
			push_warning("StaticDB: building '%s' missing display_name; using name." % id)
	return out

func _load_mutations() -> Dictionary:
	var data = _load_json(STATIC_DIR + "mutations.json", "mutations")
	if typeof(data) != TYPE_DICTIONARY:
		push_error("StaticDB: mutations.json root must be a Dictionary.")
		return {}
	if not data.has("mutations"):
		push_error("StaticDB: mutations.json missing 'mutations' array.")
		return {}
	return _validate_list("mutations", data.get("mutations"), ["id", "name"], [], {
		"id": TYPE_STRING,
		"name": TYPE_STRING
	})

func _load_zones() -> Dictionary:
	var data = _load_json(STATIC_DIR + "zones.json", "zones")
	if typeof(data) != TYPE_DICTIONARY:
		push_error("StaticDB: zones.json root must be a Dictionary.")
		return {}
	if not data.has("zones"):
		push_error("StaticDB: zones.json missing 'zones' array.")
		return {}
	return _validate_list("zones", data.get("zones"), ["id", "name"], [], {
		"id": TYPE_STRING,
		"name": TYPE_STRING
	})

func _load_bosses() -> Dictionary:
	var data = _load_json(STATIC_DIR + "bosses.json", "bosses")
	if typeof(data) != TYPE_DICTIONARY:
		push_error("StaticDB: bosses.json root must be a Dictionary.")
		return {}
	if not data.has("bosses"):
		push_error("StaticDB: bosses.json missing 'bosses' array.")
		return {}
	return _validate_list("bosses", data.get("bosses"), ["id", "name"], [], {
		"id": TYPE_STRING,
		"name": TYPE_STRING
	})

func _load_balance() -> Dictionary:
	var data = _load_json(STATIC_DIR + "balance.json", "balance")
	if typeof(data) != TYPE_DICTIONARY:
		push_error("StaticDB: balance.json root must be a Dictionary.")
		return DEFAULT_BALANCE.duplicate(true)
	var section = data.get("balance", data)
	if typeof(section) != TYPE_DICTIONARY:
		push_error("StaticDB: balance.json 'balance' must be a Dictionary.")
		return DEFAULT_BALANCE.duplicate(true)
	var out: Dictionary = DEFAULT_BALANCE.duplicate(true)
	for key in section.keys():
		out[key] = section[key]
	for req_key in REQUIRED_BALANCE_KEYS.keys():
		if not out.has(req_key):
			push_error("StaticDB: balance.json missing key '%s'." % req_key)
			out[req_key] = DEFAULT_BALANCE.get(req_key)
		else:
			if not _value_matches(out[req_key], REQUIRED_BALANCE_KEYS[req_key]):
				push_error("StaticDB: balance.json key '%s' has invalid type." % req_key)
				out[req_key] = DEFAULT_BALANCE.get(req_key)
	if typeof(out.get("route_multipliers")) == TYPE_DICTIONARY:
		for path in REQUIRED_HQ_PATHS:
			if not out["route_multipliers"].has(path):
				push_error("StaticDB: balance.json route_multipliers missing '%s'." % path)
				out["route_multipliers"][path] = DEFAULT_BALANCE["route_multipliers"].get(path, 1.0)
			elif not _is_number(out["route_multipliers"][path]):
				push_error("StaticDB: balance.json route_multipliers '%s' must be numeric." % path)
				out["route_multipliers"][path] = DEFAULT_BALANCE["route_multipliers"].get(path, 1.0)
	return out

func _load_research() -> Dictionary:
	var data = _load_json(STATIC_DIR + "research.json", "research")
	if typeof(data) != TYPE_DICTIONARY:
		push_error("StaticDB: research.json root must be a Dictionary.")
		return {}
	if not data.has("research"):
		push_error("StaticDB: research.json missing 'research' array.")
		return {}
	var list = data.get("research")
	if typeof(list) != TYPE_ARRAY:
		push_error("StaticDB: research.json 'research' must be an array.")
		return {}
	var out: Dictionary = {}
	for entry in list:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("StaticDB: research entry is not a Dictionary.")
			continue
		var missing: Array = []
		for key in ["id", "name", "flag_id", "cost", "time_sec", "requires"]:
			if not entry.has(key):
				missing.append(key)
		if missing.size() > 0:
			push_error("StaticDB: research entry missing keys: %s" % ", ".join(missing))
			continue
		if typeof(entry.id) != TYPE_STRING:
			push_error("StaticDB: research id must be string.")
			continue
		if typeof(entry.name) != TYPE_STRING:
			push_error("StaticDB: research name must be string.")
			continue
		if typeof(entry.flag_id) != TYPE_STRING:
			push_error("StaticDB: research flag_id must be string.")
			continue
		if typeof(entry.cost) != TYPE_DICTIONARY:
			push_error("StaticDB: research cost must be Dictionary.")
			continue
		if not _is_number(entry.time_sec):
			push_error("StaticDB: research time_sec must be numeric.")
			continue
		if typeof(entry.requires) != TYPE_ARRAY:
			push_error("StaticDB: research requires must be Array.")
			continue
		var id = str(entry.id)
		if out.has(id):
			push_error("StaticDB: Duplicate research id '%s'." % id)
			continue
		out[id] = entry
	for req_id in REQUIRED_RESEARCH_IDS:
		if not out.has(req_id):
			push_error("StaticDB: Missing required research id '%s'." % req_id)
	return out

func _load_json(path: String, label: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("StaticDB: Missing %s JSON at %s" % [label, path])
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("StaticDB: Failed to open %s JSON at %s" % [label, path])
		return null
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	var parse_error_code: int = OK
	var parsed_result = null
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("error"):
			parse_error_code = int(parsed.get("error", ERR_PARSE_ERROR))
		else:
			parse_error_code = OK
		parsed_result = parsed.get("result", parsed)
	elif parsed == null:
		parse_error_code = ERR_PARSE_ERROR
	else:
		parse_error_code = int(parsed.error)
		parsed_result = parsed.result
	if parse_error_code != OK:
		push_error("StaticDB: Invalid JSON in %s" % path)
		return null
	return parsed_result

func _validate_list(
	section: String,
	list_value: Variant,
	required_keys: Array,
	required_ids: Array = [],
	key_types: Dictionary = {}
) -> Dictionary:
	var out: Dictionary = {}
	if typeof(list_value) != TYPE_ARRAY:
		push_error("StaticDB: %s must be an array." % section)
		return out
	for entry in list_value:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("StaticDB: %s entry is not a Dictionary." % section)
			continue
		var missing: Array = []
		for key in required_keys:
			if not entry.has(key):
				missing.append(key)
		if missing.size() > 0:
			push_error("StaticDB: %s entry missing keys: %s" % [section, ", ".join(missing)])
			continue
		var type_ok := true
		for key in key_types.keys():
			if not entry.has(key):
				continue
			var expected = int(key_types[key])
			if typeof(entry[key]) != expected:
				push_error("StaticDB: %s entry key '%s' has invalid type." % [section, key])
				type_ok = false
		if not type_ok:
			continue
		var id = str(entry.get("id", ""))
		if id == "":
			push_error("StaticDB: %s entry has empty id." % section)
			continue
		if out.has(id):
			push_error("StaticDB: Duplicate %s id '%s'." % [section, id])
			continue
		out[id] = entry
	for req_id in required_ids:
		if not out.has(req_id):
			push_error("StaticDB: Missing required %s id '%s'." % [section, req_id])
	return out

func _value_matches(value: Variant, expected: String) -> bool:
	if expected == "number":
		return _is_number(value)
	if expected == "dict":
		return typeof(value) == TYPE_DICTIONARY
	return true

func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
