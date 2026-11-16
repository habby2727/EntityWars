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
	if not await _wait_for(func(): return not scene._global_event.is_empty() and is_instance_valid(scene._global_actor)):
		return
	var global_id: String = scene._global_event.get("event_id", "")
	var global_actor: Control = scene._global_actor
	scene._global_poll_timer = 0.0
	scene._process(1.0)
	if scene._global_poll_timer != 1.0:
		_fail("Global polling ran too early")
		return
	scene._process(19.0)
	if scene._global_poll_timer != 0.0:
		_fail("Global polling did not run at 20 seconds")
		return
	if global_id.is_empty() or scene._global_event.get("zone_id") != "zone_corrupted" or not global_actor.get_child(1).text.contains("0/5"):
		_fail("Global boss not synchronized")
		return
	scene._apply_reroll()
	if scene._global_actor != global_actor or str(scene._global_event.get("event_id", "")) != global_id:
		_fail("Reroll replaced global boss")
		return
	global_actor.get_child(2).pressed.emit()
	if not global_actor.get_child(3).visible or scene._world_modal.visible:
		_fail("Global icon opened encounter instead of tooltip")
		return
	global_actor.get_child(0).pressed.emit()
	if not scene._world_modal.visible or scene._view_guardians.visible or scene._hunt_fight.disabled:
		_fail("Global encounter unavailable")
		return
	scene._global_event["reward_status"] = "WAITING"
	scene._open_global_boss()
	if not scene._hunt_fight.disabled or not scene._preview_status.text.contains("Already defeated"):
		_fail("Global victory did not disable replay")
		return
	scene._global_event["reward_status"] = null
	scene._hunt_active_owner = scene._backend._verified_player_id
	scene._hunt_active = {"session_id": "fixture", "hunt_id": "hunt_common", "zone_id": "zone_chaos", "expires_at": scene._backend.get_server_time_unix_ms() + 60000}
	scene._open_global_boss()
	if scene._hunt_fight.disabled or scene._active_hunt_matches(""):
		_fail("A different active hunt blocked the global encounter")
		return
	scene._hunt_active.clear()
	scene._hunt_active_owner = ""
	scene._world_modal.visible = false
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
	if scene._gate_remaining() <= 0 or not scene._enter_button.disabled or scene._farm_button.disabled or not scene._claim_button.disabled:
		_fail("Cooldown must block new entry and empty loot claim")
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
		if gate._zone_rows[zone].enter.disabled:
			_fail("Zone encounters are inaccessible during exploration cooldown")
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
