extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var cache = root.get_node("MinigameInvitationCache")
	var social = root.get_node("SocialClient")
	social.friends["friend-id"] = "Friend Name"
	var now := 1700000000000
	cache.data = {"incoming":[{"invite_id":"one","room_id":"room","game_kind":"woe","inviter_id":"friend-id","expires_at":now + 90000}],"outgoing":[],"recent":[],"server_time_unix_ms":now}
	var notices = load("res://scripts/ui/minigame_invitation_notices.gd").new()
	root.add_child(notices)
	assert(notices._rows.size() == 1)
	var row: Node = notices._rows["one"]
	assert(row.get_meta("label").text.contains("Friend Name"))
	notices._refresh()
	assert(notices._rows.size() == 1 and notices._rows["one"] == row)
	for id in ["two", "three", "four"]:
		cache.data.incoming.append({"invite_id":id,"room_id":"room","game_kind":"woe","inviter_id":"friend-id","expires_at":now + 90000})
	notices._refresh()
	assert(notices._rows.size() == 4 and notices._inbox_rows.get_child_count() == 2 and notices._inbox_button.visible)
	var feedback := Label.new()
	root.add_child(feedback)
	notices._respond("woe", "one", true, "room", feedback)
	assert(feedback.text == notices.tr("INVITE_CLEARING_GUIDANCE"))
	cache.data.incoming = []
	notices._refresh()
	assert(notices._rows.is_empty())
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = "invitation-lock-test"
	gate.token = "test-token"
	gate.base_url = "https://example.invalid"
	var first := Node.new()
	var second := Node.new()
	root.add_child(first)
	root.add_child(second)
	assert(cache.lock("woe", first))
	assert(not cache.lock("woe", second))
	assert(cache.lock("core_defense", second))
	var pending := {"action":"invite", "body":{"client_action_id":"1700000000000:exact"}}
	assert(cache.save("woe", pending))
	assert(not cache.clear_exact("woe", {"action":"different"}))
	assert(cache.saved("woe") == pending)
	assert(cache.clear_exact("woe", pending))
	var account: String = root.get_node("WoeClient").account_key()
	cache.unlock("woe", first, account)
	assert(cache.lock("woe", second))
	cache.unlock("woe", second, account)
	cache.unlock("core_defense", second, account)
	var client = root.get_node("WoeClient")
	client.set_script(load("res://scripts/tests/minigame_invitation_blocked_client.gd"))
	var panel_a = load("res://scripts/ui/minigame_invitations.gd").new()
	var panel_b = load("res://scripts/ui/minigame_invitations.gd").new()
	for panel in [panel_a, panel_b]:
		panel.game_kind = "woe"
		panel.room_id = "room"
		root.add_child(panel)
		panel._server_time = now
		panel._server_tick = Time.get_ticks_msec()
	panel_a._send("friend-a")
	assert(panel_a._busy)
	var in_flight: Dictionary = panel_a._saved().duplicate(true)
	panel_b._send("friend-b")
	assert(panel_b._status.text == panel_b.tr("WOE_RETRY_PENDING"))
	assert(panel_b._saved() == in_flight)
	client.release_invitation.emit()
	await process_frame
	assert(not panel_a._busy and panel_a._saved() == in_flight)
	assert(cache.clear_exact("woe", in_flight))
	panel_a.queue_free()
	panel_b.queue_free()
	client.set_script(load("res://scripts/tests/minigame_invitation_reconcile_client.gd"))
	var recovery = load("res://scripts/tests/minigame_invitation_context_panel.gd").new()
	recovery.game_kind = "woe"
	root.add_child(recovery)
	recovery._server_time = now
	recovery._server_tick = Time.get_ticks_msec()
	recovery._reply_room = "fixture-room"
	await recovery._submit("invite/respond", {"invite_id":"fixture", "accept":true})
	assert(recovery._saved().is_empty() and client.saved_room().is_empty())
	client.state_code = 503
	await recovery._submit("invite/respond", {"invite_id":"fixture", "accept":true})
	var unresolved: Dictionary = recovery._saved().duplicate(true)
	assert(not unresolved.is_empty() and client.saved_room() == "fixture-room")
	client.state_code = 200
	var admitted := [false]
	recovery.admitted.connect(func(_room): admitted[0] = true)
	await recovery._submit("invite/respond", {"invite_id":"fixture", "accept":true})
	assert(admitted[0] and recovery._saved().is_empty())
	client.save_room("")
	recovery.queue_free()
	var scene := Control.new()
	scene.scene_file_path = SceneRouter.SCENE_MAIN_MENU
	root.add_child(scene)
	current_scene = scene
	assert(cache.eligible())
	cache._next_poll = Time.get_ticks_msec() + 60000
	cache.refresh()
	assert(not cache._busy)
	scene.scene_file_path = SceneRouter.SCENE_COMBAT
	assert(not cache.eligible())
	scene.scene_file_path = SceneRouter.SCENE_LAB_HUB
	gate.debug_offline_enabled = true
	assert(not cache.eligible())
	gate.debug_offline_enabled = false
	SceneRouter._spectator_context = {"test":true}
	assert(not cache.eligible())
	SceneRouter._spectator_context.clear()
	scene.scene_file_path = SceneRouter.SCENE_COMBAT
	cache.data = {"incoming":[{"invite_id":"old"}]}
	cache._identity = "previous generation"
	cache._process(0)
	assert(cache.data.is_empty() and cache.stale)
	current_scene = null
	scene.queue_free()
	first.queue_free()
	second.queue_free()
	feedback.queue_free()
	notices.queue_free()
	print("MINIGAME_INVITATION_NOTICES_PASS")
	quit(0)
