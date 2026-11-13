extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("INSPIRATION_TEST_DIR").replace("\\", "/")
	var dimensions := OS.get_environment("INSPIRATION_TEST_SIZE").split("x")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/") or dimensions.size() != 2:
		quit(1)
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene = load("res://scenes/Combat.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	await process_frame
	if OS.get_environment("INSPIRATION_ONLY_SELECTION") == "1":
		scene.player.inspiration = 3
		scene.player.inspiration_pending = true
		scene._finish_inspiration_exchange()
		await _capture(viewport, output, "selection")
		print("PASS inspiration selection capture ", viewport.size)
		quit(0)
		return
	scene.player.inspiration = 2
	scene._update_ui()
	await _capture(viewport, output, "two")
	scene.player.inspiration = 3
	scene.player.inspiration_pending = true
	scene._update_ui()
	await _capture(viewport, output, "three")
	seed(5)
	scene._finish_inspiration_exchange()
	await _capture(viewport, output, "selection")
	scene._choose_inspiration(0)
	await _capture(viewport, output, "equipped")
	print("PASS inspiration captures ", viewport.size)
	quit(0)

func _capture(viewport: SubViewport, output: String, state: String) -> void:
	await process_frame
	await process_frame
	var file := "%s/%s_%s.png" % [output, state, OS.get_environment("INSPIRATION_TEST_SIZE")]
	if viewport.get_texture().get_image().save_png(file) != OK:
		push_error("Failed capture " + file)
		quit(1)
