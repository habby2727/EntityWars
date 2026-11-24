extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/ui/LabStructures.tscn")
	for i in 6:
		await process_frame
	var lab = current_scene
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
	print("PASS forge layout")
	quit()
