extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("HUNT_RESTART_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("isolated user directory required")
		return
	var phase := OS.get_environment("HUNT_RESTART_PHASE")
	var client := BackendClient.new()
	client.auto_dev_login = false
	client.base_url = OS.get_environment("ENTITYWARS_BACKEND_URL")
	root.add_child(client)
	if phase == "first":
		client.set_token(OS.get_environment("HUNT_RESTART_TOKEN"))
		var deadline := Time.get_ticks_msec() + 20000
		while (client._verified_player_id.is_empty() or root.get_node("ConnectionGate").blocked()) and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		if client._verified_player_id.is_empty() or root.get_node("ConnectionGate").blocked():
			_fail("identity was not verified")
			return
		var session_id := OS.get_environment("HUNT_RESTART_SESSION")
		var mode := OS.get_environment("RESTART_MODE")
		if mode == "dungeon":
			SceneRouter._dungeon_context = {"run_id": session_id, "player_id": client._verified_player_id}
		else:
			SceneRouter._solo_hunt_context = {"session_id": session_id, "hunt_id": "hunt_common", "rotation_key": int(OS.get_environment("HUNT_RESTART_ROTATION")), "loadout_identity": client._verified_player_id}
		var payload: Variant = JSON.parse_string(OS.get_environment("RESTART_PAYLOAD"))
		if not payload is Dictionary or client.request_api("POST", OS.get_environment("RESTART_PATH"), payload).is_empty():
			_fail("could not submit turn")
			return
		print("POST SUBMITTED")
		return
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
		var gate := root.get_node("ConnectionGate")
		if OS.get_environment("RESTART_EXPECT_LOCK") == "1" and gate.state == gate.State.ERROR:
			if not gate.blocked() or not client.request_api("POST", "/player/action", {}).is_empty():
				_fail("invalid recovery journal allowed an action")
				return
			print("PASS invalid recovery journal remains locked")
			quit(0)
			return
		if not gate.player_id.is_empty() and not gate.blocked() and current_scene != null and current_scene.has_method("_on_online_hunt_response"):
			var journal := SessionRecoveryJournal.new()
			journal.set_identity(gate.player_id)
			var entry := journal.load_entry()
			var revision := int(current_scene._dungeon_session.get("combat_revision", 0)) if OS.get_environment("RESTART_MODE") == "dungeon" else int(current_scene._online_hunt_revision)
			var terminal := OS.get_environment("RESTART_TERMINAL") == "1"
			var forfeit := OS.get_environment("RESTART_FORFEIT") == "1"
			var expired := OS.get_environment("RESTART_EXPIRED") == "1"
			var closed_status: String = str(current_scene._dungeon_session.get("status", "")) if OS.get_environment("RESTART_MODE") == "dungeon" else str(current_scene._online_hunt_session.get("status", ""))
			var confirmed: bool = (entry.is_empty() and closed_status == ("LOSS" if terminal else "FORFEIT" if forfeit else "EXPIRED")) if terminal or forfeit or expired else (not entry.is_empty() and not entry.has("error") and entry.pending_kind == "")
			if confirmed and (forfeit or expired or revision == int(OS.get_environment("RESTART_REVISION"))):
				print("PASS recovered original hunt turn")
				quit(0)
				return
	_fail("restart did not recover the original turn")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
