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
	if OS.get_environment("UI_GEOMETRY_ONLY") == "1":
		if not OS.is_debug_build():
			push_error("Android preview requires a debug build")
			quit(1)
			return
		OS.set_environment("UI_ANDROID_PREVIEW", "1")
		await _check_inventory_geometry()
		return
	var dimensions := OS.get_environment("UI_CAPTURE_SIZE").split("x")
	if dimensions.size() != 2 or int(dimensions[0]) <= 0 or int(dimensions[1]) <= 0:
		push_error("UI_CAPTURE_SIZE must be WIDTHxHEIGHT")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	var aspect := float(viewport.size.x) / float(viewport.size.y)
	viewport.size_2d_override = Vector2i(roundi(1080.0 * maxf(aspect, 16.0 / 9.0)), 1080)
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

func _check_inventory_geometry() -> void:
	for pixels in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1280, 720)]:
		var viewport := SubViewport.new()
		viewport.size = pixels
		viewport.size_2d_override = Vector2i(roundi(1080.0 * maxf(float(pixels.x) / pixels.y, 16.0 / 9.0)), 1080)
		viewport.size_2d_override_stretch = true
		root.add_child(viewport)
		var inventory = load(SCENES.inventory).instantiate()
		viewport.add_child(inventory)
		for frame in 4:
			await process_frame
		for index in inventory._tabs.get_tab_count():
			inventory._tabs.current_tab = index
			for frame in 3:
				await process_frame
			var layout: HBoxContainer = inventory._tab_layouts[index]
			var list: Control = layout.get_node("Scroll")
			var detail: Control = inventory._detail_panel
			var bounds := Rect2(Vector2.ZERO, Vector2(viewport.size_2d_override))
			for control in [inventory._back_button, inventory._loadout_button, list, detail]:
				var rect: Rect2 = control.get_global_rect()
				if rect.size.x <= 0 or rect.size.y <= 0 or not bounds.grow(1.0).encloses(rect):
					push_error("Geometry outside viewport %s tab %d: %s %s" % [pixels, index, control.name, rect])
					quit(1)
					return
			if list.get_global_rect().intersects(detail.get_global_rect()):
				push_error("Inventory list overlaps detail at %s tab %d" % [pixels, index])
				quit(1)
				return
			if inventory._back_button.get_global_rect().intersects(inventory._loadout_button.get_global_rect()) or inventory._detail_icon.get_global_rect().intersects(inventory._detail_title.get_global_rect()):
				push_error("Inventory controls overlap at %s tab %d" % [pixels, index])
				quit(1)
				return
		print("PASS inventory geometry ", pixels, " logical ", viewport.size_2d_override)
		viewport.queue_free()
		await process_frame
	quit(0)
