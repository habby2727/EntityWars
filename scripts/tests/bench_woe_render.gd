extends SceneTree

class ReceiptClient extends Node:
	func valid_match(_data: Variant, _player: String) -> bool:
		return true

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var gate = root.get_node("ConnectionGate")
	assert(gate.enable_debug_lab())
	SceneRouter._woe_context = {"kind":"woe", "match_id":"visual-bench", "player_id":"", "generation":gate._generation, "base_url":str(gate.base_url), "debug_visual":true, "startup":true}
	var baseline := OS.get_environment("NET_SMOOTH_BASELINE") == "1"
	var temporary_paths: Array[String] = []
	var arena_path := "res://scripts/ui/woe_arena.gd"
	if baseline:
		var prefix := "user://net_smooth_%d_" % Time.get_ticks_usec()
		var old_unit_path := prefix + "unit.gd"
		arena_path = prefix + "arena.gd"
		for entry in [["scripts/ui/woe_unit.gd", old_unit_path], ["scripts/ui/woe_arena.gd", arena_path]]:
			var output := []
			assert(OS.execute("git", ["show", "2980b1406115d8dca58e4499f767126c5cac087c:" + entry[0]], output, true) == 0)
			var source := str(output[0]).replace("res://scripts/ui/woe_unit.gd", old_unit_path)
			var file := FileAccess.open(entry[1], FileAccess.WRITE)
			assert(file != null)
			file.store_string(source)
			file.close()
			temporary_paths.append(entry[1])
	var arena = load(arena_path).new()
	root.add_child(arena)
	arena.set_process(false)
	gate._layer.hide()
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/woe_cards.json"))
	var units := []
	for i in 64:
		var card: Dictionary = cards.cards[i % cards.cards.size()]
		units.append({"id":i + 1, "cardId":card.id, "team":"blue" if i % 2 == 0 else "red", "x":410.0 + (1100.0 if i % 4 >= 2 else 0.0) + float(i % 3), "y":500.0 + float(i % 2), "hp":card.hp, "maxHp":card.hp})
	arena._snapshot = {"kind":"woe", "mode":"2v2", "tick":0, "units":units, "laboratories":[], "players":[], "result":null}
	arena._render_snapshot()
	var times: Array[int] = []
	for frame in 360:
		if frame % 60 == 0:
			arena._snapshot.tick = frame / 6
			for data in units: data.y += 20.0 if data.team == "red" else -20.0
			arena._render_snapshot()
		if not baseline: arena._visual_clock.advance(1.0 / 60.0)
		if frame % 5 == 0: arena._effects.emit_effect("strike", "gold", Vector2(600, 500), Vector2(640, 500), "blue")
		var started := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		if frame >= 60: times.append(Time.get_ticks_usec() - started)
	times.sort()
	print("WOE_RENDER_BENCH units=64 frames=%d p50_ms=%.3f p95_ms=%.3f max_ms=%.3f" % [times.size(), times[times.size() / 2] / 1000.0, times[int(times.size() * 0.95)] / 1000.0, times.back() / 1000.0])
	var receipt_client := ReceiptClient.new()
	root.add_child(receipt_client)
	arena._client = receipt_client
	arena._revision = 0
	for cd in [false, true]:
		arena._is_cd = cd
		var receipts: Array[int] = []
		for i in 100:
			arena._action_kind = "match/deploy"
			var result := {"code":200, "data":{"accepted":true, "match_id":"visual-bench", "status":"RUNNING", "revision":1, "snapshot":arena._snapshot}}
			var started := Time.get_ticks_usec()
			arena._finish_action(result)
			receipts.append(Time.get_ticks_usec() - started)
		receipts.sort()
		print("WOE_RECEIPT_BENCH mode=%s units=64 p50_ms=%.3f p95_ms=%.3f max_ms=%.3f" % ["cd" if cd else "woe", receipts[50] / 1000.0, receipts[95] / 1000.0, receipts.back() / 1000.0])
	receipt_client.queue_free()
	arena.queue_free()
	await process_frame
	for path in temporary_paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit()
