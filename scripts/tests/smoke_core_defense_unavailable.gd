extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.player_id = "cd-unavailable-smoke"
	gate.token = "test"
	gate.base_url = "https://example.invalid"
	var cd = root.get_node("CoreDefenseClient")
	cd.set_script(load("res://scripts/tests/core_defense_unavailable_client.gd"))
	assert(cd.persist_room("expired-room"))
	assert(cd._persist_pending({"action":"start","values":{"room_id":"expired-room"},"body":{"client_action_id":"start-1"}}))
	SceneRouter._woe_context = {"kind":"core_defense","room_id":"expired-room","player_id":gate.player_id,"generation":gate._generation,"base_url":gate.base_url,"startup":true}
	var pregame = load("res://scripts/ui/core_defense_pregame.gd").new()
	root.add_child(pregame)
	await process_frame
	assert(cd.saved_room() == "expired-room" and not cd.saved_pending().is_empty())
	assert(pregame._backoff == 2.0 and not pregame._room_missing)
	cd.room_code = 429
	await pregame._refresh()
	assert(cd.saved_room() == "expired-room" and not cd.saved_pending().is_empty())
	assert(pregame._backoff == 4.0)
	cd.room_code = 404
	await pregame._refresh()
	assert(cd.saved_room() == "expired-room" and not cd.saved_pending().is_empty())
	assert(not pregame._room_missing)
	assert(cd.reconcile_missing_room("expired-room"))
	assert(cd.saved_room().is_empty() and cd.saved_pending().is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cd_unavailable_smoke.cfg"))
	pregame.queue_free()
	await process_frame
	print("CORE_DEFENSE_UNAVAILABLE_PASS")
	quit(0)
