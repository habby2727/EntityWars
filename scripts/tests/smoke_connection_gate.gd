extends SceneTree

var _fault_server: TCPServer
var _fault_peer: StreamPeerTCP
var _fault_code := 500
var _fault_body := "{}"

func _process(_delta: float) -> bool:
	if _fault_server != null:
		if _fault_peer == null and _fault_server.is_connection_available():
			_fault_peer = _fault_server.take_connection()
		if _fault_peer != null:
			_fault_peer.poll()
			if _fault_peer.get_available_bytes() > 0:
				_fault_peer.get_data(_fault_peer.get_available_bytes())
				var response := "HTTP/1.1 %d Test\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [_fault_code, _fault_body.to_utf8_buffer().size(), _fault_body]
				_fault_peer.put_data(response.to_utf8_buffer())
				_fault_peer.disconnect_from_host()
				_fault_peer = null
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_dir := OS.get_environment("GATE_TEST_ROOT").replace("\\", "/").to_lower()
	if root_dir.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(root_dir + "/"):
		push_error("Isolated user directory required")
		quit(1)
		return
	var gate := root.get_node("ConnectionGate")
	var backend := BackendClient.new()
	backend.auto_dev_login = false
	root.add_child(backend)
	backend.set_token(OS.get_environment("GATE_TEST_TOKEN"))
	var deadline := Time.get_ticks_msec() + 20000
	while gate.player_id.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if gate.player_id.is_empty():
		push_error("Authenticated player was not verified")
		quit(1)
		return
	var url: String = gate.base_url
	gate.base_url = "http://127.0.0.1:1"
	gate._check()
	deadline = Time.get_ticks_msec() + 15000
	while not gate.blocked() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not gate.blocked() or not gate._layer.visible:
		push_error("Heartbeat outage did not lock gameplay")
		quit(1)
		return
	if not backend.send_action({"action_type": "TEST"}).is_empty() or not backend.request_api("POST", "/player/action", {}).is_empty():
		push_error("Locked client allowed an action")
		quit(1)
		return
	gate.base_url = url
	gate._check()
	deadline = Time.get_ticks_msec() + 20000
	while gate.blocked() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if gate.blocked() or gate._layer.visible:
		push_error("Verified heartbeat did not unlock")
		quit(1)
		return
	var valid_token: String = gate.token
	gate.authentication_changed("invalid-test-token", url)
	deadline = Time.get_ticks_msec() + 15000
	while gate.state != gate.State.AUTH_REQUIRED and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if gate.state != gate.State.AUTH_REQUIRED or not gate.blocked():
		push_error("HTTP authentication rejection did not lock")
		quit(1)
		return
	gate.authentication_changed(valid_token, url)
	deadline = Time.get_ticks_msec() + 20000
	while gate.blocked() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if gate.blocked():
		push_error("Valid authentication did not recover")
		quit(1)
		return
	for code in [400, 409]:
		_fault_code = code
		_fault_body = '{"error":"rule_rejected"}'
		_fault_server = TCPServer.new()
		if _fault_server.listen(0, "127.0.0.1") != OK:
			push_error("Cannot start isolated HTTP fault fixture")
			quit(1)
			return
		backend.base_url = "http://127.0.0.1:%d" % _fault_server.get_local_port()
		var rejected := backend.request_api("GET", "/rule-test", null)
		deadline = Time.get_ticks_msec() + 15000
		while not backend._api_in_flight.is_empty() and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		_fault_server.stop()
		_fault_server = null
		backend.base_url = url
		if rejected.is_empty() or not backend._api_in_flight.is_empty() or gate.blocked():
			push_error("Game-rule rejection incorrectly locked gameplay")
			quit(1)
			return
	for fault in [[500, "{}", gate.State.RECONNECTING], [200, "invalid-json", gate.State.ERROR], [403, "{}", gate.State.AUTH_REQUIRED]]:
		_fault_code = fault[0]
		_fault_body = fault[1]
		_fault_server = TCPServer.new()
		if _fault_server.listen(0, "127.0.0.1") != OK:
			push_error("Cannot start isolated HTTP fault fixture")
			quit(1)
			return
		gate.base_url = "http://127.0.0.1:%d" % _fault_server.get_local_port()
		gate._check()
		deadline = Time.get_ticks_msec() + 15000
		while (gate._checking or not gate.blocked()) and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		_fault_server.stop()
		_fault_server = null
		if gate.state != fault[2]:
			push_error("HTTP fault %s produced unexpected state %s" % [fault[0], gate.state])
			quit(1)
			return
		gate.base_url = url
		gate._check()
		deadline = Time.get_ticks_msec() + 15000
		while gate.blocked() and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		if gate.blocked():
			push_error("HTTP fault recovery failed")
			quit(1)
			return
	gate.player_id = "different-player"
	gate._check()
	deadline = Time.get_ticks_msec() + 15000
	while gate.state != gate.State.ERROR and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if gate.state != gate.State.ERROR or not gate._identity_mismatch:
		push_error("Account mismatch did not lock")
		quit(1)
		return
	gate._identity_mismatch = false
	gate.player_id = backend._verified_player_id
	gate.base_url = url
	gate._check()
	deadline = Time.get_ticks_msec() + 15000
	while gate.blocked() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if gate.blocked():
		push_error("Fixture could not restore authenticated state")
		quit(1)
		return
	var saved_auth := FileAccess.get_file_as_string("user://auth.json")
	var journal_path := "user://session_recovery_version_qa.json"
	var journal := FileAccess.open(journal_path, FileAccess.WRITE)
	journal.store_string("version gate preservation fixture")
	journal.close()
	_fault_code = 426
	_fault_body = '{"error":"CLIENT_UPDATE_REQUIRED","min_client_build":5504}'
	_fault_server = TCPServer.new()
	if _fault_server.listen(0, "127.0.0.1") != OK:
		push_error("Cannot start 426 fixture")
		quit(1)
		return
	backend.base_url = "http://127.0.0.1:%d" % _fault_server.get_local_port()
	var update_request := backend.request_api("GET", "/player/state", null)
	deadline = Time.get_ticks_msec() + 15000
	while gate.state != gate.State.UPDATE_REQUIRED and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	_fault_server.stop()
	_fault_server = null
	gate.base_url = url
	gate._check()
	gate._unlock()
	await create_timer(2.5).timeout
	if update_request.is_empty() or gate.state != gate.State.UPDATE_REQUIRED or not gate._timer.is_stopped() or gate._checking or gate._retry.visible or not backend.send_action({"action_type": "TEST"}).is_empty() or not backend.request_api("POST", "/player/action", {}, false, true).is_empty():
		push_error("426 did not permanently block gameplay and retries")
		quit(1)
		return
	if FileAccess.get_file_as_string("user://auth.json") != saved_auth or FileAccess.get_file_as_string(journal_path) != "version gate preservation fixture":
		push_error("426 changed credentials or the recovery journal")
		quit(1)
		return
	print("PASS authenticated heartbeat, action lock, recovery, HTTP faults, identity mismatch and terminal 426")
	backend.queue_free()
	quit(0)
