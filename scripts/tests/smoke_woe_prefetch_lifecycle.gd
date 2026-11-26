extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var unit = load("res://scripts/ui/woe_unit.gd")
	var arena = load("res://scripts/tests/woe_poll_test_arena.gd").new()
	root.add_child(arena)
	arena.set_process(false)
	arena._start_prefetch()
	assert(root.has_node("WoeAssetPrefetch"))
	await process_frame
	arena.queue_free()
	var deadline := Time.get_ticks_msec() + 30000
	var frame_index := 0
	while root.has_node("WoeAssetPrefetch") and Time.get_ticks_msec() < deadline:
		var card: String = unit.IDS[frame_index % unit.IDS.size()]
		assert(unit.frame(card, "front", 1) != null)
		frame_index += 1
		await process_frame
	assert(not root.has_node("WoeAssetPrefetch"))
	assert(unit._prefetch_pending.is_empty() and unit._prefetch_loading.is_empty() and unit._textures.size() == 75)
	await create_timer(0.5).timeout
	print("WOE_PREFETCH_LIFECYCLE_PASS")
	quit()
