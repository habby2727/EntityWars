extends SceneTree

class DecisionHost extends Control:
	var decisions: Array = []
	func send_combat_decision(kind: String, decision: Dictionary) -> void:
		decisions.append({"kind":kind, "decision":decision.duplicate(true)})

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(change_scene_to_file("res://scenes/ui/ExpeditionVisualDebug.tscn") == OK)
	for i in 30:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == SceneRouter.SCENE_EXPEDITIONS: break
	var screen = current_scene
	screen._enter_visual_debug()
	screen._set_visual_debug_view(2)
	screen.visual_inspector.set_phase(1)
	await process_frame
	var view = screen.combat_view
	if OS.get_environment("UI_ANDROID_PREVIEW") == "1":
		for dimensions in [Vector2i(1920, 1080), Vector2i(2400, 1080)]:
			root.size = dimensions
			await process_frame
			await process_frame
			assert(view.hom_attack.size.x >= 180 and view.hom_attack.size.y >= 80)
			assert(view.hom_hold.size.x >= 180 and view.hom_hold.size.y >= 80)
			assert(not view.hom_attack.get_rect().intersects(view.hom_hold.get_rect()))
			assert(not view.hom_hold.get_rect().intersects(view.weapon_buttons[0].get_rect()))
			var switch: Button = view.stage.get_node("SwitchWeapon")
			assert(switch.size.y >= 70 and not switch.get_rect().intersects(view.stage.get_node("SpellPanel").get_rect()))
			for spell_button in view.spell_buttons:
				assert(spell_button.size.y >= 80)
	screen.lease = "test"
	screen._heartbeat_completed(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
	assert(not screen.forfeited and screen.lease == "test")
	screen.lease = ""
	for entry in [["spell", "player", view.player_sprite], ["spell", "npc", view.enemy_sprite], ["hom_attack", "player", view.player_hom_sprite], ["hom_attack", "npc", view.enemy_hom_sprite]]:
		var sprite: Control = entry[2]
		var initial := sprite.position
		view._animate_event({"kind":entry[0], "actor":entry[1], "spell_id":"cinder_fist"})
		view.animation_tweens[sprite].custom_step(0.06)
		assert(not sprite.position.is_equal_approx(initial))
		view.animation_tweens[sprite].custom_step(0.5)
		assert(sprite.position.is_equal_approx(initial))
	var icon: TextureRect = view.weapon_buttons[1].get_child(1)
	var initial_scale := icon.scale
	view._animate_event({"kind":"switch", "actor":"player", "slot":2})
	view.animation_tweens[icon].custom_step(0.06)
	assert(icon.scale.x > initial_scale.x)
	view.animation_tweens[icon].custom_step(0.5)
	assert(icon.scale.is_equal_approx(initial_scale))
	assert(not view.hom_attack.visible and not view.hom_hold.visible)
	assert(view.hom_attack.get_theme_stylebox("normal") is StyleBoxTexture)
	assert(view.hom_attack.get_theme_stylebox("normal").texture == preload("res://scripts/ui/menu_art.gd")._button_frame("boton-loadout-opciones.png").texture)
	for locale in ["en", "es"]:
		TranslationServer.set_locale(locale)
		var before: String = view.log.get_parsed_text()
		view._append_event({"kind":"damage", "actor":"player", "target":"npc", "amount":17, "hp":42})
		view._append_event({"kind":"poison", "side":"player", "amount":3, "hp":39})
		var added: String = view.log.get_parsed_text().substr(before.length())
		assert("17" in added and "42" in added and "3" in added and "39" in added and "?" not in added)
	var previous_hp: float = view.enemy_hp.value
	var impact_hp := 5 if previous_hp != 5 else 6
	var before_log: String = view.log.get_parsed_text()
	view.present_events([{"kind":"spell", "actor":"player", "spell_id":"cinder_fist"}, {"kind":"damage", "actor":"player", "target":"npc", "hp":impact_hp, "amount":10}], screen.playback_epoch)
	await create_timer(0.2).timeout
	assert(view.log.get_parsed_text() != before_log and view.enemy_hp.value == previous_hp)
	assert(view.controls.all(func(control): return control.disabled))
	var spell_log: String = view.log.get_parsed_text()
	await create_timer(0.55).timeout
	assert(view.log.get_parsed_text() != spell_log and view.enemy_hp.value == impact_hp)
	assert(view.animation_tweens.has(view.enemy_sprite))
	if impact_hp < previous_hp:
		var numbers: Array = view.get_children().filter(func(child): return child is Label and child.has_meta("floating_damage"))
		assert(numbers.size() == 1 and numbers[0].text == "-%d" % int(previous_hp - impact_hp))
	var count_before: int = view.get_children().filter(func(child): return child is Label and child.has_meta("floating_damage")).size()
	view.present_events([{"kind":"heal", "actor":"npc", "target":"npc", "hp":impact_hp + 1}, {"kind":"heal", "actor":"npc", "target":"npc", "hp":impact_hp + 1}], screen.playback_epoch)
	await create_timer(1.4).timeout
	assert(view.get_children().filter(func(child): return child is Label and child.has_meta("floating_damage")).size() <= count_before)
	view.log.meta_clicked.emit("cinder_fist")
	var dialogs: Array = view.find_children("*", "AcceptDialog", true, false)
	assert(dialogs.size() == 1)
	var dialog: AcceptDialog = dialogs[0]
	assert(dialog.borderless and dialog.transparent)
	assert(dialog.dialog_text.begins_with(dialog.title))
	assert(dialog.get_theme_stylebox("embedded_border") is StyleBoxEmpty)
	assert(dialog.get_theme_stylebox("embedded_unfocused_border") is StyleBoxEmpty)
	var capture_path := OS.get_environment("EXPEDITION_PRESENTATION_CAPTURE")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_path)
	dialog.queue_free()
	await process_frame
	var decision_host := DecisionHost.new()
	root.add_child(decision_host)
	view.host = decision_host
	view.session.combat_state.player.hom_energy = 3
	view._cast("cinder_fist")
	assert(decision_host.decisions.is_empty() and view.hom_attack.visible and view.hom_hold.visible)
	var click_at: Vector2 = view.hom_attack.get_global_transform_with_canvas() * (view.hom_attack.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = click_at
	motion.global_position = click_at
	root.push_input(motion, true)
	assert(root.gui_get_hovered_control() == view.hom_attack)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = click_at
	click.global_position = click_at
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	assert(decision_host.decisions.size() == 1 and decision_host.decisions[0].decision.hom_action == "attack" and decision_host.decisions[0].decision.spell_id == "cinder_fist")
	view._cast("cinder_fist")
	assert(view.hom_attack.visible and view.hom_hold.visible)
	click_at = view.hom_hold.get_global_transform_with_canvas() * (view.hom_hold.size * 0.5)
	motion.position = click_at
	motion.global_position = click_at
	root.push_input(motion, true)
	assert(root.gui_get_hovered_control() == view.hom_hold)
	click.position = click_at
	click.global_position = click_at
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	assert(decision_host.decisions.size() == 2 and decision_host.decisions[1].decision.hom_action == "hold")
	view.session.combat_state.player.hom_energy = 6
	view._cast("cinder_fist")
	assert(view.hom_attack.visible and view.hom_hold.visible)
	view.hom_hold.pressed.emit()
	assert(decision_host.decisions.size() == 3 and decision_host.decisions[2].decision.hom_action == "hold")
	view.session.combat_state.player.hom_energy = 2
	view._cast("cinder_fist")
	assert(decision_host.decisions.size() == 4 and decision_host.decisions[3].decision.hom_action == "hold" and not view.hom_hold.visible)
	view.host = screen
	decision_host.queue_free()
	# Exercise the same pending action across transient disconnects and failures.
	screen.backend = BackendClient.new()
	screen.add_child(screen.backend)
	screen.backend.token = "original-token"
	screen.backend._verified_player_id = "owner"
	screen.account_id = "owner"
	screen.lease = "original-lease"
	screen.lease_run = "run"
	screen.lease_token = "original-token"
	screen.session = {"run_id":"run", "revision":3, "status":"ACTIVE"}
	screen.pending = {"kind":"turn", "payload":{"run_id":"run", "expected_revision":3, "client_action_id":"original-action"}}
	screen.request_kind = "turn"
	assert(screen._valid_action_response({"run_id":"run", "revision":4}))
	assert(not screen._valid_action_response({"run_id":"run", "revision":5}))
	screen.request = "attempt"
	var gate = root.get_node("ConnectionGate")
	var old_gate_state = gate.state
	gate.state = gate.State.RECONNECTING
	screen.connection_gate_lost()
	assert(screen.recovery_required and not screen.forfeited and screen.lease == "original-lease")
	screen._completed("attempt", false, {"http_status":503})
	assert(not screen.forfeited and screen.pending.payload.client_action_id == "original-action")
	screen.request = "timeout"
	screen._completed("timeout", false, {"error":"network_error"})
	assert(not screen.forfeited and screen.pending.payload.expected_revision == 3)
	gate.state = old_gate_state
	screen._heartbeat_completed(HTTPRequest.RESULT_SUCCESS, 409, PackedStringArray(), PackedByteArray())
	assert(screen.forfeited and screen.lease.is_empty())
	await process_frame
	screen.forfeited = false
	screen.account_id = "owner"
	screen.lease = "original-lease"
	screen.backend._verified_player_id = "other"
	screen._identity_changed({"player_id":"other"})
	assert(screen.forfeited and screen.lease.is_empty())
	await process_frame
	print("EXPEDITION_PRESENTATION_PASS")
	quit()
