extends SceneTree

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
		assert(arena.scene_file_path == SceneRouter.SCENE_WOE_ARENA and arena._debug_visual)
		assert(arena._is_cd == (kind == "core_defense"))
		assert(arena._own.slots.size() == 3)
		arena._select(0)
		arena._deploy("left")
		assert(arena._debug_units.size() >= 1 and arena._units.size() >= 1)
		arena._debug_step(3.0)
		assert(arena._debug_units.size() >= 2)
		assert(arena._buttons[0].get_theme_stylebox("normal") is StyleBoxTexture)
		arena._confirm_return()
		await process_frame
		await process_frame
		assert(current_scene.scene_file_path == SceneRouter.SCENE_FOREST_WORLD)
		assert(SceneRouter._woe_context.is_empty())
		current_scene.queue_free()
		await process_frame
	print("WOE_CD_OFFLINE_VISUAL_PASS")
	quit(0)
