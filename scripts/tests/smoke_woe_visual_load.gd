extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena_script := load("res://scripts/ui/woe_arena.gd")
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/woe_cards.json"))
	var timings := []
	for mode in ["1v1", "2v2"]:
		var arena = arena_script.new()
		arena._build()
		arena._match_id = mode
		for card in cards.cards: arena._cards[card.id] = card
		var units := []
		for i in range(64):
			var card: Dictionary = cards.cards[i % cards.cards.size()]
			units.append({"id":i + 1,"cardId":card.id,"team":"blue" if i % 2 == 0 else "red","lane":"left" if i % 4 < 2 else "right","controllerId":"bot-%d" % (i % (2 if mode == "1v1" else 4)),"x":410.0 + (1100.0 if i % 4 >= 2 else 0.0) + float(i % 3),"y":500.0 + float(i % 2),"hp":card.hp,"maxHp":card.hp})
		arena._snapshot = {"kind":"woe","mode":mode,"tick":0,"units":units,"laboratories":[],"players":[],"result":null}
		arena._render_snapshot()
		assert(arena._units.size() == 64)
		var original: Vector2 = arena._units[1].target_position
		var offsets := {}
		for u in arena._units.values():
			assert(absf(u.desired_separation.x) <= 20.0 and absf(u.desired_separation.y) <= 9.0)
			offsets[str(u.desired_separation)] = true
		assert(offsets.size() >= 3 and arena._units[1].target_position == original)
		var start := Time.get_ticks_usec()
		var worst := 0
		var peak := 0
		var elements := ["sulfur","mercury","sodium","vitriol","gold","aether"]
		# 1,800 fixed 100 ms steps cover three minutes of visual updates.
		for tick in range(1800):
			var before := Time.get_ticks_usec()
			if tick % 5 == 0:
				arena._snapshot.tick = tick
				for data in units: data.y += 0.5 if data.team == "red" else -0.5
				arena._render_snapshot()
			for u in arena._units.values(): u._process(0.1)
			arena._effects.emit_effect("strike", elements[tick % 6], Vector2(600,500), Vector2(640,500), "blue")
			arena._effects.emit_effect("impact", elements[tick % 6], Vector2(600,500), Vector2(640,500), "red")
			arena._effects._process(0.1)
			peak = maxi(peak, arena._effects.effects.size())
			worst = maxi(worst, Time.get_ticks_usec() - before)
		var elapsed := Time.get_ticks_usec() - start
		assert(arena._units.size() == 64 and peak <= arena._effects.CAP and arena._effects.effects.size() <= 12)
		print("WOE_VISUAL_LOAD mode=%s units=64 simulated_seconds=180 elapsed_ms=%.2f worst_tick_ms=%.2f peak_effects=%d" % [mode,elapsed / 1000.0,worst / 1000.0,peak])
		timings.append(elapsed)
		arena.free()
	await process_frame
	print("WOE_VISUAL_LOAD_PASS")
	quit(0)
