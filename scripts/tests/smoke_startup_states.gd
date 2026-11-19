extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("STARTUP_TEST_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("isolated user directory required")
		return
	var file := FileAccess.open("user://auth.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"token": "saved-token"}))
	file.close()
	var auth := (load("res://scenes/ui/Auth.tscn") as PackedScene).instantiate()
	root.add_child(auth)
	current_scene = auth
	if auth._auth_center.visible:
		_fail("authentication panel flashed before verification")
		return
	var gate := root.get_node("ConnectionGate")
	var phase := OS.get_environment("STARTUP_TEST_PHASE")
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if phase == "valid" and current_scene != auth:
			if gate.token != "saved-token" or gate.player_id != "owner":
				_fail("valid identity changed")
				return
			print("PASS startup valid")
			quit(0)
			return
		if current_scene != auth:
			_fail("unexpected scene transition")
			return
		if phase == "401" and gate.state == gate.State.AUTH_REQUIRED and not auth.verifying:
			if not auth._auth_center.visible or not auth.tabs.visible or not auth.client.token.is_empty():
				_fail("401 did not show login")
				return
			print("PASS startup 401")
			quit(0)
			return
		if phase == "426" and gate.state == gate.State.UPDATE_REQUIRED:
			await process_frame
			if not auth._auth_center.visible or auth.tabs.visible or auth.client.token != "saved-token":
				_fail("426 did not show update only")
				return
			print("PASS startup 426")
			quit(0)
			return
		if phase == "idle" and gate.state == gate.State.IDLE:
			if auth._auth_center.visible or not gate._layer.visible or gate.token != "saved-token":
				_fail("idle overlay or token")
				return
			print("PASS startup idle")
			quit(0)
			return
		if phase in ["503", "offline"] and Time.get_ticks_msec() > deadline - 7000:
			if auth._auth_center.visible or auth.client.token != "saved-token" or gate.state == gate.State.AUTH_REQUIRED:
				_fail("transient failure exposed login or cleared token")
				return
			print("PASS startup ", phase)
			quit(0)
			return
	_fail("startup phase timed out: " + phase)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
