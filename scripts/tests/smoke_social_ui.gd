extends SceneTree

var failed := false
func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	var social = root.get_node("SocialClient")
	var chat = root.get_node("GlobalChatClient")
	var router = load("res://scripts/scene_router.gd")
	social.set_process(false)
	gate.state = gate.State.CONNECTED
	gate.debug_offline_enabled = false
	gate.player_id = "self"
	gate.token = "token"
	gate.base_url = "http://127.0.0.1:1"
	social._identity = social._identity_key()
	var data := {"player_id":"self", "friends":[{"player_id":"friend", "display_name":"Friend"}], "incoming":[{"request_id":"r1", "requester_id":"alice", "requester_name":"Alice", "created_at":1}, {"request_id":"r1", "requester_id":"alice", "requester_name":"Alice", "created_at":1}], "outgoing":[{"request_id":"r2", "recipient_id":"bob", "recipient_name":"Bob", "created_at":2}]}
	check(social._apply_snapshot(data) and social.friends.has("friend") and social.incoming.size() == 1 and social.outgoing_for("bob").request_id == "r2", "Snapshot validation or deduplication failed")
	check(not social._apply_snapshot({"player_id":"other", "friends":[], "incoming":[], "outgoing":[]}), "Other account state accepted")
	var timed := data.duplicate(true)
	timed["server_time"] = 1000000
	timed["cooldowns"] = [{"player_id":"bob", "cooldown_until":1030000}]
	check(social._apply_snapshot(timed) and social.cooldown_seconds("bob") == 30, "Server deadline was not applied")
	social._server_ticks -= 30000
	check(social.cooldown_seconds("bob") == 0, "Cooldown did not expire from monotonic time")
	social._apply_snapshot(data)
	social._pending_path = "/social/friends/request"
	social._pending_body = '{"client_action_id":"stable","target_player_id":"bob"}'
	var exact_body: String = social._pending_body
	social._mutation_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), social._epoch)
	check(social._pending_body == exact_body and social.error_key == "SOCIAL_RETRY", "Uncertain action lost its retry body")
	social._pending_body = ""
	social._pending_path = ""
	social.error_key = ""
	var safe := Control.new()
	root.add_child(safe)
	current_scene = safe
	social._popup._process(0)
	check(social._popup._current == "r1" and social._popup._panel.visible, "Incoming popup not shown")
	var duel = root.get_node("DuelClient")
	duel.enabled = true
	duel._server_time = 1000000
	duel._server_ticks = Time.get_ticks_msec()
	duel.incoming = [{"invite_id":"duel1", "challenger_name":"Bob", "expires_at":1030000}]
	social._popup._process(0)
	check(social._popup._current == "duel1" and social._popup._current_kind == "duel", "Duel did not preempt friend popup")
	duel.incoming.clear()
	social._popup._process(0)
	social._popup._process(0)
	check(social._popup._current == "r1", "Deferred friend popup did not resume")
	social._popup._dismiss_current()
	social._popup._process(0)
	check(social._popup._current.is_empty(), "Dismissed request reopened")
	social._popup.open_request("r1")
	check(social._popup._panel.visible, "Pending request could not be reopened")
	gate.state = gate.State.IDLE
	social._popup._process(0)
	check(not social._popup._panel.visible, "Popup remained visible during auth overlay")
	gate.state = gate.State.CONNECTED
	social._popup._process(0)
	check(social._popup._panel.visible, "Popup did not resume")
	safe.scene_file_path = router.SCENE_COMBAT
	social._popup._process(0)
	check(not social._popup._panel.visible, "Popup interrupted combat")
	safe.scene_file_path = ""
	social._popup._process(0)
	check(social._popup._panel.visible, "Combat-deferred popup did not resume")
	chat.online_players = [{"player_id":"friend", "username":"Zoe", "league":"Quartz", "is_friend":true}, {"player_id":"alice", "username":"Alice", "league":"Copper", "is_friend":false}, {"player_id":"self", "username":"Me", "league":"Copper", "is_friend":false}]
	chat._panel._refresh_online_list()
	var online = chat._panel._online_list
	var first = online.get_child(2)
	check(first.get_child(0) is TextureRect and first.get_child(1).get_script() == load("res://scripts/ui/social_glyph.gd") and first.get_child(2).text == "Zoe", "Server ordering, league or friend marker lost")
	social._poll_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"player_id":"self", "friends":[], "incoming":[], "outgoing":[]}).to_utf8_buffer(), social._epoch - 1)
	check(social.friends.has("friend"), "Stale callback changed state")
	safe.queue_free()
	current_scene = null
	gate.debug_offline_enabled = true
	router._forest_owner = ""
	router._forest_summoner = "wizard"
	var world = load("res://scenes/forest/ForestWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	gate.debug_offline_enabled = false
	chat._process(0)
	check(chat._panel.visible and chat._panel._online.visible and chat._panel._button.visible and chat._panel.get_parent() == chat, "Global chat controls are not available in Forest")
	world._presence = load("res://scripts/forest/forest_presence_client.gd").new()
	world.add_child(world._presence)
	world._presence.set_process(false)
	world._presence.entered = true
	world._player.transition_locked = false
	world._on_peer_joined({"player_id":"alice", "display_name":"Alice", "zone_id":"central_clearing", "x":1000, "y":760, "facing":0, "summoner_id":"witch"})
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world._world.get_global_transform() * Vector2(1000,700)
	world._unhandled_input(click)
	check(world._selected_remote == "alice" and is_instance_valid(world._remotes.alice._friend_action), "Remote click did not expose review action")
	check(world._remotes.alice._friend_action.position.y < world._remotes.alice._label.position.y, "Action not above nickname")
	var remote = world._remotes.alice
	remote.set_friend_action("add", Callable(), 5)
	var cooldown_button: Button = remote._friend_action
	check(cooldown_button.disabled and cooldown_button.tooltip_text.contains("5"), "Cooldown did not disable the action or show its deadline")
	remote.set_friend_action("add", Callable(), 0)
	check(remote._friend_action == cooldown_button and not cooldown_button.disabled, "Cooldown refresh recreated or failed to re-enable action")
	remote.set_friend_action("pending", Callable(), 10)
	check(remote._friend_action.disabled, "Pending request remained interactive")
	click.position = world._world.get_global_transform() * Vector2(50,50)
	world._unhandled_input(click)
	check(world._selected_remote.is_empty(), "Outside click did not deselect")
	world._selected_remote = "alice"
	world._joystick.vector = Vector2.RIGHT
	world._process(0.01)
	check(world._selected_remote.is_empty(), "Joystick did not deselect")
	world._selected_remote = "alice"
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_UP
	world._unhandled_key_input(key)
	check(world._selected_remote.is_empty(), "Arrow movement did not deselect")
	world._selected_remote = "alice"
	world._on_peer_left("alice")
	check(world._selected_remote.is_empty() and world._remotes.is_empty(), "Peer leave did not clear selection")
	TranslationServer.set_locale("es")
	await process_frame
	await process_frame
	check(TranslationServer.translate("SOCIAL_ACCEPT") == "Aceptar", "Spanish translation missing")
	check(TranslationServer.translate("SOCIAL_ADD") == "Agregar amigo" and TranslationServer.translate("SOCIAL_LATER") == "Más tarde" and TranslationServer.translate("SOCIAL_COOLDOWN").begins_with("Límite") and TranslationServer.translate("SOCIAL_RETRY").contains("acción"), "Spanish social accents or wording incorrect")
	var social_font: Font = social._popup._dismiss.get_theme_font("font")
	check(social_font.resource_path.contains("Oldnewspapertypes") and social_font.has_char(0x00e1) and social_font.has_char(0x00ed) and social_font.has_char(0x00f3) and social_font.has_char(0x00f1), "Spanish social font lacks required glyphs")
	TranslationServer.set_locale("en")
	await process_frame
	await process_frame
	check(TranslationServer.translate("SOCIAL_ACCEPT") == "Accept", "English translation missing")
	check(social._popup._dismiss.get_theme_font("font").resource_path.contains("Bakula"), "English social button did not restore Bakula")
	social._identity = social._identity_key()
	social._poll_completed(HTTPRequest.RESULT_SUCCESS, 503, PackedStringArray(), '{"error":"SOCIAL_DISABLED"}'.to_utf8_buffer(), social._epoch)
	check(not social.enabled and social.friends.is_empty() and social.incoming.is_empty() and social._next_poll > Time.get_ticks_msec() + 50000, "Disabled state did not clear or back off")
	social._apply_snapshot(data)
	gate.token = "new-token"
	social._process(0)
	check(not social.enabled and social.friends.is_empty() and social.incoming.is_empty(), "Identity change retained social state")
	check(social._auth_response(HTTPRequest.RESULT_SUCCESS, 409, {"error":"SESSION_IDLE"}) and gate.state == gate.State.IDLE, "Idle response did not invoke the connection gate")
	world.queue_free()
	await process_frame
	print("SOCIAL_UI_SMOKE_", "FAILED" if failed else "PASS")
	quit(1 if failed else 0)
