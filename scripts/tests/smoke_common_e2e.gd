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
	while current_scene == loadout and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
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
	if not combat.confirm_popup.visible:
		_fail("Active hunt did not request confirmation")
		return
	combat._on_confirm_stay()
	if current_scene != combat:
		_fail("Canceling leave exited the active hunt")
		return
	combat._on_back_pressed()
	combat._on_confirm_leave()
	deadline = Time.get_ticks_msec() + 20000
	while current_scene == combat and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	zone = current_scene
	if zone == null or zone.scene_file_path != SceneRouter.SCENE_WORLD_ZONE_CHAOS:
		_fail("Forfeit did not return to the original zone")
		return
	var journal := SessionRecoveryJournal.new()
	journal.set_identity(OS.get_environment("EW_COMMON_PLAYER"))
	if not journal.load_entry().is_empty():
		_fail("Forfeit left a recovery journal")
		return
	SceneRouter.go_to_world_zone("zone_crystal")
	await process_frame
	await process_frame
	zone = current_scene
	deadline = Time.get_ticks_msec() + 30000
	while (zone._backend._verified_player_id.is_empty() or zone._hunt_rotation < 0 or not zone._hunt_session_checked or zone._common_progress.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	zone._world_sprite.gui_input.emit(click)
	if zone._hunt_fight.disabled:
		_fail("Next zone boss unavailable")
		return
	zone._start_map_hunt()
	deadline = Time.get_ticks_msec() + 20000
	while current_scene == zone and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == zone or str(SceneRouter._solo_hunt_context.get("session_id", "")) in ["", session_id] or root.get_node("ConnectionGate").blocked():
		_fail("Next zone hunt did not start")
		return
	var b_id := str(SceneRouter._solo_hunt_context.get("session_id", ""))
	var b_context := SceneRouter._solo_hunt_context.duplicate(true)
	var b_loadout = current_scene
	deadline = Time.get_ticks_msec() + 20000
	while (not b_loadout._hunt_recovered or b_loadout._hunt_backend._verified_player_id.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not b_loadout._hunt_recovered:
		_fail("Second hunt loadout did not recover")
		return
	var stale := {"version": 1, "mode": "hunt", "player_id": OS.get_environment("EW_COMMON_PLAYER"), "session_id": session_id, "context": {"hunt_id": "hunt_common", "visual_zone_id": "zone_chaos"}, "pending_kind": "", "payload": {}}
	if not journal.save_entry(stale):
		_fail("Could not create stale A journal")
		return
	var gate := root.get_node("ConnectionGate")
	if gate.journal_pending(b_loadout._hunt_backend, "hunt", "loadout", {"session_id": b_id, "client_action_id": "b-loadout-probe"}):
		_fail("B was allowed to overwrite the stale A journal")
		return
	deadline = Time.get_ticks_msec() + 30000
	while (gate.blocked() or current_scene == b_loadout or not current_scene.has_method("_on_online_hunt_response")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if gate.blocked() or current_scene == b_loadout or not current_scene.has_method("_on_online_hunt_response") or not journal.load_entry().is_empty() or str(current_scene._online_hunt_session.get("status", "")) != "FORFEIT":
		_fail("Closed A was not verified and reconciled before B")
		return
	SceneRouter._solo_hunt_context = b_context
	SceneRouter._hunt_loadout_active = true
	change_scene_to_file(SceneRouter.SCENE_LOADOUT)
	await scene_changed
	var resumed = current_scene
	deadline = Time.get_ticks_msec() + 20000
	while (not resumed._hunt_recovered or gate.blocked()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if gate.blocked() or not resumed._hunt_recovered or str(SceneRouter._solo_hunt_context.get("session_id", "")) != b_id or str(SceneRouter._solo_hunt_context.get("recovered_session", {}).get("status", "")) != "ACTIVE":
		_fail("Active B did not resume after closed A recovery")
		return
	resumed._on_play_pressed()
	deadline = Time.get_ticks_msec() + 20000
	while (current_scene == null or current_scene == resumed) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == null or current_scene == resumed or not current_scene.has_method("_on_online_hunt_response") or str(current_scene._solo_context.get("session_id", "")) != b_id:
		_fail("B loadout could not be submitted after A recovery: scene=%s context=%s expected=%s details=%s" % [current_scene.scene_file_path if is_instance_valid(current_scene) else "null", str(SceneRouter._solo_hunt_context), b_id, resumed.lbl_build_error.text if is_instance_valid(resumed) else "scene changed"])
		return
	current_scene.queue_free()
	await process_frame
	await process_frame
	print("PASS cross-session stale A verified before active B")
	print("PASS common appearance -> one-click Ready -> confirmed forfeit -> next zone")
	quit(0)
