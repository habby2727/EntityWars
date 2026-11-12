extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var user_root := OS.get_environment("UI_CAPTURE_DIR").replace("\\", "/").to_lower()
	if user_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(user_root + "/"):
		_fail("Isolation missing")
		return
	node_added.connect(func(node):
		if node is BackendClient:
			node.base_url = "http://127.0.0.1:1"
			node.auto_dev_login = false)
	var file := FileAccess.open("user://debug.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"unlock_all_buildings": true}))
	file.close()
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await process_frame
	await process_frame
	current_scene.get_node("LowerButtons/InventoryButton").pressed.emit()
	if not await _expect("res://scenes/ui/Inventory.tscn"):
		return
	SceneRouter.go_to_main_menu()
	if not await _expect("res://scenes/MainMenu.tscn"):
		return
	current_scene.get_node("LowerButtons/CombatButton").pressed.emit()
	if not await _expect("res://scenes/LoadoutGrid.tscn"):
		return
	SceneRouter.go_to_main_menu()
	if not await _expect("res://scenes/MainMenu.tscn"):
		return
	current_scene.get_node("LowerButtons/LaboratoryButton").pressed.emit()
	if not await _expect("res://scenes/ui/LabHub.tscn"):
		return
	current_scene._quick_panel.manage_requested.emit("build_forge")
	if not await _expect("res://scenes/ui/LabStructures.tscn"):
		return
	if current_scene._selected_id != "build_forge":
		_fail("Forge focus missing")
		return
	SceneRouter.go_to_inventory("Builds", true)
	if not await _expect("res://scenes/ui/Inventory.tscn"):
		return
	SceneRouter.go_to_lab_hub()
	if not await _expect("res://scenes/ui/LabHub.tscn"):
		return
	current_scene._quick_panel.manage_requested.emit("world_gate")
	if not await _expect("res://scenes/ui/WorldGate.tscn"):
		return
	SceneRouter.go_to_combat()
	if not await _expect("res://scenes/Combat.tscn"):
		return
	print("PASS navigation MainMenu, Inventory, Loadout, Lab, Forge, World Gate and Combat")
	quit(0)

func _expect(path: String) -> bool:
	await process_frame
	await process_frame
	if current_scene == null or current_scene.scene_file_path != path:
		_fail("Expected " + path)
		return false
	return true

func _fail(message: String) -> void:
	push_error("UI_NAVIGATION_FAIL: " + message)
	quit(1)
