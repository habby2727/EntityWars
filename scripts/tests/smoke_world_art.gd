extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.has_environment("EW_CAPTURE_DIR"):
		DisplayServer.window_set_size(Vector2i(1280, 720) if OS.has_environment("EW_SMALL") else Vector2i(1920, 1080))
	for world in ["Chaos", "Corrupted", "Crystal"]:
		var scene := load("res://scenes/ui/WorldZone%s.tscn" % world) as PackedScene
		var zone := scene.instantiate()
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
		zone._show_map_hunt(rare)
		await process_frame
		if OS.has_environment("EW_CAPTURE_DIR"):
			await create_timer(0.3).timeout
			root.get_texture().get_image().save_png(OS.get_environment("EW_CAPTURE_DIR").path_join("map_hunt_" + world + ".png"))
		assert(zone._preview_stage.get_child_count() == 6)
		var map_actor: Control = zone._preview_stage.get_child(0)
		map_actor.get_child(0).gui_input.emit(click)
		assert(zone._preview_selection == "hunt_rare" and zone._hunt_fight.visible)
		zone._world_modal.visible = false
		zone._preview_stage.get_node("NearbyHunt").pressed.emit()
		assert(zone._hunt_selected.id == "hunt_mythic")
		zone._clear_guardian_preview()
		zone._debug.unlock_all_buildings = true
		zone._reroll_world_art()
		assert(is_instance_valid(zone._preview_stage))
		assert(zone._preview_stage.get_child_count() >= 3)
		zone._show_debug_boss(4)
		await process_frame
		assert(zone._preview_stage.get_child_count() == 8)
		if OS.has_environment("EW_CAPTURE_DIR"):
			await create_timer(0.3).timeout
			root.get_texture().get_image().save_png(OS.get_environment("EW_CAPTURE_DIR").path_join("legendary_" + world + ".png"))
		zone._clear_guardian_preview()
		zone.queue_free()
		await process_frame
		print("PASS ", world, " ", entries.size())
	quit()
