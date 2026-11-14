extends SceneTree

const BASE := "res://assets/ui/loading_screens/entity_wars_loading/scenes/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for name in ["loading_portal", "loading_chaos", "loading_laboratory"]:
		var packed := load(BASE + name + ".tscn") as PackedScene
		if packed == null:
			push_error("Loading variant missing: " + name)
			quit(1)
			return
		var screen := packed.instantiate()
		root.add_child(screen)
		screen.set_progress(0.5)
		if not screen.get_node("ProgressFill").material is ShaderMaterial:
			push_error("Loading shader missing: " + name)
			quit(1)
			return
		screen.queue_free()
		await process_frame
	var startup := (load(BASE + "loading_startup.tscn") as PackedScene).instantiate()
	var started_at := Time.get_ticks_msec()
	root.add_child(startup)
	current_scene = startup
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/MainMenu.tscn":
			if Time.get_ticks_msec() - started_at < 3000:
				push_error("Loading screen was visible for less than three seconds")
				quit(1)
				return
			if ProjectSettings.get_setting("application/config/icon") != "res://assets/ui/ew-icon.png":
				push_error("Application icon is not configured")
				quit(1)
				return
			print("PASS: three loading variants and startup to MainMenu")
			current_scene.queue_free()
			await process_frame
			call_deferred("quit", 0)
			return
	push_error("Loading startup did not reach MainMenu")
	quit(1)
