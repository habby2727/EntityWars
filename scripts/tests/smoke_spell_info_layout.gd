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
