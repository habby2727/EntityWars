extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("ACCOUNT_TEST_ROOT").replace("\\", "/").to_lower()
	assert(not test_root.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"))
	var gate := root.get_node("ConnectionGate")
	gate.player_id = "offline-account"
	gate.token = "offline-token"
	gate.base_url = "http://127.0.0.1:1"
	var file := FileAccess.open(BackendClient.AUTH_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"token":"offline-token", "dev_name":"Alice"}))
	file.close()
	var settings = load("res://scenes/ui/Settings.tscn").instantiate()
	root.add_child(settings)
	current_scene = settings
	await process_frame
	settings._logout()
	var deadline := Time.get_ticks_msec() + 12000
	while (not is_instance_valid(current_scene) or not current_scene.has_method("auth_gate_screen")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	assert(is_instance_valid(current_scene) and current_scene.has_method("auth_gate_screen"))
	assert(gate.player_id.is_empty() and gate.token.is_empty())
	var saved := FileAccess.open(BackendClient.AUTH_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(saved.get_as_text())
	assert(not data.has("token") and data.dev_name == "Alice")
	assert(current_scene.logout_notice.visible and current_scene.logout_notice.text == tr("AUTH_LOGOUT_UNCONFIRMED"))
	print("LOGOUT_OFFLINE_PASS")
	quit()
