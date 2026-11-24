extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate := root.get_node("ConnectionGate")
	gate.debug_offline_enabled = true
	SceneRouter._forest_owner = ""
	SceneRouter._forest_summoner = "wizard"
	var world = load("res://scenes/forest/ForestWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var chat := root.get_node("GlobalChatClient")
	chat.set_process(false)
	chat._panel.show()
	var npc = world._npcs[0]
	world._player.transition_locked = false
	world._player.position = npc.position
	world._process(0.01)
	assert(npc._interaction_hint.visible)
	load("res://scripts/ui/lab_resource_bars.gd").update(world._resource_rows, {"wallet":{"essence":525,"core":52,"arcane_shard":26,"time_crystal":10}, "wallet_capacities":{"essence":9999,"core":999,"arcane_shard":499,"time_crystal":199}})
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(dimensions)
		await create_timer(0.5).timeout
		await process_frame
		var resources: Control = world._canvas.get_node("ForestResourceBars")
		var leave: Control = world._canvas.get_node("LeaveButton")
		var mask: Control = world._mask_button
		assert(not resources.get_global_rect().intersects(leave.get_global_rect()))
		assert(not resources.get_global_rect().intersects(mask.get_global_rect()))
		assert(not leave.get_global_rect().intersects(mask.get_global_rect()))
		assert(not resources.get_global_rect().intersects(chat._panel._toggle_row.get_global_rect()))
		assert(not leave.get_global_rect().intersects(chat._panel._toggle_row.get_global_rect()))
		if OS.get_environment("FOREST_SCREENSHOT_DIR") != "":
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.save_png(OS.get_environment("FOREST_SCREENSHOT_DIR").path_join("forest_%dx%d.png" % [dimensions.x, dimensions.y]))
		print("FOREST_LAYOUT_PASS ", dimensions)
	world.queue_free()
	quit()
