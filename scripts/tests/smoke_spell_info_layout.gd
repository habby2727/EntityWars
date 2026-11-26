extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/ui/LabStructures.tscn")
	for i in 8:
		await process_frame
	var lab = current_scene
	assert(not lab._spell_registry.spells.is_empty())
	lab._select_building("ultrahit_tower")
	for i in 8:
		await process_frame
	assert(not lab._spell_rows.is_empty())
	for row in lab._spell_rows.values():
		for label in [row.name, row.status]:
			assert(label.get_theme_font("font").resource_path.contains("MedievalSharp"))
			assert(label.get_theme_font_size("font_size") <= 18)
		var info: Button = row.status.get_parent().get_child(1)
		assert(info.text == "i" and info.get_theme_stylebox("normal") is StyleBoxFlat)
		assert(info.get_theme_stylebox("normal").corner_radius_top_left > 0)
		info.pressed.emit()
		assert(lab._spell_info.visible and lab._spell_info.get_meta("spell") == row.spell)
		lab._spell_info.hide()
		break
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		for spell in lab._spell_registry.spells.values():
			lab._show_spell_info(spell)
			for i in 6:
				await process_frame
			var panel: Control = lab._spell_info_panel
			var bounds := panel.get_global_rect()
			var text_bounds: Rect2 = lab._spell_info_text.get_global_rect()
			var overlay: Rect2 = lab._spell_info.get_global_rect()
			assert(panel.find_children("*", "ScrollContainer", true, false).is_empty())
			assert(panel.size.y >= panel.get_combined_minimum_size().y - 1)
			assert(overlay.encloses(bounds))
			assert(bounds.encloses(text_bounds))
			assert(lab._spell_info_text.size.y >= lab._spell_info_text.get_combined_minimum_size().y - 1)
	print("PASS spell information panels")
	quit()
