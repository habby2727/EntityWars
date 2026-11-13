extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.has_environment("EW_CAPTURE_DIR"):
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	for world in ["Chaos", "Corrupted", "Crystal"]:
		var scene := load("res://scenes/ui/WorldZone%s.tscn" % world) as PackedScene
		var zone := scene.instantiate()
		root.add_child(zone)
		await process_frame
		if OS.has_environment("EW_CAPTURE_DIR"):
			await create_timer(1.0).timeout
			root.get_texture().get_image().save_png(OS.get_environment("EW_CAPTURE_DIR").path_join(world + ".png"))
		var entries: Array = zone.WORLD_ART["zone_" + world.to_lower()]
		assert(zone._background.texture != null)
		for index in entries.size():
			zone._change_world_art(1)
			assert(zone._world_sprite.texture != null)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		zone._world_sprite.gui_input.emit(click)
		assert(zone._world_modal.visible)
		var close_button: Button = null
		for button in zone._world_modal.find_children("*", "Button", true, false):
			if button.text == "X":
				close_button = button
				break
		assert(close_button != null and close_button.text == "X")
		close_button.pressed.emit()
		assert(not zone._world_modal.visible)
		zone.queue_free()
		await process_frame
		print("PASS ", world, " ", entries.size())
	quit()
