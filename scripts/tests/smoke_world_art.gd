extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_environment("EW_C6_E2E") == "1":
		await _run_real_guardian()
		return
	if OS.has_environment("EW_CAPTURE_DIR"):
		DisplayServer.window_set_size(Vector2i(1280, 720) if OS.has_environment("EW_SMALL") else Vector2i(1920, 1080))
	for world in ["Chaos", "Corrupted", "Crystal"]:
		var scene := load("res://scenes/ui/WorldZone%s.tscn" % world) as PackedScene
		var zone := scene.instantiate()
		zone.get_node("BackendClient").auto_dev_login = false
		zone.get_node("BackendClient").base_url = "http://127.0.0.1:1"
		root.add_child(zone)
		await process_frame
		if OS.has_environment("EW_CAPTURE_DIR"):
			await create_timer(1.0).timeout
			root.get_texture().get_image().save_png(OS.get_environment("EW_CAPTURE_DIR").path_join(world + ".png"))
		var entries: Array = zone.WORLD_ART["zone_" + world.to_lower()]
		assert(zone._background.texture != null)
		for index in entries.size():
			zone._change_world_art(1)
			assert(zone._world_sprite.texture != null)
			for companion in zone._world_companions:
				assert(companion.get_node("EncounterName").text.contains(str(companion.get_meta("appearance_name"))))
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		zone._world_companions[0].gui_input.emit(click)
		assert(zone._debug_visual.id != zone._central_visual.id)
		zone._world_modal.visible = false
		zone._world_sprite.gui_input.emit(click)
		assert(zone._debug_visual == zone._central_visual)
		assert(zone._world_modal.visible)
		var close_button: Button = null
		for button in zone._world_modal.find_children("*", "Button", true, false):
			if button.text == "X":
				close_button = button
				break
		assert(close_button != null and close_button.text == "X")
		close_button.pressed.emit()
		assert(not zone._world_modal.visible)
		var tiers := ["mythic", "rare", "epic", "legendary"]
		var textures := ["boss_colossus", "boss_leviathan", "boss_temporal", "ghost_boss"]
		for tier_index in tiers.size():
			var guardians: Array = []
			if tier_index > 0:
				guardians.append({"id": "higher", "name": "Higher guardian", "tier": tiers[tier_index - 1], "texture_id": textures[tier_index - 1]})
			var commons := 2 if tier_index <= 1 else tier_index + 1
			for i in commons:
				guardians.append({"id": "common_%d" % i, "name": "Common %d" % i, "tier": "common", "texture_id": "res://assets/lab/bosses/%s_zone_common/%s.png" % [world.to_lower(), entries[i]]})
			var main := {"id": "main", "name": "Boss", "tier": tiers[tier_index], "texture_id": textures[tier_index]}
			zone.show_guardian_preview(main, guardians)
			await process_frame
			assert(zone._preview_stage.get_child_count() == guardians.size() + 1)
			var actor: Control = zone._preview_stage.get_child(1)
			actor.get_child(0).gui_input.emit(click)
			assert(zone._preview_selection == str(guardians[0].id))
			zone._world_modal.visible = false
			guardians[0]["defeated"] = true
			zone.show_guardian_preview(main, guardians)
			await process_frame
			assert(zone._preview_stage.get_child_count() == guardians.size())
			for guardian in guardians:
				guardian["defeated"] = true
			zone.show_guardian_preview(main, guardians)
			await process_frame
			assert(zone._preview_stage.get_child_count() == 1)
			assert(not "LOCKED" in zone._preview_stage.get_child(0).get_child(1).text)
			if OS.has_environment("EW_CAPTURE_DIR") and tier_index == 3:
				for guardian in guardians:
					guardian["defeated"] = false
				zone.show_guardian_preview(main, guardians)
				await process_frame
				await create_timer(0.3).timeout
				root.get_texture().get_image().save_png(OS.get_environment("EW_CAPTURE_DIR").path_join("stage_" + world + ".png"))
		zone._clear_guardian_preview()
		var rare := {"id": "hunt_rare", "name": "Rare Boss", "tier": "rare", "texture_id": "boss_leviathan", "available": true}
		var mythic := {"id": "hunt_mythic", "name": "Mythic Boss", "tier": "mythic", "texture_id": "boss_colossus", "available": true}
		zone._hunt_schedule = [rare, mythic]
		zone._backend.token = "fixture"
		zone._backend._verified_player_id = "fixture-player"
		zone._hunt_selected = rare.duplicate(true)
		zone._hunt_progress_key = zone._guardian_key()
		zone._hunt_progress_owner = "fixture-player"
		var online_guardians: Array = []
		for i in 3:
			online_guardians.append({"guardian_id": "guardian_%d" % i, "name": "Guardian %d" % i, "tier": "common", "texture_id": "res://assets/lab/bosses/%s_zone_common/%s.png" % [world.to_lower(), entries[i]], "defeated": false})
		zone._hunt_progress = {"guardians": online_guardians, "defeated_count": 0, "total_count": 3, "boss_unlocked": false}
		zone._show_map_hunt(rare)
		await process_frame
		if OS.has_environment("EW_CAPTURE_DIR"):
			await create_timer(0.3).timeout
			root.get_texture().get_image().save_png(OS.get_environment("EW_CAPTURE_DIR").path_join("map_hunt_" + world + ".png"))
		assert(zone._preview_stage.get_child_count() == 5)
		var stage_before = zone._preview_stage
		var actors_before = stage_before.get_children()
		zone._open_main_preview()
		assert(zone._boss_portrait.texture != null and zone._view_guardians.visible)
		zone._show_selected_guardians()
		assert(zone._hunt_guardian_id == "guardian_0" and zone._preview_stage == stage_before and zone._preview_stage.get_children() == actors_before)
		var guard: Control = zone._preview_stage.get_child(1)
		guard.get_child(0).gui_input.emit(click)
		assert(zone._hunt_guardian_id == "guardian_0" and zone._hunt_fight.visible)
		zone._world_modal.visible = false
		var previous_rotation: int = zone._debug_rotation
		var rightmost: Control = zone._preview_stage.get_child(3)
		var rightmost_sprite: Control = rightmost.get_child(0)
		var nearby: Control = zone._preview_stage.get_node("NearbyHunt")
		assert(not rightmost_sprite.get_global_rect().intersects(nearby.get_global_rect()))
		var actual_click := InputEventMouseButton.new()
		actual_click.button_index = MOUSE_BUTTON_LEFT
		actual_click.pressed = true
		actual_click.position = root.get_canvas_transform() * rightmost_sprite.get_global_rect().get_center()
		root.push_input(actual_click, true)
		await process_frame
		assert(zone._hunt_guardian_id == "guardian_2" and zone._debug_rotation == previous_rotation and zone._hunt_selected.id == "hunt_rare")
		zone._world_modal.visible = false
		zone._hunt_active_owner = "fixture-player"
		zone._hunt_active = {"hunt_id": "hunt_common", "parent_hunt_id": "hunt_rare", "guardian_id": "guardian_2", "zone_id": zone._get_zone_id(), "expires_at": 9999999999999}
		assert(zone._active_hunt_matches("guardian_2") and not zone._active_hunt_matches("guardian_0") and not zone._active_hunt_matches(""))
		zone._hunt_active.clear()
		var map_actor: Control = zone._preview_stage.get_child(0)
		map_actor.get_child(0).gui_input.emit(click)
		assert(zone._preview_selection == "hunt_rare" and zone._hunt_fight.visible and zone._hunt_fight.disabled)
		zone._world_modal.visible = false
		online_guardians[0].defeated = true
		zone._hunt_progress.defeated_count = 1
		zone._show_map_hunt(rare)
		await process_frame
		assert(zone._preview_stage.get_child_count() == 4)
		for guardian in online_guardians:
			guardian.defeated = true
		zone._hunt_progress.boss_unlocked = true
		zone._hunt_progress.defeated_count = 3
		zone._show_map_hunt(rare)
		await process_frame
		assert(zone._preview_stage.get_child_count() == 2)
		zone._world_modal.visible = false
		var online_stage = zone._preview_stage
		var online_actors: Array = online_stage.get_children()
		zone._preview_stage.get_node("NearbyHunt").pressed.emit()
		assert(zone._hunt_selected.id == "hunt_mythic", "selected: " + str(zone._hunt_selected))
		assert(zone._world_modal.visible and zone._preview_selection == "hunt_mythic")
		assert(zone._preview_stage == online_stage and zone._preview_stage.get_children() == online_actors)
		zone._world_modal.visible = false
		zone._clear_guardian_preview()
		zone._debug.unlock_all_buildings = true
		var reroll_style = zone._reroll_button.get_theme_stylebox("normal")
		zone._reroll_world_art()
		zone._update_reroll_button()
		assert(zone._reroll_button.disabled and zone._reroll_remaining() > 0)
		assert(zone._reroll_button.get_theme_stylebox("disabled") == reroll_style)
		var rotation_before: int = zone._debug_rotation
		zone._reroll_world_art()
		assert(zone._debug_rotation == rotation_before)
		assert(is_instance_valid(zone._preview_stage))
		assert(zone._preview_stage.get_child_count() >= 3)
		zone._show_debug_boss(4)
		await process_frame
		assert(zone._preview_stage.get_child_count() == 7)
		var debug_stage = zone._preview_stage
		var debug_actors: Array = debug_stage.get_children()
		zone._preview_stage.get_node("NearbyDebugBoss").pressed.emit()
		assert(zone._world_modal.visible and zone._preview_selection == "debug_mythic")
		assert(zone._preview_stage == debug_stage and zone._preview_stage.get_children() == debug_actors)
		zone._world_modal.visible = false
		zone._show_debug_boss(4)
		await process_frame
		zone._show_debug_boss(2)
		zone._preview_stage.get_node("NearbyDebugBoss").pressed.emit()
		assert(zone._preview_selection == "debug_epic" and zone._view_guardians.visible)
		assert(zone._preview_status.text.contains("its 4 guardians"))
		zone._view_guardians.pressed.emit()
		assert(zone._preview_stage == debug_stage or is_instance_valid(zone._preview_stage))
		zone._show_debug_boss(4)
		await process_frame
		if OS.has_environment("EW_GUARDIAN_CAPTURE") and world == "Chaos":
			zone._debug.unlock_all_buildings = false
			var legendary := {"id": "hunt_legendary", "name": "Eternal Warden Titan", "tier": "legendary", "texture_id": "ghost_boss", "available": true}
			zone._hunt_selected = legendary
			zone._hunt_progress_key = zone._guardian_key()
			zone._hunt_progress_owner = "fixture-player"
			var group: Array = []
			for i in 5:
				group.append({"guardian_id": "guardian_%d" % i, "name": "Gate Sentinel Guardian %d" % (i + 1), "tier": "common", "texture_id": "res://assets/lab/bosses/%s_zone_common/%s.png" % [world.to_lower(), entries[i]], "defeated": false})
			zone._hunt_progress = {"guardians": group, "defeated_count": 0, "total_count": 5, "boss_unlocked": false}
			zone._show_map_hunt(legendary)
			await process_frame
			zone._preview_stage.get_child(0).get_child(0).gui_input.emit(click)
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(OS.get_environment("EW_GUARDIAN_CAPTURE")) == OK)
		if OS.has_environment("EW_CAPTURE_DIR"):
			await create_timer(0.3).timeout
			root.get_texture().get_image().save_png(OS.get_environment("EW_CAPTURE_DIR").path_join("legendary_" + world + ".png"))
		zone._clear_guardian_preview()
		zone.queue_free()
		await process_frame
		print("PASS ", world, " ", entries.size())
	quit()

func _run_real_guardian() -> void:
	var test_root := OS.get_environment("EW_C6_ROOT").replace("\\", "/").to_lower()
	if test_root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(test_root + "/"):
		push_error("Isolated user directory required")
		quit(1)
		return
	var auth := FileAccess.open("user://auth.json", FileAccess.WRITE)
	auth.store_string(JSON.stringify({"token": OS.get_environment("EW_C6_TOKEN")}))
	auth.close()
	change_scene_to_file("res://scenes/ui/WorldZoneChaos.tscn")
	await process_frame
	await process_frame
	var zone = current_scene
	var deadline := Time.get_ticks_msec() + 30000
	while (zone._backend._verified_player_id.is_empty() or zone._hunt_schedule.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	var special: Dictionary = {}
	for boss in zone._hunt_schedule:
		if str(boss.get("tier", "")) != "common" and bool(boss.get("available", false)):
			special = boss
			break
	if special.is_empty():
		push_error("No available special boss or schedule unavailable")
		quit(1)
		return
	zone._show_map_hunt(special)
	deadline = Time.get_ticks_msec() + 20000
	while zone._hunt_progress_key != zone._guardian_key() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if zone._hunt_progress_key != zone._guardian_key() or zone._hunt_progress.get("guardians", []).is_empty():
		push_error("Guardian progress unavailable")
		quit(1)
		return
	var guardian: Dictionary = zone._hunt_progress.guardians.back()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	zone._preview_stage.get_child(zone._hunt_progress.guardians.size()).get_child(0).gui_input.emit(click)
	if zone._hunt_guardian_id != str(guardian.guardian_id) or zone._hunt_fight.disabled:
		push_error("Guardian selection unavailable")
		quit(1)
		return
	zone._start_map_hunt()
	deadline = Time.get_ticks_msec() + 20000
	while current_scene == zone and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	var loadout = current_scene
	if loadout == zone or not loadout._hunt_mode:
		push_error("Guardian start failed: %s, requests=%s" % [zone._preview_status.text, str(zone._hunt_requests)])
		quit(1)
		return
	var session_id := str(SceneRouter._solo_hunt_context.get("session_id", ""))
	deadline = Time.get_ticks_msec() + 20000
	while not loadout._hunt_recovered and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if not loadout._hunt_recovered:
		push_error("Guardian loadout recovery failed")
		quit(1)
		return
	loadout._on_play_pressed()
	deadline = Time.get_ticks_msec() + 20000
	while int(SceneRouter._solo_hunt_context.get("recovered_session", {}).get("combat_revision", 0)) < 1 and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	loadout._on_play_pressed()
	await process_frame
	await process_frame
	var combat = current_scene
	if combat == loadout or not combat._online_hunt_guard:
		push_error("Guardian combat entry failed")
		quit(1)
		return
	deadline = Time.get_ticks_msec() + 20000
	while combat._online_hunt_session.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if combat._online_hunt_session.is_empty() or str(combat._online_hunt_session.get("session_id", "")) != session_id or str(combat._online_hunt_session.get("guardian_id", "")) != str(guardian.guardian_id) or combat._combat_started or combat.enemy_entity_name.text != str(guardian.name) or combat.enemy_entity.texture == null:
		push_error("Guardian combat snapshot mismatch")
		quit(1)
		return
	if str(guardian.texture_id).begins_with("res://") and combat.enemy_entity.texture.resource_path != str(guardian.texture_id):
		push_error("Guardian texture mismatch")
		quit(1)
		return
	combat._on_back_pressed()
	await process_frame
	await process_frame
	zone = current_scene
	deadline = Time.get_ticks_msec() + 30000
	while (zone._hunt_schedule.is_empty() or zone._hunt_active.is_empty() or zone._hunt_active_owner.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if zone._hunt_active.is_empty():
		push_error("Guardian session did not resume in World Zone")
		quit(1)
		return
	zone._show_map_hunt(special)
	deadline = Time.get_ticks_msec() + 20000
	while zone._hunt_progress_key != zone._guardian_key() and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	if zone._hunt_progress_key != zone._guardian_key() or not zone._active_hunt_matches(str(guardian.guardian_id)):
		push_error("Guardian identity did not match on resume")
		quit(1)
		return
	zone._preview_stage.get_child(zone._hunt_progress.guardians.size()).get_child(0).gui_input.emit(click)
	if zone._hunt_fight.disabled or zone._hunt_fight.text != "Resume Hunt":
		push_error("Guardian resume control unavailable")
		quit(1)
		return
	zone._start_map_hunt()
	await process_frame
	await process_frame
	if str(SceneRouter._solo_hunt_context.get("session_id", "")) != session_id:
		push_error("Resume changed the guardian session")
		quit(1)
		return
	print("PASS real guardian WorldZone -> Loadout -> Combat ", guardian.guardian_id)
	quit(0)
