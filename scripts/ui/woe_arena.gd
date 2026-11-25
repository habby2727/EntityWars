extends Control

const BG := preload("res://assets/forest/woe/backgrounds/Classic_Arena_1920x1080.png")
const ZEAL := preload("res://assets/forest/woe/zeal.png")
const UNIT := preload("res://scripts/ui/woe_unit.gd")
const EFFECTS := preload("res://scripts/ui/woe_effects.gd")
const ARENA := "res://data/static/woe_arena.json"
const CARDS := "res://data/static/woe_cards.json"
const POLL_INTERVAL := 1.0
const MENU_ART := preload("res://scripts/ui/menu_art.gd")

class Meter extends Control:
	var segments := 10
	var value := 0.0
	var maximum := 10.0
	var fill_color := Color("8adfff")
	var border_color := Color("d9f5ff")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), border_color)
		var width := (size.x - 4.0) / segments
		for i in range(segments):
			var rect := Rect2(2.0 + width * i, 2.0, width - 2.0, size.y - 4.0)
			draw_rect(rect, Color("203044"))
			var fraction := clampf(value / maxf(1.0, maximum) * segments - i, 0.0, 1.0)
			if fraction > 0.0: draw_rect(Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y)), fill_color)

class DeployMarker extends Button:
	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 38.0, Color(1.0, 0.84, 0.2, 0.12))
		draw_arc(center, 39.0, 0, TAU, 48, Color("ffe778"), 3.0)
		draw_arc(center, 28.0, 0, TAU, 40, Color("fff3b0"), 2.0)
		draw_circle(center, 4.0, Color("fff7c9"))

var _identity := ""
var _client: Node
var _is_cd := false
var _debug_visual := false
var _debug_spawn_timer := 0.0
var _debug_attack_timer := 0.0
var _debug_index := 0
var _debug_next_id := 1
var _debug_units: Array = []
var _server_score := {}
var _match_id := ""
var _cursor := 0
var _revision := -1
var _poll := 0.0
var _backoff := POLL_INTERVAL
var _poll_period := POLL_INTERVAL
var _delivery_ticks := 0
var _awaiting_deploy_state := false
var _deploy_receipt_revision := -1
var _missing_match := false
var _other_recovery_busy := false
var _other_recovery_next := 0
var _requesting := false
var _acting := false
var _action_kind := ""
var _forfeited := false
var _selected := -1
var _selected_card := ""
var _display_zeal := 0.0
var _snapshot := {}
var _own := {}
var _team := ""
var _units := {}
var _known_units := {}
var _corpses: Array = []
var _playback_ready := false
var _silent_until_seq := 0
var _last_snapshot_tick := 0
var _effects: Node2D
var _cards := {}
var _lab_bars := {}
var _lane_buttons := {}
var _buttons: Array[Button] = []
var _canvas: Control
var _stage: Control
var _field: Node2D
var _clock: Label
var _notice: Label
var _result: Label
var _zeal_meter: Meter
var _zeal_label: Label
var _forfeit: Button
var _return_button: Button
var _finished := false
var _returning := false
var _seconds := 0.0

func _ready() -> void:
	_is_cd = SceneRouter._woe_context.get("kind", "woe") == "core_defense"
	_debug_visual = bool(SceneRouter._woe_context.get("debug_visual", false)) and ConnectionGate.debug_lab_navigation_allowed()
	_client = CoreDefenseClient if _is_cd else WoeClient
	if _is_cd:
		_poll_period = 1.0
		_backoff = 1.0
	_identity = _client.identity()
	if not SceneRouter.woe_context_valid():
		SceneRouter.finish_woe_safely.call_deferred()
		return
	_match_id = str(SceneRouter._woe_context.get("match_id", ""))
	if _match_id.is_empty():
		SceneRouter.finish_woe_safely.call_deferred()
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARDS))
	if catalog is Dictionary:
		for card in catalog.get("cards", []): _cards[str(card.id)] = card
	_forfeited = not _debug_visual and _client.saved_forfeit() == _match_id
	_build()
	_forfeit.disabled = _forfeited
	if _debug_visual:
		_debug_render()
	else:
		_poll_state()

func _valid() -> bool:
	return is_inside_tree() and _identity == _client.identity() and SceneRouter.woe_context_valid() and str(SceneRouter._woe_context.get("match_id", "")) == _match_id

func _build() -> void:
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	add_child(aspect)
	_canvas = Control.new()
	aspect.add_child(_canvas)
	_canvas.resized.connect(_resize)
	_stage = Control.new()
	_stage.size = Vector2(1920,1080)
	_canvas.add_child(_stage)
	var bg := TextureRect.new()
	bg.texture = BG
	bg.size = Vector2(1920,1080)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(bg)
	_field = Node2D.new()
	_stage.add_child(_field)
	_effects = EFFECTS.new()
	_stage.add_child(_effects)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARENA))
	for team in (["blue"] if _is_cd else ["blue", "red"]):
		for lane in ["left", "right"]:
			var point: Dictionary = data.laboratories[team][lane]
			var meter := Meter.new()
			meter.position = Vector2(float(point.x)-65,float(point.y)-84)
			meter.size = Vector2(130,15)
			meter.maximum = 1000
			meter.value = 1000
			meter.border_color = Color("67bfff") if team == "blue" else Color("ff8477")
			meter.fill_color = Color("9bf0a2")
			meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(meter)
			_lab_bars[team + ":" + lane] = meter
			var spawn: Dictionary = data.spawns[team][lane]
			var marker := DeployMarker.new()
			marker.position = Vector2(float(spawn.x)-55,float(spawn.y)-55)
			marker.size = Vector2(110,110)
			marker.text = ""
			for style in ["normal", "hover", "pressed", "focus", "disabled"]:
				marker.add_theme_stylebox_override(style, StyleBoxEmpty.new())
			marker.add_theme_font_size_override("font_size", 48)
			marker.modulate = Color(1,0.9,0.15,0.8)
			marker.pressed.connect(_deploy.bind(lane))
			marker.visible = false
			_stage.add_child(marker)
			_lane_buttons[team + ":" + lane] = marker
	var top := HBoxContainer.new()
	top.position = Vector2(320, 15) if _is_cd else Vector2(660, 15)
	top.size = Vector2(1280, 55) if _is_cd else Vector2(600, 55)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.add_child(top)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 25 if _is_cd else 32)
	top.add_child(_clock)
	_notice = Label.new()
	_notice.position = Vector2(670,75)
	_notice.size = Vector2(580,35)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_notice)
	_result = Label.new()
	_result.position = Vector2(600,120)
	_result.size = Vector2(720,70)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 38)
	_stage.add_child(_result)
	var hud := HBoxContainer.new()
	hud.position = Vector2(535,930)
	hud.size = Vector2(850,135)
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 8)
	_stage.add_child(hud)
	for i in range(3):
		var button := Button.new()
		button.custom_minimum_size = Vector2(170,120)
		button.add_theme_font_size_override("font_size", 24)
		MENU_ART.button(button)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select.bind(i))
		hud.add_child(button)
		_buttons.append(button)
	var zeal_box := VBoxContainer.new()
	zeal_box.custom_minimum_size = Vector2(230,100)
	hud.add_child(zeal_box)
	var zeal_title := HBoxContainer.new()
	zeal_box.add_child(zeal_title)
	var icon := TextureRect.new()
	icon.texture = ZEAL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(36,36)
	zeal_title.add_child(icon)
	_zeal_label = Label.new()
	zeal_title.add_child(_zeal_label)
	_zeal_meter = Meter.new()
	_zeal_meter.custom_minimum_size = Vector2(220,18)
	zeal_box.add_child(_zeal_meter)
	_forfeit = Button.new()
	_forfeit.position = Vector2(1640, 30)
	_forfeit.size = Vector2(230,55)
	_forfeit.text = tr("WOE_FORFEIT")
	MENU_ART.button(_forfeit)
	_forfeit.pressed.connect(_confirm_forfeit)
	_stage.add_child(_forfeit)
	_return_button = Button.new()
	_return_button.position = Vector2(1640,95)
	_return_button.size = Vector2(230,55)
	_return_button.text = tr("WOE_RETURN")
	MENU_ART.button(_return_button)
	_return_button.pressed.connect(_confirm_return)
	_stage.add_child(_return_button)
	_resize()

func _resize() -> void:
	if is_instance_valid(_stage): _stage.scale = _canvas.size / Vector2(1920,1080)

func _process(delta: float) -> void:
	if not _identity.is_empty() and _identity != _client.identity():
		_return_when_idle()
		return
	if _returning: return
	_seconds += delta
	if is_instance_valid(_zeal_meter):
		_display_zeal = lerpf(_display_zeal, float(_own.get("zeal", 0)), 1.0 - exp(-delta * 8.0))
		_zeal_meter.value = _display_zeal
		_zeal_meter.queue_redraw()
	for marker in _lane_buttons.values():
		if marker.visible: marker.modulate.a = 0.6 + 0.3 * sin(_seconds * 4.0)
	if _debug_visual:
		_debug_step(delta)
		return
	if _finished:
		if not _other_recovery_busy and Time.get_ticks_msec() >= _other_recovery_next and not _client.saved_pending().is_empty():
			if str(_client.saved_pending().get("action", "")) == "start": _reconcile_pending_start()
			else: _reconcile_other_matches()
		return
	_poll -= delta
	if _poll <= 0.0 and not _requesting and not _finished and not _missing_match and (not _is_cd or not _acting) and _valid(): _poll_state()

func _poll_state() -> void:
	if _requesting or (_is_cd and _acting) or not _valid(): return
	_requesting = true
	var requested_id := _match_id
	var endpoint := "/forest/core-defense/" if _is_cd else "/forest/woe/"
	var request_start := Time.get_ticks_msec()
	var result: Dictionary = await _client.request(endpoint + "match/state?match_id=%s&after=%d" % [requested_id.uri_encode(), _cursor], null, self)
	_requesting = false
	if _returning or not _valid() or requested_id != _match_id: return
	_delivery_ticks = mini(20, ceili(float(Time.get_ticks_msec() - request_start) / 100.0))
	if ((int(result.get("code", 0)) == 404 and str(result.get("error", "")) == "MATCH_UNAVAILABLE") or (int(result.get("code", 0)) == 403 and str(result.get("error", "")) == "NOT_PARTICIPANT")):
		_missing_match = _client.reconcile_missing_match(_match_id, str(result.error))
		_notice.text = tr("CD_UNAVAILABLE")
		if _missing_match:
			_forfeit.disabled = true
			_selected = -1
			_update_hud()
		else: _poll = 8.0
		return
	if int(result.get("code", 0)) != 200 or not _client.valid_match(result.get("data"), str(ConnectionGate.player_id)) or str(result.data.get("match_id", "")) != _match_id:
		_playback_ready = false
		_notice.text = tr("WOE_ARENA_NETWORK")
		if int(result.get("code",0)) == 429: _poll_period = 4.0
		_backoff = minf(8.0, maxf(1.0, _backoff * 2.0))
		_poll = _backoff
		return
	_backoff = 1.0 if _is_cd else POLL_INTERVAL
	if _poll_period > 1.0: _poll_period = 1.0
	_server_score = result.data.get("score", {}) if result.data.get("score") is Dictionary else {}
	_notice.text = tr("WOE_FORFEITED_NOTICE") if _forfeited else ""
	_accept_state(result.data, true)
	if str(_client.saved_pending().get("action", "")) == "start" and not _other_recovery_busy and Time.get_ticks_msec() >= _other_recovery_next:
		_reconcile_pending_start()
	elif not _other_recovery_busy and Time.get_ticks_msec() >= _other_recovery_next:
		_reconcile_other_matches()
	if _is_cd and int(result.data.get("revision", -1)) >= _deploy_receipt_revision:
		_awaiting_deploy_state = false
		_deploy_receipt_revision = -1
		_update_hud()
	_poll = 0.85 if _cursor < int(result.data.get("latest_event_seq", _cursor)) else _poll_period
	if _is_cd and not _finished and not _acting and str(_client.saved_forfeit_action().get("values", {}).get("match_id", "")) == _match_id:
		_retry_forfeit()
	elif not _acting and not _client.saved_pending().is_empty():
		var pending: Dictionary = _client.saved_pending()
		if (not _is_cd or not _finished) and str(pending.get("action", "")).begins_with("match/") and str(pending.get("values", {}).get("match_id", "")) == _match_id: _retry_pending()

func _accept_state(data: Dictionary, consume_events: bool) -> void:
	if str(data.get("match_id", "")) != _match_id: return
	var snapshot_tick := int(data.get("snapshot", {}).get("tick", data.get("tick", 0)))
	var resync := consume_events and bool(data.get("resync_required", false))
	if consume_events and not _playback_ready:
		_silent_until_seq = maxi(_silent_until_seq, int(data.get("latest_event_seq", data.get("cursor", _cursor))))
	if resync:
		_clear_visuals()
		_cursor = int(data.get("cursor", _cursor))
		_playback_ready = false
	# Reconcile authoritative state first. Events never create or remove live units.
	if int(data.get("revision", -1)) >= _revision and data.get("snapshot") is Dictionary:
		_revision = int(data.revision)
		_snapshot = data.snapshot
		_last_snapshot_tick = int(_snapshot.get("tick", 0))
		_render_snapshot()
	if consume_events and not resync:
		var shown := 0
		for event in data.get("events", []):
			if not event is Dictionary: continue
			var seq := int(event.get("seq", 0))
			if seq <= _cursor: continue
			if seq != _cursor + 1: break
			_cursor = seq
			_remember_event(event)
			# Pages from startup, reconnect and long backlogs advance the cursor silently.
			if _playback_ready and seq > _silent_until_seq and int(event.get("tick", -100)) >= maxi(snapshot_tick, _last_snapshot_tick) - (maxi(10, ceili(_poll_period * 10.0)) + _delivery_ticks + 2 if _is_cd else 5) and shown < 48:
				_event(event)
				shown += 1
	if consume_events: _playback_ready = true

func _clear_visuals() -> void:
	for child in _field.get_children(): child.queue_free()
	_units.clear()
	_corpses.clear()
	_known_units.clear()
	if is_instance_valid(_effects): _effects.clear()

func _remember(id: int, card: String, team: String, point: Vector2, unit_kind: String = "homunculus", element: String = "") -> void:
	if id <= 0 or card not in UNIT.IDS + UNIT.ENEMY_IDS or team not in ["blue", "red"]: return
	_known_units[id] = {"cardId":card, "team":team, "position":point, "kind":unit_kind, "element":element if not element.is_empty() else _element(card)}
	while _known_units.size() > 256: _known_units.erase(_known_units.keys()[0])

func _point(value: Variant) -> Vector2:
	return Vector2(float(value.get("x", 0)), float(value.get("y", 0))) if value is Dictionary else Vector2.ZERO

func _remember_event(event: Dictionary) -> void:
	if str(event.get("type", "")) == "spawn":
		_remember(int(event.get("unit_id", 0)), str(event.get("assetId", event.get("card_id", ""))), str(event.get("team", "")), _point(event.get("position")), str(event.get("kind", "homunculus")), str(event.get("element", "")))
	elif str(event.get("type", "")) in ["attack", "death"]:
		_remember(int(event.get("attacker", 0)), str(event.get("cardId", "")), str(event.get("team", "")), _point(event.get("position")), str(event.get("kind", "homunculus")), str(event.get("element", "")))

func _element(card_id: String) -> String:
	return str(_cards.get(card_id, {}).get("element", ""))

func _event(event: Dictionary) -> void:
	var kind := str(event.get("type", ""))
	if kind == "spawn":
		var point := _point(event.get("position"))
		_effects.emit_effect("spawn", str(event.get("element", _element(str(event.get("card_id", ""))))), point, point, str(event.get("team", "")))
	elif kind == "attack":
		var source := _point(event.get("position"))
		var target := _point(event.get("targetPosition"))
		var element := str(event.get("element", _element(str(event.get("cardId", "")))) )
		var attacker: Variant = _units.get(int(event.get("attacker", 0)))
		if is_instance_valid(attacker) and (not _is_cd or (attacker.card_id == str(event.get("assetId", event.get("cardId", ""))) and attacker.team == str(event.get("team", "")))) and attacker.target_position.distance_to(source) < 80.0: attacker.attack()
		var victim: Variant = _units.get(int(event.get("target", 0))) if event.get("target") is int or event.get("target") is float else null
		if is_instance_valid(victim) and victim.target_position.distance_to(target) < 80.0: victim.hit()
		_effects.emit_effect("charge", element, source, target, str(event.get("team", "")))
		_effects.emit_effect("strike", element, source, target, str(event.get("team", "")))
		_effects.emit_effect("lab" if event.get("target") is String else "impact", element, source, target, str(event.get("team", "")))
		if event.get("target") is String and _lab_bars.has(str(event.target)):
			var lab: Meter = _lab_bars[str(event.target)]
			lab.modulate = Color(2,2,2,1)
			create_tween().tween_property(lab, "modulate", Color.WHITE, 0.3)
		_damage(target, int(event.get("damage",0)))
	elif kind == "death" and (event.get("targetKind") == "unit" or event.get("target") is int or event.get("target") is float):
		var id := int(event.get("target",0))
		var known: Dictionary = _known_units.get(id, {})
		var card := str(event.get("victimAssetId", event.get("victimCardId", known.get("cardId", ""))))
		var team := str(event.get("victimTeam", known.get("team", "")))
		var raw_point: Variant = event.get("victimPosition", event.get("targetPosition"))
		if not raw_point is Dictionary or not raw_point.has("x") or not raw_point.has("y"):
			if known.get("position") is Vector2: raw_point = {"x":known.position.x,"y":known.position.y}
			else: return
		var point := _point(raw_point)
		# A dead unit is rendered only as an independent corpse, never a live unit.
		if card in UNIT.IDS + UNIT.ENEMY_IDS and team in ["blue", "red"] and not _units.has(id):
			for old in _corpses.duplicate():
				if not is_instance_valid(old) or old.is_queued_for_deletion(): _corpses.erase(old)
			if _corpses.size() >= 32:
				_corpses.pop_front().queue_free()
			var corpse := UNIT.new()
			_field.add_child(corpse)
			corpse.setup({"id":id,"cardId":card,"assetId":card,"kind":str(event.get("victimKind", known.get("kind", "homunculus"))),"team":team,"x":point.x,"y":point.y,"hp":0,"maxHp":1})
			corpse.die()
			_corpses.append(corpse)
			_effects.emit_effect("death", str(event.get("victimElement", known.get("element", _element(card)))), point, point, team)

func _add_unit(data: Dictionary) -> Node:
	var id := int(data.get("id",0))
	if _units.has(id): return _units[id]
	var asset := str(data.get("assetId", data.get("cardId", "")))
	var kind := str(data.get("kind", "homunculus"))
	if (kind == "enemy" and asset not in UNIT.ENEMY_IDS) or (kind == "homunculus" and asset not in UNIT.IDS) or kind not in ["enemy", "homunculus"] or str(data.get("team", "")) not in ["blue", "red"]: return null
	var unit := UNIT.new()
	_field.add_child(unit)
	unit.setup(data)
	_units[id] = unit
	return unit

func _damage(point: Vector2, amount: int) -> void:
	if _field.get_child_count() >= 220: return
	var label := Label.new()
	label.position = point + Vector2(-20,-65)
	label.text = str(amount)
	label.add_theme_color_override("font_color", Color("fff1a1"))
	_field.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 35, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)

func _render_snapshot() -> void:
	var live := {}
	for data in _snapshot.get("units", []):
		if not data is Dictionary: continue
		var id := int(data.get("id",0))
		_remember(id, str(data.get("assetId", data.get("cardId", ""))), str(data.get("team", "")), Vector2(float(data.get("x",0)), float(data.get("y",0))), str(data.get("kind", "homunculus")), str(data.get("element", "")))
		var unit := _add_unit(data)
		if is_instance_valid(unit):
			unit.update_state(data)
			live[id] = true
	for id in _units.keys():
		if not live.has(id):
			if is_instance_valid(_units[id]): _units[id].queue_free()
			_units.erase(id)
	_separate_units()
	_own = {}
	for p in _snapshot.get("players", []):
		if p is Dictionary and str(p.get("id", "")) == str(ConnectionGate.player_id): _own = p
	_team = str(_own.get("team", ""))
	for lab in _snapshot.get("laboratories", []):
		if lab is Dictionary and _lab_bars.has(str(lab.get("id", ""))):
			var meter: Meter = _lab_bars[str(lab.id)]
			meter.value = float(lab.get("hp",0))
			meter.maximum = float(lab.get("maxHp",1000))
			meter.queue_redraw()
	var time_left := maxi(0, 180 - int(_snapshot.get("tick", 0)) / 10)
	if _is_cd:
		var elapsed := int(_snapshot.get("tick", 0)) / 10
		_clock.text = tr("CD_WAVE_STATUS") % [int(_snapshot.get("wave", 0)), int(_snapshot.get("completedWaves", 0)), int(_snapshot.get("enemiesKilled", 0)), int(_snapshot.get("pendingSpawns", 0)), elapsed / 60, elapsed % 60]
		if _snapshot.get("phase") == "intermission": _notice.text = tr("CD_INTERMISSION") % (float(_snapshot.get("intermissionTicks", 0)) / 10.0)
	else:
		_clock.text = "%s  %02d:%02d  %s" % [tr("WOE_BLUE"), time_left / 60, time_left % 60, tr("WOE_RED")]
	var outcome: Variant = _snapshot.get("result")
	_finished = outcome is Dictionary
	if _finished:
		if not _debug_visual and not _client.reconcile_terminal({"match_id":_match_id,"status":"FINISHED","snapshot":_snapshot}):
			_notice.text = tr("CD_UNAVAILABLE")
		var winner := str(outcome.get("winner", ""))
		_result.text = (tr("CD_RESULT") % [int(_server_score.get("completed_waves", _snapshot.get("completedWaves", 0))), tr("CD_REASON_" + str(outcome.get("reason", "laboratories")).to_upper())]) if _is_cd else (tr("WOE_DRAW") if winner.is_empty() or winner == "<null>" else (tr("WOE_VICTORY") if winner == _team else tr("WOE_DEFEAT")))
		_forfeit.disabled = true
		_selected = -1
	_update_hud()

# Stable, bounded visual spacing based only on nearby authoritative positions.
func _separate_units() -> void:
	var ids := _units.keys()
	ids.sort()
	for id in ids:
		var unit: Node2D = _units[id]
		var rank := 0
		var neighbors := 0
		for other_id in ids:
			if other_id == id: continue
			var other: Node2D = _units[other_id]
			if unit.target_position.distance_squared_to(other.target_position) < 45.0 * 45.0:
				neighbors += 1
				if other_id < id: rank += 1
		if neighbors == 0:
			unit.set_separation(Vector2.ZERO)
			continue
		var column := (rank % 5) - 2
		var row := (rank / 5) % 3
		unit.set_separation(Vector2(float(column) * 3.0, float(row - 1) * 2.0), float(rank % 3) * 3.0)

func _update_hud() -> void:
	var zeal := float(_own.get("zeal",0))
	_zeal_label.text = "%s  %.1f / 10" % [tr("WOE_ZEAL"), zeal]
	var slots: Array = _own.get("slots", [])
	if _selected >= 0 and (_selected >= slots.size() or str(slots[_selected]) != _selected_card or zeal < float(_cards.get(_selected_card, {}).get("cost", 99))):
		_selected = -1
		_selected_card = ""
	for i in range(3):
		var button := _buttons[i]
		var id := str(slots[i]) if i < slots.size() else ""
		var card: Dictionary = _cards.get(id, {})
		button.icon = UNIT.frame(id,"front",1)
		button.text = "%s\n%d" % [id.capitalize(), int(card.get("cost",0))] if not card.is_empty() else ""
		button.disabled = _returning or _finished or _missing_match or _forfeited or _acting or (_is_cd and _awaiting_deploy_state) or card.is_empty() or zeal < float(card.get("cost",99))
		button.modulate = Color("ffe38a") if _selected == i else (Color(0.65,0.7,0.75,1) if button.disabled else Color.WHITE)
	for key in _lane_buttons:
		var marker: Button = _lane_buttons[key]
		var lab: Meter = _lab_bars[key]
		var lane := str(key).get_slice(":", 1)
		marker.visible = not _returning and not _finished and not _missing_match and not _forfeited and not (_is_cd and _awaiting_deploy_state) and _selected >= 0 and str(key).begins_with(_team + ":") and lab.value > 0 and (_is_cd or _debug_visual or lane in _own.get("allowedDeploymentLanes", []))
		marker.disabled = _acting

func _select(slot: int) -> void:
	if _returning: return
	_selected = -1 if _selected == slot else slot
	var slots: Array = _own.get("slots", [])
	_selected_card = str(slots[_selected]) if _selected >= 0 and _selected < slots.size() else ""
	_update_hud()

func _deploy(lane: String) -> void:
	var slots: Array = _own.get("slots", [])
	if _acting or (_is_cd and _awaiting_deploy_state) or _selected < 0 or _selected >= slots.size(): return
	var slot := _selected
	_selected = -1
	if _debug_visual:
		_debug_deploy(str(slots[slot]), lane)
		return
	_action("match/deploy", {"match_id":_match_id,"slot":slot,"card_id":str(slots[slot]),"lane":lane})

func _action(action: String, values: Dictionary) -> void:
	if _returning or _acting or not _valid(): return
	_acting = true
	_action_kind = action
	_update_hud()
	var result: Dictionary = await _client.mutate(action, values)
	_acting = false
	if not _valid(): return
	_finish_action(result)

func _retry_pending() -> void:
	if _acting or not _valid(): return
	_acting = true
	_action_kind = str(_client.saved_pending().get("action", ""))
	var result: Dictionary = await _client.retry_pending()
	_acting = false
	if not _valid(): return
	_finish_action(result)

func _retry_forfeit() -> void:
	if _acting or not _valid(): return
	_acting = true
	_action_kind = "match/forfeit"
	var result: Dictionary = await _client.retry_forfeit()
	_acting = false
	if not _valid(): return
	_finish_action(result)

func _finish_action(result: Dictionary) -> void:
	if _is_cd and _action_kind == "match/deploy" and int(result.get("code",0)) == 200 and result.get("data", {}).get("accepted", false):
		_notice.text = ""
		_awaiting_deploy_state = true
		_deploy_receipt_revision = int(result.data.get("revision", -1))
	elif int(result.get("code",0)) == 200 and _client.valid_match(result.get("data"), str(ConnectionGate.player_id)):
		if _action_kind == "match/forfeit":
			_forfeited = true
			_client.save_forfeit(_match_id)
			_forfeit.disabled = true
			_selected = -1
		if _is_cd: _server_score = result.data.get("score", {}) if result.data.get("score") is Dictionary else {}
		_accept_state(result.data, false)
	else:
		if str(result.get("error", "")) == "ACTION_EXPIRED" and _is_cd:
			_awaiting_deploy_state = true
			_notice.text = tr("CD_ACTION_EXPIRED")
		if str(result.get("error", "")) == "FORFEITED":
			_forfeited = true
			_client.save_forfeit(_match_id)
			_forfeit.disabled = true
		if str(result.get("error", "")) != "ACTION_EXPIRED" or not _is_cd:
			_notice.text = tr("WOE_ARENA_NETWORK") if int(result.get("code",0)) == 0 or int(result.get("code",0)) >= 500 else tr("WOE_ARENA_ACTION_FAILED")
	_action_kind = ""
	if int(result.get("code", 0)) == 429: _poll_period = 4.0
	_poll = 4.0 if int(result.get("code", 0)) == 429 else (2.0 if int(result.get("code", 0)) == 0 or int(result.get("code", 0)) >= 500 else 0.85)
	_update_hud()

func _confirm_forfeit() -> void:
	if _debug_visual:
		SceneRouter.finish_woe_safely()
		return
	if _finished or _forfeited or _acting: return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = tr("CD_FORFEIT_CONFIRM") if _is_cd else tr("WOE_FORFEIT_CONFIRM")
	dialog.confirmed.connect(func(): _action("match/forfeit", {"match_id":_match_id}))
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_return() -> void:
	if _debug_visual or _missing_match:
		_return_when_idle()
		return
	if _finished:
		if _is_cd and not _client.reconcile_terminal({"match_id":_match_id,"status":"FINISHED","snapshot":_snapshot}):
			_notice.text = tr("CD_UNAVAILABLE")
			return
		_client.save_match("")
		_client.save_forfeit("")
		_client.save_room("")
		_return_when_idle()
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = tr("WOE_RETURN_CONFIRM")
	dialog.confirmed.connect(_return_when_idle)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _return_when_idle() -> void:
	if _returning: return
	_returning = true
	if _identity != _client.identity(): hide()
	else:
		_return_button.disabled = true
		_forfeit.disabled = true
		_update_hud()
	while is_inside_tree() and (_requesting or _acting or _other_recovery_busy):
		await get_tree().process_frame
	if is_inside_tree(): SceneRouter.finish_woe_safely()

# A deliberately visual-only local preview, independent of match persistence and networking.
func _debug_render() -> void:
	_snapshot = {"kind":"core_defense" if _is_cd else "woe", "tick":int(_seconds * 10), "wave":1 + int(_seconds / 30), "completedWaves":int(_seconds / 30), "enemiesKilled":0, "pendingSpawns":0, "units":_debug_units, "laboratories":[], "players":[{"id":str(ConnectionGate.player_id), "team":"blue", "zeal":10, "slots":[UNIT.IDS[_debug_index % UNIT.IDS.size()], UNIT.IDS[(_debug_index + 1) % UNIT.IDS.size()], UNIT.IDS[(_debug_index + 2) % UNIT.IDS.size()]]}], "result":null}
	_render_snapshot()
	_notice.text = tr("WOE_DEBUG_VISUAL")

func _debug_deploy(card: String, lane: String) -> void:
	_debug_add(card, "blue", "homunculus", 410.0 if lane == "left" else 1510.0, 800.0)
	_debug_index = (_debug_index + 1) % UNIT.IDS.size()
	_debug_render()

func _debug_add(asset: String, team: String, kind: String, x: float, y: float) -> void:
	if _debug_units.size() >= 30: _debug_units.pop_front()
	_debug_units.append({"id":_debug_next_id, "cardId":asset, "assetId":asset, "kind":kind, "team":team, "x":x, "y":y, "hp":100, "maxHp":100})
	_debug_next_id += 1

func _debug_step(delta: float) -> void:
	_debug_spawn_timer -= delta
	if _debug_spawn_timer <= 0.0:
		_debug_spawn_timer = 2.5
		var enemy_index := int(_seconds / 2.5)
		var enemy: String = UNIT.ENEMY_IDS[enemy_index % UNIT.ENEMY_IDS.size()] if _is_cd else UNIT.IDS[enemy_index % UNIT.IDS.size()]
		_debug_add(enemy, "red", "enemy" if _is_cd else "homunculus", 410.0 if enemy_index % 2 == 0 else 1510.0, 280.0)
	for unit in _debug_units:
		var direction := 1.0 if unit.team == "red" else -1.0
		unit.y = float(unit.y) + direction * 45.0 * delta
		if (direction > 0 and unit.y > 650.0) or (direction < 0 and unit.y < 430.0):
			unit.y = 280.0 if direction > 0 else 800.0
	_debug_render()
	_debug_attack_timer -= delta
	if _debug_attack_timer <= 0.0:
		_debug_attack_timer = 1.5
		for unit in _units.values():
			if is_instance_valid(unit): unit.attack()

func _reconcile_pending_start() -> void:
	_other_recovery_busy = true
	_other_recovery_next = Time.get_ticks_msec() + 5000
	var saved: Dictionary = _client.saved_pending()
	var room_id := str(saved.get("values", {}).get("room_id", ""))
	if room_id.is_empty():
		_other_recovery_busy = false
		return
	var endpoint := "/forest/core-defense/" if _is_cd else "/forest/woe/"
	var room: Dictionary = await _client.request(endpoint + "state?room_id=" + room_id.uri_encode(), null, self)
	if not _valid():
		_other_recovery_busy = false
		return
	if room.code == 200 and _client.valid_room(room.get("data"), str(ConnectionGate.player_id)) and not str(room.data.get("match_id", "")).is_empty():
		_client.reconcile_started(room.data)
	elif int(room.get("code", 0)) == 404 and str(room.get("error", "")) == "ROOM_UNAVAILABLE":
		_client.reconcile_missing_room(room_id)
	_other_recovery_busy = false

# Old journals can block a new match, but must never be replayed in it.
func _reconcile_other_matches() -> void:
	_other_recovery_busy = true
	_other_recovery_next = Time.get_ticks_msec() + 5000
	var ids: Array[String] = []
	var entries := [_client.saved_pending()]
	if _is_cd: entries.append(_client.saved_forfeit_action())
	for entry in entries:
		var id := str(entry.get("values", {}).get("match_id", ""))
		if not id.is_empty() and id != _match_id and id not in ids: ids.append(id)
	for id in ids:
		var endpoint := "/forest/core-defense/" if _is_cd else "/forest/woe/"
		var result: Dictionary = await _client.request(endpoint + "match/state?match_id=" + id.uri_encode() + "&after=0", null, self)
		if not _valid():
			_other_recovery_busy = false
			return
		if result.code == 200 and _client.valid_match(result.get("data"), str(ConnectionGate.player_id)) and str(result.data.match_id) == id and result.data.status == "FINISHED":
			if not _client.reconcile_terminal(result.data): _notice.text = tr("CD_UNAVAILABLE")
		elif (int(result.get("code", 0)) == 404 and str(result.get("error", "")) == "MATCH_UNAVAILABLE") or (int(result.get("code", 0)) == 403 and str(result.get("error", "")) == "NOT_PARTICIPANT"):
			if not _client.reconcile_missing_match(id, str(result.error)): _notice.text = tr("CD_UNAVAILABLE")
	_other_recovery_busy = false
