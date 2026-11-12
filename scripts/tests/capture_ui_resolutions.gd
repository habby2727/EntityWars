extends SceneTree

const SCENES := {
	"main_menu": "res://scenes/MainMenu.tscn",
	"loadout": "res://scenes/LoadoutGrid.tscn",
	"inventory": "res://scenes/ui/Inventory.tscn",
	"lab": "res://scenes/ui/LabHub.tscn",
	"forge": "res://scenes/ui/LabStructures.tscn",
	"combat": "res://scenes/Combat.tscn",
	"world_gate": "res://scenes/ui/WorldGate.tscn",
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("UI_CAPTURE_DIR").replace("\\", "/")
	var user_path := OS.get_user_data_dir().replace("\\", "/").to_lower()
	if output.is_empty() or not user_path.begins_with(output.to_lower() + "/"):
		push_error("UI capture requires isolated user data")
		quit(1)
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var dimensions := OS.get_environment("UI_CAPTURE_SIZE").split("x")
	if dimensions.size() != 2 or int(dimensions[0]) <= 0 or int(dimensions[1]) <= 0:
		push_error("UI_CAPTURE_SIZE must be WIDTHxHEIGHT")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	viewport.size_2d_override = Vector2i(1920, 1080)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for name in SCENES:
		if name == "forge":
			SceneRouter._next_lab_focus_id = "build_forge"
		var scene: Node = load(SCENES[name]).instantiate()
		for node in scene.find_children("*", "Node", true, false):
			if node is BackendClient:
				node.base_url = "http://127.0.0.1:1"
				node.auto_dev_login = false
		viewport.add_child(scene)
		await create_timer(0.4).timeout
		await process_frame
		var image := viewport.get_texture().get_image()
		var file := "%s/%s_%dx%d.png" % [output, name, image.get_width(), image.get_height()]
		if image.is_empty() or image.save_png(file) != OK:
			push_error("Could not capture " + name)
			quit(1)
			return
		print("CAPTURE ", file)
		scene.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame
	quit(0)
