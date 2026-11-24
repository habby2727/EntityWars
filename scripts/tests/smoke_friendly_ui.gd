extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	gate.state = gate.State.CONNECTED
	gate.player_id = "friendly-test"
	gate.token = "friendly-token"
	gate.base_url = "http://127.0.0.1:1"
	var duel = root.get_node("DuelClient")
	duel.set_process(false)
	duel._identity = duel._identity_key()
	var first_key: String = duel._recovery_key()
	gate.base_url = "http://127.0.0.1:2"
	assert(duel._recovery_key() != first_key)
	gate.base_url = "http://127.0.0.1:1"
	gate.player_id = "other-account"
	assert(duel._recovery_key() != first_key)
	gate.player_id = "friendly-test"
	duel._save_recovery("invite")
	duel._pending_path = "/forest/duels/ready"
	duel._pending_body = '{"invite_id":"invite","selection":{},"client_action_id":"stable"}'
	duel._save_pending()
	duel._pending_path = ""
	duel._pending_body = ""
	gate._generation += 1
	duel._process(0)
	assert(duel._tracked_invite == "invite" and duel._pending_body.contains("stable"))
	duel._pending_path = ""
	duel._pending_body = ""
	duel._save_pending()
	duel._action_owner = gate.player_id
	duel._action_base = gate.base_url
	duel._pending_path = "/forest/duels/ready"
	duel._pending_body = '{"invite_id":"invite","client_action_id":"stable"}'
	duel._next_retry = Time.get_ticks_msec() + 60000
	duel._next_poll = Time.get_ticks_msec() + 60000
	gate._generation += 1
	duel._process(0)
	assert(duel._pending_body == '{"invite_id":"invite","client_action_id":"stable"}')
	duel._pending_body = ""
	duel._pending_path = ""
	duel._tracked_invite = "historic-invite"
	duel._verify_invite = "historic-invite"
	duel._verify_match = "historic-match"
	var match_events := []
	duel.match_started.connect(func(invite_id, match_id): match_events.append([invite_id, match_id]))
	var historic := {"match_id":"historic-match", "kind":"friendly", "status":"FINISHED"}
	duel._poll_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(historic).to_utf8_buffer(), duel._epoch - 1)
	assert(duel._tracked_invite == "historic-invite" and match_events.is_empty())
	duel._poll_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(historic).to_utf8_buffer(), duel._epoch)
	assert(duel._tracked_invite.is_empty() and match_events.is_empty())
	SceneRouter._friendly_context = {"player_id":"friendly-test", "generation":gate._generation, "invite_id":"invite", "expires_at":9999999999999, "opponent":"Rival"}
	var loadout = load("res://scenes/LoadoutGrid.tscn").instantiate()
	root.add_child(loadout)
	current_scene = loadout
	await process_frame
	assert(loadout.ranked_queue.friendly and loadout.ranked_queue.selected)
	assert(not loadout.btn_seal_attack.visible and not loadout.btn_seal_defense.visible)
	loadout.queue_free()
	await process_frame
	SceneRouter._ranked_context = {"match_id":"friendly-match", "kind":"friendly", "player_id":"friendly-test"}
	var combat = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(combat)
	current_scene = combat
	await process_frame
	var controller = combat._ranked_controller
	controller.set_process(false)
	assert(controller.friendly and controller.match_prefix == "/forest/duels/match")
	controller.request_id = "test"
	controller.request_kind = "state"
	controller._on_response("test", true, {"match_id":"friendly-match", "kind":"ranked"})
	assert(controller.state.is_empty())
	controller.state = {"status":"FINISHED", "result":{"result":"win"}}
	controller._show_result_popup()
	assert(controller.result_popup_shown)
	print("FRIENDLY_UI_SMOKE_PASS")
	combat.queue_free()
	quit(0)
