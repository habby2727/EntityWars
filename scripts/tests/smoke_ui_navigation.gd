extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var user_root := OS.get_environment("UI_CAPTURE_DIR").replace("\\", "/").to_lower()
	if user_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(user_root + "/"):
		_fail("Isolation missing")
		return
	node_added.connect(func(node):
		if node is BackendClient:
			node.base_url = "http://127.0.0.1:1"
			node.auto_dev_login = false)
	var file := FileAccess.open("user://debug.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"unlock_all_buildings": true}))
	file.close()
	var default_panel := PanelContainer.new()
	root.add_child(default_panel)
	var custom_panel := PanelContainer.new()
	var custom_style := StyleBoxFlat.new()
	custom_panel.add_theme_stylebox_override("panel", custom_style)
	root.add_child(custom_panel)
	var dialog := ConfirmationDialog.new()
	root.add_child(dialog)
	await process_frame
	await process_frame
	if not default_panel.get_theme_stylebox("panel") is StyleBoxTexture or not dialog.get_theme_stylebox("panel") is StyleBoxTexture or custom_panel.get_theme_stylebox("panel") != custom_style:
		_fail("Default panels should use the frame without replacing custom styles")
		return
	default_panel.queue_free()
	custom_panel.queue_free()
	dialog.queue_free()
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await process_frame
	await process_frame
	current_scene.get_node("LowerButtons/InventoryButton").pressed.emit()
	if not await _expect("res://scenes/ui/Inventory.tscn"):
		return
	SceneRouter.go_to_main_menu()
	if not await _expect("res://scenes/MainMenu.tscn"):
		return
	current_scene.get_node("LowerButtons/CombatButton").pressed.emit()
	if not await _expect("res://scenes/LoadoutGrid.tscn"):
		return
	if not current_scene.get_node("RootMargin/MainHSplit/RightPanel/Card/CardMargin/CardVBox/TechCenter").visible:
		_fail("Normal combat loadout should retain techniques")
		return
	SceneRouter.go_to_main_menu()
	if not await _expect("res://scenes/MainMenu.tscn"):
		return
	current_scene.get_node("LowerButtons/LaboratoryButton").pressed.emit()
	if not await _expect("res://scenes/ui/LabHub.tscn"):
		return
	current_scene._quick_panel.manage_requested.emit("build_forge")
	if not await _expect("res://scenes/ui/LabStructures.tscn"):
		return
	if current_scene._grid.columns != 2 or current_scene._cards.size() != 12:
		_fail("Building navigation should have two columns and twelve cards")
		return
	if current_scene._selected_id != "build_forge":
		_fail("Forge focus missing")
		return
	for card in current_scene._cards.values():
		if card.get_node("HBox/IconFrame").texture != null:
			_fail("Building navigation has a duplicate slot")
			return
		var icon_center: Vector2 = card.get_node("HBox/IconFrame").get_global_rect().get_center()
		if absf(icon_center.x - card.get_global_rect().get_center().x) > 1.0:
			_fail("Building navigation icon is not centered")
			return
	var forge_area: Control = current_scene._specialized_panel.find_child("CatalogStatsArea", true, false)
	if not forge_area is HBoxContainer or forge_area.get_node_or_null("PreviewSlot") == null or forge_area.get_node_or_null("StatsScroll") == null:
		_fail("Forge preview must sit next to its statistics")
		return
	var forge_panel = current_scene._specialized_panel
	var has_weapons_title := false
	for label in forge_panel.find_children("*", "Label", true, false):
		if label.text == "WEAPONS CATALOG":
			has_weapons_title = true
	if not has_weapons_title:
		_fail("Forge catalog title is missing")
		return
	forge_panel._forge_state["item_progress"] = {forge_panel._forge_item: {"level": 3, "specialization": "defensive", "traits": [{"id": "ward_pct", "points": 1}, {"id": "reflect_pct", "points": 1}, {"id": "evasion_pct", "points": 1}], "fusion": {"donor_id": "wind_amulet"}}}
	forge_panel._update_forge_button()
	if not forge_panel._forge_info.text.contains("Current:") or not forge_panel._fusion_info.text.contains("Preview:") or forge_panel._forge_info.text.split("\n").size() > 11:
		_fail("Forge effects should stay compact when a fusion is present")
		return
	current_scene._select_building("homunculus_vat")
	await process_frame
	var vat_area: Control = current_scene._specialized_panel.find_child("CatalogStatsArea", true, false)
	if not vat_area is VBoxContainer or vat_area.get_node_or_null("PreviewSlot") == null or vat_area.get_node("PreviewSlot").get_child(0).texture == null:
		_fail("Homunculus preview needs a framed slot above its statistics")
		return
	for building_id in current_scene.BUILDING_ORDER:
		current_scene._select_building(building_id)
		await process_frame
		if current_scene._selected_id != building_id or not is_instance_valid(current_scene._upgrade_btn):
			_fail("Building menu unavailable: " + building_id)
			return
	current_scene._select_building("build_forge")
	SceneRouter.go_to_inventory("Builds", true)
	if not await _expect("res://scenes/ui/Inventory.tscn"):
		return
	SceneRouter.go_to_lab_hub()
	if not await _expect("res://scenes/ui/LabHub.tscn"):
		return
	current_scene._quick_panel.manage_requested.emit("world_gate")
	if not await _expect("res://scenes/ui/WorldGate.tscn"):
		return
	SceneRouter.go_to_combat()
	if not await _expect("res://scenes/Combat.tscn"):
		return
	print("PASS navigation MainMenu, Inventory, Loadout, Lab, Forge, World Gate and Combat")
	quit(0)

func _expect(path: String) -> bool:
	await process_frame
	await process_frame
	if current_scene == null or current_scene.scene_file_path != path:
		_fail("Expected " + path)
		return false
	return true

func _fail(message: String) -> void:
	push_error("UI_NAVIGATION_FAIL: " + message)
	quit(1)
