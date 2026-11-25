extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = "woe-recovery-smoke"
	gate.token = "test-token"
	gate.base_url = "https://example.invalid"
	var client = load("res://scripts/tests/woe_recovery_fake_client.gd").new()
	root.add_child(client)
	assert(client._save_pending({}))
	var values := {"match_id":"old","slot":0,"card_id":"neon","lane":"left"}
	client.fail_storage = true
	var failed: Dictionary = await client.mutate("match/deploy", values)
	assert(failed.error == "WOE_RECOVERY_STORAGE" and client.bodies.is_empty())
	client.fail_storage = false
	client.responses = [{"code":0,"error":"WOE_NETWORK"}, {"code":429,"error":"RATE_LIMIT"}, {"code":408,"error":"TIMEOUT"}, {"code":503,"error":"UNAVAILABLE"}]
	await client.mutate("match/deploy", values)
	var original: Dictionary = client.saved_pending().body.duplicate(true)
	for i in range(3): await client.retry_pending()
	assert(client.saved_pending().body == original)
	for body in client.bodies: assert(body == original)
	var restarted = load("res://scripts/tests/woe_recovery_fake_client.gd").new()
	root.add_child(restarted)
	assert(restarted.saved_pending().body == original)
	assert(restarted.reconcile_missing_match("different", "MATCH_UNAVAILABLE"))
	assert(not restarted.saved_pending().is_empty())
	assert(restarted.reconcile_missing_match("old", "MATCH_UNAVAILABLE"))
	assert(restarted.saved_pending().is_empty())
	restarted.responses = [{"code":429,"error":"ACTION_LIMIT"}]
	await restarted.mutate("match/deploy", {"match_id":"new","slot":0,"card_id":"neon","lane":"left"})
	assert(restarted.saved_pending().is_empty())
	assert(restarted._save_pending({"action":"start","values":{"room_id":"old-room"},"body":{"client_action_id":"exact"}}))
	var room := {"room_id":"other-room","mode":"1v1","status":"STARTED","match_id":"new", "members":[{"player_id":gate.player_id}]}
	restarted.reconcile_started(room)
	assert(not restarted.saved_pending().is_empty())
	room.room_id = "old-room"
	restarted.reconcile_started(room)
	assert(restarted.saved_pending().is_empty())
	client.queue_free()
	restarted.queue_free()
	print("WOE_RECOVERY_SMOKE_PASS")
	quit()
