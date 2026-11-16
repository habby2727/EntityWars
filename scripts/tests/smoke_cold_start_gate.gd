extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("GATE_TEST_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		_fail("isolated user directory required")
		return
	var file := FileAccess.open("user://auth.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"token": "offline-cached-token"}))
	file.close()
	var client := BackendClient.new()
	client.auto_dev_login = false
	client.base_url = "http://127.0.0.1:1"
	root.add_child(client)
	var gate := root.get_node("ConnectionGate")
	if not gate.blocked() or not client.request_api("POST", "/player/action", {}).is_empty() or not client.send_action({"action_type": "TEST"}).is_empty():
		_fail("cached credentials permitted an action before verification")
		return
	await create_timer(1.0).timeout
	if not gate.blocked() or not gate.player_id.is_empty():
		_fail("offline credentials were accepted")
		return
	print("PASS offline cached credentials remain locked")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
