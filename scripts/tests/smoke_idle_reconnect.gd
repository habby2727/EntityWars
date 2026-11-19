extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("IDLE_TEST_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("isolated user directory required")
		return
	var original := OS.get_environment("IDLE_TEST_TOKEN")
	var file := FileAccess.open("user://auth.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"token": original}))
	file.close()
	var auth := (load("res://scenes/ui/Auth.tscn") as PackedScene).instantiate()
	root.add_child(auth)
	current_scene = auth
	var gate := root.get_node("ConnectionGate")
	var deadline := Time.get_ticks_msec() + 15000
	while gate.state != gate.State.IDLE and Time.get_ticks_msec() < deadline:
		await process_frame
	if gate.state != gate.State.IDLE or not gate._layer.visible or gate._retry.text != "Reconnect":
		_fail("Auth scene did not display idle overlay")
		return
	gate._retry.pressed.emit()
	while gate.state != gate.State.CONNECTED and Time.get_ticks_msec() < deadline:
		await process_frame
	if gate.state != gate.State.CONNECTED or gate.token != original or gate.player_id != OS.get_environment("IDLE_TEST_PLAYER"):
		_fail("Reconnect did not preserve and verify identity")
		return
	print("PASS reconnect from Auth with original identity")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
