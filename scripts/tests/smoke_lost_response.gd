extends SceneTree

const ACTION_ID := "lost-forge-action"
var client: BackendClient
var restart := false
var sent := 0
var finished := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var url := OS.get_environment("LOST_RESPONSE_URL")
	var user_root := OS.get_environment("FORGE_SMOKE_USER_ROOT").replace("\\", "/").to_lower()
	if not url.begins_with("http://127.0.0.1:") or user_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(user_root + "/"):
		_fail("Isolation missing")
		return
	restart = OS.get_environment("LOST_RESPONSE_RESTART") == "1"
	client = BackendClient.new()
	client.base_url = url
	client.auto_dev_login = false
	client.auto_flush = restart
	client.state_updated.connect(_state_updated)
	client.action_sent.connect(func(id, _key):
		if id == ACTION_ID:
			sent += 1)
	client.action_uncertain.connect(_uncertain)
	client.action_confirmed.connect(_confirmed)
	client.action_failed.connect(func(_id, error): _fail("Unexpected rejection: " + error))
	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.timeout.connect(func(): _fail("Timeout"))
	client.add_child(timeout)
	root.add_child(client)
	timeout.start(80.0)
	if not restart:
		client.login_dev("lost_response_smoke")

func _state_updated(state: Dictionary) -> void:
	if state.is_empty() or restart or sent > 0:
		return
	if int(state.get("wallet", {}).get("essence", -1)) != 100:
		_fail("Initial balance mismatch")
		return
	var original_url := client.base_url
	client.base_url = "invalid://"
	var unsent := client.send_action({"action_type": "FORGE_UPGRADE", "client_action_id": "unsent-action", "payload": {"item_id": "bismuth_talisman"}})
	client.base_url = original_url
	if not unsent.is_empty() or client.get_pending_count() != 0:
		_fail("Action that could not be sent was retained")
		return
	var id := client.send_action({"action_type": "FORGE_UPGRADE", "client_action_id": ACTION_ID, "payload": {"item_id": "bismuth_talisman"}})
	if id != ACTION_ID:
		_fail("Could not send action")
		return
	var duplicate := client.send_action({"action_type": "FORGE_UPGRADE", "payload": {"item_id": "bismuth_talisman"}})
	if duplicate != ACTION_ID or sent != 1 or client.get_pending_count() != 1:
		_fail("Double submission was not deduplicated")

func _uncertain(id: String, _reason: String) -> void:
	if restart or id != ACTION_ID or client.get_pending_count() != 1:
		_fail("Uncertain operation was not retained")
		return
	var entry: Dictionary = client.get_pending_actions()[0]
	if entry.get("_recovery", {}).get("status") != "UNCERTAIN" or entry.get("_recovery", {}).get("player_id") != client._verified_player_id:
		_fail("Uncertain operation has incorrect owner or status")
		return
	var owner := client._verified_player_id
	var owner_generation := client._session_generation
	if not _owner_pending_is_intact(owner):
		_fail("A pending file was not persisted")
		return
	_snapshot("A before switch", owner)
	client.login_dev("combat_account_b")
	var verified_b := await _wait_identity()
	_snapshot("B", owner)
	if not verified_b or client._verified_player_id == owner or client._session_generation <= owner_generation or client.get_pending_count() != 0 or not _owner_pending_is_intact(owner):
		_fail("Uncertain action leaked into account B")
		return
	var b_token: String = client.token
	client.login_dev("lost_response_smoke")
	var b_generation := client._session_generation
	var verified_a := await _wait_identity()
	_snapshot("A after return", owner)
	if not verified_a or client._verified_player_id != owner or client._session_generation <= b_generation or client.get_pending_count() != 1 or not _owner_pending_is_intact(owner) or str(client.get_pending_actions()[0].get("client_action_id", "")) != ACTION_ID:
		_fail("Uncertain action was not restored to account A")
		return
	if not await _check_journal_blocks_switch(owner, b_token):
		return
	print("PASS response lost; uncertain action isolated A/B/A")
	finished = true
	client.queue_free()
	quit(0)

func _snapshot(label: String, owner: String) -> void:
	var gate := root.get_node("ConnectionGate")
	var path := "user://pending_actions_%s.json" % owner.sha256_text()
	var content := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"
	print("A/B/A ", label, " client_id=", client._verified_player_id, " generation=", client._session_generation, " token_present=", not client.token.is_empty(), " http_status=", client._http.get_http_client_status(), " http_meta=", client._http.get_meta("request_meta", {}), " gate_id=", gate.player_id, " gate_state=", gate.state, " gate_generation=", gate._generation, " gate_checking=", gate._checking, " pending=", client.get_pending_count(), " owner_file=", content)

func _owner_pending_is_intact(owner: String) -> bool:
	var path := "user://pending_actions_%s.json" % owner.sha256_text()
	if not FileAccess.file_exists(path): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("actions") is Array or data.actions.size() != 1: return false
	var action: Dictionary = data.actions[0]
	return action.get("client_action_id") == ACTION_ID and action.get("_recovery", {}).get("player_id") == owner and action.get("_recovery", {}).get("status") == "UNCERTAIN"

func _check_journal_blocks_switch(owner: String, b_token: String) -> bool:
	var journal := SessionRecoveryJournal.new()
	journal.set_identity(owner)
	var entry := {"version": 1, "mode": "hunt", "player_id": owner, "session_id": "fixture-session", "context": {}, "pending_kind": "", "payload": {}}
	if not journal.save_entry(entry):
		_fail("Could not create isolated journal fixture")
		return false
	var saved_token: String = client.token
	var gate := root.get_node("ConnectionGate")
	if not gate.begin_explicit_login():
		_fail("Could not start journal switch check")
		return false
	client.set_token(b_token)
	var deadline := Time.get_ticks_msec() + 25000
	while not gate._identity_mismatch and Time.get_ticks_msec() < deadline:
		await process_frame
	_snapshot("journal switch", owner)
	if not gate._identity_mismatch or not gate.blocked() or not client.request_api("POST", "/player/action", {}).is_empty() or not _owner_pending_is_intact(owner):
		_fail("Active journal did not block the other account")
		return false
	if not journal.remove():
		_fail("Could not remove isolated journal fixture")
		return false
	client.set_token(saved_token)
	print("PASS active journal blocks switching accounts")
	return true

func _wait_identity() -> bool:
	var deadline := Time.get_ticks_msec() + 25000
	var gate := root.get_node("ConnectionGate")
	while (client._verified_player_id.is_empty() or gate.blocked() or gate.player_id != client._verified_player_id) and Time.get_ticks_msec() < deadline:
		await process_frame
	return not client._verified_player_id.is_empty() and not gate.blocked() and gate.player_id == client._verified_player_id

func _confirmed(id: String) -> void:
	if not restart or id != ACTION_ID or sent != 1:
		_fail("Unexpected confirmation")
		return
	var state := client.load_cached_state()
	if int(state.get("item_progress", {}).get("bismuth_talisman", {}).get("level", 0)) != 1 or int(state.get("wallet", {}).get("essence", -1)) != 80 or client.get_pending_count() != 0:
		_fail("Recovery duplicated or failed to persist the upgrade")
		return
	print("PASS restart recovery: original ID, level 1, essence 80, queue empty")
	finished = true
	client.queue_free()
	quit(0)

func _fail(message: String) -> void:
	if not finished:
		finished = true
		push_error("LOST_RESPONSE_FAIL: " + message)
		quit(1)
