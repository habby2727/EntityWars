extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	assert(gate.enable_debug_lab())
	SceneRouter._forest_owner = ""
	SceneRouter._forest_summoner = "wizard"
	var travel_world = load("res://scenes/forest/ForestWorld.tscn").instantiate()
	root.add_child(travel_world)
	current_scene = travel_world
	await process_frame
	var guide = null
	for candidate in travel_world._npcs:
		if candidate.npc_id == "duels_guide": guide = candidate
	assert(guide != null and guide.get_node("Nameplate").text == tr("FOREST_NPC_DUELS_GUIDE_NAME"))
	travel_world._player.position = guide.position
	travel_world._player.transition_locked = false
	travel_world._open_dialogue(guide)
	assert(travel_world._action_row.get_node_or_null("Action_duels_travel") != null)
	travel_world._open_npc_action("duels_travel")
	await process_frame
	assert(str(travel_world._zones[travel_world._zone_index].id) == "duel_clearing")
	travel_world.queue_free()
	await process_frame
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
		assert(arena._own.slots.size() == 4)
		arena._select(0)
		var marker = arena._lane_buttons["blue:left"]
		assert(marker.visible and marker.size == Vector2(140, 140))
		arena._process(0.1)
		var first_alpha: float = marker.modulate.a
		arena._process(0.4)
		assert(absf(marker.modulate.a - first_alpha) > 0.1)
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
