extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	var social = root.get_node("SocialClient")
	var scene := Control.new()
	root.add_child(scene)
	current_scene = scene
	gate.state = gate.State.CONNECTED
	gate.player_id = OS.get_environment("SOCIAL_TEST_ID")
	gate.token = OS.get_environment("SOCIAL_TEST_TOKEN")
	gate.base_url = OS.get_environment("SOCIAL_TEST_URL")
	var other := OS.get_environment("SOCIAL_TEST_OTHER")
	var role := OS.get_environment("SOCIAL_TEST_ROLE")
	var deadline := Time.get_ticks_msec() + 25000
	while not social.enabled and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if not social.enabled:
		_fail("Social state unavailable")
		return
	if role == "a":
		if not social.request_friend(other):
			_fail("Request did not start")
			return
		while social.incoming_for(other).is_empty() and Time.get_ticks_msec() < deadline:
			await create_timer(0.3).timeout
			social.poll_now()
		if social.incoming_for(other).is_empty():
			_fail("Reverse request not received")
			return
		var request_id: String = social.incoming_for(other).request_id
		if social._popup._current != request_id:
			_fail("Popup was not shown for the incoming request")
			return
		if not social.respond(request_id, true):
			_fail("Accept did not start")
			return
	else:
		while social.incoming_for(other).is_empty() and Time.get_ticks_msec() < deadline:
			await create_timer(0.3).timeout
			social.poll_now()
		if social.incoming_for(other).is_empty():
			_fail("First request not received")
			return
		var request_id: String = social.incoming_for(other).request_id
		if social._popup._current != request_id:
			_fail("Popup was not shown for the incoming request")
			return
		if not social.respond(request_id, false):
			_fail("Decline did not start")
			return
		while (social._mutation_busy or not social.incoming_for(other).is_empty()) and Time.get_ticks_msec() < deadline:
			await create_timer(0.3).timeout
			social.poll_now()
		if not social.request_friend(other):
			_fail("Reverse request did not start")
			return
	while not social.friends.has(other) and Time.get_ticks_msec() < deadline:
		await create_timer(0.3).timeout
		social.poll_now()
	if not social.friends.has(other):
		_fail("Friendship did not reach this client")
		return
	print("SOCIAL_HTTP_", role, "_PASS")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
