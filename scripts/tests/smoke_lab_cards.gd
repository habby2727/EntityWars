extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	TranslationServer.set_locale("es")
	change_scene_to_file("res://scenes/ui/LabHub.tscn")
	for i in 8:
		await process_frame
	var panel = current_scene._quick_panel
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxTexture
	assert(panel_style != null and panel_style.texture.resource_path.ends_with("betterui/panel_vertical.png"))
	assert(panel._frame.texture.resource_path.ends_with("betterui/panel_vertical.png"))
	for action in [panel._close, panel._upgrade, panel._collect, panel._manage]:
		assert(action.get_theme_stylebox("normal") is StyleBoxTexture)
		assert(action.has_meta("betterui_button"))
	for viewport_size in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1280, 720)]:
		root.size = viewport_size
		for locale in ["es", "en"]:
			TranslationServer.set_locale(locale)
			for id in current_scene.BUILDING_IDS:
				panel.show_building(id)
				for i in 8:
					await process_frame
				assert(panel.find_children("*", "ScrollContainer", true, false).is_empty())
				assert(panel.size.y >= panel.get_combined_minimum_size().y)
				var bounds: Rect2 = panel.get_global_rect()
				assert(bounds.position.x >= -2 and bounds.position.y >= -2)
				assert(bounds.end.x <= root.get_visible_rect().end.x + 2 and bounds.end.y <= root.get_visible_rect().end.y + 2)
				var visible_actions: Array[Button] = []
				for action: Button in [panel._upgrade, panel._collect, panel._manage]:
					if action.visible:
						assert(action.get_meta("betterui_button") == "boton_corto.png")
						visible_actions.append(action)
				for index in range(1, visible_actions.size()):
					var previous := visible_actions[index - 1].get_global_rect()
					var current := visible_actions[index].get_global_rect()
					assert(is_equal_approx(previous.position.y, current.position.y))
					assert(previous.end.x <= current.position.x and bounds.encloses(current))
				for control in panel.find_children("*", "Control", true, false):
					if control.is_visible_in_tree():
						var rect: Rect2 = control.get_global_rect()
						assert(rect.position.y >= bounds.position.y - 2 and rect.end.y <= bounds.end.y + 2)
						assert(rect.position.x >= bounds.position.x - 2 and rect.end.x <= bounds.end.x + 2)
	print("PASS laboratory cards")
	quit()

