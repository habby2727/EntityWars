extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("FOREST_MEMORY_TEST_ROOT").replace("\\", "/").to_lower()
	assert(not test_root.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"))
	root.get_node("GlobalChatClient").set_process(false)
	root.get_node("SocialClient").set_process(false)
	var gate = root.get_node("ConnectionGate")
	gate.state = gate.State.CONNECTED
	gate.player_id = "forest-memory-one"
	gate.token = "fixture-token"
	gate._timer.stop()
	SceneRouter.clear_account_context()
	SceneRouter.go_to_summoner_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_SUMMONER_SELECTION)
	SceneRouter.enter_forest("witch")
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD)
	SceneRouter.clear_account_context()
	SceneRouter.go_to_summoner_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD and SceneRouter.forest_selected_summoner() == "witch")
	SceneRouter.enter_forest("wizard")
	await process_frame
	await process_frame
	SceneRouter.clear_account_context()
	SceneRouter.go_to_summoner_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD and SceneRouter.forest_selected_summoner() == "wizard")
	SceneRouter.clear_account_context()
	gate.player_id = "forest-memory-two"
	SceneRouter.go_to_summoner_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_SUMMONER_SELECTION and SceneRouter.forest_selected_summoner().is_empty())
	var config := ConfigFile.new()
	assert(config.load(SceneRouter.FOREST_PREFERENCES) == OK)
	config.set_value("players", gate.player_id.sha256_text(), "invalid")
	assert(config.save(SceneRouter.FOREST_PREFERENCES) == OK)
	SceneRouter.go_to_summoner_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_SUMMONER_SELECTION)
	assert(gate.enable_debug_lab())
	SceneRouter.clear_account_context()
	SceneRouter.go_to_summoner_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_SUMMONER_SELECTION)
	SceneRouter.enter_forest("cyberghost")
	await process_frame
	await process_frame
	SceneRouter.clear_account_context()
	SceneRouter.go_to_summoner_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD and SceneRouter.forest_selected_summoner() == "cyberghost")
	current_scene._change_summoner()
	for i in 8:
		await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_SUMMONER_SELECTION)
	current_scene._select("witch")
	current_scene._confirm_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD and SceneRouter.forest_selected_summoner() == "witch")
	SceneRouter.clear_account_context()
	SceneRouter.go_to_summoner_selection()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD and SceneRouter.forest_selected_summoner() == "witch")
	print("PASS forest summoner memory")
	quit()
