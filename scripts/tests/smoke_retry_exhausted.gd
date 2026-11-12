extends SceneTree

var client: BackendClient
var count := 0
var started := false
var finished := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var url := OS.get_environment("LOST_RESPONSE_URL")
	var user_root := OS.get_environment("FORGE_SMOKE_USER_ROOT").replace("\\", "/").to_lower()
	if not url.begins_with("http://127.0.0.1:") or user_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(user_root + "/"):
		_fail("Isolation missing")
		return
	client = BackendClient.new()
	client.base_url = url
	client.auto_dev_login = false
	client.state_updated.connect(_on_state)
	client.action_uncertain.connect(func(id, _reason):
		if id == "retry-500": count += 1)
	client.action_failed.connect(func(_id, reason): _fail("Unexpected rejection: " + reason))
	root.add_child(client)
	await create_timer(10.0).timeout
	if not started or count != 4 or int(client._recovery_attempts.get("retry-500", -1)) != 3 or client.get_pending_count() != 1:
		_fail("Retry limit or persistent uncertain state incorrect: %d" % count)
		return
	var state := client.load_cached_state()
	if int(state.get("wallet", {}).get("essence", -1)) != 80 or int(state.get("item_progress", {}).get("bismuth_talisman", {}).get("level", 0)) != 1:
		_fail("HTTP 500 changed confirmed state")
		return
	finished = true
	print("PASS HTTP 500 uncertain, three retries, bounded and retained")
	client.queue_free()
	await process_frame
	quit(0)

func _on_state(state: Dictionary) -> void:
	if started or state.is_empty():
		return
	started = true
	if client.send_action({"action_type": "FORGE_UPGRADE", "client_action_id": "retry-500", "payload": {"item_id": "bismuth_talisman"}}) != "retry-500":
		_fail("Could not send test action")

func _fail(message: String) -> void:
	if not finished:
		finished = true
		push_error("RETRY_SMOKE_FAIL: " + message)
		quit(1)
