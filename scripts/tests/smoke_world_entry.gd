extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var url := OS.get_environment("FORGE_SMOKE_URL")
	var user_root := OS.get_environment("FORGE_SMOKE_USER_ROOT").replace("\\", "/").to_lower()
	if not url.begins_with("http://127.0.0.1:") or user_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(user_root + "/"):
		_fail("Isolation missing")
		return
	var login := BackendClient.new()
	login.base_url = url
	login.auto_dev_login = false
	root.add_child(login)
	login.login_dev("world_gate_smoke")
	if not await _wait_for(func(): return not login._verified_player_id.is_empty()):
		return
	var scene = load("res://scenes/ui/WorldZone.tscn").instantiate()
	scene.zone_id_override = "zone_corrupted"
	scene.get_node("BackendClient").base_url = url
	scene.get_node("BackendClient").auto_dev_login = false
	root.add_child(scene)
	if not await _wait_for(func(): return not scene._world_state.is_empty() and not scene._backend._verified_player_id.is_empty()):
		return
	await create_timer(0.4).timeout
	if scene._session_id != "" or int(scene._backend.load_cached_state().get("wallet", {}).get("essence", -1)) != 100 or int(scene._player_world.get("daily_entries", 0)) != 0:
		_fail("Viewing zone charged or started a session")
		return
	scene._on_enter_pressed()
	if not scene._enter_confirm.visible or scene._session_id != "" or not scene._enter_confirm.dialog_text.contains("5 Essence"):
		_fail("Entry confirmation missing cost or created session")
		return
	scene._enter_confirm.confirmed.emit()
	if not await _wait_for(func(): return not scene._session_id.is_empty()):
		return
	if int(scene._backend.load_cached_state().get("wallet", {}).get("essence", -1)) != 95:
		_fail("Confirmed entry cost mismatch")
		return
	var session_id: String = scene._session_id
	if scene._gate_remaining() <= 0 or not scene._enter_button.disabled or scene._farm_button.disabled or scene._claim_button.disabled:
		_fail("Cooldown must block new entry while preserving farm and claim")
		return
	var before_countdown: int = scene._gate_remaining()
	await create_timer(1.1).timeout
	if scene._gate_remaining() >= before_countdown:
		_fail("Server-derived cooldown did not count down locally")
		return
	var gate = load("res://scenes/ui/WorldGate.tscn").instantiate()
	gate.get_node("BackendClient").base_url = url
	gate.get_node("BackendClient").auto_dev_login = false
	root.add_child(gate)
	if not await _wait_for(func(): return gate._gate_remaining() > 0 and not gate._zone_rows.is_empty()):
		return
	if gate._zone_rows["zone_corrupted"].enter.disabled:
		_fail("Existing zone session cannot be resumed during cooldown")
		return
	for zone in gate._zone_rows:
		if zone != "zone_corrupted" and not gate._zone_rows[zone].enter.disabled:
			_fail("New zone entry remains enabled during cooldown")
			return
	gate.queue_free()
	scene._update_from_state(scene._backend.load_cached_state())
	scene._on_enter_pressed()
	if scene._session_id != session_id:
		_fail("Existing session was not retained")
		return
	print("PASS World Gate: explicit entry, cooldown and existing session access")
	scene.queue_free()
	login.queue_free()
	await process_frame
	quit(0)

func _wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not predicate.call():
		_fail("Timed out waiting for backend state")
		return false
	return true

func _fail(message: String) -> void:
	push_error("WORLD_ENTRY_FAIL: " + message)
	quit(1)
