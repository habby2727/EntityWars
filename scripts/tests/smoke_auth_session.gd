extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("AUTH_SMOKE_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("isolated user directory required")
		return
	var phase := OS.get_environment("AUTH_SMOKE_PHASE")
	var gate := root.get_node("ConnectionGate")
	if phase == "invalid":
		var file := FileAccess.open("user://auth.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"token": "invalid", "dev_name": "SmokeUser"}))
		file.close()
	var auth := (load("res://scenes/ui/Auth.tscn") as PackedScene).instantiate()
	root.add_child(auth)
	current_scene = auth
	await process_frame
	if phase == "register":
		var preflight_deadline := Time.get_ticks_msec() + 10000
		while not auth.preflight_ok and Time.get_ticks_msec() < preflight_deadline:
			await process_frame
		if not auth.preflight_ok:
			_fail("version preflight failed")
			return
		if auth.verifying:
			_fail("unexpected cached session")
			return
		auth.username[1].text = "SmokeUser"
		auth.password[1].text = "secret1"
		auth.confirm.text = "secret1"
		auth.tabs.current_tab = 1
		auth._submit(1)
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if phase in ["register", "cached"] and current_scene != auth:
			if current_scene.scene_file_path != "res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_startup.tscn" or gate.blocked() or gate.player_id.is_empty():
				_fail("entered wrong scene or entered without verified gate")
				return
			print("PASS auth ", phase)
			quit(0)
			return
		if phase == "invalid" and not auth.verifying and auth.tabs.visible and auth.client.token.is_empty():
			print("PASS invalid token returns to login")
			quit(0)
			return
		if phase == "offline" and not auth._auth_center.visible and not auth.preflight_ok and not auth.client.token.is_empty():
			print("PASS offline session remains locked")
			quit(0)
			return
	_fail("auth phase timed out: " + phase)

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
