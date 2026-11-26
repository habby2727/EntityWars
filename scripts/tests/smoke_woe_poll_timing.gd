extends SceneTree

class FakeClient extends Node:
	var rtt := 0.0
	var starts: Array[int] = []
	var durations: Array[int] = []
	var active := 0
	var max_active := 0
	var origin := 0
	func identity() -> String:
		return ""
	func saved_pending() -> Dictionary:
		return {}
	func saved_forfeit_action() -> Dictionary:
		return {}
	func valid_match(_data: Variant, _player: String) -> bool:
		return true
	func request(_path: String, _body: Variant = null, _owner: Node = null) -> Dictionary:
		starts.append(Time.get_ticks_msec())
		active += 1
		max_active = maxi(max_active, active)
		await get_tree().create_timer(rtt).timeout
		active -= 1
		durations.append(Time.get_ticks_msec() - starts.back())
		var tick := maxi(0, (Time.get_ticks_msec() - origin) / 100)
		return {"code":200, "data":{"match_id":"timing", "revision":tick, "snapshot":{"tick":tick, "units":[], "laboratories":[], "players":[], "result":null}, "events":[]}}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arenas: Array = []
	for cd in [false, true]:
		for milliseconds in [50, 150, 250, 350]:
			var client := FakeClient.new()
			client.rtt = float(milliseconds) / 1000.0
			client.origin = Time.get_ticks_msec()
			root.add_child(client)
			var arena = load("res://scripts/tests/woe_poll_test_arena.gd").new()
			root.add_child(arena)
			arena._is_cd = cd
			arena._client = client
			arena._match_id = "timing"
			arena._other_recovery_busy = true
			arena._build()
			arena._acting = true
			arena._poll_state()
			arenas.append({"arena":arena, "client":client, "rtt":milliseconds, "cd":cd})
	var deadline := Time.get_ticks_msec() + 5500
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if arenas.all(func(item): return item.client.starts.size() >= 4): break
	for item in arenas:
		var arena = item.arena
		var client = item.client
		arena.set_process(false)
		assert(client.starts.size() >= 4 and client.max_active == 1 and arena._acting)
		print("POLL_TIMING mode=%s rtt_ms=%d intervals_ms=%d,%d,%d" % ["cd" if item.cd else "woe", item.rtt, client.starts[1]-client.starts[0], client.starts[2]-client.starts[1], client.starts[3]-client.starts[2]])
		for i in range(1, 4):
			var interval: int = client.starts[i] - client.starts[i - 1]
			var total := 0
			for value in client.durations.slice(0, i): total += int(value)
			var budget := ceili(float(total) / i)
			assert(interval >= 995 + budget and interval < 1200 + budget)
		arena._finish_action({"code":429, "error":"RATE_LIMIT"})
		assert(arena._poll >= 4.0 and arena._next_poll_ms >= Time.get_ticks_msec() + 3900)
	while arenas.any(func(item): return item.client.active > 0):
		await process_frame
	for item in arenas:
		assert(item.arena._next_poll_ms >= item.arena._rate_limit_until)
		item.arena.queue_free()
		item.client.queue_free()
	await process_frame
	await process_frame
	print("WOE/CD monotonic polling PASS")
	quit()
