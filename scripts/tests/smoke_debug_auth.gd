extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.has_feature("editor"))
	change_scene_to_file("res://scenes/ui/Auth.tscn")
	await process_frame
	await process_frame
	var auth := current_scene
	var gate := root.get_node("ConnectionGate")
	var button := auth.find_child("DebugLaboratory", true, false) as Button
	assert(button != null)
	gate.require_authentication()
	button.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene != auth and current_scene.scene_file_path == SceneRouter.SCENE_LAB_HUB)
	assert(gate.debug_offline_enabled and gate.blocked())
	assert(not gate._layer.visible)
	gate._unlock()
	assert(gate.blocked())
	var flags := DebugFlags.new()
	assert(flags.unlock_all_buildings)
	assert(flags.save_lab_state({"debug_test": 42}))
	assert(flags.load_lab_state().get("debug_test") == 42)
	flags.free()
	var backend := BackendClient.new()
	backend.auto_dev_login = false
	root.add_child(backend)
	await process_frame
	assert(backend.send_action({"action_type": "UPGRADE_BUILDING"}) == "")
	assert(backend.request_api("POST", "/dungeon/start", {}, false, true) == "")
	gate.debug_offline_enabled = false
	gate._fail(gate.State.ERROR, "Authentication failed")
	assert(gate._layer.visible and gate._debug_lab_button.visible)
	gate._debug_lab_button.pressed.emit()
	await process_frame
	await process_frame
	assert(gate.debug_offline_enabled and not gate._layer.visible)
	assert(current_scene.scene_file_path == SceneRouter.SCENE_LAB_HUB)
	var lab = current_scene
	lab._buttons["world_gate"].pressed.emit()
	assert(lab._quick_panel.visible and not lab._quick_panel._manage.disabled)
	lab._quick_panel._manage.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_WORLD_GATE)
	await _capture("world_gate")
	for zone_id in ["zone_chaos", "zone_corrupted", "zone_crystal"]:
		var world_gate = current_scene
		assert(world_gate._zone_rows.has(zone_id))
		assert(not world_gate._zone_rows[zone_id].enter.disabled)
		world_gate._zone_rows[zone_id].enter.pressed.emit()
		await process_frame
		await process_frame
		assert(current_scene._get_zone_id() == zone_id)
		assert(current_scene._world_stage.visible and current_scene._common_picker.item_count > 1)
		await _capture(zone_id)
		current_scene._common_picker.select(1)
		current_scene._common_picker.item_selected.emit(1)
		assert(current_scene._hunt_fight.disabled and current_scene._preview_status.text.contains("Offline"))
		assert(gate.blocked())
		SceneRouter.go_to_world_gate()
		await process_frame
		await process_frame
		assert(current_scene.scene_file_path == SceneRouter.SCENE_WORLD_GATE)
	gate.require_update()
	assert(not gate.debug_lab_navigation_allowed())
	assert(gate._layer.visible)
	assert(not gate._debug_lab_button.visible)
	backend.queue_free()
	current_scene.queue_free()
	await process_frame
	await process_frame
	if UIThemeFactory._catalog != null:
		UIThemeFactory._catalog.free()
		UIThemeFactory._catalog = null
	print("PASS editor offline debug laboratory and protected requests")
	quit(0)

func _capture(name: String) -> void:
	var directory := OS.get_environment("EW_DEBUG_CAPTURE_DIR")
	if directory.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
