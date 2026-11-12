extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("LOADOUT_TEST_DIR").replace("\\", "/")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/"):
		quit(1)
		return
	var scene = load("res://scenes/LoadoutGrid.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if scene._has_duplicate_build_items():
		push_error("Default weapons are duplicated")
		quit(1)
		return
	for button in [scene.dd_item1, scene.dd_item2]:
		for i in scene._items.size() * 2:
			scene._on_equip_button_pressed(button)
			if scene._has_duplicate_build_items():
				push_error("Weapon selector allowed a duplicate")
				quit(1)
				return
	var file := FileAccess.open("user://seal_attack.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"equip_1": "bismuth_talisman", "equip_2": "bismuth_talisman"}))
	file.close()
	scene._load_seal("attack")
	if scene._has_duplicate_build_items() or scene._idx_to_id(scene._items, scene.dd_item1) != "bismuth_talisman":
		push_error("Duplicate legacy seal was not repaired")
		quit(1)
		return
	print("PASS distinct default weapons, cycling and legacy seal")
	scene.queue_free()
	await process_frame
	quit(0)
