extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var unit = load("res://scripts/ui/woe_unit.gd")
	unit.begin_prefetch()
	var timings: Array[int] = []
	var start := Time.get_ticks_msec()
	while not unit._prefetch_pending.is_empty() or not unit._prefetch_loading.is_empty():
		var before := Time.get_ticks_usec()
		unit.service_prefetch()
		timings.append(Time.get_ticks_usec() - before)
		await process_frame
		assert(Time.get_ticks_msec() - start < 30000)
	timings.sort()
	assert(unit._textures.size() == 75)
	print("WOE_PREFETCH textures=%d elapsed_ms=%d service_calls=%d service_p50_us=%d service_p95_us=%d service_max_us=%d" % [unit._textures.size(), Time.get_ticks_msec() - start, timings.size(), timings[timings.size() / 2], timings[int(timings.size() * 0.95)], timings.back()])
	unit._textures.clear()
	await create_timer(0.5).timeout
	quit()
