extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(load("res://scripts/main_menu.gd") != null)
	var client = root.get_node("WoeClient")
	var private_view := {"match_id":"m","status":"RUNNING","snapshot":{"players":[{"id":"a","team":"blue","slots":["neon"],"zeal":5},{"id":"b","team":"red"}]}}
	assert(client.valid_match(private_view, "a") and not client.valid_match(private_view, "b"))
	private_view.snapshot.players[1].slots = ["luny"]
	assert(not client.valid_match(private_view, "a"))
	var script := load("res://scripts/ui/woe_unit.gd")
	assert(script != null)
	for card in script.IDS:
		for facing in ["front", "back"]:
			for i in range(1,4): assert(script.frame(card, facing, i) != null)
	var unit = script.new()
	root.add_child(unit)
	unit.setup({"id":7,"cardId":"neon","team":"blue","x":410,"y":800,"hp":80,"maxHp":160})
	assert(unit.sprite.texture == script.frame("neon", "back", 1))
	assert(absf(unit.sprite.texture.get_height() * unit.sprite.scale.y - 56.0) < 0.01)
	assert(absf(unit.visual_offset) <= 9.0)
	unit.update_state({"x":430,"y":780,"hp":70,"maxHp":160})
	unit._process(0.1)
	assert(unit.position.x > 410 and unit.position.x < 430 and unit.moving)
	unit.attack()
	assert(unit.strike_time > 0)
	unit._process(0.3)
	assert(unit.strike_time == 0.0)
	unit.die()
	unit._process(1.0)
	assert(unit.dying and is_equal_approx(unit.death_time,1.5))
	unit._process(1.6)
	assert(unit.is_queued_for_deletion())
	var red = script.new()
	root.add_child(red)
	red.setup({"id":8,"cardId":"cedix","team":"red","x":1,"y":1,"hp":5,"maxHp":5})
	assert(red.sprite.texture == script.frame("cedix", "front", 1))
	red.queue_free()
	var arena_script := load("res://scripts/ui/woe_arena.gd")
	assert(arena_script != null)
	var arena = arena_script.new()
	root.add_child(arena)
	arena._build()
	assert(arena._buttons.size() == 3 and arena._lab_bars.size() == 4 and arena._lane_buttons.size() == 4)
	arena._canvas.size = Vector2(1280,720)
	arena._resize()
	assert(arena._stage.scale.is_equal_approx(Vector2(2.0/3.0,2.0/3.0)))
	arena._match_id = "m"
	arena._cards = {"neon":{"cost":2}}
	arena._snapshot = {"tick":1,"units":[],"laboratories":[],"players":[{"id":str(root.get_node("ConnectionGate").player_id),"team":"blue","zeal":5,"slots":["neon","neon","neon"]}],"result":null}
	arena._render_snapshot()
	assert(arena._zeal_meter.segments == 10 and arena._buttons[0].icon != null)
	arena._select(0)
	assert(arena._lane_buttons["blue:left"].visible and not arena._lane_buttons["red:left"].visible)
	arena._accept_state({"match_id":"m","revision":2,"snapshot":arena._snapshot,"events":[{"seq":1,"type":"spawn","unit_id":4,"card_id":"neon","team":"red","position":{"x":100,"y":100}}]},true)
	assert(arena._cursor == 1)
	arena._accept_state({"match_id":"m","revision":1,"snapshot":arena._snapshot,"events":[{"seq":1,"type":"spawn","unit_id":4,"card_id":"neon","team":"red","position":{"x":100,"y":100}}]},true)
	assert(arena._cursor == 1 and arena._revision == 2)
	arena._event({"type":"death","target":9,"targetKind":"unit","victimCardId":"neon","victimTeam":"red","victimPosition":{"x":100,"y":100}})
	var corpse := false
	for child in arena._field.get_children():
		if child.get("dying") == true: corpse = true
	assert(corpse)
	arena._lab_bars["blue:left"].value = 0
	arena._update_hud()
	assert(not arena._lane_buttons["blue:left"].visible and arena._lane_buttons["blue:right"].visible)
	arena._accept_state({"match_id":"m","revision":3,"snapshot":arena._snapshot,"resync_required":true,"cursor":50},true)
	assert(arena._cursor == 50 and arena._units.is_empty())
	var finished: Dictionary = arena._snapshot.duplicate(true)
	finished.result = {"winner":"blue","reason":"timeout"}
	arena._accept_state({"match_id":"m","revision":4,"snapshot":finished,"events":[]},false)
	assert(arena._finished and arena._forfeit.disabled and arena._buttons[0].disabled)
	arena.queue_free()
	print("WOE_ARENA_SMOKE_PASS")
	quit(0)
