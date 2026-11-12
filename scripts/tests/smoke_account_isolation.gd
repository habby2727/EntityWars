extends SceneTree

var client: BackendClient
var stage := "a"
var a_id := ""
var a_state := {}
var old_generation := 0
var url := ""

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	url = OS.get_environment("FORGE_SMOKE_URL")
	var root_path := OS.get_environment("FORGE_SMOKE_USER_ROOT").replace("\\", "/").to_lower()
	if not url.begins_with("http://127.0.0.1:") or root_path.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(root_path + "/"):
		_fail("Isolation configuration missing")
		return
	create_timer(25.0).timeout.connect(func(): _fail("Timeout: " + stage))
	_new_client()
	client.login_dev("isolation_account_a")

func _new_client() -> void:
	client = BackendClient.new()
	client.base_url = url
	client.auto_dev_login = false
	client.auto_flush = false
	client.state_updated.connect(_state_updated)
	root.add_child(client)
	if not client.load_cached_state().is_empty():
		_fail("State visible before identity verification")

func _state_updated(state: Dictionary) -> void:
	if state.is_empty():
		return
	match stage:
		"a":
			a_id = str(state.get("player_id", ""))
			a_state = state.duplicate(true)
			old_generation = client._session_generation
			client._in_flight = {"fixture_busy": true}
			var id := client.send_action({"action_type": "UPGRADE_BUILDING", "client_action_id": "account-a-pending", "payload": {"building_id": "lab_th"}})
			client._in_flight.clear()
			if id != "account-a-pending" or client.get_pending_count() != 1:
				_fail("Account A pending action was not saved")
				return
			stage = "b"
			client.call_deferred("login_dev", "isolation_account_b")
		"b":
			if str(state.get("player_id", "")) == a_id or client.get_pending_count() != 0:
				_fail("Account B received A state or queue")
				return
			var b_id := str(state.get("player_id", ""))
			var b_token := client.token
			client._http.set_meta("request_meta", {"session_generation": old_generation, "kind": "login"})
			client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"token": "stale-token"}).to_utf8_buffer())
			if client.token != b_token:
				_fail("Late login replaced B token")
				return
			client._http.set_meta("request_meta", {"session_generation": old_generation, "kind": "state"})
			client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"updated_player_state": a_state}).to_utf8_buffer())
			if str(client.load_cached_state().get("player_id", "")) != b_id:
				_fail("Late A response contaminated B")
				return
			stage = "a_return"
			client.call_deferred("login_dev", "isolation_account_a")
		"a_return":
			if str(state.get("player_id", "")) != a_id or client.get_pending_count() != 1:
				_fail("Account A state or queue was not restored")
				return
			stage = "restart"
			call_deferred("_restart_client")
		"restart":
			if str(state.get("player_id", "")) != a_id or client.get_pending_count() != 1:
				_fail("Account A was not restored after client restart")
				return
			print("PASS account A/B/A, scoped queue, restart and simulated late response")
			client.queue_free()
			quit(0)

func _restart_client() -> void:
	client.queue_free()
	_new_client()

func _fail(message: String) -> void:
	push_error("ACCOUNT_SMOKE_FAIL: " + message)
	quit(1)
