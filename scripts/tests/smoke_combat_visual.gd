extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("COMBAT_VISUAL_DIR").replace("\\", "/")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/"):
		push_error("Visual test requires isolated user data")
		quit(1)
		return
	var debug := FileAccess.open("user://debug.json", FileAccess.WRITE)
	debug.store_string(JSON.stringify({"unlock_all_buildings": true}))
	debug.close()
	var scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if not scene._combat_started or not scene.spell_buttons[0].visible or scene.spell_buttons[0].disabled:
		push_error("Combat controls unavailable")
		quit(1)
		return
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output + "/combat.png") != OK:
		push_error("Cannot capture rendered combat")
		quit(1)
		return
	scene.spell_buttons[0].pressed.emit()
	if not scene._resolving_exchange:
		push_error("Spell button did not start an exchange")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 15000
	while scene._resolving_exchange and Time.get_ticks_msec() < deadline:
		await process_frame
	if scene._resolving_exchange:
		push_error("Combat exchange timed out")
		quit(1)
		return
	print("PASS rendered combat and spell button signal")
	scene.queue_free()
	await process_frame
	quit(0)
