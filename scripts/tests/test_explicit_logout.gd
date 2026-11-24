extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_root := OS.get_environment("ACCOUNT_TEST_ROOT").replace("\\", "/").to_lower()
	assert(not test_root.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"))
	if OS.get_environment("LOGOUT_TEST_RESTART") == "1":
		var restarted := BackendClient.new()
		restarted._load_auth()
		assert(restarted.token == "token-b")
		assert(restarted.load_cached_state().is_empty())
		assert(restarted._reconcile.set_identity("account-b"))
		assert(restarted.load_cached_state().wallet.essence == 20)
		assert(BackendClient.clear_saved_token())
		restarted._reconcile.clear_identity()
		assert(restarted._reconcile.set_identity("account-a"))
		assert(restarted.load_cached_state().wallet.essence == 10)
		restarted._debug_flags.free()
		restarted.free()
		print("EXPLICIT_LOGOUT_RESTART_PASS")
		quit()
		return
	var gate := root.get_node("ConnectionGate")
	var chat := root.get_node("GlobalChatClient")
	var social := root.get_node("SocialClient")
	var duel := root.get_node("DuelClient")
	var scene := Control.new()
	root.add_child(scene)
	current_scene = scene
	var client := BackendClient.new()
	client.auto_dev_login = false
	client.auto_flush = false
	scene.add_child(client)
	gate.player_id = "account-a"
	gate.token = "token-a"
	gate.base_url = "http://127.0.0.1:1"
	client.token = gate.token
	client._verified_player_id = gate.player_id
	assert(client._reconcile.set_identity("account-a"))
	assert(client._reconcile.apply_server_state({"player_id":"account-a", "state_revision":1, "wallet":{"essence":10}}))
	client._last_login_name = "Alice"
	client._save_auth()
	var old_generation: int = gate._generation
	var old_epoch: int = chat._epoch
	var old_social_epoch: int = social._epoch
	var old_duel_epoch: int = duel._epoch
	var old_http: HTTPRequest = gate._http
	var old_client_http: HTTPRequest = client._http
	var journal := FileAccess.open("user://session_recovery_test.json", FileAccess.WRITE)
	journal.store_string("pending")
	journal.close()
	assert(not gate.explicit_logout_safe())
	assert(FileAccess.file_exists("user://session_recovery_test.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://session_recovery_test.json"))
	client._pending.enqueue({"client_action_id":"unresolved"})
	assert(not gate.explicit_logout_safe())
	client._pending.clear_identity()
	assert(gate.explicit_logout_safe())
	chat.messages = [{"text":"private-a"}]
	social.friends = {"friend-a":"Alice"}
	duel.incoming = [{"id":"private-a"}]
	assert(BackendClient.clear_saved_token())
	gate.explicit_logout_reset()
	assert(gate.player_id.is_empty() and gate.token.is_empty() and gate._generation > old_generation)
	assert(gate._http != old_http and client._http == null)
	assert(not old_http.request_completed.is_connected(gate._on_check_completed))
	assert(not old_client_http.request_completed.is_connected(client._on_request_completed))
	assert(client.token.is_empty() and client.load_cached_state().is_empty())
	assert(chat.messages.is_empty() and social.friends.is_empty() and duel.incoming.is_empty())
	var file := FileAccess.open(BackendClient.AUTH_PATH, FileAccess.READ)
	var auth: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert(not auth.has("token") and auth.dev_name == "Alice")
	chat._poll_completed(HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), PackedByteArray(), old_epoch)
	social._poll_completed(HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), PackedByteArray(), old_social_epoch)
	duel._poll_completed(HTTPRequest.RESULT_SUCCESS, 401, PackedStringArray(), PackedByteArray(), old_duel_epoch)
	assert(gate.state == gate.State.CONNECTED)
	assert(client._reconcile.set_identity("account-b"))
	assert(client.load_cached_state().is_empty())
	assert(client._reconcile.apply_server_state({"player_id":"account-b", "state_revision":1, "wallet":{"essence":20}}))
	client._reconcile.clear_identity()
	assert(client._reconcile.set_identity("account-a"))
	assert(client.load_cached_state().wallet.essence == 10)
	client.token = "token-b"
	client._save_auth()
	print("EXPLICIT_LOGOUT_ISOLATION_PASS")
	quit()
