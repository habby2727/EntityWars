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
	var defense_notice: Label = scene.btn_seal_defense.get_node("ComingSoon")
	var attack_item = scene._idx_to_id(scene._items, scene.dd_item1)
	scene.btn_seal_defense.pressed.emit()
	if scene._mode != "attack" or not scene.btn_seal_attack.button_pressed or scene.btn_seal_defense.button_pressed or not defense_notice.visible or defense_notice.text != "Coming soon" or scene._idx_to_id(scene._items, scene.dd_item1) != attack_item:
		push_error("Defense seal should show Coming soon while keeping attack active")
		quit(1)
		return
	scene.btn_seal_attack.pressed.emit()
	if defense_notice.visible or scene._mode != "attack":
		push_error("Attack seal did not remain active")
		quit(1)
		return
	var sword: Dictionary = scene._reg.get_items().get("bismuth_talisman", {})
	var helper = preload("res://scripts/domain/item_progress.gd")
	var effects: Dictionary = helper.effective_item(sword, {"bismuth_talisman": {"level": 5}}).get("effects", {})
	var readable: String = scene._build_effects_text(effects)
	if not readable.contains("Power: 6") or not readable.contains("True damage on hit: 1") or readable.contains("[") or readable.contains("_"):
		push_error("Build effect description is not readable or level-correct: " + readable)
		quit(1)
		return
	var percentage: String = scene._build_effects_text({"ward_pct": [0.075], "ignore_reflect_chance": [0.1]})
	if not percentage.contains("7.5%") or not percentage.contains("10%"):
		push_error("Percent effects are not displayed correctly: " + percentage)
		quit(1)
		return
	for button in [scene.dd_item1, scene.dd_item2]:
		scene._on_build_hover_entered(button)
		if not scene.tooltip_panel.visible or scene.tooltip_label.text.contains("[") or scene.tooltip_label.text.contains("{"):
			push_error("Weapon tooltip contains raw effect data")
			quit(1)
			return
		scene._on_build_hover_exited()
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
	scene._update_save_button_label()
	var reset_mark: Label = scene.btn_save.get_node("ResetMark")
	if not reset_mark.visible or reset_mark.text != "X" or reset_mark.get_theme_color("font_color").r < 0.8:
		push_error("Saved seal reset mark is not visible")
		quit(1)
		return
	scene._on_save_reset_pressed()
	if reset_mark.visible or FileAccess.file_exists("user://seal_attack.json"):
		push_error("Reset mark or saved seal remained after deletion")
		quit(1)
		return
	print("PASS distinct default weapons, cycling and legacy seal")
	scene.queue_free()
	await process_frame
	quit(0)
