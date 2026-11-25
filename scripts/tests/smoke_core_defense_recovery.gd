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
	client.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cd_recovery_smoke.cfg"))
	print("CORE_DEFENSE_RECOVERY_SMOKE_PASS")
	quit(0)
