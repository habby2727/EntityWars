extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func _run() -> void:
	var chat = root.get_node("GlobalChatClient")
	var gate = root.get_node("ConnectionGate")
	gate.player_id = "mine"
	chat._identity = "mine"
	chat._apply_snapshot({"messages": [{"id": 1, "player_id": "other", "username": "Alice", "text": "[b]<test>"}], "online_count": 2})
	_check(not chat.unread and chat.latest_id == 1 and chat.online_count == 2, "First snapshot or presence failed")
	chat._apply_snapshot({"messages": [{"id": 2, "player_id": "mine", "username": "Me", "text": "hello"}], "online_count": 2})
	_check(not chat.unread, "Own message marked unread")
	chat._apply_snapshot({"messages": [{"id": 3, "player_id": "other", "username": "Alice", "league": "Quartz", "text": "[b]<test>"}], "online_count": 2, "online_players": [{"player_id": "other", "username": "Alice", "league": "Quartz"}, {"player_id": "mine", "username": "Me", "league": "Copper"}]})
	_check(chat.unread, "Other message did not mark unread")
	for path in ["res://scenes/ui/LabHub.tscn", "res://scenes/ui/LabStructures.tscn", "res://scenes/ui/Lab.tscn"]:
		var scene = load(path).instantiate()
		var backend = scene.get_node_or_null("BackendClient")
		if backend != null:
			backend.auto_dev_login = false
			backend.auto_flush = false
		root.add_child(scene)
		await process_frame
		var panel: Node = null
		for child in scene.get_children():
			if child.get_script() != null and child.get_script().resource_path == "res://scripts/ui/global_chat_panel.gd":
				panel = child
		_check(panel != null, "Chat widget missing from " + path)
		await process_frame
		_check(panel._button.get_theme_font("font").has_char(0x1f4ac), "Emoji font lacks chat glyph")
		_check(panel._scroll.get_v_scroll_bar() is VScrollBar, "Native scrollbar missing")
		panel._online.pressed.emit()
		_check(panel._online_panel.visible and panel._online_list.get_child_count() == 2, "Online list did not open")
		_check(panel._online_list.get_child(0).get_child(0) is TextureRect, "League icon missing from online list")
		panel._online.pressed.emit()
		_check(not panel._online_panel.visible, "Online list did not close")
		panel._open()
		_check(panel._panel.visible and not chat.unread, "Opening did not clear badge")
		_check(panel._log.get_parsed_text().contains("[b]<test>"), "Message markup was not kept as text")
		panel._close()
		_check(not panel._panel.visible, "Closing panel failed")
		scene.queue_free()
		await process_frame
	var many := []
	for i in 25:
		many.append({"id": i + 10, "player_id": "other", "username": "Alice", "text": ("long message " + str(i) + " ").repeat(16)})
	chat._apply_snapshot({"messages": many, "online_count": 1})
	_check(chat.messages.size() == 20, "History limit failed")
	var scroll_panel = load("res://scripts/ui/global_chat_panel.gd").new()
	root.add_child(scroll_panel)
	scroll_panel._open()
	await process_frame
	await process_frame
	var bar: VScrollBar = scroll_panel._scroll.get_v_scroll_bar()
	_check(bar.max_value > bar.page, "Twenty messages did not scroll")
	scroll_panel._scroll.scroll_vertical = 10
	await process_frame
	var saved: int = scroll_panel._scroll.scroll_vertical
	scroll_panel._refresh()
	await process_frame
	await process_frame
	_check(scroll_panel._scroll.scroll_vertical == saved, "Scroll position was not preserved")
	scroll_panel.queue_free()
	await process_frame
	_check(not chat.send_message("offline"), "Offline send was allowed")
	TranslationServer.set_locale("es")
	_check(TranslationServer.translate("CHAT_SEND") == "Enviar", "Spanish translation missing")
	TranslationServer.set_locale("en")
	if not OS.get_environment("CHAT_TEST_TOKEN").is_empty():
		gate.player_id = OS.get_environment("CHAT_TEST_PLAYER")
		gate.token = OS.get_environment("CHAT_TEST_TOKEN")
		gate.base_url = OS.get_environment("CHAT_TEST_URL")
		await process_frame
		var deadline := Time.get_ticks_msec() + 8000
		while not chat._initialized and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		_check(chat._initialized and chat.online_count == 1, "HTTP polling failed")
		_check(chat.send_message("Network smoke"), "HTTP send did not start")
		deadline = Time.get_ticks_msec() + 8000
		while (chat._send_busy or chat.messages.is_empty()) and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		_check(not chat.messages.is_empty() and chat.messages.back().text == "Network smoke", "HTTP send/poll failed")
		gate.state = gate.State.RECONNECTING
		await process_frame
		_check(not chat.send_message("blocked") and not chat._poll_busy, "Blocked chat made a request")
		gate.state = gate.State.CONNECTED
		await process_frame
		deadline = Time.get_ticks_msec() + 8000
		while (chat._poll_busy or chat.online_count == 0) and Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
		_check(chat.online_count == 1, "Polling did not resume after reconnect")
	print("GLOBAL_CHAT_SMOKE_PASS")
	quit(0)
