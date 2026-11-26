extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var baseline := OS.get_environment("NET_SMOOTH_BASELINE") == "1"
	var unit_script: Script
	if baseline:
		var output := []
		assert(OS.execute("git", ["show", "2980b1406115d8dca58e4499f767126c5cac087c:scripts/ui/woe_unit.gd"], output, true) == 0)
		var old_unit := GDScript.new()
		old_unit.source_code = str(output[0])
		assert(old_unit.reload() == OK)
		unit_script = old_unit
	else:
		unit_script = load("res://scripts/ui/woe_unit.gd")
	var clock_script = load("res://scripts/ui/woe_visual_clock.gd") if not baseline else null
	for kind in ["homunculus", "enemy"]:
		for scenario in ["stable", "jitter_outage"]:
			for rtt_ms in [50, 150, 250, 350]:
				_run_case(unit_script, clock_script, kind, scenario, rtt_ms, baseline)
	for rtt_ms in [50, 150, 250, 350]:
		_report_long_rate(rtt_ms, baseline)
	quit()

func _report_long_rate(rtt_ms: int, baseline: bool) -> void:
	var now := 0.0
	var requests := 0
	var history: Array[float] = []
	while now < 360.0:
		var jitter: float = [0.0, 0.12, -0.04, 0.20, -0.02][requests % 5]
		var latency := maxf(0.01, float(rtt_ms) / 1000.0 + jitter)
		history.append(latency)
		while history.size() > 8: history.pop_front()
		var average := 0.0
		for value in history: average += value
		average /= history.size()
		now += 1.0 + (latency if baseline else average)
		requests += 1
	print("NET_SMOOTH_RATE rtt_ms=%d seconds=360 requests=%d requests_per_min=%.2f" % [rtt_ms, requests, requests / 6.0])

func _run_case(unit_script: Script, clock_script: Script, kind: String, scenario: String, rtt_ms: int, baseline: bool) -> void:
	var unit = unit_script.new()
	root.add_child(unit)
	unit.set_process(false)
	unit.setup({"id":1, "cardId":"neon" if kind == "homunculus" else "noxiris", "kind":kind, "team":"blue", "x":0.0, "y":0.0, "snapshot_tick":0})
	var clock = clock_script.new() if clock_script != null else null
	if clock != null: unit.visual_clock = clock
	var pending: Array[Dictionary] = []
	var next_request := 0.0
	var rtt_history: Array[float] = []
	var requests := 0
	var stalls := 0
	var samples := 0
	var delay_total := 0.0
	var correction_total := 0.0
	var correction_max := 0.0
	var corrections := 0
	var max_step := 0.0
	var times: Array[int] = []
	for frame in range(1800):
		var now := float(frame) / 60.0
		if now + 0.00001 >= next_request:
			var jitter: float = [0.0, 0.12, -0.04, 0.20, -0.02][requests % 5] if scenario == "jitter_outage" else 0.0
			var latency := maxf(0.01, float(rtt_ms) / 1000.0 + jitter)
			var down := scenario == "jitter_outage" and now >= 10.0 and now < 13.0
			var elapsed := 1.5 if down else latency
			var tick := floori((now + latency * 0.5) * 10.0)
			if not down: pending.append({"arrive":now + latency, "tick":tick, "started":now, "rtt":latency})
			requests += 1
			var budget := 0.0
			for value in rtt_history: budget += value
			if not rtt_history.is_empty(): budget /= rtt_history.size()
			next_request = now + (elapsed + 1.0 if baseline or down else maxf(1.0 + budget, elapsed))
		while not pending.is_empty() and now >= float(pending[0].arrive):
			var packet: Dictionary = pending.pop_front()
			if not baseline:
				rtt_history.append(float(packet.rtt))
				while rtt_history.size() > 8: rtt_history.pop_front()
				var budget := 0.0
				for value in rtt_history: budget += value
				budget /= rtt_history.size()
				next_request = float(packet.started) + 1.0 + budget
			var authoritative := Vector2(float(packet.tick) * 9.0, 0.0)
			var correction: float = unit.position.distance_to(authoritative)
			correction_total += correction
			correction_max = maxf(correction_max, correction)
			corrections += 1
			if clock != null: clock.observe(int(packet.tick), now)
			unit.update_state({"x":authoritative.x, "y":0.0, "snapshot_tick":int(packet.tick)})
		if clock != null: clock.advance(1.0 / 60.0)
		var before: Vector2 = unit.position
		var started := Time.get_ticks_usec()
		unit._process(1.0 / 60.0)
		times.append(Time.get_ticks_usec() - started)
		var step: float = before.distance_to(unit.position)
		max_step = maxf(max_step, step)
		if now >= 3.0:
			samples += 1
			if step < 0.001: stalls += 1
			delay_total += (now * 90.0 - unit.position.x) / 90.0
	times.sort()
	print("NET_SMOOTH_BENCH mode=%s scenario=%s rtt_ms=%d requests=%d stalls_pct=%.2f mean_delay_ms=%.1f correction_mean_px=%.1f correction_max_px=%.1f max_step_px=%.2f process_p50_us=%d process_p95_us=%d process_max_us=%d" % [kind, scenario, rtt_ms, requests, 100.0 * stalls / samples, delay_total * 1000.0 / samples, correction_total / maxi(1, corrections), correction_max, max_step, times[times.size() / 2], times[int(times.size() * 0.95)], times.back()])
	unit.queue_free()
