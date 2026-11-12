extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("HOM_TEST_DIR").replace("\\", "/")
	var dimensions := OS.get_environment("HOM_TEST_SIZE").split("x")
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
	for state in ["charging", "ready", "boosted", "spent"]:
		scene.player.hom_spent = state == "spent"
		scene.player.hom_energy = 1 if state == "charging" else 3 if state == "ready" else 6 if state == "boosted" else 0
		scene.enemy.hom_energy = 3
		scene._update_ui()
		scene.hom_decision.visible = state in ["ready", "boosted"]
		scene.get_node("HomDecision/Attack").text = "Attack (BOOST)" if state == "boosted" else "Attack"
		await process_frame
		await process_frame
		var file := "%s/%s_%s.png" % [output, state, OS.get_environment("HOM_TEST_SIZE")]
		if viewport.get_texture().get_image().save_png(file) != OK:
			quit(1)
			return
	print("PASS hom UI captures ", viewport.size)
	quit(0)
