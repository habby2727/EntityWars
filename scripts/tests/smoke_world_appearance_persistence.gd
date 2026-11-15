extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var isolation := OS.get_environment("EW_APPEARANCE_TEST_ROOT").replace("\\", "/").to_lower()
	if isolation.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(isolation + "/"):
		push_error("Isolated user directory required")
		quit(1)
		return
	var flags = FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	for world in ["Chaos", "Corrupted", "Crystal"]:
		var scene = load("res://scenes/ui/WorldZone%s.tscn" % world)
		var first = scene.instantiate()
		root.add_child(first)
		await process_frame
		var seen := {}
		var orders := {}
		for seed_value in range(1, 65):
			first._apply_appearance_seed(seed_value)
			seen[first._world_art_order[0]] = true
			orders[str(first._world_art_order)] = true
		assert(seen.size() == first.WORLD_ART[first._get_zone_id()].size())
		assert(orders.size() > 10)
		first._reroll_world_art()
		var expected_seed = first._appearance_seed
		var expected_order = first._world_art_order.duplicate()
		var expected_boss = first._debug_rotation
		var expected_rare = first._debug_rare_index
		first.queue_free()
		await process_frame
		var second = scene.instantiate()
		root.add_child(second)
		await process_frame
		assert(second._appearance_seed == expected_seed)
		assert(second._world_art_order == expected_order)
		assert(second._debug_rotation == expected_boss)
		assert(second._debug_rare_index == expected_rare)
		assert(second._reroll_remaining() > 0)
		second.queue_free()
		await process_frame
		print("PASS saved shuffled zone ", world)
	quit()
