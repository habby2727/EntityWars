extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("EW_DUNGEON_DEBUG_E2E") == "1":
		await _run_debug_entry()
		return
	if OS.get_environment("EW_DUNGEON_E2E") == "1":
		await _run_e2e()
		return
	var backend := BackendClient.new()
	backend.auto_dev_login = false
	root.add_child(backend)
	await process_frame
	backend.token = "fixture-token"
	backend._verified_player_id = "fixture-player"
	var panel = load("res://scripts/ui/lab_specialized_panel.gd").new()
	root.add_child(panel)
	var registry := DataRegistry.new()
	panel.setup(registry, backend, false, 20, 10)
	var state := {"lab": {"hqLevel": 4, "buildings": {"sync_nexus": {"level": 1}}, "runtime": {}}}
	panel.show_building("sync_nexus", state, {}, {}, true)
	panel._update_sync_status()
	assert(panel._lab_buttons.size() == 1)
	assert(panel._lab_buttons[0].text == "START")
	assert(is_instance_valid(panel._dungeon_entry_button) and panel._dungeon_entry_button.text == "ENTER DUNGEON")
	assert(not panel._dungeon_ranking_button.disabled)
	panel._dungeon_request = "fixture-request"
	panel._dungeon_request_owner = "fixture-player"
	panel._dungeon_ranking_month = "2026-01"
	panel._on_dungeon_api_completed("fixture-request", true, {"season": "2026-01", "leaders": [{"rank": 1, "display_name": "Test", "cleared_floor": 3, "total_turns": 17}], "player": {"rank": 1, "cleared_floor": 3}})
	assert(panel._dungeon_ranking_text.text.contains("Test"))
	assert(panel._dungeon_ranking_text.text.contains("Floor 3"))
	assert(panel._lab_buttons[0].text == "START")
	panel.queue_free()
	backend.queue_free()
	await process_frame
	registry.free()
	var lab = load("res://scenes/ui/LabStructures.tscn").instantiate()
	lab._debug.unlock_all_buildings = false
	lab.get_node("BackendClient").auto_dev_login = false
	root.add_child(lab)
	await process_frame
	var lab_backend: BackendClient = lab._backend
	if not lab_backend.state_updated.is_connected(lab._on_state_updated):
		lab._debug.unlock_all_buildings = false
		lab._connect_backend()
	assert(lab_backend.state_updated.is_connected(lab._on_state_updated))
	root.remove_child(lab)
	assert(not lab_backend.state_updated.is_connected(lab._on_state_updated))
	lab_backend.state_updated.emit({})
	lab._on_state_updated({})
	lab._refresh_from_state()
	lab.queue_free()
	await process_frame
	SceneRouter._dungeon_context = {"run_id": "fixture-run", "player_id": "fixture-player"}
	assert(SceneRouter._solo_hunt_context.is_empty())
	change_scene_to_file("res://scenes/LoadoutGrid.tscn")
	await process_frame
	await process_frame
	var loadout = current_scene
	assert(loadout._dungeon_mode and not loadout._hunt_mode)
	assert(not loadout.btn_save.visible)
	assert(not loadout.get_node("RootMargin/MainHSplit/LeftPanel/ModeRow/AttackCol").visible)
	assert(not loadout.get_node("RootMargin/MainHSplit/LeftPanel/ModeRow/DefenseCol").visible)
	assert(loadout.get_node("RootMargin/MainHSplit/LeftPanel/TabButtons").visible)
	assert(loadout._idx_to_id(loadout._items, loadout.dd_item1).is_empty())
	assert(loadout._idx_to_id(loadout._items, loadout.dd_item2).is_empty())
	loadout._on_play_pressed()
	assert(current_scene == loadout)
	SceneRouter.return_from_dungeon()
	await process_frame
	await process_frame
	assert(current_scene.scene_file_path == "res://scenes/ui/LabStructures.tscn")
	SceneRouter._dungeon_context = {"run_id": "fixture-run", "player_id": "fixture-player"}
	change_scene_to_file("res://scenes/Combat.tscn")
	await process_frame
	await process_frame
	var combat = current_scene
	assert(combat._combat_session_invalid and not combat._combat_started)
	assert(not combat.spell_panel.visible)
	var combo_text: String = combat._dungeon_strategic_event({"kind": "combo_trigger", "source_spell_id": "pyrolytic_fuse", "prerequisite": "poison", "actual_bonus_damage": 8})
	assert(combo_text.contains("ALCHEMICAL COMBO") and combo_text.contains("Pyrolytic Fuse") and combo_text.contains("+8 damage"))
	SceneRouter._dungeon_context.clear()
	current_scene.queue_free()
	await process_frame
	if is_instance_valid(UIThemeFactory._catalog):
		UIThemeFactory._catalog.free()
		UIThemeFactory._catalog = null
	print("PASS Dungeon ranking and Sync Nexus calibration controls")
	quit(0)

func _run_debug_entry() -> void:
	var test_root := OS.get_environment("DUNGEON_TEST_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		push_error("Isolated user directory required")
		quit(1)
		return
	var backend := BackendClient.new()
	backend.auto_dev_login = false
	root.add_child(backend)
	await process_frame
	var registry := DataRegistry.new()
	var panel = load("res://scripts/ui/lab_specialized_panel.gd").new()
	root.add_child(panel)
	panel.setup(registry, backend, true, 20, 10)
	panel.show_building("sync_nexus", {"lab": {"hqLevel": 4, "buildings": {"sync_nexus": {"level": 1}}, "runtime": {}}}, {}, {}, true)
	panel._update_sync_status()
	if panel._dungeon_entry_button.disabled or not backend.token.is_empty():
		push_error("Local debug entry unavailable before login")
		quit(1)
		return
	backend.token = "existing-token"
	panel._enter_dungeon()
	if not is_instance_valid(panel._dungeon_debug_confirm) or not panel._dungeon_debug_confirm.visible or backend.token != "existing-token" or not panel._dungeon_entry_request.is_empty():
		push_error("Existing identity was not protected by confirmation")
		quit(1)
		return
	panel._dungeon_debug_confirm.hide()
	backend.token = ""
	panel._enter_dungeon()
	var deadline := Time.get_ticks_msec() + 30000
	while (current_scene == null or not current_scene.has_method("_submit_dungeon_loadout")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == null or not current_scene.has_method("_submit_dungeon_loadout"):
		push_error("Debug account did not reach loadout: " + panel._dungeon_entry_status.text)
		quit(1)
		return
	var loadout = current_scene
	while not loadout._dungeon_recovered and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._dungeon_recovered:
		push_error("Debug Dungeon session recovery failed")
		quit(1)
		return
	loadout._set_button_selection(loadout.dd_item1, loadout._items, "bismuth_talisman")
	loadout._set_button_selection(loadout.dd_item2, loadout._items, "vitriol_vial")
	loadout._hunt_spells[loadout._current_entity_id] = ["pyrolytic_fuse", "cinder_fist", "ash_temper", "brimstone_crash"]
	loadout._on_play_pressed()
	deadline = Time.get_ticks_msec() + 30000
	while current_scene == loadout and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == loadout or not bool(SceneRouter._dungeon_context.get("session", {}).get("combat_ready", false)):
		push_error("Debug loadout was not confirmed by server")
		quit(1)
		return
	var combat = current_scene
	deadline = Time.get_ticks_msec() + 30000
	while combat._dungeon_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._dungeon_session.is_empty() or not is_instance_valid(combat._dungeon_floor_label) or not combat._dungeon_floor_label.text.begins_with("DUNGEONS — FLOOR ") or combat.spell_buttons[0].get_node_or_null("DungeonSpellType0") == null or not combat.spell_buttons[0].get_node("DungeonSpellType1").visible:
		push_error("Dungeon header or spell icons unavailable")
		quit(1)
		return
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	combat._dungeon_brief.hide()
	combat._dungeon_refresh_controls()
	var revision := int(combat._dungeon_session.combat_revision)
	if combat.switch_weapon_btn.disabled or not combat.switch_weapon_btn.visible:
		push_error("Dungeon switch unavailable with two supported weapons")
		quit(1)
		return
	combat._on_switch_weapon()
	deadline = Time.get_ticks_msec() + 30000
	while not combat._dungeon_playing_events and int(combat._dungeon_session.combat_revision) == revision and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if not combat._dungeon_playing_events or int(combat._dungeon_session.combat_revision) != revision or not combat.switch_weapon_btn.disabled:
		push_error("Dungeon playback did not lock actions before applying the final state")
		quit(1)
		return
	while int(combat._dungeon_session.combat_revision) == revision and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if int(combat._dungeon_session.combat_revision) != revision + 1 or int(combat._dungeon_session.combat_state.active_weapon_slot) != 2:
		push_error("Dungeon server switch failed")
		quit(1)
		return
	var db_path := OS.get_environment("DUNGEON_TEST_DB").replace("\\", "/").to_lower()
	if not db_path.begins_with(test_root + "/") or not db_path.ends_with("test.sqlite"):
		push_error("Unsafe Inspiration fixture database")
		quit(1)
		return
	OS.set_environment("DUNGEON_TEST_RUN_ID", str(SceneRouter._dungeon_context.get("run_id", "")))
	var fixture := "const {Database}=require('bun:sqlite');const db=new Database(process.env.DUNGEON_TEST_DB);const row=db.query('SELECT combat_state_json FROM dungeon_runs WHERE run_id=?').get(process.env.DUNGEON_TEST_RUN_ID);const s=JSON.parse(row.combat_state_json);s.player.inspiration=2;s.player.hp=s.player.max_hp=1000;s.npc.hp=s.npc.max_hp=1000;s.npc.status.atk_down=0;s.spells.find(x=>x.id==='brimstone_crash').accuracy=1;db.query('UPDATE dungeon_runs SET combat_state_json=? WHERE run_id=?').run(JSON.stringify(s),process.env.DUNGEON_TEST_RUN_ID);db.close();"
	var output := []
	if OS.execute("bun", ["-e", fixture], output, true) != 0:
		push_error("Inspiration fixture failed")
		quit(1)
		return
	combat._dungeon_recover()
	deadline = Time.get_ticks_msec() + 30000
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	revision = int(combat._dungeon_session.combat_revision)
	combat._on_spell_chosen(3)
	if not combat._dungeon_hom_choice.is_empty(): combat._on_hom_choice("hold")
	deadline = Time.get_ticks_msec() + 30000
	while int(combat._dungeon_session.combat_revision) == revision and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not combat._inspiration_panel.visible or combat._inspiration_options.size() != 3:
		push_error("Dungeon Inspiration offers were not displayed")
		quit(1)
		return
	var turn_before := int(combat._dungeon_session.combat_state.turn)
	revision = int(combat._dungeon_session.combat_revision)
	var chosen_id := str(combat._inspiration_options[0].id)
	combat._choose_inspiration(0)
	deadline = Time.get_ticks_msec() + 30000
	while int(combat._dungeon_session.combat_revision) == revision and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if int(combat._dungeon_session.combat_revision) != revision + 1 or int(combat._dungeon_session.combat_state.turn) != turn_before or chosen_id not in combat._dungeon_session.combat_state.player.spell_ids:
		push_error("Dungeon Inspiration choice was not confirmed")
		quit(1)
		return
	var prior_run := str(SceneRouter._dungeon_context.get("run_id", ""))
	panel._enter_dungeon()
	deadline = Time.get_ticks_msec() + 30000
	while (not is_instance_valid(panel._dungeon_debug_run_choice) or not panel._dungeon_debug_run_choice.visible) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not is_instance_valid(panel._dungeon_debug_run_choice) or not panel._dungeon_debug_run_choice.visible or str(panel._dungeon_debug_session.get("run_id", "")) != prior_run:
		push_error("Debug run choice did not preserve the active run")
		quit(1)
		return
	panel._dungeon_debug_run_action("new_test_run")
	if not panel._dungeon_debug_abandon_confirm.visible or not panel._dungeon_entry_request.is_empty():
		push_error("New test run did not require confirmation")
		quit(1)
		return
	panel._dungeon_debug_abandon()
	deadline = Time.get_ticks_msec() + 30000
	while (current_scene == combat or not current_scene.has_method("_submit_dungeon_loadout")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == combat or str(SceneRouter._dungeon_context.get("run_id", "")) == prior_run:
		push_error("New test run did not reach a fresh Loadout")
		quit(1)
		return
	print("PASS authenticated local debug entry, preparation and Dungeon loadout")
	panel.queue_free()
	backend.queue_free()
	current_scene.queue_free()
	registry.free()
	await process_frame
	quit(0)

func _run_e2e() -> void:
	var test_root := OS.get_environment("DUNGEON_TEST_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		push_error("Isolated user directory required")
		quit(1)
		return
	var seal_existed := FileAccess.file_exists("user://seal_attack.json")
	var seal_before := FileAccess.get_file_as_bytes("user://seal_attack.json") if seal_existed else PackedByteArray()
	var file := FileAccess.open("user://auth.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"token": OS.get_environment("DUNGEON_TEST_TOKEN")}))
	file.close()
	var backend := BackendClient.new()
	backend.auto_dev_login = false
	root.add_child(backend)
	var deadline := Time.get_ticks_msec() + 30000
	while backend._verified_player_id.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if backend._verified_player_id.is_empty():
		push_error("Dungeon authentication failed")
		quit(1)
		return
	var panel = load("res://scripts/ui/lab_specialized_panel.gd").new()
	root.add_child(panel)
	var registry := DataRegistry.new()
	panel.setup(registry, backend, false, 20, 10)
	panel.show_building("sync_nexus", {"lab": {"hqLevel": 4, "buildings": {"sync_nexus": {"level": 1}}, "runtime": {}}}, {}, {}, true)
	panel._enter_dungeon()
	deadline = Time.get_ticks_msec() + 30000
	while (current_scene == null or not current_scene.has_method("_submit_dungeon_loadout")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == null or not current_scene.has_method("_submit_dungeon_loadout"):
		push_error("Dungeon entry did not reach loadout: " + panel._dungeon_entry_status.text)
		quit(1)
		return
	var loadout = current_scene
	deadline = Time.get_ticks_msec() + 30000
	while not loadout._dungeon_recovered and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._dungeon_recovered:
		push_error("Dungeon loadout recovery failed: " + loadout.lbl_build_error.text)
		quit(1)
		return
	loadout._dungeon_backend.api_completed.disconnect(loadout._on_dungeon_loadout_response)
	loadout._on_play_pressed()
	var lost_loadout_request: String = loadout._dungeon_request
	deadline = Time.get_ticks_msec() + 30000
	while not loadout._dungeon_backend._api_in_flight.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	loadout._dungeon_backend.api_completed.connect(loadout._on_dungeon_loadout_response)
	if lost_loadout_request.is_empty() or not loadout._dungeon_backend._api_in_flight.is_empty():
		push_error("Dungeon lost-loadout fixture failed")
		quit(1)
		return
	loadout._on_dungeon_loadout_response(lost_loadout_request, false, {"error": "network_error"})
	deadline = Time.get_ticks_msec() + 30000
	while current_scene == loadout and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == loadout or not current_scene._combat_session_invalid or current_scene._combat_started:
		push_error("Dungeon loadout did not reach safe combat")
		quit(1)
		return
	if not bool(SceneRouter._dungeon_context.get("session", {}).get("combat_ready", false)):
		push_error("Dungeon combat was not server confirmed")
		quit(1)
		return
	var run_id := str(SceneRouter._dungeon_context.get("run_id", ""))
	var combat = current_scene
	deadline = Time.get_ticks_msec() + 30000
	while combat._dungeon_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._dungeon_session.is_empty() or combat.player_entity.texture == null or combat.enemy_entity.texture == null:
		push_error("Dungeon server fighters not rendered")
		quit(1)
		return
	if not is_instance_valid(combat._dungeon_floor_label) or not combat._dungeon_floor_label.text.begins_with("DUNGEONS — FLOOR ") or combat.spell_buttons[0].get_node_or_null("DungeonSpellType0") == null:
		push_error("Dungeon floor header or spell icon missing")
		quit(1)
		return
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	combat._dungeon_brief.hide()
	combat._dungeon_refresh_controls()
	if OS.has_environment("DUNGEON_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		if screenshot == null or screenshot.is_empty() or screenshot.save_png(OS.get_environment("DUNGEON_CAPTURE_DIR").path_join("dungeon-combat.png")) != OK:
			push_error("Dungeon screenshot failed")
			quit(1)
			return
	var initial_revision := int(combat._dungeon_session.combat_revision)
	combat._on_spell_chosen(0)
	var replay_payload: Dictionary = combat._dungeon_pending.duplicate(true)
	deadline = Time.get_ticks_msec() + 30000
	while int(combat._dungeon_session.get("combat_revision", 0)) == initial_revision and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if int(combat._dungeon_session.get("combat_revision", 0)) != initial_revision + 1:
		push_error("Dungeon real turn failed")
		quit(1)
		return
	var first_hp := int(combat._dungeon_session.combat_state.npc.hp)
	var first_log: String = combat.log_box.get_parsed_text()
	combat._dungeon_pending = replay_payload.duplicate(true)
	combat._dungeon_send_pending()
	deadline = Time.get_ticks_msec() + 30000
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not combat._dungeon_pending.is_empty() or int(combat._dungeon_session.combat_revision) != initial_revision + 1 or int(combat._dungeon_session.combat_state.npc.hp) != first_hp or combat.log_box.get_parsed_text() != first_log:
		push_error("Dungeon replay duplicated damage or events")
		quit(1)
		return
	var owner: String = combat._combat_backend._verified_player_id
	combat._combat_backend._verified_player_id = "different-account"
	combat._dungeon_refresh_controls()
	if not combat.spell_buttons[0].disabled:
		push_error("Dungeon allowed actions after account change")
		quit(1)
		return
	combat._combat_backend._verified_player_id = owner
	combat._dungeon_refresh_controls()
	assert(combat._reward_request_id.is_empty())
	combat._combat_backend.api_completed.disconnect(combat._dungeon_on_response)
	combat._on_spell_chosen(0)
	var lost: Dictionary = combat._dungeon_pending.duplicate(true)
	var lost_request: String = combat._dungeon_request
	deadline = Time.get_ticks_msec() + 30000
	while not combat._combat_backend._api_in_flight.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	combat._combat_backend.api_completed.connect(combat._dungeon_on_response)
	if lost.is_empty() or lost_request.is_empty() or not combat._combat_backend._api_in_flight.is_empty():
		push_error("Dungeon lost-response fixture failed")
		quit(1)
		return
	combat._dungeon_on_response(lost_request, false, {"error": "network_error"})
	if combat._dungeon_pending != lost or not combat.spell_buttons[0].disabled:
		push_error("Dungeon did not lock the uncertain action")
		quit(1)
		return
	combat._on_next_turn()
	deadline = Time.get_ticks_msec() + 30000
	while (not combat._dungeon_pending.is_empty() or not combat._dungeon_request.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not combat._dungeon_pending.is_empty() or int(combat._dungeon_session.combat_revision) != initial_revision + 2 or not combat._dungeon_seen_actions.has(str(lost.payload.client_action_id)):
		push_error("Dungeon lost-response recovery failed")
		quit(1)
		return
	var database := OS.get_environment("DUNGEON_TEST_DB").replace("\\", "/").to_lower()
	if not database.begins_with(test_root + "/") or not database.ends_with("test.sqlite"):
		push_error("Unsafe Dungeon fixture database")
		quit(1)
		return
	OS.set_environment("DUNGEON_TEST_RUN_ID", run_id)
	var strategic_fixture := "const {Database}=require('bun:sqlite');const db=new Database(process.env.DUNGEON_TEST_DB);const row=db.query('SELECT combat_state_json FROM dungeon_runs WHERE run_id=?').get(process.env.DUNGEON_TEST_RUN_ID);const s=JSON.parse(row.combat_state_json);const catalog=require('./data/spells.json').spells;s.fixture_original_spell_ids=s.player.spell_ids;s.player.type='vitriol';s.player.hp=s.player.max_hp=10000;s.player.atk=100;s.player.status={};s.player.cooldowns={};s.npc.hp=s.npc.max_hp=10000;s.npc.atk=1;s.npc.status={};s.npc.hom_energy=0;s.npc.cooldowns=Object.fromEntries(s.npc.spell_ids.map(id=>[id,1000]));for(const id of ['nuclear_fallout','etching_fang','caustic_mark','pyrolytic_fuse']){let x=structuredClone(catalog.find(x=>x.id===id));x.accuracy=1;s.spells=s.spells.filter(y=>y.id!==id);s.spells.push(x)}s.player.spell_ids=['nuclear_fallout','etching_fang','caustic_mark','pyrolytic_fuse'];db.query('UPDATE dungeon_runs SET combat_state_json=? WHERE run_id=?').run(JSON.stringify(s),process.env.DUNGEON_TEST_RUN_ID);db.close();"
	var strategic_output := []
	if OS.execute("bun", ["-e", strategic_fixture], strategic_output, true) != 0:
		push_error("Dungeon strategic fixture update failed")
		quit(1)
		return
	combat._dungeon_recover()
	deadline = Time.get_ticks_msec() + 30000
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	var combo_payload: Dictionary = {}
	var anomaly_steps := 0
	for index in [0, 1, 1, 1, 2, 3]:
		var rev := int(combat._dungeon_session.combat_revision)
		combat._on_spell_chosen(index)
		if not combat._dungeon_hom_choice.is_empty(): combat._on_hom_choice("hold")
		if index == 3: combo_payload = combat._dungeon_pending.duplicate(true)
		deadline = Time.get_ticks_msec() + 30000
		while int(combat._dungeon_session.get("combat_revision", 0)) == rev and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
		if int(combat._dungeon_session.get("combat_revision", 0)) != rev + 1:
			push_error("Dungeon strategic turn failed")
			quit(1)
			return
		var anomaly: Variant = combat._dungeon_session.combat_state.get("physical_anomaly")
		if index == 0 and (not anomaly is Dictionary or int(anomaly.remaining_exchanges) != 3 or not combat._physical_anomaly_label.text.contains("Nuclear Fallout") or not combat._physical_anomaly_label.text.contains("Sulfur +15%") or not combat._physical_anomaly_label.text.contains("Gold -15%")):
			push_error("Dungeon online anomaly display mismatch")
			quit(1)
			return
		if index == 1:
			anomaly_steps += 1
			var remaining := 3 - anomaly_steps
			if (remaining > 0 and (not anomaly is Dictionary or int(anomaly.get("remaining_exchanges", -1)) != remaining or not combat._physical_anomaly_label.text.contains("%d exchanges" % remaining))) or (remaining == 0 and (anomaly != null or combat._physical_anomaly_label.visible)):
				push_error("Dungeon online anomaly countdown mismatch")
				quit(1)
				return
	if combat._physical_anomaly_label.visible or not combat.log_box.get_parsed_text().contains("ALCHEMICAL COMBO | Poison + Pyrolytic Fuse"):
		push_error("Dungeon anomaly expiry or verified combo feedback missing")
		quit(1)
		return
	var combo_log: String = combat.log_box.get_parsed_text()
	var combo_revision := int(combat._dungeon_session.combat_revision)
	combat._dungeon_pending = combo_payload
	combat._dungeon_send_pending()
	deadline = Time.get_ticks_msec() + 30000
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not combat._dungeon_pending.is_empty() or int(combat._dungeon_session.combat_revision) != combo_revision or combat.log_box.get_parsed_text() != combo_log:
		push_error("Dungeon combo replay duplicated feedback")
		quit(1)
		return
	var restore_fixture := "const {Database}=require('bun:sqlite');const db=new Database(process.env.DUNGEON_TEST_DB);const row=db.query('SELECT combat_state_json FROM dungeon_runs WHERE run_id=?').get(process.env.DUNGEON_TEST_RUN_ID);const s=JSON.parse(row.combat_state_json);s.player.spell_ids=s.fixture_original_spell_ids;delete s.fixture_original_spell_ids;s.player.cooldowns={};db.query('UPDATE dungeon_runs SET combat_state_json=? WHERE run_id=?').run(JSON.stringify(s),process.env.DUNGEON_TEST_RUN_ID);db.close();"
	if OS.execute("bun", ["-e", restore_fixture], strategic_output, true) != 0:
		push_error("Dungeon fixture restoration failed")
		quit(1)
		return
	var fixture := "const {Database}=require('bun:sqlite');const db=new Database(process.env.DUNGEON_TEST_DB);const row=db.query('SELECT combat_state_json FROM dungeon_runs WHERE run_id=?').get(process.env.DUNGEON_TEST_RUN_ID);const state=JSON.parse(row.combat_state_json);state.npc.hp=1;state.player.hp=state.player.max_hp;db.query('UPDATE dungeon_runs SET combat_state_json=? WHERE run_id=?').run(JSON.stringify(state),process.env.DUNGEON_TEST_RUN_ID);db.close();"
	var fixture_output := []
	if OS.execute("bun", ["-e", fixture], fixture_output, true) != 0:
		push_error("Dungeon fixture update failed")
		quit(1)
		return
	combat._dungeon_recover()
	deadline = Time.get_ticks_msec() + 30000
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	var previous_entity := str(combat._dungeon_session.combat_state.npc.id)
	var previous_hom := str(combat._dungeon_session.combat_state.npc.hom_id)
	for attempt in 8:
		if str(combat._dungeon_session.get("phase", "")) == "FLOOR_CLEARED": break
		var rev := int(combat._dungeon_session.combat_revision)
		combat._on_spell_chosen(0)
		if not combat._dungeon_hom_choice.is_empty(): combat._on_hom_choice("hold")
		deadline = Time.get_ticks_msec() + 30000
		while int(combat._dungeon_session.get("combat_revision", 0)) == rev and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
	if str(combat._dungeon_session.get("phase", "")) != "FLOOR_CLEARED":
		push_error("Dungeon floor did not reach verified victory")
		quit(1)
		return
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	combat._on_next_turn()
	deadline = Time.get_ticks_msec() + 30000
	while int(combat._dungeon_session.get("combat_state", {}).get("floor", 0)) < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	var next_npc: Dictionary = combat._dungeon_session.get("combat_state", {}).get("npc", {})
	if int(combat._dungeon_session.get("combat_state", {}).get("floor", 0)) != 2 or str(next_npc.get("id", "")) == previous_entity or str(next_npc.get("hom_id", "")) == previous_hom:
		push_error("Dungeon next floor did not change opponent")
		quit(1)
		return
	if FileAccess.file_exists("user://seal_attack.json") != seal_existed or (seal_existed and FileAccess.get_file_as_bytes("user://seal_attack.json") != seal_before):
		push_error("Dungeon modified the PvP seal")
		quit(1)
		return
	current_scene._on_back_pressed()
	await process_frame
	await process_frame
	panel._enter_dungeon()
	deadline = Time.get_ticks_msec() + 30000
	while (current_scene == null or not current_scene.has_method("_begin_combat_initialization")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if current_scene == null or not current_scene.has_method("_begin_combat_initialization") or str(SceneRouter._dungeon_context.get("run_id", "")) != run_id or current_scene._combat_started:
		push_error("Dungeon resume changed the run or started local combat")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + 30000
	while current_scene._dungeon_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if int(current_scene._dungeon_session.get("combat_state", {}).get("floor", 0)) != 2:
		push_error("Dungeon resume did not recover floor 2")
		quit(1)
		return
	combat = current_scene
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	combat._dungeon_brief.hide()
	combat._dungeon_refresh_controls()
	var loss_fixture := "const {Database}=require('bun:sqlite');const db=new Database(process.env.DUNGEON_TEST_DB);const row=db.query('SELECT combat_state_json FROM dungeon_runs WHERE run_id=?').get(process.env.DUNGEON_TEST_RUN_ID);const state=JSON.parse(row.combat_state_json);state.player.hp=1;state.npc.atk=10000;state.npc.hp=state.npc.max_hp;db.query('UPDATE dungeon_runs SET combat_state_json=? WHERE run_id=?').run(JSON.stringify(state),process.env.DUNGEON_TEST_RUN_ID);db.close();"
	for attempt in 12:
		if str(combat._dungeon_session.get("status", "")) == "LOSS": break
		if OS.execute("bun", ["-e", loss_fixture], fixture_output, true) != 0:
			push_error("Dungeon loss fixture failed")
			quit(1)
			return
		combat._dungeon_recover()
		deadline = Time.get_ticks_msec() + 30000
		while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
		var rev := int(combat._dungeon_session.combat_revision)
		combat._on_spell_chosen(0)
		if not combat._dungeon_hom_choice.is_empty(): combat._on_hom_choice("hold")
		deadline = Time.get_ticks_msec() + 30000
		while int(combat._dungeon_session.get("combat_revision", 0)) == rev and Time.get_ticks_msec() < deadline:
			await create_timer(0.1).timeout
	if str(combat._dungeon_session.get("status", "")) != "LOSS" or not combat.log_box.get_parsed_text().contains("RUN OVER") or combat.next_turn_btn.text != "Return":
		push_error("Dungeon verified loss presentation failed")
		quit(1)
		return
	for button in combat.spell_buttons:
		if not button.disabled:
			push_error("Dungeon loss did not lock spells")
			quit(1)
			return
	while not combat._dungeon_request.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	current_scene.queue_free()
	panel.queue_free()
	backend.queue_free()
	await process_frame
	registry.free()
	if is_instance_valid(UIThemeFactory._catalog):
		UIThemeFactory._catalog.free()
		UIThemeFactory._catalog = null
	print("PASS real HTTP Dungeon turn, lost-response recovery, victory, next floor, resume and loss")
	quit(0)
