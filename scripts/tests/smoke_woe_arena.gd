extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(load("res://scripts/main_menu.gd") != null)
	var client = root.get_node("WoeClient")
	var private_view := {"match_id":"m","status":"RUNNING","snapshot":{"kind":"woe","players":[{"id":"a","team":"blue","slots":["neon"],"zeal":5},{"id":"b","team":"red"}]}}
	assert(client.valid_match(private_view, "a") and not client.valid_match(private_view, "b"))
	private_view.snapshot.players[1].slots = ["luny"]
	assert(not client.valid_match(private_view, "a"))
	var script := load("res://scripts/ui/woe_unit.gd")
	assert(script != null)
	for card in script.IDS:
		var region := Rect2()
		for facing in ["front", "back"]:
			for i in range(1,4):
				var texture: AtlasTexture = script.frame(card, facing, i)
				assert(texture != null)
				if region.size == Vector2.ZERO: region = texture.region
				assert(texture.region == region)
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
	assert(arena._buttons.size() == 4 and arena._lab_bars.size() == 4 and arena._lane_buttons.size() == 4)
	for viewport_size in [Vector2(1920,1080),Vector2(1280,720),Vector2(960,540)]:
		arena._canvas.size = viewport_size
		arena._resize()
		assert(arena._stage.scale.is_equal_approx(viewport_size / Vector2(1920,1080)))
		assert(arena._lane_buttons["blue:left"].size == Vector2(140,140))
		assert(arena._lane_buttons["blue:left"].position + Vector2(70,70) == Vector2(410,800))
		assert(arena._lane_buttons["red:right"].position + Vector2(70,70) == Vector2(1510,280))
		assert((arena._lane_buttons["blue:left"].size * arena._stage.scale).x >= 70.0)
		assert(arena._lab_bars["blue:left"].position.x + arena._lab_bars["blue:left"].size.x < 535.0)
	arena._match_id = "m"
	arena._cards = {"neon":{"cost":2,"element":"mercury"}}
	arena._snapshot = {"tick":1,"units":[],"laboratories":[],"players":[{"id":str(root.get_node("ConnectionGate").player_id),"team":"blue","zeal":5,"slots":["neon","neon","neon"],"allowedDeploymentLanes":["left","right"]}],"result":null}
	arena._render_snapshot()
	assert(arena._zeal_meter.segments == 10 and arena._buttons[0].icon != null)
	arena._snapshot.players[0].zeal_regen_ticks = 15
	arena._render_snapshot()
	assert(arena._zeal_label.text.contains("5 / 10"))
	assert(is_equal_approx(arena._zeal_meter.value, 5.5) and arena._zeal_meter.translucent_partial)
	arena._playback_ready = true
	arena._process(0.3)
	assert(absf(arena._zeal_meter.value - 5.6) < 0.001)
	arena._zeal_sync_ms -= 3000
	arena._process(0.3)
	assert(absf(arena._zeal_meter.value - 5.6) < 0.001)
	arena._snapshot.players[0].zeal = 2
	arena._snapshot.players[0].zeal_regen_ticks = 18
	arena._render_snapshot()
	assert(arena._zeal_label.text.contains("2 / 10") and absf(arena._zeal_meter.value - 2.6) < 0.001)
	arena._snapshot.players[0].zeal = 5
	arena._render_snapshot()
	assert(not arena._buttons[3].visible)
	arena._cards["solcarp"] = {"cost":5,"woe_cost":7,"element":"gold"}
	arena._snapshot.players[0].slots.append("solcarp")
	arena._render_snapshot()
	assert(arena._buttons[3].visible and arena._buttons[3].disabled and arena._buttons[3].text.ends_with("7"))
	arena._is_cd = true
	arena._snapshot.allied_count = 4
	arena._snapshot.allied_cap = 4
	arena._snapshot.regeneration_blocked = true
	arena._render_snapshot()
	assert(arena._buttons[3].disabled and arena._buttons[3].text.ends_with("5"))
	var paused: float = arena._zeal_meter.value
	arena._process(0.5)
	assert(is_equal_approx(paused, arena._zeal_meter.value))
	var card_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/woe_cards.json"))
	for potion in card_data.potions: arena._cards[str(potion.id)] = potion
	arena._snapshot.players[0].slots[3] = "thunderlock"
	arena._render_snapshot()
	assert(not arena._buttons[3].disabled and arena._buttons[3].icon != null)
	arena._select(3)
	assert(arena._potion_target.visible and arena._potion_target.radius == 80.0)
	assert(not arena._lane_buttons["blue:left"].visible and not arena._lane_buttons["blue:right"].visible)
	for viewport_size in [Vector2(1920,1080),Vector2(1280,720),Vector2(960,540)]:
		arena._canvas.size = viewport_size
		arena._resize()
		var logical := Vector2(960,540)
		var screen: Vector2 = arena._potion_target.get_global_transform_with_canvas() * logical
		assert((arena._potion_target.get_global_transform_with_canvas().affine_inverse() * screen).distance_to(logical) < 0.01)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(960,540)
	arena._potion_target._gui_input(motion)
	assert(arena._potion_target.showing and arena._potion_target.point == Vector2(960,540))
	arena._debug_visual = true
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(960,540)
	arena._potion_target._gui_input(tap)
	assert(not arena._potion_target.visible and arena._selected == -1)
	arena._debug_visual = false
	arena._snapshot.players[0].slots[3] = "solcarp"
	arena._render_snapshot()
	arena._event({"type":"tower_strike","position":{"x":410,"y":220},"targetPosition":{"x":420,"y":250}})
	assert(arena._effects.effects.back().kind == "tower_strike")
	arena._is_cd = false
	arena._snapshot.erase("allied_count")
	arena._snapshot.erase("allied_cap")
	arena._snapshot.erase("regeneration_blocked")
	arena._render_snapshot()
	arena._select(0)
	assert(arena._lane_buttons["blue:left"].visible and arena._lane_buttons["blue:right"].visible and not arena._lane_buttons["red:left"].visible)
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
	arena._own.allowedDeploymentLanes = ["right"]
	arena._update_hud()
	assert(arena._lane_buttons["blue:right"].visible)
	var action_snapshot: Dictionary = arena._snapshot.duplicate(true)
	action_snapshot.kind = "woe"
	arena._action_kind = "match/deploy"
	arena._poll = 0.25
	arena._finish_action({"code":200,"data":{"match_id":"m","status":"RUNNING","revision":arena._revision,"snapshot":action_snapshot}})
	assert(is_equal_approx(arena._poll, 0.25))
	arena._action_kind = "match/deploy"
	arena._finish_action({"code":429,"error":"RATE_LIMIT"})
	assert(arena._poll == 4.0 and arena._poll_period == 4.0)
	assert(arena.POLL_INTERVAL == 1.0)
	arena._accept_state({"match_id":"m","revision":4,"snapshot":arena._snapshot,"resync_required":true,"cursor":50},true)
	assert(arena._cursor == 50 and arena._units.is_empty())
	var finished: Dictionary = arena._snapshot.duplicate(true)
	finished.tick = 1800
	finished.result = {"winner":null,"reason":"timeout"}
	arena._accept_state({"match_id":"m","revision":5,"snapshot":finished,"events":[]},false)
	assert(arena._finished and arena._forfeit.disabled and arena._buttons[0].disabled and arena._clock.text.contains("00:00"))
	finished.result = {"winner":"red","reason":"laboratories"}
	arena._accept_state({"match_id":"m","revision":6,"snapshot":finished,"events":[]},false)
	assert(arena._finished and arena._result.text == arena.tr("WOE_DEFEAT"))
	var defense = arena
	defense._effects.clear()
	defense._clear_visuals()
	defense._finished = false
	defense._debug_visual = true
	defense._cursor = 0
	defense._revision = -1
	defense._silent_until_seq = 0
	defense._match_id = "defense"
	defense._cards = {"neon":{"cost":2,"element":"mercury"}}
	defense._playback_ready = true
	var labs: Array = []
	for team in ["blue","red"]:
		for lane in ["left","right"]:
			labs.append({"id":team + ":" + lane,"team":team,"hp":1000,"maxHp":1000})
	var defense_snapshot := {"tick":100,"units":[{"id":81,"cardId":"neon","team":"blue","x":410,"y":320,"hp":100,"maxHp":150}],"laboratories":labs,"players":[],"result":null}
	var shot := {"seq":1,"tick":90,"type":"lab_attack","labId":"red:left","team":"red","target":81,"targetPosition":{"x":410,"y":320},"position":{"x":410,"y":220},"damage":26}
	defense._accept_state({"match_id":"defense","revision":1,"snapshot":defense_snapshot,"events":[shot]},true)
	assert(defense._defense_ranges.radius == 120.0 and defense._defense_ranges.labs.size() == 4)
	assert(defense._defense_ranges.labs["red:left"].active and not defense._defense_ranges.labs["blue:left"].active)
	assert(defense._defense_ranges.labs["red:left"].center == Vector2(410,220))
	assert(defense._defense_ranges.labs["red:right"].center == Vector2(1510,220))
	assert(defense._defense_ranges.labs["blue:left"].center == Vector2(410,860) and defense._defense_ranges.labs["blue:right"].center == Vector2(1510,860))
	assert(defense._effects.effects.size() == 1 and defense._effects.effects[0].source == Vector2(410,220) and defense._effects.effects[0].target == Vector2(410,320))
	assert(defense._defense_ranges.labs["red:left"].flash > 0.0)
	defense_snapshot.units[0].y = 340.0
	defense._defense_ranges.update_snapshot(labs,defense_snapshot.units,false)
	assert(defense._defense_ranges.labs["red:left"].active)
	defense_snapshot.units[0].y = 340.1
	defense._defense_ranges.update_snapshot(labs,defense_snapshot.units,false)
	assert(not defense._defense_ranges.labs["red:left"].active)
	defense_snapshot.units[0].y = 320.0
	defense._defense_ranges.update_snapshot(labs,defense_snapshot.units,false)
	defense._accept_state({"match_id":"defense","revision":1,"snapshot":defense_snapshot,"events":[shot]},true)
	assert(defense._effects.effects.size() == 1)
	defense._effects.clear()
	defense._units[81].position = Vector2(408,332)
	defense._event(shot)
	assert(defense._effects.effects[0].target == Vector2(408,332))
	defense._units[81].position = Vector2(410,320)
	var crowded_events: Array = []
	for i in range(48):
		crowded_events.append({"seq":i+2,"tick":100,"type":"attack","attacker":1,"target":81,"cardId":"neon","team":"red","position":{"x":400,"y":300},"targetPosition":{"x":410,"y":320},"damage":1})
	var crowded_shot: Dictionary = shot.duplicate(true)
	crowded_shot.seq = 50
	crowded_events.append(crowded_shot)
	defense._accept_state({"match_id":"defense","revision":1,"snapshot":defense_snapshot,"events":crowded_events},true)
	assert(defense._cursor == 50 and defense._effects.effects.any(func(effect): return effect.kind == "lab_defense"))
	defense._effects.clear()
	defense._event(shot)
	for viewport_size in [Vector2(1920,1080),Vector2(1280,720),Vector2(960,540)]:
		defense._canvas.size = viewport_size
		defense._resize()
		assert((defense._defense_ranges.labs["red:left"].center * defense._stage.scale).is_equal_approx(Vector2(410,220) * viewport_size / Vector2(1920,1080)))
	defense_snapshot.units.clear()
	defense._accept_state({"match_id":"defense","revision":2,"snapshot":defense_snapshot,"events":[]},false)
	assert(not defense._defense_ranges.labs["red:left"].active)
	labs[2].hp = 0
	defense._accept_state({"match_id":"defense","revision":3,"snapshot":defense_snapshot,"events":[]},false)
	assert(not defense._defense_ranges.labs["red:left"].alive and defense._effects.effects.is_empty())
	for child in defense._field.get_children():
		if child.has_meta("defense_lab_id"): assert(child.is_queued_for_deletion())
	defense_snapshot.result = {"winner":null,"reason":"timeout"}
	defense._debug_visual = true
	defense._accept_state({"match_id":"defense","revision":4,"snapshot":defense_snapshot,"events":[]},false)
	assert(defense._defense_ranges.ended)
	defense_snapshot.result = null
	labs[2].hp = 1000
	defense_snapshot.units.append({"id":81,"cardId":"neon","team":"blue","x":410,"y":320,"hp":100,"maxHp":150})
	shot.seq = 51
	defense._accept_state({"match_id":"defense","revision":5,"snapshot":defense_snapshot,"resync_required":true,"cursor":51,"events":[shot]},true)
	assert(defense._cursor == 51 and defense._effects.effects.is_empty())
	defense._accept_state({"match_id":"defense","revision":5,"snapshot":defense_snapshot,"events":[shot]},true)
	assert(defense._effects.effects.is_empty())
	var cd_arena = arena_script.new()
	cd_arena._is_cd = true
	cd_arena._build()
	assert(cd_arena._defense_ranges == null)
	cd_arena._event({"type":"lab_attack","labId":"blue:left","target":81})
	assert(cd_arena._effects.effects.is_empty())
	var potion_effects = load("res://scripts/ui/woe_effects.gd").new()
	potion_effects.show_potion_area("aether", Vector2(960,540), 80, 5.0, 1.0)
	potion_effects.show_potion_area("vitriol", Vector2(800,500), 130, 3.0)
	assert(potion_effects.potion_areas.size() == 2)
	assert(potion_effects.potion_areas[0].radius == 80 and potion_effects.potion_areas[1].radius == 130)
	potion_effects._process(3.0)
	assert(potion_effects.potion_areas.size() == 1 and potion_effects.potion_areas[0].element == "aether")
	potion_effects._process(1.0)
	assert(potion_effects.potion_areas.is_empty())
	for i in range(120): potion_effects.show_potion_area("aether", Vector2.ZERO, 80, 5.0)
	assert(potion_effects.potion_areas.size() == potion_effects.CAP)
	potion_effects.clear()
	assert(potion_effects.potion_areas.is_empty())
	potion_effects.free()
	cd_arena.free()
	arena.queue_free()
	print("WOE_ARENA_SMOKE_PASS")
	quit(0)
