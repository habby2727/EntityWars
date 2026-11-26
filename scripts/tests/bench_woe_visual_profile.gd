extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var unit = load("res://scripts/ui/woe_unit.gd")
	var cold: Array[int] = []
	var warm: Array[int] = []
	for pass_index in 2:
		for card in unit.IDS + unit.ENEMY_IDS:
			for facing in (["front"] if card in unit.ENEMY_IDS else ["front", "back"]):
				for index in range(1, 4):
					var started := Time.get_ticks_usec()
					assert(unit.frame(card, facing, index) != null)
					(cold if pass_index == 0 else warm).append(Time.get_ticks_usec() - started)
	cold.sort()
	warm.sort()
	var arena = load("res://scripts/tests/woe_poll_test_arena.gd").new()
	root.add_child(arena)
	arena._build()
	var labels: Array[int] = []
	for i in 100:
		var started := Time.get_ticks_usec()
		arena._damage(Vector2(960, 540), i)
		labels.append(Time.get_ticks_usec() - started)
	labels.sort()
	print("WOE_PROFILE texture_samples=%d cold_p50_us=%d cold_p95_us=%d cold_max_us=%d warm_p50_us=%d warm_p95_us=%d warm_max_us=%d damage_labels=%d label_p50_us=%d label_p95_us=%d label_max_us=%d" % [cold.size(), cold[cold.size() / 2], cold[int(cold.size() * 0.95)], cold.back(), warm[warm.size() / 2], warm[int(warm.size() * 0.95)], warm.back(), labels.size(), labels[labels.size() / 2], labels[int(labels.size() * 0.95)], labels.back()])
	arena.queue_free()
	await process_frame
	await process_frame
	quit()
