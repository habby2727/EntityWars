extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var expected_profile := OS.get_environment("FOREST_TEST_PROFILE").replace("\\", "/").to_lower()
	if expected_profile.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(expected_profile):
		_fail("Godot user profile is not isolated")
		return
	print("PHASE startup profile_isolated")
	var gate = root.get_node("ConnectionGate")
	var duel = root.get_node("DuelClient")
	gate.state = gate.State.CONNECTED
	gate.player_id = OS.get_environment("FOREST_TWO_ID")
	gate.token = OS.get_environment("FOREST_TWO_TOKEN")
	gate.base_url = OS.get_environment("FOREST_TWO_URL")
	SceneRouter._forest_owner = gate.player_id
	SceneRouter._forest_summoner = "wizard"
	var world = load("res://scenes/forest/ForestWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec() + 45000
	while (not is_instance_valid(world._presence) or not world._presence.entered or not duel.enabled) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not is_instance_valid(world._presence) or not world._presence.entered or not duel.enabled:
		_fail("Forest or duel service unavailable")
		return
	print("PHASE entered")
	deadline = Time.get_ticks_msec() + 15000
	var other := OS.get_environment("FOREST_TWO_OTHER")
	if OS.get_environment("FOREST_DUEL_ROLE") == "0":
		while not world._remotes.has(other) and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
		if not duel.request_duel(other):
			_fail("Challenge did not start")
			return
		while (duel.cooldown_seconds(other) <= 30 or duel.incoming.is_empty()) and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
		if duel.cooldown_seconds(other) <= 30 or duel.incoming.is_empty():
			_fail("Decline cooldown or reverse challenge missing")
			return
		if not world._remotes.has(other):
			_fail("Opponent left before cooldown verification")
			return
		world._selected_remote = other
		world._update_social_remotes()
		if not world._remotes[other]._duel_action.disabled:
			_fail("Rejected challenge did not disable swords")
			return
		if not duel.respond(str(duel.incoming[0].invite_id), true):
			_fail("Reverse challenge could not be accepted")
			return
	else:
		while duel.incoming.is_empty() and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
		if duel.incoming.is_empty() or not duel.respond(str(duel.incoming[0].invite_id), false):
			_fail("Challenge could not be declined")
			return
		while (duel._mutation_busy or not duel._pending_body.is_empty()) and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
		if not duel.request_duel(other):
			_fail("Reverse challenge did not start")
			return
		while duel._mutation_busy and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
		if not duel.error_key.is_empty():
			_fail("Reverse challenge failed: " + duel.error_key)
			return
	print("PHASE invitation")
	deadline = Time.get_ticks_msec() + 15000
	while (not is_instance_valid(current_scene) or current_scene.scene_file_path != SceneRouter.SCENE_LOADOUT) and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	if not is_instance_valid(current_scene) or current_scene.scene_file_path != SceneRouter.SCENE_LOADOUT:
		_fail("Friendly loadout not opened")
		return
	if not current_scene.ranked_queue.friendly:
		_fail("Wrong loadout mode")
		return
	print("PHASE loadout")
	deadline = Time.get_ticks_msec() + 15000
	var loadout = current_scene
	for backend in [loadout._spell_backend, loadout.ranked_queue.backend]:
		backend._invalidate_session()
		backend.base_url = gate.base_url
		backend.token = gate.token
		backend.refresh_state()
	while (not loadout._spell_synced or not loadout.ranked_queue.synced or loadout._spell_backend._verified_player_id != gate.player_id or loadout.ranked_queue.backend._verified_player_id != gate.player_id) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._spell_synced or not loadout.ranked_queue.synced:
		_fail("Loadout identity did not synchronize")
		return
	loadout.ranked_queue._join()
	if duel._pending_body.is_empty() and not loadout.ranked_queue.queued:
		_fail("READY did not start: " + loadout.ranked_queue.info.text)
		return
	while (not is_instance_valid(current_scene) or current_scene.scene_file_path != SceneRouter.SCENE_COMBAT) and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	if not is_instance_valid(current_scene) or current_scene.scene_file_path != SceneRouter.SCENE_COMBAT:
		_fail("Friendly combat not opened")
		return
	if not current_scene._ranked_controller.friendly:
		_fail("Wrong combat mode")
		return
	print("PHASE combat")
	deadline = Time.get_ticks_msec() + 20000
	var controller = current_scene._ranked_controller
	var match_id: String = SceneRouter._ranked_context.match_id
	controller.backend._invalidate_session()
	controller.backend.base_url = gate.base_url
	controller.backend.token = gate.token
	controller.backend.refresh_state()
	while (controller.backend._verified_player_id != gate.player_id or str(controller.state.get("status", "")) != "ACTIVE") and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if controller.backend._verified_player_id != gate.player_id or str(controller.state.get("status", "")) != "ACTIVE":
		_fail("Friendly combat did not recover authenticated state: verified=%s expected=%s status=%s gate=%s header=%s" % [controller.backend._verified_player_id, gate.player_id, str(controller.state.get("status", "")), gate.state, controller.header.text])
		return
	if OS.get_environment("FOREST_DUEL_ROLE") == "0":
		controller.chat_input.text = "fixture duel chat"
		controller._send_chat()
	while controller.chat_cursor == 0 and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	if controller.chat_cursor == 0 or not controller.chat_log.get_parsed_text().contains("fixture duel chat"):
		_fail("Friendly match chat not delivered")
		return
	controller._submit_decision({"turn":1,"spell_id":controller.state.player.spell_ids[0]})
	while int(controller.state.get("combat_revision", 0)) < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if int(controller.state.get("combat_revision", 0)) < 2:
		_fail("Friendly decisions did not resolve")
		return
	if OS.get_environment("FOREST_DUEL_ROLE") == "0":
		while not controller.request_id.is_empty() and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
		controller.forfeit()
	while str(controller.state.get("status", "")) != "FINISHED" and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	if str(controller.state.get("status", "")) != "FINISHED" or controller.state.get("result", {}).has("mp_delta"):
		_fail("Friendly forfeit or result failed")
		return
	print("PHASE finished")
	deadline = Time.get_ticks_msec() + 10000
	controller.return_to_loadout()
	while (not is_instance_valid(current_scene) or current_scene.scene_file_path != SceneRouter.SCENE_FOREST_WORLD) and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	if not is_instance_valid(current_scene) or current_scene.scene_file_path != SceneRouter.SCENE_FOREST_WORLD:
		_fail("Forest return failed")
		return
	print("FRIENDLY_HTTP_PASS ", match_id)
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
