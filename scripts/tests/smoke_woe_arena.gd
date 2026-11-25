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
	unit._process(0.125)
	var first_blink: bool = unit.visible
	unit._process(0.125)
	assert(unit.visible != first_blink)
	unit._process(0.75)
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
	for viewport_size in [Vector2(1920,1080),Vector2(1280,720),Vector2(960,540)]:
		arena._canvas.size = viewport_size
		arena._resize()
		assert(arena._stage.scale.is_equal_approx(viewport_size / Vector2(1920,1080)))
		assert(arena._lane_buttons["blue:left"].size == Vector2(110,110))
	arena._match_id = "m"
	arena._cards = {"neon":{"cost":2,"element":"mercury"}}
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
	arena._clear_visuals()
	arena._cursor = 0
	arena._playback_ready = false
	arena._silent_until_seq = 0
	var snap: Dictionary = arena._snapshot.duplicate(true)
	snap.tick = 100
	var spawn := {"seq":1,"tick":99,"type":"spawn","unit_id":41,"card_id":"neon","team":"red","position":{"x":100,"y":100}}
	arena._accept_state({"match_id":"m","revision":3,"snapshot":snap,"latest_event_seq":2,"events":[spawn]},true)
	assert(arena._cursor == 1 and arena._effects.effects.is_empty() and arena._units.is_empty())
	var attack := {"seq":2,"tick":100,"type":"attack","attacker":41,"target":42,"cardId":"neon","team":"red","position":{"x":100,"y":100},"targetPosition":{"x":120,"y":100},"damage":4}
	arena._accept_state({"match_id":"m","revision":3,"snapshot":snap,"latest_event_seq":2,"events":[attack]},true)
	assert(arena._cursor == 2 and arena._effects.effects.is_empty())
	attack.seq = 3
	arena._accept_state({"match_id":"m","revision":3,"snapshot":snap,"events":[attack]},true)
	assert(arena._cursor == 3 and arena._effects.effects.size() == 3 and arena._units.is_empty())
	arena._accept_state({"match_id":"m","revision":3,"snapshot":snap,"events":[attack]},true)
	assert(arena._effects.effects.size() == 3)
	attack.seq = 4
	attack.tick = 90
	arena._accept_state({"match_id":"m","revision":3,"snapshot":snap,"events":[attack]},true)
	assert(arena._cursor == 4 and arena._effects.effects.size() == 3)
	var death := {"seq":5,"tick":100,"type":"death","target":41,"targetKind":"unit","victimCardId":"neon","victimTeam":"red","victimPosition":{"x":100,"y":100}}
	arena._accept_state({"match_id":"m","revision":3,"snapshot":snap,"events":[death]},true)
	assert(arena._corpses.size() == 1 and arena._units.is_empty())
	death.seq = 6
	death.erase("victimCardId")
	death.erase("victimTeam")
	death.erase("targetKind")
	arena._accept_state({"match_id":"m","revision":3,"snapshot":snap,"events":[death]},true)
	assert(arena._corpses.size() == 2 and arena._units.is_empty())
	arena._event({"type":"death","target":999,"targetPosition":{"x":100,"y":100}})
	assert(arena._corpses.size() == 2 and arena._units.is_empty())
	arena._playback_ready = false
	attack.seq = 7
	attack.tick = 100
	arena._accept_state({"match_id":"m","revision":3,"snapshot":snap,"latest_event_seq":7,"events":[attack]},true)
	assert(arena._cursor == 7 and arena._effects.effects.size() == 5)
	var fx = arena._effects
	for element in ["sulfur","mercury","sodium","vitriol","gold","aether"]:
		fx.emit_effect("spawn", element, Vector2.ZERO, Vector2.ZERO, "blue")
	assert(fx.effects.size() == 11)
	await process_frame
	for i in range(200): fx.emit_effect("impact", "gold", Vector2.ZERO, Vector2.ZERO)
	assert(fx.effects.size() == fx.CAP)
	fx._process(1.0)
	assert(fx.effects.is_empty())
	arena._lab_bars["blue:left"].value = 0
	arena._update_hud()
	assert(not arena._lane_buttons["blue:left"].visible and arena._lane_buttons["blue:right"].visible)
	arena._accept_state({"match_id":"m","revision":4,"snapshot":arena._snapshot,"resync_required":true,"cursor":50},true)
	assert(arena._cursor == 50 and arena._units.is_empty())
	var finished: Dictionary = arena._snapshot.duplicate(true)
	finished.result = {"winner":"blue","reason":"timeout"}
	arena._accept_state({"match_id":"m","revision":5,"snapshot":finished,"events":[]},false)
	assert(arena._finished and arena._forfeit.disabled and arena._buttons[0].disabled)
	arena.queue_free()
	print("WOE_ARENA_SMOKE_PASS")
	quit(0)
