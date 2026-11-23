extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(OS.get_environment("UI_ANDROID_PREVIEW") == "1")
	assert(change_scene_to_file("res://scenes/ui/ExpeditionVisualDebug.tscn") == OK)
	for i in 30:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == SceneRouter.SCENE_EXPEDITIONS: break
	var screen = current_scene
	screen._enter_visual_debug()
	screen._set_visual_debug_view(2)
	for dimensions in [Vector2i(1920, 1080), Vector2i(2400, 1080)]:
		root.size = dimensions
		screen.visual_inspector.set_phase(1)
		for i in 3: await process_frame
		var combat = screen.combat_view
		var panel: Control = combat.stage.get_node("SpellPanel")
		var switch: Control = combat.stage.get_node("SwitchWeapon")
		assert(switch.position.y >= panel.position.y + panel.size.y)
		assert(is_equal_approx(switch.get_rect().get_center().x, panel.get_rect().get_center().x))
		for button in combat.spell_buttons:
			assert(button.get_theme_stylebox("normal") is StyleBoxFlat)
			assert(button.get_child_count() > 0 and button.get_child(0).get_script() == preload("res://scripts/ui/combat_type_icon.gd"))
		screen.visual_inspector.set_phase(3)
		for i in 3: await process_frame
		var scroll: ScrollContainer = screen.body.get_node("RewardScroll")
		assert(scroll.size.y > 0 and scroll.size.x > 0)
		assert(screen.capture_sprite.texture != null and screen.phase_buttons.size() == 2)
		for button in screen.phase_buttons:
			assert(button.is_visible_in_tree() and button.size.y >= 54)
			assert(scroll.get_global_rect().intersects(button.get_global_rect()))
	var sample: Dictionary = screen.session.duplicate(true)
	sample.run_id = "test-run"
	sample.revision = 2
	sample.victory_reward = {"reward_id":"test-run:victory", "tier":"normal", "grants":{"essence":1}}
	var gate = root.get_node("ConnectionGate")
	var old_state = gate.state
	var old_player_id = gate.player_id
	gate.state = gate.State.CONNECTED
	gate.player_id = "test-player"
	screen.visual_debug = false
	screen.visual_inspector.queue_free()
	screen.backend = BackendClient.new()
	screen.backend.auto_dev_login = false
	screen.add_child(screen.backend)
	screen.backend.token = "test-token"
	screen.backend._verified_player_id = "test-player"
	screen.account_id = "test-player"
	screen.lease = "test-lease"
	screen.lease_run = "test-run"
	screen.session = {"run_id":"test-run", "revision":1, "phase":"COMBAT", "status":"ACTIVE"}
	screen.pending = {"kind":"turn", "payload":{"run_id":"test-run", "expected_revision":1, "client_action_id":"test-action"}}
	screen.request = "test-request"
	screen.request_kind = "turn"
	screen._completed("test-request", true, {"session":sample, "mana":1, "crystals":3, "server_time_unix_ms":0})
	await process_frame
	assert(screen.session.phase == "REWARD" and is_instance_valid(screen.capture_sprite))
	assert(is_instance_valid(screen.reward_popup))
	var popup: CanvasLayer = screen.reward_popup
	var buttons := popup.find_children("*", "Button", true, false)
	assert(buttons.size() >= 2)
	buttons.back().pressed.emit()
	await process_frame
	assert(not is_instance_valid(screen.reward_popup) and screen.phase_buttons.size() == 2)
	assert(screen.phase_buttons[0].is_visible_in_tree() and not screen.phase_buttons[0].disabled)
	screen.lease = ""
	gate.state = old_state
	gate.player_id = old_player_id
	print("EXPEDITION_ANDROID_REWARD_PASS")
	quit()
