extends Control

const BG := preload("res://assets/forest/woe/backgrounds/Classic_Arena_1920x1080.png")
const ZEAL := preload("res://assets/forest/woe/zeal.png")
const UNIT := preload("res://scripts/ui/woe_unit.gd")
const ARENA := "res://data/static/woe_arena.json"
const CARDS := "res://data/static/woe_cards.json"
const POLL_INTERVAL := 0.5

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

var _identity := ""
var _match_id := ""
var _cursor := 0
var _revision := -1
var _poll := 0.0
var _backoff := POLL_INTERVAL
var _poll_period := POLL_INTERVAL
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
var _seconds := 0.0

func _ready() -> void:
	_identity = WoeClient.identity()
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
	_forfeited = WoeClient.saved_forfeit() == _match_id
	_build()
	_forfeit.disabled = _forfeited
	_poll_state()

func _valid() -> bool:
	return is_inside_tree() and _identity == WoeClient.identity() and SceneRouter.woe_context_valid() and str(SceneRouter._woe_context.get("match_id", "")) == _match_id

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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARENA))
	for team in ["blue", "red"]:
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
			var marker := Button.new()
			marker.position = Vector2(float(spawn.x)-55,float(spawn.y)-55)
			marker.size = Vector2(110,110)
			marker.text = "?"
			for style in ["normal", "hover", "pressed", "focus", "disabled"]:
				marker.add_theme_stylebox_override(style, StyleBoxEmpty.new())
			marker.add_theme_font_size_override("font_size", 48)
			marker.modulate = Color(1,0.9,0.15,0.8)
			marker.pressed.connect(_deploy.bind(lane))
			marker.visible = false
			_stage.add_child(marker)
			_lane_buttons[team + ":" + lane] = marker
	var top := HBoxContainer.new()
	top.position = Vector2(660, 15)
	top.size = Vector2(600, 55)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.add_child(top)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 32)
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
	_forfeit.pressed.connect(_confirm_forfeit)
	_stage.add_child(_forfeit)
	_return_button = Button.new()
	_return_button.position = Vector2(1640,95)
	_return_button.size = Vector2(230,55)
	_return_button.text = tr("WOE_RETURN")
	_return_button.pressed.connect(_confirm_return)
	_stage.add_child(_return_button)
	_resize()

func _resize() -> void:
	if is_instance_valid(_stage): _stage.scale = _canvas.size / Vector2(1920,1080)

func _process(delta: float) -> void:
	if not _identity.is_empty() and _identity != WoeClient.identity():
		SceneRouter.finish_woe_safely()
		return
	_seconds += delta
	if is_instance_valid(_zeal_meter):
		_display_zeal = lerpf(_display_zeal, float(_own.get("zeal", 0)), 1.0 - exp(-delta * 8.0))
		_zeal_meter.value = _display_zeal
		_zeal_meter.queue_redraw()
	for marker in _lane_buttons.values():
		if marker.visible: marker.modulate.a = 0.6 + 0.3 * sin(_seconds * 4.0)
	_poll -= delta
	if _poll <= 0.0 and not _requesting and _valid(): _poll_state()

func _poll_state() -> void:
	if _requesting or not _valid(): return
	_requesting = true
	var requested_id := _match_id
	var result: Dictionary = await WoeClient.request("/forest/woe/match/state?match_id=%s&after=%d" % [requested_id.uri_encode(), _cursor], null, self)
	if not _valid() or requested_id != _match_id: return
	_requesting = false
	if int(result.get("code", 0)) != 200 or not WoeClient.valid_match(result.get("data"), str(ConnectionGate.player_id)) or str(result.data.get("match_id", "")) != _match_id:
		_notice.text = tr("WOE_ARENA_NETWORK")
		if int(result.get("code",0)) == 429: _poll_period = 0.65
		_backoff = minf(8.0, maxf(1.0, _backoff * 2.0))
		_poll = _backoff
		return
	_backoff = POLL_INTERVAL
	_notice.text = tr("WOE_FORFEITED_NOTICE") if _forfeited else ""
	_accept_state(result.data, true)
	_poll = 0.05 if _cursor < int(result.data.get("latest_event_seq", _cursor)) else _poll_period
	if not _acting and not WoeClient.saved_pending().is_empty():
		var pending: Dictionary = WoeClient.saved_pending()
		if str(pending.get("action", "")).begins_with("match/") and str(pending.get("values", {}).get("match_id", "")) == _match_id: _retry_pending()

func _accept_state(data: Dictionary, consume_events: bool) -> void:
	if str(data.get("match_id", "")) != _match_id: return
	if consume_events:
		if bool(data.get("resync_required", false)):
			_clear_visuals()
			_cursor = int(data.get("cursor", _cursor))
		else:
			for event in data.get("events", []):
				if not event is Dictionary: continue
				var seq := int(event.get("seq", 0))
				if seq <= _cursor: continue
				if seq != _cursor + 1: break
				_event(event)
				_cursor = seq
	if int(data.get("revision", -1)) >= _revision and data.get("snapshot") is Dictionary:
		_revision = int(data.revision)
		_snapshot = data.snapshot
		_render_snapshot()

func _clear_visuals() -> void:
	for child in _field.get_children(): child.queue_free()
	_units.clear()

func _event(event: Dictionary) -> void:
	var kind := str(event.get("type", ""))
	if kind == "spawn":
		var pos: Dictionary = event.get("position", {})
		_add_unit({"id":event.get("unit_id",0),"cardId":event.get("card_id",""),"team":event.get("team",""),"x":pos.get("x",0),"y":pos.get("y",0),"hp":1,"maxHp":1})
	elif kind == "attack":
		var attacker: Variant = _units.get(int(event.get("attacker", 0)))
		if is_instance_valid(attacker): attacker.attack()
		var victim: Variant = _units.get(int(event.get("target", 0))) if event.get("target") is int or event.get("target") is float else null
		if is_instance_valid(victim): victim.hit()
		if event.get("target") is String and _lab_bars.has(str(event.target)):
			var lab: Meter = _lab_bars[str(event.target)]
			lab.modulate = Color(2,2,2,1)
			create_tween().tween_property(lab, "modulate", Color.WHITE, 0.3)
		var point: Dictionary = event.get("targetPosition", {})
		_damage(Vector2(float(point.get("x",0)),float(point.get("y",0))), int(event.get("damage",0)))
	elif kind == "death" and event.get("targetKind") == "unit":
		var id := int(event.get("target",0))
		var victim: Variant = _units.get(id)
		if not is_instance_valid(victim):
			var point: Dictionary = event.get("victimPosition", event.get("targetPosition", {}))
			victim = _add_unit({"id":id,"cardId":event.get("victimCardId",""),"team":event.get("victimTeam",""),"x":point.get("x",0),"y":point.get("y",0),"hp":0,"maxHp":1})
		if is_instance_valid(victim):
			victim.die()
			_units.erase(id)
			_bound_effects()

func _add_unit(data: Dictionary) -> Node:
	var id := int(data.get("id",0))
	if _units.has(id): return _units[id]
	if str(data.get("cardId", "")) not in UNIT.IDS or str(data.get("team", "")) not in ["blue", "red"]: return null
	var unit := UNIT.new()
	_field.add_child(unit)
	unit.setup(data)
	_units[id] = unit
	return unit

func _bound_effects() -> void:
	if _field.get_child_count() > 220:
		for child in _field.get_children():
			if child is Node2D and child.get("dying") == true:
				child.queue_free()
				break

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
		var unit := _add_unit(data)
		if is_instance_valid(unit):
			unit.update_state(data)
			live[id] = true
	for id in _units.keys():
		if not live.has(id):
			if is_instance_valid(_units[id]): _units[id].queue_free()
			_units.erase(id)
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
	_clock.text = "%s  %02d:%02d  %s" % [tr("WOE_BLUE"), time_left / 60, time_left % 60, tr("WOE_RED")]
	var outcome: Variant = _snapshot.get("result")
	_finished = outcome is Dictionary
	if _finished:
		var winner := str(outcome.get("winner", ""))
		_result.text = tr("WOE_DRAW") if winner.is_empty() or winner == "<null>" else (tr("WOE_VICTORY") if winner == _team else tr("WOE_DEFEAT"))
		_forfeit.disabled = true
		_selected = -1
	_update_hud()

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
		button.disabled = _finished or _forfeited or _acting or card.is_empty() or zeal < float(card.get("cost",99))
		button.modulate = Color("fff29c") if _selected == i else Color.WHITE
	for key in _lane_buttons:
		var marker: Button = _lane_buttons[key]
		var lab: Meter = _lab_bars[key]
		marker.visible = not _finished and not _forfeited and _selected >= 0 and str(key).begins_with(_team + ":") and lab.value > 0
		marker.disabled = _acting

func _select(slot: int) -> void:
	_selected = -1 if _selected == slot else slot
	var slots: Array = _own.get("slots", [])
	_selected_card = str(slots[_selected]) if _selected >= 0 and _selected < slots.size() else ""
	_update_hud()

func _deploy(lane: String) -> void:
	var slots: Array = _own.get("slots", [])
	if _acting or _selected < 0 or _selected >= slots.size(): return
	var slot := _selected
	_selected = -1
	_action("match/deploy", {"match_id":_match_id,"slot":slot,"card_id":str(slots[slot]),"lane":lane})

func _action(action: String, values: Dictionary) -> void:
	if _acting or not _valid(): return
	_acting = true
	_action_kind = action
	_update_hud()
	var result: Dictionary = await WoeClient.mutate(action, values)
	if not _valid(): return
	_acting = false
	_finish_action(result)

func _retry_pending() -> void:
	if _acting or not _valid(): return
	_acting = true
	_action_kind = str(WoeClient.saved_pending().get("action", ""))
	var result: Dictionary = await WoeClient.retry_pending()
	if not _valid(): return
	_acting = false
	_finish_action(result)

func _finish_action(result: Dictionary) -> void:
	if int(result.get("code",0)) == 200 and WoeClient.valid_match(result.get("data"), str(ConnectionGate.player_id)):
		if _action_kind == "match/forfeit":
			_forfeited = true
			WoeClient.save_forfeit(_match_id)
			_forfeit.disabled = true
			_selected = -1
		_accept_state(result.data, false)
	else:
		if str(result.get("error", "")) == "FORFEITED":
			_forfeited = true
			WoeClient.save_forfeit(_match_id)
			_forfeit.disabled = true
		_notice.text = tr("WOE_ARENA_NETWORK") if int(result.get("code",0)) == 0 or int(result.get("code",0)) >= 500 else tr("WOE_ARENA_ACTION_FAILED")
	_action_kind = ""
	_poll = 0.05
	_update_hud()

func _confirm_forfeit() -> void:
	if _finished or _forfeited or _acting: return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = tr("WOE_FORFEIT_CONFIRM")
	dialog.confirmed.connect(func(): _action("match/forfeit", {"match_id":_match_id}))
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_return() -> void:
	if _finished:
		WoeClient.save_match("")
		WoeClient.save_forfeit("")
		WoeClient.save_room("")
		SceneRouter.finish_woe_safely()
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = tr("WOE_RETURN_CONFIRM")
	dialog.confirmed.connect(SceneRouter.finish_woe_safely)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
