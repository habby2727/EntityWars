extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("DUNGEON_TEST_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("isolated user directory required")
		return
	var file := FileAccess.open("user://auth.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"token": OS.get_environment("DUNGEON_TEST_TOKEN")}))
	file.close()
	var backend := BackendClient.new()
	backend.auto_dev_login = false
	root.add_child(backend)
	var deadline := Time.get_ticks_msec() + 25000
	while backend._verified_player_id.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if backend._verified_player_id.is_empty():
		_fail("authentication failed")
		return
	var gate := root.get_node("ConnectionGate")
	while gate.blocked() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if gate.blocked():
		_fail("connection gate did not verify account")
		return
	var registry := DataRegistry.new()
	var panel = load("res://scripts/ui/lab_specialized_panel.gd").new()
	root.add_child(panel)
	panel.setup(registry, backend, false, 20, 10)
	panel.show_building("sync_nexus", {"lab": {"hqLevel": 4, "buildings": {"sync_nexus": {"level": 1}}, "runtime": {}}}, {}, {}, true)
	panel._enter_dungeon()
	await process_frame
	var warning := gate.get_node_or_null("DungeonWarning")
	if warning == null or not panel._dungeon_entry_request.is_empty():
		_fail("entry started before confirmation")
		return
	warning.get_child(1).get_child(0).get_child(0).get_child(1).get_child(1).pressed.emit()
	await process_frame
	if not panel._dungeon_entry_request.is_empty() or not SceneRouter._dungeon_context.is_empty():
		_fail("cancel created a session")
		return
	panel._enter_dungeon()
	await process_frame
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(0).pressed.emit()
	deadline = Time.get_ticks_msec() + 25000
	while (current_scene == null or not current_scene.has_method("_submit_dungeon_loadout")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == null or not current_scene.has_method("_submit_dungeon_loadout"):
		_fail("entry did not reach loadout: " + panel._dungeon_entry_status.text)
		return
	var loadout = current_scene
	while not loadout._dungeon_recovered and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._dungeon_recovered:
		_fail("loadout initialization failed: " + loadout.lbl_build_error.text)
		return
	loadout._dungeon_exit_warning()
	await process_frame
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(1).pressed.emit()
	await process_frame
	if SceneRouter._dungeon_context.is_empty():
		_fail("stay closed the loadout run")
		return
	loadout._dungeon_exit_warning()
	await process_frame
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(0).pressed.emit()
	await create_timer(2.0).timeout
	if not SceneRouter._dungeon_context.is_empty():
		_fail("loadout exit did not clear the context")
		return
	panel._enter_dungeon()
	await process_frame
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(0).pressed.emit()
	deadline = Time.get_ticks_msec() + 25000
	while (current_scene == null or not current_scene.has_method("_submit_dungeon_loadout")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == null or not current_scene.has_method("_submit_dungeon_loadout"):
		_fail("second run did not reach loadout")
		return
	loadout = current_scene
	while not loadout._dungeon_recovered and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._dungeon_recovered:
		_fail("second loadout initialization failed")
		return
	loadout._on_card_picked("entity", "sulfur_01")
	loadout._on_play_pressed()
	deadline = Time.get_ticks_msec() + 25000
	while current_scene == loadout and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == loadout:
		_fail("loadout was not accepted: " + loadout.lbl_build_error.text)
		return
	var combat = current_scene
	while combat._dungeon_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._dungeon_session.is_empty() or not combat._dungeon_synchronized:
		_fail("combat did not use the live loadout response")
		return
	combat._dungeon_brief.hide()
	combat._on_back_pressed()
	await process_frame
	if gate.get_node_or_null("DungeonWarning") == null:
		_fail("combat exit warning missing")
		return
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(1).pressed.emit()
	await process_frame
	if SceneRouter._dungeon_context.is_empty():
		_fail("stay closed the Dungeon")
		return
	combat._dungeon_session.combat_state["blessing"] = {"pending": true, "offers": [{"id": "a", "name": "A"}, {"id": "b", "name": "B"}, {"id": "c", "name": "C"}]}
	combat._refresh_dungeon_blessing()
	if not combat._blessing_panel.visible:
		_fail("blessing selection did not open")
		return
	combat._on_back_pressed()
	await process_frame
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(0).pressed.emit()
	await create_timer(4.0).timeout
	if not SceneRouter._dungeon_context.is_empty():
		_fail("exit did not clear the Dungeon context")
		return
	print("PASS Dungeon real entry, cancellation, loadout, combat, stay and exit")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
