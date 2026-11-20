extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("en")
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
	var loadout_entity: String = current_scene._current_entity_id
	var loadout_homunculus: String = current_scene._current_homunculus_id
	var loadout_mode: String = current_scene._mode
	current_scene._set_button_selection(current_scene.dd_item1, current_scene._items, "bismuth_talisman")
	var weapon_index: int = current_scene.dd_item1.get_meta("selected_idx")
	current_scene._open_spell_dialog()
	if current_scene._spell_draft.size() < 2:
		_fail("Spell draft should contain equipped spells")
		return
	var spell_draft: Array = current_scene._spell_draft.duplicate()
	current_scene._select_spell_slot(1)
	var duplicate: Dictionary = current_scene._reg.get_spell_by_id(str(spell_draft[0]))
	current_scene._choose_catalog_spell(duplicate, "Initial")
	TranslationServer.set_locale("es")
	if current_scene._current_entity_id != loadout_entity or current_scene._current_homunculus_id != loadout_homunculus or current_scene._mode != loadout_mode:
		_fail("Changing language must preserve the loadout")
		return
	if current_scene.dd_item1.get_meta("selected_idx") != weapon_index or current_scene.dd_item1.text != "Espada de bismuto":
		_fail("Changing language must preserve and translate the selected weapon")
		return
	if current_scene._spell_draft != spell_draft or not current_scene._spell_description.text.contains("Ya está equipado"):
		_fail("Changing language must preserve the draft and its duplicate warning")
		return
	TranslationServer.set_locale("en")
	current_scene._spell_dialog.hide()
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
	var forge_list: ItemList = forge_panel.find_child("LocalizationCatalogItems", true, false)
	var selected_forge: String = forge_panel._forge_item
	var selected_rows := forge_list.get_selected_items()
	var original_state: Dictionary = forge_panel._forge_state.duplicate(true)
	TranslationServer.set_locale("es")
	if forge_panel._forge_item != selected_forge or forge_list.get_selected_items() != selected_rows or forge_list.get_item_text(selected_rows[0]) == "" or forge_panel._forge_state != original_state:
		_fail("Changing language should preserve the selected forge item")
		return
	TranslationServer.set_locale("en")
	var has_weapons_title := false
	for label in forge_panel.find_children("*", "Label", true, false):
		if label.tr(label.text) == "WEAPONS CATALOG":
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
	var vat_panel_layout = current_scene._specialized_panel
	var vat_list: ItemList = vat_panel_layout.find_child("LocalizationCatalogItems", true, false)
	var vat_preview: Control = vat_panel_layout.find_child("PreviewSlot", true, false)
	var vat_scroll: ScrollContainer = vat_area.get_node("StatsScroll")
	if not vat_area is HBoxContainer or vat_preview == null or vat_panel_layout.get_index() != 0:
		_fail("Homunculus preview and details must start at the top of the panel")
		return
	for locale in ["en", "es"]:
		TranslationServer.set_locale(locale)
		for index in range(vat_list.item_count):
			vat_list.select(index)
			vat_list.item_selected.emit(index)
			await process_frame
			var panel_rect: Rect2 = current_scene._right_panel.get_global_rect()
			if vat_list.get_global_rect().intersects(vat_preview.get_global_rect()) or vat_list.get_global_rect().intersects(vat_scroll.get_global_rect()) or not panel_rect.encloses(vat_scroll.get_global_rect()):
				_fail("Homunculus details must stay inside the panel and clear of the list")
				return
	TranslationServer.set_locale("en")
	vat_panel_layout._forge_state["homunculus_progress"] = {vat_panel_layout._vat_item: {"level": 3, "xp": 570, "owned": true}}
	vat_panel_layout._forge_state["wallet"] = {"essence": 0, "core": 0, "arcane_shard": 0}
	vat_panel_layout._forge_state["lab"]["buildings"]["homunculus_vat"] = {"level": 1}
	vat_panel_layout._update_vat_status()
	if not vat_panel_layout._vat_xp.text.contains("570") or not vat_panel_layout._vat_xp.text.contains("863") or vat_panel_layout._vat_mutations[0].disabled:
		_fail("Vat must show XP and allow free level-gated mutation: %s | %s" % [vat_panel_layout._vat_xp.text, vat_panel_layout._vat_status.text])
		return
	for building_id in current_scene.BUILDING_ORDER:
		current_scene._select_building(building_id)
		await process_frame
		if current_scene._selected_id != building_id or not is_instance_valid(current_scene._upgrade_btn):
			_fail("Building menu unavailable: " + building_id)
			return
	current_scene._select_building("experiment_chamber")
	var experiment_row: Dictionary = current_scene._experiment_rows["volatile_overclock"]
	var experiment_button: Button = experiment_row.button
	var experiment_disabled := experiment_button.disabled
	TranslationServer.set_locale("es")
	if experiment_row.name_label.text != "Más esencia" or not experiment_row.desc_label.text.contains("20 minutos") or experiment_button.disabled != experiment_disabled:
		_fail("Changing language must preserve experiment actions")
		return
	TranslationServer.set_locale("en")
	current_scene._select_building("arcane_archives")
	var research_row: Dictionary = current_scene._research_rows["archive_basics"]
	TranslationServer.set_locale("es")
	if research_row.name_label.text != "Fundamentos de archivo":
		_fail("Research name should change immediately")
		return
	TranslationServer.set_locale("en")
	current_scene._select_building("homunculus_vat")
	var vat_panel = current_scene._specialized_panel
	var selected_homunculus: String = vat_panel._vat_item
	var vat_state: Dictionary = vat_panel._forge_state.duplicate(true)
	TranslationServer.set_locale("es")
	if vat_panel._vat_item != selected_homunculus or vat_panel._forge_state != vat_state or not vat_panel._vat_info.text.contains("Mutación:") or not vat_panel._vat_mutations[0].tooltip_text.contains("Potencia +1."):
		_fail("Changing language must preserve the homunculus and update mutation details")
		return
	TranslationServer.set_locale("en")
	current_scene._select_building("build_forge")
	current_scene._select_building("sync_nexus")
	var sync_panel = current_scene._specialized_panel
	var sync_button: Button = sync_panel._lab_buttons[0]
	var sync_disabled := sync_button.disabled
	var sync_state: Dictionary = sync_panel._forge_state.duplicate(true)
	TranslationServer.set_locale("es")
	var sync_description: Label = sync_panel.find_child("SyncDescription", true, false)
	if sync_description == null or not sync_description.text.contains("Ajusta el nexo") or sync_button.disabled != sync_disabled or sync_panel._forge_state != sync_state:
		_fail("Changing language should preserve the Sync Nexus action")
		return
	TranslationServer.set_locale("en")
	current_scene._select_building("essence_reactor")
	var route: OptionButton = current_scene._route_option
	route.select(1)
	var route_id: Variant = route.get_item_metadata(route.selected)
	TranslationServer.set_locale("es")
	if route.selected != 1 or route.get_item_metadata(route.selected) != route_id or route.get_item_text(route.selected) != "Volátil":
		_fail("Changing language should preserve the unsaved route and its identifier")
		return
	TranslationServer.set_locale("en")
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
	var zone_selection: String = current_scene._selected_zone_id
	var chaos_row: Dictionary = current_scene._zone_rows["zone_chaos"]
	TranslationServer.set_locale("es")
	if current_scene._selected_zone_id != zone_selection or chaos_row.name.text != "Zona del caos" or not chaos_row.lore.text.contains("tormentas alquímicas"):
		_fail("Changing language must preserve the selected zone and translate its card")
		return
	TranslationServer.set_locale("en")
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
