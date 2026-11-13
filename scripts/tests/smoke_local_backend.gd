extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := OS.get_environment("LOCAL_BACKEND_TEST_DIR").replace("\\", "/")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/"):
		push_error("Local backend test requires isolated user data")
		quit(1)
		return
	var client := BackendClient.new()
	client.auto_dev_login = false
	client.auto_flush = false
	root.add_child(client)
	var suffix := Crypto.new().generate_random_bytes(8).hex_encode()
	var name_a := "godot_local_a_" + suffix
	var name_b := "godot_local_b_" + suffix
	client.login_dev(name_a)
	if not await _wait_verified(client):
		return
	var account_a := client._verified_player_id
	client.login_dev(name_b)
	if not await _wait_verified(client):
		return
	var account_b := client._verified_player_id
	client.login_dev(name_a)
	if not await _wait_verified(client):
		return
	if account_a.is_empty() or account_b == account_a or client._verified_player_id != account_a or str(client._reconcile.get_state().get("player_id", "")) != account_a:
		push_error("Account-scoped local identity mismatch")
		quit(1)
		return
	print("PASS Godot BackendClient local login and A/B/A identity")
	client.queue_free()
	await process_frame
	quit(0)

func _wait_verified(client: BackendClient) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while client._verified_player_id.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if client._verified_player_id.is_empty():
		push_error("Local backend login timed out")
		quit(1)
		return false
	return true
