extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _f8() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F8
	event.pressed = true
	Input.parse_input_event(event)
	await _settle()
	var release := InputEventKey.new()
	release.keycode = KEY_F8
	release.pressed = false
	Input.parse_input_event(release)

func _capture(label: String, size: Vector2i) -> void:
	var dir := OS.get_environment("EXPEDITION_MINIMIZE_CAPTURE")
	if dir.is_empty(): return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(dir.path_join("%dx%d_%s.png" % [size.x, size.y, label])) == OK)

func _run() -> void:
	assert(OS.has_feature("editor"))
	assert(change_scene_to_file("res://scenes/ui/ExpeditionVisualDebug.tscn") == OK)
	for i in 30:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == SceneRouter.SCENE_EXPEDITIONS: break
	var screen = current_scene
	assert(screen != null and screen.backend == null)
	screen._enter_visual_debug()
	var inspector = screen.visual_inspector
	inspector.select_enemy(4)
	inspector.select_hom(5)
	inspector.select_background(2)
	inspector.set_phase(1)
	await _settle()
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await _settle()
		var body_id: int = screen.body.get_instance_id()
		var hud_id: int = screen.combat_view.get_instance_id()
		var video_id: int = screen.video.get_instance_id()
		var stream: VideoStream = screen.video.stream
		assert(screen.video.has_method("get_stream_position"))
		var position_before := float(screen.video.call("get_stream_position"))
		var original: Dictionary = screen.session.duplicate(true)
		var selections := [inspector.phase_index, inspector.enemy_index, inspector.hom_index, inspector.background_index]
		var expanded_height: float = screen.body.size.y
		var expanded_position: Vector2 = screen.combat_view.spell_buttons[0].global_position
		assert(screen.video.is_playing() and inspector.visible)
		await _capture("expanded", size)
		inspector.minimize_button.pressed.emit()
		await _settle()
		assert(not inspector.visible and screen.visual_debug_view == 1 and screen.visual_debug_restore.visible)
		assert(screen.body.size.y > expanded_height and screen.retry.visible and screen.retry.disabled)
		assert(screen.status.text == screen.tr("EXPEDITION_BALANCE") % [4, 3, "00:00:00", "00:00:00"])
		var minimized_height: float = screen.body.size.y
		var minimized_position: Vector2 = screen.combat_view.spell_buttons[0].global_position
		await _capture("minimized", size)
		screen.visual_debug_restore.pressed.emit()
		await _settle()
		assert(inspector.visible and not screen.visual_debug_restore.visible)
		assert(is_equal_approx(screen.body.size.y, expanded_height))
		assert(screen.combat_view.spell_buttons[0].global_position.is_equal_approx(expanded_position))
		await _f8()
		assert(not inspector.visible and screen.visual_debug_restore.visible)
		await _f8()
		assert(screen.visual_debug_view == 2 and not inspector.visible and not screen.visual_debug_restore.visible)
		assert(is_equal_approx(screen.body.size.y, minimized_height))
		assert(screen.combat_view.spell_buttons[0].global_position.is_equal_approx(minimized_position))
		assert(screen.video.is_playing())
		await _capture("clean", size)
		await _f8()
		assert(screen.visual_debug_view == 0 and inspector.visible)
		assert(screen.body.get_instance_id() == body_id and screen.combat_view.get_instance_id() == hud_id)
		assert(screen.video.get_instance_id() == video_id and screen.video.stream == stream and screen.video.is_playing())
		assert(float(screen.video.call("get_stream_position")) + 0.05 >= position_before)
		assert(screen.session == original and selections == [inspector.phase_index, inspector.enemy_index, inspector.hom_index, inspector.background_index])
		assert(screen.pending.is_empty() and screen.backend == null)
		stream = null
	print("EXPEDITION_DEBUG_MINIMIZE_PASS")
	quit()
