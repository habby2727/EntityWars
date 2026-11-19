extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("HUNT_RESTART_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("isolated user directory required")
		return
	var phase := OS.get_environment("HUNT_RESTART_PHASE")
	var client: BackendClient
	if phase == "loadout_back":
		var auth := FileAccess.open("user://auth.json", FileAccess.WRITE)
		auth.store_string(JSON.stringify({"token": OS.get_environment("HUNT_RESTART_TOKEN")}))
		auth.close()
		SceneRouter._solo_hunt_context = {"session_id": OS.get_environment("HUNT_RESTART_SESSION"), "hunt_id": "hunt_common", "visual_zone_id": "zone_chaos"}
		SceneRouter._hunt_loadout_active = true
		change_scene_to_file(SceneRouter.SCENE_LOADOUT)
		await process_frame
		await process_frame
		var loadout = current_scene
		var limit := Time.get_ticks_msec() + 20000
		while (not loadout._hunt_recovered or root.get_node("ConnectionGate").blocked()) and Time.get_ticks_msec() < limit:
			await create_timer(0.05).timeout
		if not loadout._hunt_recovered:
			_fail("loadout did not recover")
			return
		loadout._on_hunt_back()
		while current_scene == loadout and Time.get_ticks_msec() < limit:
			await create_timer(0.05).timeout
		var journal := SessionRecoveryJournal.new()
		journal.set_identity(OS.get_environment("HUNT_RESTART_PLAYER"))
		if current_scene == null or current_scene.scene_file_path != SceneRouter.SCENE_WORLD_ZONE_CHAOS or not journal.load_entry().is_empty():
			_fail("loadout Back did not close the session and return to its zone")
			return
		print("PASS loadout Back closed original hunt")
		quit(0)
		return
	if phase == "first":
		client = BackendClient.new()
		client.auto_dev_login = false
		client.base_url = OS.get_environment("ENTITYWARS_BACKEND_URL")
		root.add_child(client)
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
	if change_scene_to_file("res://scenes/ui/Auth.tscn") != OK:
		_fail("could not open Auth")
		return
	await scene_changed
	if current_scene == null or current_scene.scene_file_path != "res://scenes/ui/Auth.tscn":
		_fail("restart did not start at Auth")
		return
	client = current_scene.client
	var deadline := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var gate := root.get_node("ConnectionGate")
		if current_scene != null and current_scene.scene_file_path in ["res://scenes/MainMenu.tscn", "res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_startup.tscn"]:
			_fail("entered menu or loading before recovery")
			return
		if not gate.player_id.is_empty() and gate.player_id != OS.get_environment("HUNT_RESTART_PLAYER"):
			_fail("verified the wrong account")
			return
		if OS.get_environment("RESTART_EXPECT_LOCK") == "1" and gate.state == gate.State.ERROR:
			if not gate.blocked() or not client.request_api("POST", "/player/action", {}).is_empty():
				_fail("invalid recovery journal allowed an action")
				return
			await create_timer(1.0).timeout
			if not gate.blocked() or current_scene == null or current_scene.scene_file_path != "res://scenes/ui/Auth.tscn":
				_fail("invalid recovery journal did not remain locked at Auth")
				return
			print("PASS invalid recovery journal remains locked")
			quit(0)
			return
		if OS.get_environment("RESTART_FORFEIT") == "1" and not gate.player_id.is_empty() and not gate.blocked() and current_scene != null and current_scene.scene_file_path in [SceneRouter.SCENE_WORLD_GATE, SceneRouter.SCENE_WORLD_ZONE, SceneRouter.SCENE_WORLD_ZONE_CHAOS, SceneRouter.SCENE_WORLD_ZONE_CORRUPTED, SceneRouter.SCENE_WORLD_ZONE_CRYSTAL]:
			var journal := SessionRecoveryJournal.new()
			journal.set_identity(gate.player_id)
			if journal.load_entry().is_empty():
				print("PASS recovered original hunt turn")
				quit(0)
				return
		if not gate.player_id.is_empty() and not gate.blocked() and current_scene != null and current_scene.has_method("_on_online_hunt_response"):
			var journal := SessionRecoveryJournal.new()
			journal.set_identity(gate.player_id)
			var entry := journal.load_entry()
			var revision := int(current_scene._dungeon_session.get("combat_revision", 0)) if OS.get_environment("RESTART_MODE") == "dungeon" else int(current_scene._online_hunt_revision)
			var terminal := OS.get_environment("RESTART_TERMINAL") == "1"
			var win := OS.get_environment("RESTART_WIN") == "1"
			var defeat := OS.get_environment("RESTART_DEFEAT") == "1"
			var forfeit := OS.get_environment("RESTART_FORFEIT") == "1"
			var expired := OS.get_environment("RESTART_EXPIRED") == "1"
			var closed_status: String = str(current_scene._dungeon_session.get("status", "")) if OS.get_environment("RESTART_MODE") == "dungeon" else str(current_scene._online_hunt_session.get("status", ""))
			var confirmed: bool = (entry.is_empty() and closed_status == ("VERIFIED_WIN" if win else "VERIFIED_LOSS" if defeat else "LOSS" if terminal else "FORFEIT" if forfeit else "EXPIRED")) if win or defeat or terminal or forfeit or expired else (not entry.is_empty() and not entry.has("error") and entry.pending_kind == "")
			if confirmed and (forfeit or expired or revision == int(OS.get_environment("RESTART_REVISION"))):
				if win and (str(current_scene._solo_context.get("session_id", "")) != OS.get_environment("HUNT_RESTART_SESSION") or current_scene._combat_identity != OS.get_environment("HUNT_RESTART_PLAYER")):
					_fail("victory recovered a different player or session")
					return
				if win and (not current_scene._online_hunt_info.visible or "VICTORY" not in current_scene._online_hunt_info.text or "essence" not in current_scene._online_hunt_info.text.to_lower()):
					_fail("recovered victory or reward was not displayed: " + current_scene._online_hunt_info.text)
					return
				if defeat and (not current_scene._online_hunt_info.visible or "DEFEAT" not in current_scene._online_hunt_info.text):
					_fail("recovered defeat was not displayed: " + current_scene._online_hunt_info.text)
					return
				print("PASS recovered original hunt turn")
				quit(0)
				return
	_fail("restart did not recover the original turn")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
