extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GlobalChatClient").set_process(false)
	root.get_node("SocialClient").set_process(false)
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.player_id = "startup-priority-fixture"
	gate.token = "fixture-token"
	gate.base_url = "https://example.invalid"
	var woe = root.get_node("WoeClient")
	var cd = root.get_node("CoreDefenseClient")
	woe.set_script(load("res://scripts/tests/minigame_startup_woe_client.gd"))
	cd.set_script(load("res://scripts/tests/minigame_startup_cd_client.gd"))
	var live_woe := OS.get_environment("INVUIR_STARTUP_WOE") == "1"
	woe.fixture_status = "RUNNING" if live_woe else "FINISHED"
	cd.fixture_status = "FINISHED" if live_woe else "RUNNING"
	woe.save_match("old-woe" if live_woe else "woe-fixture")
	cd.save_match("cd-fixture" if live_woe else "old-cd")
	var arena_transitions := [0]
	scene_changed.connect(func():
		if is_instance_valid(current_scene) and current_scene.scene_file_path == SceneRouter.SCENE_WOE_ARENA: arena_transitions[0] += 1)
	change_scene_to_file(SceneRouter.SCENE_MAIN_MENU)
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and (not is_instance_valid(current_scene) or current_scene.scene_file_path != SceneRouter.SCENE_WOE_ARENA):
		await process_frame
	assert(is_instance_valid(current_scene) and current_scene.scene_file_path == SceneRouter.SCENE_WOE_ARENA)
	var arena_id := current_scene.get_instance_id()
	assert(str(SceneRouter._woe_context.get("match_id", "")) == ("woe-fixture" if live_woe else "cd-fixture"))
	assert((woe.saved_match() if live_woe else cd.saved_match()) == ("woe-fixture" if live_woe else "cd-fixture"))
	await create_timer(0.5).timeout
	assert(is_instance_valid(current_scene) and current_scene.get_instance_id() == arena_id)
	assert(arena_transitions[0] == 1)
	# Startup recovery has no previous Forest position; use the account's saved
	# summoner and enter at the normal spawn rather than sending it to the lab.
	var preferences := ConfigFile.new()
	preferences.load(SceneRouter.FOREST_PREFERENCES)
	var has_summoner := OS.get_environment("INVUIR_NO_SUMMONER") != "1"
	preferences.set_value("players", str(gate.player_id).sha256_text(), "wizard" if has_summoner else "")
	assert(preferences.save(SceneRouter.FOREST_PREFERENCES) == OK)
	SceneRouter._forest_owner = ""
	SceneRouter._forest_summoner = ""
	var arena = current_scene
	arena._confirm_return()
	for child in arena.get_children():
		if child is ConfirmationDialog: child.confirmed.emit()
	deadline = Time.get_ticks_msec() + 10000
	var destination := SceneRouter.SCENE_FOREST_WORLD if has_summoner else SceneRouter.SCENE_SUMMONER_SELECTION
	while Time.get_ticks_msec() < deadline and (not is_instance_valid(current_scene) or current_scene.scene_file_path != destination):
		await process_frame
	assert(is_instance_valid(current_scene) and current_scene.scene_file_path == destination)
	assert(SceneRouter.forest_selected_summoner() == ("wizard" if has_summoner else ""))
	print("MINIGAME_STARTUP_PRIORITY_PASS ", "woe" if live_woe else "core_defense")
	quit(0)
