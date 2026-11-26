extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/ui/LabStructures.tscn")
	for i in 6:
		await process_frame
	var lab = current_scene
	var panel_style := lab._right_panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert(panel_style != null and panel_style.texture.resource_path.ends_with("betterui/panel_horizontal.png"))
	lab._select_building("build_forge")
	for locale in ["es", "en"]:
		TranslationServer.set_locale(locale)
		for i in 6:
			await process_frame
		var forge = lab._specialized_panel
		assert(forge._forge_info.get_theme_font_size("font_size") == 24)
		assert(forge._forge_info.text.contains(" | "))
		assert(forge._forge_info.text.split("\n").size() == 4)
		assert(forge._forge_info.text.contains("Nv 1:" if locale == "es" else "Lv 1:"))
		assert(forge._forge_info.text.contains("Siguiente:" if locale == "es" else "Next:"))
		assert(forge._forge_info.get_parent().size.x > 0)
		var panel_rect: Rect2 = lab._right_panel.get_global_rect()
		var forge_rect: Rect2 = forge.get_global_rect()
		assert(panel_rect.encloses(forge_rect))
		var content_bounds := Rect2(panel_rect.position + Vector2(45, 35), panel_rect.size - Vector2(90, 83))
		assert(content_bounds.encloses(forge._forge_status.get_global_rect()))
		for control in [forge._forge_button, forge._forge_reroll_button, forge._forge_reroll_slot, forge._fusion_button]:
			assert(panel_rect.encloses(control.get_global_rect()))
	print("PASS forge layout")
	quit()
