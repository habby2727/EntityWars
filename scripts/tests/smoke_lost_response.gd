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
	timeout.start(20.0)
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
	client.login_dev("combat_account_b")
	if not await _wait_identity() or client._verified_player_id == owner or client.get_pending_count() != 0:
		_fail("Uncertain action leaked into account B")
		return
	client.login_dev("lost_response_smoke")
	if not await _wait_identity() or client._verified_player_id != owner or client.get_pending_count() != 1:
		_fail("Uncertain action was not restored to account A")
		return
	print("PASS response lost; uncertain action isolated A/B/A")
	finished = true
	client.queue_free()
	quit(0)

func _wait_identity() -> bool:
	var deadline := Time.get_ticks_msec() + 6000
	while client._verified_player_id.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	return not client._verified_player_id.is_empty()

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
