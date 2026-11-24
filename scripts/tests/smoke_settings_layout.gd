extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("es")
	var settings = load("res://scenes/ui/Settings.tscn").instantiate()
	root.add_child(settings)
	current_scene = settings
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(dimensions)
		await create_timer(0.5).timeout
		var logout: Control = settings.get_node("Center/Panel/Margin/Content/Logout")
		var back: Control = settings.get_node("Center/Panel/Margin/Content/Back")
		assert(not logout.get_global_rect().intersects(back.get_global_rect()))
		if not OS.get_environment("FOREST_SCREENSHOT_DIR").is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("FOREST_SCREENSHOT_DIR").path_join("settings_%dx%d.png" % [dimensions.x, dimensions.y]))
		print("SETTINGS_LAYOUT_PASS ", dimensions)
	settings.queue_free()
	quit()
