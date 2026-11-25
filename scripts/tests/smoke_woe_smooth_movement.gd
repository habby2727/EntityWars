extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script = load("res://scripts/ui/woe_unit.gd")
	# Both modes use this unit renderer, including Core Defense enemies.
	for kind in ["homunculus", "enemy"]:
		var unit = script.new()
		root.add_child(unit)
		unit.set_process(false)
		unit.setup({"id": 1, "kind": kind, "x": 0.0, "y": 0.0})
		unit.update_state({"x": 90.0, "y": 0.0})
		for frame in range(60):
			var before: Vector2 = unit.position
			unit._process(1.0 / 60.0)
			assert(absf(unit.position.x - before.x - 1.5) < 0.01)
		assert(absf(unit.position.x - 90.0) < 0.01)
		unit.update_state({"x": 180.0, "y": 0.0})
		unit._process(0.25)
		var before_duplicate: Vector2 = unit.position
		unit.update_state({"x": 180.0, "y": 0.0})
		unit._process(0.25)
		assert(absf(unit.position.x - before_duplicate.x - 22.5) < 0.01)
		unit._process(0.5)
		unit._process(0.1)
		assert(not unit.moving and absf(unit.position.x - 180.0) < 0.01)
		# A long network interruption must not produce a fast catch-up jump.
		unit._process(8.0)
		unit.update_state({"x": 780.0, "y": 0.0})
		var before_gap: Vector2 = unit.position
		unit._process(0.1)
		assert(unit.position.x - before_gap.x <= 12.01)
		assert(is_finite(unit.position.x) and unit.position.x < 780.0)
		unit.update_state({"x": 175.0, "y": 10.0})
		unit._process(1.0)
		assert(unit.position.distance_to(Vector2(175.0, 10.0)) < 0.01)
		unit.update_state({"x": 225.0, "y": 10.0, "snapshot_tick":100, "paralyzed_until":150, "poison_until":130})
		var frozen: Vector2 = unit.position
		unit._process(1.0)
		assert(unit.position == frozen and not unit.moving and unit.paralyzed_remaining > 0.0 and unit.poison_remaining > 0.0)
		unit.update_state({"x": 225.0, "y": 10.0, "snapshot_tick":150})
		unit._process(0.1)
		assert(unit.position.x > frozen.x and unit.paralyzed_remaining == 0.0 and unit.poison_remaining == 0.0)
		unit.queue_free()
	print("WOE/CD smooth movement OK")
	quit()
