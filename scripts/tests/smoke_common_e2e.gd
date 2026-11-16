extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _run() -> void:
	var test_root := OS.get_environment("EW_COMMON_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("Isolated user directory required")
		return
	var auth := FileAccess.open("user://auth.json", FileAccess.WRITE)
	auth.store_string(JSON.stringify({"token": OS.get_environment("EW_COMMON_TOKEN")}))
	auth.close()
	change_scene_to_file("res://scenes/ui/WorldZoneChaos.tscn")
	await process_frame
	await process_frame
	var zone = current_scene
	var deadline := Time.get_ticks_msec() + 30000
	while (zone._backend._verified_player_id.is_empty() or zone._hunt_rotation < 0 or not zone._hunt_session_checked or zone._common_owner != zone._backend._verified_player_id or zone._common_progress.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	zone._world_sprite.gui_input.emit(click)
	var appearance: String = zone._hunt_selected.get("appearance_id", "")
	var expected_name: String = zone._debug_visual.get("name", "")
	var expected_texture: String = zone._debug_visual.get("texture", "")
	if appearance.is_empty() or zone._hunt_fight.disabled:
		_fail("Common selection unavailable: " + zone._preview_status.text)
		return
	zone._start_map_hunt()
	deadline = Time.get_ticks_msec() + 20000
	while current_scene == zone and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	var loadout = current_scene
	if loadout == zone or not loadout._hunt_mode:
		_fail("Common start failed: " + zone._preview_status.text)
		return
	var session_id := str(SceneRouter._solo_hunt_context.get("session_id", ""))
	deadline = Time.get_ticks_msec() + 20000
	while not loadout._hunt_recovered and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._hunt_recovered:
		_fail("Common loadout recovery failed")
		return
	var snapshot: Dictionary = SceneRouter._solo_hunt_context.get("recovered_session", {}).get("boss_definition", {})
	if snapshot.get("appearance_id") != appearance or snapshot.get("name") != expected_name or snapshot.get("texture_id") != expected_texture:
		_fail("Common trusted snapshot mismatch: " + str(snapshot))
		return
	loadout._on_play_pressed()
	deadline = Time.get_ticks_msec() + 20000
	while int(SceneRouter._solo_hunt_context.get("recovered_session", {}).get("combat_revision", 0)) < 1 and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	loadout._on_play_pressed()
	await process_frame
	await process_frame
	var combat = current_scene
	if combat == loadout or not combat._online_hunt_guard:
		_fail("Common combat entry failed")
		return
	deadline = Time.get_ticks_msec() + 20000
	while combat._online_hunt_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._online_hunt_session.is_empty() or combat.enemy_entity_name.text != expected_name or combat.enemy_entity.texture == null or combat.enemy_entity.texture.resource_path != expected_texture:
		_fail("Common combat appearance mismatch")
		return
	combat._on_back_pressed()
	await process_frame
	await process_frame
	zone = current_scene
	deadline = Time.get_ticks_msec() + 30000
	while (zone._hunt_active.is_empty() or zone._hunt_active_owner.is_empty() or zone._common_progress.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if zone._hunt_active.is_empty():
		_fail("Common session did not recover")
		return
	zone._debug_visual = {"id": appearance, "name": expected_name, "texture": expected_texture, "tier": "common"}
	zone._show_common_details()
	if not zone._active_hunt_matches("") or zone._hunt_fight.disabled:
		_fail("Common resume unavailable: " + zone._preview_status.text)
		return
	zone._start_map_hunt()
	await process_frame
	await process_frame
	if str(SceneRouter._solo_hunt_context.get("session_id", "")) != session_id:
		_fail("Resume changed common session")
		return
	print("PASS common appearance -> session -> loadout -> combat -> resume")
	quit(0)
