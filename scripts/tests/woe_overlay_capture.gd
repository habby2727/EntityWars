extends SceneTree

# Mocked entries: this renders the real controls without calling any API.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GlobalChatClient").set_process(false)
	var cache = root.get_node("MinigameInvitationCache")
	cache.set_process(false)
	var gate = root.get_node("ConnectionGate")
	gate._timer.stop()
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = "preview-account"
	gate.token = "preview-token"
	gate.base_url = "https://example.invalid"
	root.get_node("CoreDefenseClient").set_script(load("res://scripts/tests/rankings_fake_client.gd"))
	var scene := Control.new()
	root.add_child(scene)
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_scene = scene
	var background := TextureRect.new()
	background.texture = load("res://assets/forest/woe/backgrounds/Classic_Arena_1920x1080.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(background)
	var popup = load("res://scripts/ui/core_defense_rankings.gd").new()
	scene.add_child(popup)
	await create_timer(0.35).timeout
	var social = root.get_node("SocialClient")
	social.friends["fixture-friend"] = "Example Friend"
	var now := int(Time.get_unix_time_from_system() * 1000)
	cache.data = {"incoming":[{"invite_id":"fixture","room_id":"fixture","game_kind":"woe","inviter_id":"fixture-friend","expires_at":now+90000}],"outgoing":[],"recent":[],"server_time_unix_ms":now}
	cache.stale = false
	cache.received_tick = Time.get_ticks_msec()
	cache.changed.emit()
	cache._overlay.show()
	for size in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(960,540)]:
		DisplayServer.window_set_size(size)
		await process_frame
		popup.size = Vector2(620, 380)
		popup.position = (root.get_visible_rect().size - popup.size) / 2.0
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var file := OS.get_environment("WOE_CAPTURE_DIR").path_join("mocked_overlays_%dx%d.png" % [size.x,size.y])
		assert(picture != null and picture.get_width() > 0 and picture.save_png(file) == OK)
		print("WOE_OVERLAY_CAPTURE ", file, " actual=", picture.get_size())
	popup._close()
	cache._overlay.hide()
	await process_frame
	quit()
