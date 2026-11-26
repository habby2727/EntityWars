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
	assert(feedback.text == notices.tr("INVITE_ACTIVITY_BLOCKED"))
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
