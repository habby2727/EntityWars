extends SceneTree

# Captures the editor-only preview, without contacting the minigame API.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	assert(gate.enable_debug_lab())
	SceneRouter._forest_owner = ""
	SceneRouter._forest_summoner = "wizard"
	for kind in ["woe", "core_defense"]:
		var world = load("res://scenes/forest/ForestWorld.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		await process_frame
		assert(world._set_zone(world._zone_index_for_id("duel_clearing")))
		var npc = null
		for candidate in world._npcs:
			if candidate.npc_id == ("war_of_entities" if kind == "woe" else "core_defense"): npc = candidate
		assert(npc != null)
		world._player.position = npc.position
		world._player.transition_locked = false
		world._open_dialogue(npc)
		world._open_npc_action(kind)
		await process_frame
		await process_frame
		var arena = current_scene
		assert(arena._debug_visual)
		arena._select(0)
		arena._deploy("left")
		arena._debug_step(3.0)
		# Synthetic preview crowd; server state is not used or modified.
		for i in range(16):
			var team := "blue" if i < 8 else "red"
			var asset := "neon" if team == "blue" else ("noxiris" if kind == "core_defense" else "mantillo")
			arena._debug_add(asset, team, "enemy" if kind == "core_defense" and team == "red" else "homunculus", 855.0 + float(i % 8) * 30.0, 565.0 if team == "blue" else 515.0)
		if kind == "woe":
			for x in [410.0,1510.0]:
				arena._debug_add("neon", "red", "homunculus", x, 760.0)
				arena._debug_add("mantillo", "blue", "homunculus", x, 320.0)
		arena._debug_render()
		if kind == "woe":
			for team in ["blue", "red"]:
				for lane in ["left", "right"]:
					arena._snapshot.laboratories.append({"id":team+":"+lane,"team":team,"hp":1000,"maxHp":1000})
			arena._render_snapshot()
		arena._select(0)
		arena.set_process(false)
		arena._own.zeal = 5
		arena._own.zeal_regen_ticks = 17
		arena._sync_zeal_display()
		if OS.get_environment("WOE_POTION_CAPTURE") == "1":
			var potion_id := OS.get_environment("WOE_POTION_ID")
			if potion_id not in ["thunderlock", "vitriol_potion", "blood_potion", "aether_potion"]: potion_id = "thunderlock"
			arena._own.slots[3] = potion_id
			arena._select(3)
			arena._potion_target.point = Vector2(960,540)
			arena._potion_target.showing = true
			arena._potion_target.queue_redraw()
			var count := 0
			for unit in arena._units.values():
				if count >= 4: break
				unit.update_state({"x":unit.target_position.x,"y":unit.target_position.y,"snapshot_tick":100,"paralyzed_until":150,"poison_until":130,"blood_until":140,"aether_until":140})
				count += 1
		if kind == "core_defense":
			arena._snapshot["allied_count"] = 2
			arena._snapshot["allied_cap"] = 4
		arena._update_hud()
		for size in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(960,540)]:
			DisplayServer.window_set_size(size)
			await create_timer(0.5).timeout
			for unit in arena._units.values():
				if is_instance_valid(unit): unit.attack()
			if kind == "woe":
				for team in ["blue", "red"]:
					for lane in ["left", "right"]:
						var center: Vector2 = arena._defense_ranges.labs[team+":"+lane].center
						var target := center + Vector2(0,-100 if team == "blue" else 100)
						arena._event({"type":"lab_attack","labId":team+":"+lane,"targetPosition":{"x":target.x,"y":target.y},"damage":26})
			if OS.get_environment("WOE_POTION_CAPTURE") == "1":
				arena._event({"type":"potion_cast","cardId":str(arena._own.slots[3]),"team":"blue","position":{"x":960,"y":540}})
			arena._event({"type":"death","target":999,"targetKind":"unit","victimCardId":"neon","victimTeam":"red","victimPosition":{"x":1020,"y":540}})
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			var file := OS.get_environment("WOE_CAPTURE_DIR").path_join("%s_%dx%d.png" % [kind,size.x,size.y])
			assert(picture != null and picture.get_width() > 0 and picture.save_png(file) == OK)
			print("WOE_RENDER_CAPTURE ", file, " actual=", picture.get_size())
		arena._confirm_return()
		await process_frame
		await process_frame
		current_scene.queue_free()
		await process_frame
	quit()
