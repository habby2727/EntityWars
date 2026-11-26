extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GlobalChatClient").set_process(false)
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.player_id = "concurrent-test"
	gate.token = "test"
	gate.base_url = "https://example.invalid"
	var client = load("res://scripts/tests/core_defense_concurrent_client.gd").new()
	root.add_child(client)
	client.request("/forest/core-defense/match/deploy", {"slot":0})
	await process_frame
	assert(client._request_busy and client.mutation_pending)
	var result: Dictionary = await client.request("/forest/core-defense/match/state?new")
	assert(result.code == 200 and client.mutation_pending and client._request_busy)
	client.request("/forest/core-defense/match/state?old")
	await create_timer(0.03).timeout
	await client.request("/forest/core-defense/match/state?new")
	await create_timer(0.35).timeout
	assert(not client._request_busy and client.server_time_ms == 1700000001000)
	client.queue_free()
	print("CORE_DEFENSE_CONCURRENT_REQUESTS_PASS")
	quit()
