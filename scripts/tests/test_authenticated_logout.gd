extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var isolated := OS.get_environment("ACCOUNT_TEST_ROOT").replace("\\", "/").to_lower()
	assert(not isolated.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(isolated + "/"))
	var a := OS.get_environment("ACCOUNT_A_ID")
	var b := OS.get_environment("ACCOUNT_B_ID")
	var client := BackendClient.new()
	client.auto_dev_login = false
	client.auto_flush = false
	if OS.get_environment("ACCOUNT_RESTART") == "1":
		client._load_auth()
		assert(client.token == OS.get_environment("ACCOUNT_B_TOKEN"))
		assert(client.load_cached_state().is_empty())
		assert(client._reconcile.set_identity(b))
		assert(client.load_cached_state().wallet.essence == 20)
		client._reconcile.clear_identity()
		assert(client._reconcile.set_identity(a))
		assert(client.load_cached_state().wallet.essence == 10)
		client.token = OS.get_environment("ACCOUNT_A_RETURN_TOKEN")
		client._save_auth()
		client._debug_flags.free()
		client.free()
		print("AUTHENTICATED_LOGOUT_RESTART_PASS")
		quit(0)
		return
	var gate := root.get_node("ConnectionGate")
	gate.player_id = a
	gate.token = OS.get_environment("ACCOUNT_A_TOKEN")
	gate.base_url = OS.get_environment("ENTITYWARS_BACKEND_URL")
	gate.state = gate.State.CONNECTED
	client.token = gate.token
	client._verified_player_id = a
	assert(client._reconcile.set_identity(a))
	assert(client._reconcile.apply_server_state({"player_id":a, "state_revision":1, "wallet":{"essence":10}}))
	client._save_auth()
	var settings = load("res://scenes/ui/Settings.tscn").instantiate()
	root.add_child(settings)
	current_scene = settings
	await process_frame
	assert(gate.explicit_logout_safe())
	settings._logout()
	var deadline := Time.get_ticks_msec() + 15000
	while current_scene == settings and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	assert(current_scene != settings and SceneRouter.logout_notice.is_empty())
	assert(gate.player_id.is_empty() and gate.token.is_empty())
	var saved := BackendClient.new()
	saved._load_auth()
	assert(saved.token.is_empty())
	assert(saved._reconcile.set_identity(b))
	assert(saved.load_cached_state().is_empty())
	assert(saved._reconcile.apply_server_state({"player_id":b, "state_revision":1, "wallet":{"essence":20}}))
	saved.token = OS.get_environment("ACCOUNT_B_TOKEN")
	saved._save_auth()
	saved._debug_flags.free()
	saved.free()
	client._debug_flags.free()
	client.free()
	print("AUTHENTICATED_LOGOUT_PASS")
	quit(0)
