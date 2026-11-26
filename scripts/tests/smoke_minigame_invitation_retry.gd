extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GlobalChatClient").set_process(false)
	root.get_node("SocialClient").set_process(false)
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = "retry-test-account"
	gate.token = "test-token"
	gate.base_url = "https://example.invalid"
	var scene := Control.new()
	scene.scene_file_path = SceneRouter.SCENE_MAIN_MENU
	root.add_child(scene)
	current_scene = scene
	var client = root.get_node("WoeClient")
	client.set_script(load("res://scripts/tests/minigame_invitation_retry_client.gd"))
	var cache = root.get_node("MinigameInvitationCache")
	cache._identity = client.identity()
	cache._resumed_identity = client.identity()
	cache._next_poll = Time.get_ticks_msec() + 60000
	cache.stale = false
	cache.received_tick = Time.get_ticks_msec()
	cache.data = {"server_time_unix_ms":1700000000000, "incoming":[], "outgoing":[], "recent":[]}
	cache.save("woe", {})
	var panel = load("res://scripts/ui/minigame_invitations.gd").new()
	panel.game_kind = "woe"
	root.add_child(panel)
	panel.room_id = "room"
	panel._send("friend")
	panel.queue_free()
	assert(not cache.operation("woe").is_empty())
	assert(not cache.submit("woe", "invite", {"room_id":"room", "game_kind":"woe", "target_player_id":"friend"}))
	var original: Dictionary = cache.saved("woe").body.duplicate(true)
	await create_timer(2.0).timeout
	assert(client.calls.size() == 2)
	assert(client.calls[0] == original and client.calls[1] == original)
	assert(cache.saved("woe").is_empty())
	assert(cache.operation("woe").is_empty())
	client.calls.clear()
	client.send_count = 0
	assert(cache.submit("woe", "invite", {"room_id":"room", "game_kind":"woe", "target_player_id":"friend"}))
	gate.token = "changed-session"
	cache._process(0.0)
	await create_timer(1.6).timeout
	assert(client.calls.size() == 1)
	assert(cache.operation("woe").is_empty() and cache.last_status("woe") == "INVITE_SESSION_CHANGED")
	assert(cache.save("woe", {}))
	cache._next_poll = Time.get_ticks_msec() + 60000
	scene.scene_file_path = SceneRouter.SCENE_COMBAT
	assert(not SceneRouter.invitation_handoff_safe())
	scene.scene_file_path = SceneRouter.SCENE_MAIN_MENU
	assert(SceneRouter.invitation_handoff_safe())
	var verified := {"room_id":"verified-room", "mode":"1v1", "status":"WAITING", "members":[{"player_id":gate.player_id}]}
	assert(SceneRouter.begin_invited_minigame("woe", verified))
	assert(SceneRouter.woe_context_valid() and SceneRouter._woe_context.get("return_scene") == SceneRouter.SCENE_MAIN_MENU)
	SceneRouter._woe_context.clear()
	current_scene = null
	scene.queue_free()
	print("MINIGAME_INVITATION_RETRY_PASS")
	quit(0)
