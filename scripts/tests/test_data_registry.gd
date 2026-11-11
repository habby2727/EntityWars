extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _ids(records: Array) -> Array:
	var ids := []
	for record in records:
		ids.append(str(record.get("id", "")))
	ids.sort()
	return ids

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", label)
	else:
		print("PASS: ", label)

func _run() -> void:
	var registry = load("res://scripts/data_registry.gd").new()
	var specs = [
		["entities", "get_entities", 6],
		["homunculi", "get_homunculi", 8],
		["items", "get_items", 8],
		["attack", "get_attack_techniques", 3],
		["defense", "get_defense_techniques", 3]
	]
	var expected := {}
	for spec in specs:
		var filename = "techniques" if spec[0] in ["attack", "defense"] else spec[0]
		var source = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % filename))
		var records = registry.call(spec[1])
		var actual: Array = records.values() if records is Dictionary else records
		expected[spec[0]] = _ids(source[spec[0]])
		_check(actual.size() == spec[2] and _ids(actual) == expected[spec[0]], str(spec[0]))

	for script_path in ["res://scripts/loadout_grid.gd", "res://scripts/combat.gd"]:
		var script = load(script_path)
		if script == null or not script.can_instantiate():
			_check(false, script_path + " loads")
			continue
		var consumer = script.new()
		consumer._load_registry_safe()
		for key in ["entities", "homunculi", "items"]:
			_check(_ids(consumer.get("_" + key)) == expected[key], script_path + " " + key)
		if script_path.ends_with("loadout_grid.gd"):
			_check(_ids(consumer._atk_techs) == expected.attack, "loadout attack techniques")
			_check(_ids(consumer._def_techs) == expected.defense, "loadout defense techniques")
		if consumer._reg != null:
			consumer._reg.free()
		consumer.free()

	var original = registry.get_entities().duplicate(true)
	var path = "user://registry_test_%s.json" % OS.get_process_id()
	registry._load_json_file(path, "entities")
	_check(registry.get_entities() == original, "missing file preserves data")
	for invalid in ["{", "[]", '{"entities": {}}', '{"entities": [{"id": ""}]}']:
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(invalid)
		file.close()
		registry._load_json_file(path, "entities")
		_check(registry.get_entities() == original, "invalid data preserves entities: " + invalid)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	registry.free()
	print("DataRegistry checks: %s failure(s)" % failures)
	quit(0 if failures == 0 else 1)
