extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = "cd-recovery-smoke"
	gate.token = "test-token"
	gate.base_url = "https://example.invalid"
	var client = load("res://scripts/tests/core_defense_fake_client.gd").new()
	root.add_child(client)
	client._persist_pending({})
	client._save_forfeit_action({})
	client.server_time_ms = 1700000000000
	client.server_tick_ms = Time.get_ticks_msec()
	var values := {"match_id":"m","slot":0,"card_id":"neon","lane":"left"}
	client.responses = [{"code":0,"error":"WOE_NETWORK"},{"code":200,"data":{"accepted":true,"match_id":"m"}}]
	var first: Dictionary = await client.mutate("match/deploy",values)
	assert(first.code == 0 and not client.saved_pending().is_empty())
	var saved: Dictionary = client.saved_pending()
	assert(str(saved.body.client_action_id).begins_with("1700000000") and str(saved.body.client_action_id).contains(":"))
	var second: Dictionary = await client.retry_pending()
	assert(second.code == 200 and client.saved_pending().is_empty() and client.bodies[0] == client.bodies[1])
	client.responses = [{"code":0,"error":"WOE_NETWORK"},{"code":409,"error":"ACTION_EXPIRED"}]
	await client.mutate("match/deploy",values)
	var expired: Dictionary = await client.retry_pending()
	assert(expired.error == "ACTION_EXPIRED" and client.saved_pending().is_empty())
	client.responses = [{"code":0,"error":"WOE_NETWORK"}]
	await client.mutate("match/deploy",values)
	var terminal := {"match_id":"m","status":"FINISHED","snapshot":{"kind":"core_defense","mode":"solo","players":[{"id":"cd-recovery-smoke","team":"blue","slots":["neon"],"zeal":5}]}}
	client.responses = [{"code":0,"error":"WOE_NETWORK"},{"code":200,"data":terminal}]
	await client.mutate("match/forfeit",{"match_id":"m"})
	assert(not client.saved_forfeit_action().is_empty() and not client.saved_pending().is_empty())
	var forfeited: Dictionary = await client.retry_forfeit()
	assert(forfeited.code == 200 and client.saved_forfeit_action().is_empty() and client.saved_pending().is_empty())
	# A different terminal match must never erase either journal.
	client.responses = [{"code":0,"error":"WOE_NETWORK"}, {"code":0,"error":"WOE_NETWORK"}]
	await client.mutate("match/deploy", values)
	await client.mutate("match/forfeit", {"match_id":"m"})
	var other := terminal.duplicate(true)
	other.match_id = "other"
	assert(client.reconcile_terminal(other))
	assert(not client.saved_pending().is_empty() and not client.saved_forfeit_action().is_empty())
	# A new client instance sees the same exact replay body after restart.
	var replay: Dictionary = client.saved_pending().body.duplicate(true)
	var restarted = load("res://scripts/tests/core_defense_fake_client.gd").new()
	root.add_child(restarted)
	assert(restarted.saved_pending().body == replay)
	assert(restarted.reconcile_terminal(terminal))
	assert(restarted.saved_pending().is_empty() and restarted.saved_forfeit_action().is_empty())
	restarted.server_time_ms = 1700000000000
	restarted.server_tick_ms = Time.get_ticks_msec()
	restarted.fail_storage = true
	var failed: Dictionary = await restarted.mutate("match/deploy", values)
	assert(failed.error == "CD_RECOVERY_STORAGE" and restarted.saved_pending().is_empty())
	restarted.fail_storage = false
	restarted.responses = [{"code":0,"error":"WOE_NETWORK"}]
	await restarted.mutate("match/deploy", values)
	assert(not restarted.saved_pending().is_empty())
	restarted.fail_storage = true
	restarted.responses = [{"code":200,"data":{"accepted":true,"match_id":"m"}}]
	var failed_clear: Dictionary = await restarted.retry_pending()
	assert(failed_clear.error == "CD_RECOVERY_STORAGE" and not restarted.saved_pending().is_empty())
	restarted.fail_storage = false
	assert(restarted.reconcile_terminal(terminal))
	var old_generation: int = gate._generation
	restarted._time_identity = restarted.identity()
	gate._generation += 1
	assert(restarted.authoritative_time() == 0)
	gate._generation = old_generation
	# Room cleanup is exact; transient and unrelated match failures cannot discard it.
	assert(restarted.persist_room("room-a"))
	assert(restarted._persist_pending({"action":"start","values":{"room_id":"room-a"},"body":{"client_action_id":"start-id"}}))
	assert(restarted.reconcile_missing_room("room-b"))
	assert(restarted.saved_room() == "room-a" and not restarted.saved_pending().is_empty())
	assert(restarted.reconcile_missing_room("room-a"))
	assert(restarted.saved_room().is_empty() and restarted.saved_pending().is_empty())
	restarted.server_time_ms = 1700000000000
	restarted.server_tick_ms = Time.get_ticks_msec()
	restarted.responses = [{"code":0,"error":"WOE_NETWORK"}]
	await restarted.mutate("match/deploy", values)
	var old_account := str(gate.player_id)
	gate.player_id = "another-account"
	assert(restarted.saved_pending().is_empty())
	assert(not restarted.reconcile_missing_match("m", "FOREST_CORE_DEFENSE_UNAVAILABLE"))
	gate.player_id = old_account
	assert(not restarted.saved_pending().is_empty())
	assert(restarted.reconcile_missing_match("m", "MATCH_UNAVAILABLE"))
	assert(restarted.saved_pending().is_empty())
	restarted.server_time_ms = 1700000000000
	restarted.server_tick_ms = Time.get_ticks_msec()
	restarted.responses = [{"code":409,"error":"MATCH_FINISHED"},{"code":409,"error":"MATCH_FINISHED"}]
	await restarted.mutate("match/deploy", values)
	await restarted.mutate("match/forfeit", {"match_id":"m"})
	assert(not restarted.saved_pending().is_empty() and not restarted.saved_forfeit_action().is_empty())
	assert(restarted.reconcile_terminal(terminal))
	assert(restarted.saved_pending().is_empty() and restarted.saved_forfeit_action().is_empty())
	restarted.queue_free()
	client.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cd_recovery_smoke.cfg"))
	print("CORE_DEFENSE_RECOVERY_SMOKE_PASS")
	quit(0)
