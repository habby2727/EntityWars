extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	gate.debug_offline_enabled = true
	SceneRouter._forest_owner = ""
	SceneRouter._forest_summoner = "wizard"
	var world = load("res://scenes/forest/ForestWorld.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	assert(world._npcs.size() >= 2)
	var npc = world._npcs[0]
	world._player.transition_locked = false
	world._player.position = npc.position
	world._process(0.01)
	assert(world._nearest_npc() == npc and npc._interaction_hint.visible)
	assert(npc._interaction_hint.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_E
	world._unhandled_key_input(key)
	assert(world._dialogue.visible and world._talking_to == npc)
	world._process(0.01)
	assert(not npc._interaction_hint.visible)
	world._close_dialogue()
	world._player.position = npc.position + Vector2(1000,1000)
	world._process(0.01)
	assert(not npc._interaction_hint.visible)
	print("FOREST_NPC_HINT_SMOKE_PASS")
	world.queue_free()
	quit(0)
