extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root_dir := OS.get_environment("HUNT_TEST_ROOT").replace("\\", "/").to_lower()
	if root_dir.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(root_dir + "/"):
		push_error("Isolated user directory required")
		quit(1)
		return
	if OS.get_environment("EW_HUNT_E2E") == "1":
		if not OS.get_environment("EW_TERMINAL_EXPECT").is_empty():
			await _run_terminal()
			return
		await _run_online()
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	change_scene_to_file("res://scenes/ui/WorldZoneChaos.tscn")
	await process_frame
	await process_frame
	var zone = current_scene
	zone._show_debug_boss(2)
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	zone._preview_stage.get_child(2).get_child(0).gui_input.emit(click)
	assert(zone._debug_fight.visible and not zone._debug_fight.disabled)
	var texture_path: String = zone._debug_visual.texture
	zone._start_debug_hunt()
	await process_frame
	await process_frame
	var loadout = current_scene
	assert(loadout != null and loadout._hunt_mode)
	assert(loadout._spell_button.is_visible_in_tree() and loadout._spell_button.text == "Change Spells")
	loadout._open_spell_dialog()
	assert(loadout._spell_slots.size() == 4 and not loadout._spell_picker.visible)
	loadout._select_spell_slot(0)
	assert(loadout._spell_picker.visible)
	loadout._spell_dialog.hide()
	assert(not loadout.btn_save.is_visible_in_tree() and not loadout.btn_seal_attack.is_visible_in_tree())
	loadout._current_entity_id = str(loadout._entities[1].id)
	loadout._current_homunculus_id = str(loadout._homunculi[1].id)
	var entity_id: String = loadout._current_entity_id
	var hom_id: String = loadout._current_homunculus_id
	var weapon_id: String = loadout._idx_to_id(loadout._items, loadout.dd_item1)
	var weapon2: String = loadout._idx_to_id(loadout._items, loadout.dd_item2)
	var before: Dictionary = loadout._spell_debug.load_lab_state()
	var spells: Array = loadout._equipped_spells("attack", entity_id)
	spells.reverse()
	loadout._spell_draft = spells.duplicate()
	loadout._confirm_spell_dialog()
	assert(loadout._equipped_spells("attack", entity_id) == spells)
	assert(loadout._spell_debug.load_lab_state() == before)
	SceneRouter._solo_hunt_context["session_id"] = "test-session"
	loadout._on_play_pressed()
	assert(current_scene == loadout and SceneRouter._hunt_loadout_active)
	assert("Recover the authenticated" in loadout.lbl_build_error.text)
	var backend := BackendClient.new()
	backend.token = "test-token"
	backend._verified_player_id = "test-player"
	loadout._hunt_backend = backend
	loadout._hunt_identity = "test-player"
	loadout._hunt_payload = {"entity_id": entity_id, "weapon_ids": [weapon_id, weapon2], "homunculus_id": hom_id, "spell_ids": spells, "mode": "attack"}
	var approved := {"session_id": "test-session", "status": "ACTIVE", "combat_revision": 1, "combat_state": {"turn": 0}, "combat_loadout": loadout._hunt_payload.duplicate(true)}
	loadout._hunt_submit_request = "test-submit"
	loadout._on_hunt_recovery_completed("test-submit", true, approved)
	assert(SceneRouter._solo_hunt_context.recovered_session == approved)
	assert(loadout._hunt_payload.is_empty())
	assert("Combat ready" in loadout.lbl_build_error.text)
	loadout._hunt_recovery_request = "test-recovery"
	loadout._on_hunt_recovery_completed("test-recovery", true, {"session": approved})
	assert(loadout._hunt_recovered)
	var uncertain := {"client_action_id": "stable-id", "entity_id": entity_id, "weapon_ids": [weapon_id, weapon2], "homunculus_id": hom_id, "spell_ids": spells, "mode": "attack"}
	loadout._hunt_payload = uncertain.duplicate(true)
	loadout._hunt_recovery_request = "test-uncertain"
	loadout._on_hunt_recovery_completed("test-uncertain", true, {"session": {"session_id": "test-session", "status": "ACTIVE"}})
	assert(loadout._hunt_recovered and loadout._hunt_payload == uncertain)
	assert("Retry the same loadout" in loadout.lbl_build_error.text)
	loadout._hunt_recovery_request = "test-duplicate"
	loadout._on_hunt_recovery_completed("test-duplicate", true, {"session": approved})
	assert(loadout._hunt_payload.is_empty() and "Combat ready" in loadout.lbl_build_error.text)
	loadout._hunt_payload = {"entity_id": entity_id}
	loadout._hunt_submit_request = "test-rejection"
	loadout._on_hunt_recovery_completed("test-rejection", false, {"error": "Invalid or unsupported hunt loadout."})
	assert(loadout._hunt_payload.is_empty() and "rejected" in loadout.lbl_build_error.text)
	for result in ["WIN", "LOSS"]:
		var terminal := approved.duplicate(true)
		terminal.status = "VERIFIED_" + result
		terminal.combat_state.terminal_result = result
		assert(loadout._accept_hunt_session(terminal))
		terminal.combat_state.terminal_result = "LOSS" if result == "WIN" else "WIN"
		assert(not loadout._accept_hunt_session(terminal))
	for status in ["EXPIRED", "FORFEIT"]:
		var closed := approved.duplicate(true)
		closed.status = status
		assert(not loadout._accept_hunt_session(closed))
	var foreign := approved.duplicate(true)
	foreign.session_id = "foreign-session"
	assert(not loadout._accept_hunt_session(foreign))
	loadout._hunt_backend = null
	backend._debug_flags.free()
	backend.free()
	SceneRouter._solo_hunt_context["session_id"] = ""
	loadout._on_play_pressed()
	await process_frame
	await process_frame
	var combat = current_scene
	assert(combat != null and combat._solo_boss_mode)
	assert(combat._solo_context.visual_zone_id == "zone_chaos")
	assert(combat._solo_texture != null and combat._solo_texture.resource_path == texture_path)
	combat._update_ui()
	assert(combat.enemy_entity.texture.resource_path == texture_path)
	assert(combat.player.id == entity_id)
	assert(combat.player.hom_id == hom_id)
	assert(str(combat.player.equip_1.get("id", "")) == weapon_id)
	assert(str(combat.player.equip_2.get("id", "")) == weapon2)
	assert(combat.player.spell_ids == spells)
	assert(not FileAccess.file_exists("user://seal_attack.json"))
	var key := SceneRouter.debug_guardian_key("zone_chaos", 2, "debug_rare|preview_common_0")
	combat.player.hp = 0
	combat._handle_battle_end()
	assert(not SceneRouter._debug_guardian_wins.has(key))
	combat._battle_over = false
	combat.player.hp = combat.player.max_hp
	combat.enemy.hp = 0
	combat._handle_battle_end()
	assert(SceneRouter._debug_guardian_wins.has(key))
	combat._on_next_turn()
	await process_frame
	await process_frame
	assert(current_scene is WorldZone and current_scene.zone_id_override == "zone_chaos")
	current_scene._show_debug_boss(2)
	await process_frame
	assert(current_scene._preview_stage.get_child_count() == 5)
	current_scene._show_debug_boss(2, "another_rare")
	await process_frame
	assert(current_scene._preview_stage.get_child_count() == 6)
	current_scene._show_debug_boss(2)
	await process_frame
	current_scene._preview_stage.get_child(0).get_child(0).gui_input.emit(click)
	assert(current_scene._debug_fight.disabled)
	current_scene._world_modal.visible = false
	SceneRouter._debug_guardian_wins[SceneRouter.debug_guardian_key("zone_chaos", 2, "debug_rare|preview_higher")] = true
	SceneRouter._debug_guardian_wins[SceneRouter.debug_guardian_key("zone_chaos", 2, "debug_rare|preview_common_1")] = true
	current_scene._show_debug_boss(2)
	await process_frame
	current_scene._preview_stage.get_child(0).get_child(0).gui_input.emit(click)
	assert(not current_scene._debug_fight.disabled)
	current_scene._world_modal.visible = false
	current_scene._clear_guardian_preview()
	current_scene._world_companions[0].gui_input.emit(click)
	current_scene._world_modal.visible = false
	current_scene._world_sprite.gui_input.emit(click)
	var central_path: String = current_scene._central_visual.texture
	assert(current_scene._debug_visual.texture == central_path)
	current_scene._start_debug_hunt()
	await process_frame
	await process_frame
	assert(current_scene._hunt_mode)
	current_scene._on_play_pressed()
	await process_frame
	await process_frame
	assert(current_scene._solo_texture.resource_path == central_path)
	print("PASS hunt loadout, boss session and selections")
	quit(0)

func _run_online() -> void:
	var token := OS.get_environment("EW_HUNT_TOKEN")
	var session_id := OS.get_environment("EW_HUNT_SESSION")
	var auth := FileAccess.open("user://auth.json", FileAccess.WRITE)
	auth.store_string(JSON.stringify({"token": token}))
	auth.close()
	SceneRouter._solo_hunt_context = {"session_id": session_id, "hunt_id": "hunt_common", "rotation_key": 0}
	SceneRouter._hunt_loadout_active = true
	change_scene_to_file("res://scenes/LoadoutGrid.tscn")
	await process_frame
	await process_frame
	var loadout = current_scene
	var deadline := Time.get_ticks_msec() + 20000
	while not loadout._hunt_recovered and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._hunt_recovered:
		push_error("Recovery failed: " + loadout.lbl_build_error.text)
		quit(1)
		return
	if int(SceneRouter._solo_hunt_context.get("recovered_session", {}).get("combat_revision", 0)) < 1:
		loadout._on_play_pressed()
		while int(SceneRouter._solo_hunt_context.get("recovered_session", {}).get("combat_revision", 0)) < 1 and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
	var session: Dictionary = SceneRouter._solo_hunt_context.get("recovered_session", {})
	if int(session.get("combat_revision", 0)) != 1 or current_scene != loadout:
		push_error("Initialization failed: " + loadout.lbl_build_error.text)
		quit(1)
		return
	loadout._on_play_pressed()
	await process_frame
	await process_frame
	var combat = current_scene
	if combat == null or not combat._online_hunt_guard:
		push_error("Initialized session did not enter protected combat")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + 20000
	while combat._online_hunt_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._online_hunt_revision != 1 or combat._combat_started or not combat._combat_session_invalid:
		push_error("Server combat recovery failed or local combat started")
		quit(1)
		return
	if not OS.get_environment("EW_C3_E2E").is_empty():
		var mode := OS.get_environment("EW_C3_E2E")
		var initial_turn := int(combat._online_hunt_session.combat_state.turn)
		assert(combat._inspiration_panel.visible and combat._inspiration_options.size() == 3)
		var chosen_id := str(combat._inspiration_options[0].id)
		if mode == "lost":
			combat._combat_backend.api_completed.disconnect(combat._on_online_hunt_response)
		if mode == "decline":
			combat._on_inspiration_cancel()
		else:
			combat._choose_inspiration(0)
		if mode == "lost":
			var original: Dictionary = combat._online_turn_payload.duplicate(true)
			deadline = Time.get_ticks_msec() + 20000
			while combat.next_turn_btn.text != "Recover" and Time.get_ticks_msec() < deadline:
				await create_timer(0.1).timeout
			combat._combat_backend.api_completed.connect(combat._on_online_hunt_response)
			assert(not original.is_empty() and combat._online_turn_payload == original)
			combat._on_next_turn()
		deadline = Time.get_ticks_msec() + 20000
		while combat._online_hunt_revision < 2 and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
		if combat._online_hunt_revision != 2 or int(combat._online_hunt_session.combat_state.turn) != initial_turn or combat._inspiration_panel.visible:
			push_error("Inspiration response failed")
			quit(1)
			return
		if mode != "decline":
			var spell_index := -1
			for i in 4:
				if str(combat._online_hunt_session.combat_state.moves[i].id) == chosen_id:
					spell_index = i
			assert(spell_index >= 0)
			combat._on_spell_chosen(spell_index)
			assert(combat.hom_decision.visible and not combat._online_hom_payload.is_empty())
			combat._on_hom_choice("sacrifice" if mode == "sacrifice" else "attack")
			deadline = Time.get_ticks_msec() + 20000
			while combat._online_hunt_revision < 3 and Time.get_ticks_msec() < deadline:
				await create_timer(0.1).timeout
			assert(combat._online_hunt_revision == 3 and int(combat._online_hunt_session.combat_state.turn) == initial_turn + 1)
			if mode == "sacrifice":
				assert(combat._online_hunt_session.combat_state.player.homunculus_spent)
			else:
				for event in combat._online_hunt_session.get("events", []):
					if event.get("kind", "") == "hom_damage":
						print("HOM_DAMAGE ", mode, " ", event.get("damage", 0))
		print("PASS real C3 ", mode)
		quit(0)
		return
	if OS.get_environment("EW_SWITCH_E2E") == "1":
		var baseline: Dictionary = combat._online_hunt_session.duplicate(true)
		var invalid: Dictionary = baseline.duplicate(true)
		invalid.combat_loadout.weapon_ids[1] = null
		combat._online_hunt_session = invalid
		assert(combat._online_switch_decision().is_empty())
		invalid = baseline.duplicate(true)
		invalid.combat_state.inspiration.pending = true
		combat._online_hunt_session = invalid
		assert(combat._online_switch_decision().is_empty())
		combat._online_hunt_session = baseline
		for target in [2, 1]:
			var rev: int = combat._online_hunt_revision
			combat._on_switch_weapon()
			var submitted: Dictionary = combat._online_turn_payload.duplicate(true)
			combat._on_switch_weapon()
			assert(not submitted.is_empty() and combat._online_turn_payload == submitted and submitted.decision.switch_slot == target)
			deadline = Time.get_ticks_msec() + 20000
			while combat._online_hunt_revision == rev and Time.get_ticks_msec() < deadline:
				await create_timer(0.1).timeout
			if combat._online_hunt_revision != rev + 1 or int(combat._online_hunt_session.combat_state.player.active_weapon_slot) != target or combat._combat_started:
				push_error("Online switch failed")
				quit(1)
				return
		print("PASS real online switch 1 -> 2 -> 1")
		quit(0)
		return
	var recovered: Dictionary = combat._online_hunt_session.duplicate(true)
	combat._online_hunt_session.combat_state.player.homunculus_energy = 3
	combat._on_spell_chosen(0)
	var hom_choice: Dictionary = combat._online_hom_payload.duplicate(true)
	assert(not hom_choice.is_empty() and combat.hom_decision.visible)
	assert(combat._online_turn_payload.is_empty() and combat._online_switch_decision().is_empty())
	combat._on_spell_chosen(0)
	assert(combat._online_hom_payload == hom_choice)
	combat._online_hom_payload.clear()
	combat.hom_decision.hide()
	combat._online_hunt_session = recovered.duplicate(true)
	combat._refresh_online_spell_buttons()
	assert(int(combat.player_hp.value) == int(recovered.combat_state.player.hp))
	assert(int(combat.enemy_hp.value) == int(recovered.combat_state.boss.hp))
	assert(not combat.spell_buttons[0].disabled)
	var fixture: Dictionary = recovered.duplicate(true)
	fixture.combat_state.player.status = {"poison": 2}
	fixture.combat_state.boss.status = {"stun": 1}
	fixture.combat_state.moves[0].cooldown_remaining = 2
	fixture.combat_state.inspiration = {"pending": true, "offers": ["cinder_fist", "silver_needle", "crystal_ram"]}
	fixture.combat_state.minions = [{"id": "minion_0", "hp": 10, "max_hp": 20}, {"id": "minion_1", "hp": 20, "max_hp": 20}]
	combat._online_hunt_session = fixture.duplicate(true)
	assert(combat._online_spell_decision(0).is_empty())
	fixture.combat_state.inspiration.pending = false
	combat._online_hunt_session = fixture.duplicate(true)
	assert(combat._online_spell_decision(1).target == "minion_0")
	fixture.combat_state.inspiration.pending = true
	assert(combat._render_online_hunt(fixture))
	assert(combat._solo_minion_views[0].visible and combat._solo_minion_views[1].visible)
	assert(is_equal_approx(combat._solo_minion_views[0].get_node("HP/Fill").size.x, 45.0))
	var inspect := InputEventMouseButton.new()
	inspect.button_index = MOUSE_BUTTON_LEFT
	inspect.pressed = true
	combat._on_online_minion_input(inspect, 1)
	assert(combat._online_inspected_minion == "minion_1")
	assert(combat._online_spell_decision(1).target == "minion_1")
	assert(combat._solo_minion_views[1].get_node("Selection").text == "TARGET")
	var capture_path := OS.get_environment("EW_HUNT_CAPTURE")
	if not capture_path.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		var capture := root.get_texture().get_image()
		if capture == null or capture.save_png(capture_path) != OK:
			push_error("Failed to capture online combat")
			quit(1)
			return
	assert("CD: 2" in combat.spell_buttons[0].text and "Inspiration:" in combat._online_hunt_info.text)
	fixture.combat_state.minions[0].hp = 0
	assert(combat._render_online_hunt(fixture))
	assert(combat._solo_minion_views[0].visible and not combat._solo_minion_views[1].visible)
	fixture.combat_state.minions[1].hp = 0
	assert(combat._render_online_hunt(fixture))
	assert(not combat._solo_minion_views[0].visible and not combat._solo_minion_views[1].visible)
	assert(combat._online_inspected_minion.is_empty())
	assert(combat._online_hunt_revision == 1 and not combat._combat_started)
	combat._online_hunt_session = recovered.duplicate(true)
	assert(combat._render_online_hunt(recovered))
	combat._online_hunt_session.clear()
	var server_url: String = combat._combat_backend.base_url
	combat._combat_backend.base_url = "http://127.0.0.1:1"
	combat._on_online_hunt_identity({"player_id": combat._combat_identity})
	deadline = Time.get_ticks_msec() + 20000
	while combat.next_turn_btn.text != "Retry" and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	combat._combat_backend.base_url = server_url
	if combat.next_turn_btn.text != "Retry" or combat._combat_started:
		push_error("Network failure did not leave a safe retry: button=%s request=%s started=%s" % [combat.next_turn_btn.text, combat._online_hunt_request, combat._combat_started])
		quit(1)
		return
	combat._on_next_turn()
	deadline = Time.get_ticks_msec() + 20000
	while combat._online_hunt_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._online_hunt_session != recovered or combat._combat_started:
		push_error("HTTP retry did not recover the same session")
		quit(1)
		return
	combat._on_spell_chosen(0)
	var pending: Dictionary = combat._online_turn_payload.duplicate(true)
	combat._on_spell_chosen(0)
	assert(not pending.is_empty() and combat._online_turn_payload == pending)
	assert(combat.spell_buttons[0].disabled)
	deadline = Time.get_ticks_msec() + 20000
	while combat._online_hunt_revision < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._online_hunt_revision != 2 or not combat._online_turn_payload.is_empty() or combat._combat_started:
		push_error("Authoritative turn failed")
		quit(1)
		return
	assert(int(combat.player_hp.value) == int(combat._online_hunt_session.combat_state.player.hp))
	assert(int(combat.enemy_hp.value) == int(combat._online_hunt_session.combat_state.boss.hp))
	var available := -1
	for i in 4:
		if not combat._online_spell_decision(i).is_empty():
			available = i
			break
	assert(available >= 0)
	combat._combat_backend.base_url = "http://127.0.0.1:1"
	combat._on_spell_chosen(available)
	var unresolved: Dictionary = combat._online_turn_payload.duplicate(true)
	deadline = Time.get_ticks_msec() + 20000
	while combat.next_turn_btn.text != "Recover" and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	assert(combat.next_turn_btn.text == "Recover" and combat._online_turn_payload == unresolved)
	assert(combat._online_hunt_revision == 2 and not combat._combat_started)
	for button in combat.spell_buttons:
		assert(button.disabled)
	combat._combat_backend.base_url = server_url
	combat._on_next_turn()
	deadline = Time.get_ticks_msec() + 20000
	while combat._online_hunt_revision < 3 and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	assert(combat._online_hunt_revision == 3 and combat._online_turn_payload.is_empty())
	assert(combat._online_processed_turns.has(unresolved.client_action_id))
	available = -1
	for i in 4:
		if not combat._online_spell_decision(i).is_empty():
			available = i
			break
	assert(available >= 0)
	combat._combat_backend.api_completed.disconnect(combat._on_online_hunt_response)
	combat._on_spell_chosen(available)
	var lost: Dictionary = combat._online_turn_payload.duplicate(true)
	deadline = Time.get_ticks_msec() + 20000
	while combat.next_turn_btn.text != "Recover" and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	combat._combat_backend.api_completed.connect(combat._on_online_hunt_response)
	assert(combat._online_turn_payload == lost and combat._online_hunt_revision == 3)
	combat._on_next_turn()
	deadline = Time.get_ticks_msec() + 20000
	while not combat._online_turn_payload.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	assert(combat._online_hunt_revision == 4 and combat._online_turn_payload.is_empty())
	assert(combat._online_processed_turns.has(lost.client_action_id))
	var replayed_response: Dictionary = combat._online_hunt_session.duplicate(true)
	var before_replay: String = combat.log_box.get_parsed_text()
	combat._online_turn_payload = lost.duplicate(true)
	combat._online_turn_request = "duplicate-test"
	combat._on_online_hunt_response("duplicate-test", true, replayed_response)
	assert(combat.log_box.get_parsed_text() == before_replay)
	assert(combat._online_hunt_revision == 4 and combat._online_turn_payload.is_empty())
	assert(not combat._combat_started)
	combat._on_online_hunt_identity({"player_id": "different-player"})
	if not combat._online_hunt_session.is_empty() or combat.next_turn_btn.text != "Return" or not combat._combat_session_invalid or combat._combat_started:
		push_error("Identity mismatch did not fail closed")
		quit(1)
		return
	print("PASS real HTTP hunt loadout, combat recovery and local isolation")
	quit(0)

func _run_terminal() -> void:
	var auth := FileAccess.open("user://auth.json", FileAccess.WRITE)
	auth.store_string(JSON.stringify({"token": OS.get_environment("EW_HUNT_TOKEN")}))
	auth.close()
	var session_id := OS.get_environment("EW_HUNT_SESSION")
	var expected := OS.get_environment("EW_TERMINAL_EXPECT")
	SceneRouter._solo_hunt_context = {"session_id": session_id, "hunt_id": "hunt_common", "rotation_key": 0}
	SceneRouter._hunt_loadout_active = true
	change_scene_to_file("res://scenes/LoadoutGrid.tscn")
	await process_frame
	await process_frame
	var loadout = current_scene
	var deadline := Time.get_ticks_msec() + 20000
	while not loadout._hunt_recovered and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._hunt_recovered:
		push_error("Terminal loadout recovery failed: " + loadout.lbl_build_error.text)
		quit(1)
		return
	loadout._on_play_pressed()
	await process_frame
	await process_frame
	var combat = current_scene
	if combat == null or not combat._online_hunt_guard:
		push_error("Terminal combat entry failed")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + 20000
	while combat._online_hunt_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._online_hunt_session.is_empty():
		push_error("Terminal session GET failed")
		quit(1)
		return
	var attempts := 0
	while str(combat._online_hunt_session.get("status", "")) == "ACTIVE" and attempts < 12:
		var available := -1
		for i in 4:
			if not combat._online_spell_decision(i).is_empty():
				available = i
				break
		if available < 0:
			break
		var revision: int = combat._online_hunt_revision
		var simulate_lost := OS.get_environment("EW_TERMINAL_LOST") == "1"
		if simulate_lost:
			combat._combat_backend.api_completed.disconnect(combat._on_online_hunt_response)
		combat._on_spell_chosen(available)
		var pending: Dictionary = combat._online_turn_payload.duplicate(true)
		if simulate_lost:
			deadline = Time.get_ticks_msec() + 20000
			while combat.next_turn_btn.text != "Recover" and Time.get_ticks_msec() < deadline:
				await create_timer(0.1).timeout
			combat._combat_backend.api_completed.connect(combat._on_online_hunt_response)
			assert(combat._online_turn_payload == pending and combat.next_turn_btn.text == "Recover")
			combat._on_next_turn()
		deadline = Time.get_ticks_msec() + 20000
		while combat._online_hunt_revision == revision and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
		attempts += 1
	if str(combat._online_hunt_session.get("status", "")) != "VERIFIED_" + expected or combat._online_hunt_revision < 2 or combat._combat_started:
		push_error("Unexpected terminal result: " + str(combat._online_hunt_session.get("status", "")))
		quit(1)
		return
	for button in combat.spell_buttons:
		assert(button.disabled)
	assert(combat.next_turn_btn.text == "Return")
	assert(int(combat.player_hp.value) == int(combat._online_hunt_session.combat_state.player.hp))
	assert(int(combat.enemy_hp.value) == int(combat._online_hunt_session.combat_state.boss.hp))
	var final_revision: int = combat._online_hunt_revision
	combat._on_spell_chosen(0)
	assert(combat._online_hunt_revision == final_revision and combat._online_turn_payload.is_empty())
	assert(combat.log_box.get_parsed_text().count("Server result: ") == 1)
	print("PASS real terminal ", expected, " revision ", combat._online_hunt_revision)
	quit(0)
