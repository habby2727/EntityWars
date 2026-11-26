extends Control

const BG := preload("res://assets/forest/woe/backgrounds/Classic_Arena_1920x1080.png")
const ZEAL := preload("res://assets/forest/woe/zeal.png")
const SCORE_BANNER := preload("res://assets/ui/new-elements/banner-listas.png")
const UNIT := preload("res://scripts/ui/woe_unit.gd")
const EFFECTS := preload("res://scripts/ui/woe_effects.gd")
const POTION_VISUALS := preload("res://scripts/ui/woe_potion_visuals.gd")
const ARENA := "res://data/static/woe_arena.json"
const CARDS := "res://data/static/woe_cards.json"
const POLL_INTERVAL := 1.0
const MAX_VISUAL_EVENTS := 192
const MAX_VISUAL_EVENTS_PER_FRAME := 24
const MENU_ART := preload("res://scripts/ui/menu_art.gd")
const VISUAL_CLOCK := preload("res://scripts/ui/woe_visual_clock.gd")

class PrefetchPump extends Node:
	var unit_script: Script
	func _process(_delta: float) -> void:
		unit_script.service_prefetch()
		if unit_script._prefetch_pending.is_empty() and unit_script._prefetch_loading.is_empty():
			queue_free()

class Meter extends Control:
	var segments := 10
	var value := 0.0
	var maximum := 10.0
	var fill_color := Color("8adfff")
	var border_color := Color("d9f5ff")
	var translucent_partial := false
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), border_color)
		var width := (size.x - 4.0) / segments
		for i in range(segments):
			var rect := Rect2(2.0 + width * i, 2.0, width - 2.0, size.y - 4.0)
			draw_rect(rect, Color("203044"))
			var fraction := clampf(value / maxf(1.0, maximum) * segments - i, 0.0, 1.0)
			if fraction > 0.0:
				var cell_color := fill_color
				if translucent_partial and fraction < 1.0: cell_color.a *= 0.5
				draw_rect(Rect2(rect.position, Vector2(rect.size.x * fraction, rect.size.y)), cell_color)

class DefenseRanges extends Node2D:
	var labs := {}
	var radius := 120.0
	var ended := false
	func configure(data: Dictionary) -> void:
		radius = float(data.get("laboratory_defense", {}).get("range", 120))
		for team in ["blue", "red"]:
			for lane in ["left", "right"]:
				var point: Dictionary = data.laboratories[team][lane]
				labs[team + ":" + lane] = {"team":team, "center":Vector2(float(point.x),float(point.y)), "alive":false, "active":false, "flash":0.0}

	func update_snapshot(laboratories: Array, units: Array, finished: bool) -> void:
		ended = finished
		for id in labs:
			labs[id].alive = false
			labs[id].active = false
		for lab in laboratories:
			if not lab is Dictionary: continue
			var id := str(lab.get("id", ""))
			if not labs.has(id): continue
			labs[id].alive = not finished and float(lab.get("hp", 0)) > 0.0
			if not labs[id].alive:
				labs[id].flash = 0.0
				continue
			for unit in units:
				if not unit is Dictionary or str(unit.get("team", "")) == labs[id].team or str(unit.get("team", "")) not in ["blue", "red"] or float(unit.get("hp", 0)) <= 0.0: continue
				var point := Vector2(float(unit.get("x", 0)),float(unit.get("y", 0)))
				if point.distance_squared_to(labs[id].center) <= radius * radius:
					labs[id].active = true
					break
		queue_redraw()

	func flash(id: String) -> void:
		if labs.has(id) and labs[id].alive and labs[id].active:
			labs[id].flash = 0.25
			queue_redraw()

	func _process(delta: float) -> void:
		for id in labs:
			if labs[id].flash > 0.0:
				labs[id].flash = maxf(0.0, labs[id].flash - delta)
				queue_redraw()

	func _draw() -> void:
		if ended: return
		for id in labs:
			var lab: Dictionary = labs[id]
			if not lab.alive or not lab.active: continue
			var points := PackedVector2Array([lab.center])
			var start := PI if lab.team == "blue" else 0.0
			for i in range(33):
				var angle := start + PI * float(i) / 32.0
				points.append(lab.center + Vector2.from_angle(angle) * radius)
			var tint := Color("59bdff") if lab.team == "blue" else Color("ff6b59")
			tint.a = 0.10 + 0.16 * float(lab.flash) / 0.25
			draw_colored_polygon(points, tint)

class DeployMarker extends Button:
	func _draw() -> void:
		var center := size * 0.5
		draw_circle(center, 55.0, Color(1.0, 0.76, 0.08, 0.16))
		draw_circle(center, 47.0, Color(1.0, 0.87, 0.25, 0.24))
		draw_arc(center, 48.0, 0, TAU, 48, Color("ffe778"), 5.0)
		draw_arc(center, 34.0, 0, TAU, 40, Color("fff3b0"), 3.0)
		draw_circle(center, 6.0, Color("fff7c9"))

class PotionTarget extends Control:
	const VISUALS := preload("res://scripts/ui/woe_potion_visuals.gd")
	signal cast_requested(point: Vector2)
	signal cancel_requested
	var radius := 0.0
	var point := Vector2.ZERO
	var showing := false
	var potion_id := ""
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			point = event.position
			showing = true
			queue_redraw()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT: cancel_requested.emit()
			elif event.button_index == MOUSE_BUTTON_LEFT: cast_requested.emit(event.position)
			accept_event()
		elif event is InputEventScreenTouch and event.pressed:
			cast_requested.emit(event.position)
			accept_event()
	func _draw() -> void:
		if not showing: return
		var color: Color = VISUALS.MAP.get(potion_id, {}).get("color", Color.WHITE)
		color.a = 0.18
		draw_circle(point,radius,color)
		color.a = 0.7
		draw_arc(point,radius,0,TAU,48,color,2.0)

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
var _next_poll_ms := 0
var _recent_poll_rtts: Array[int] = []
var _backoff := POLL_INTERVAL
var _poll_period := POLL_INTERVAL
var _rate_limit_until := 0
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
var _zeal_progress := 0.0
var _zeal_sync_ms := 0
var _snapshot := {}
var _own := {}
var _team := ""
var _units := {}
var _visual_clock = VISUAL_CLOCK.new()
var _visual_events: Array[Dictionary] = []
var _known_units := {}
var _corpses: Array = []
var _playback_ready := false
var _silent_until_seq := 0
var _last_snapshot_tick := 0
var _effects: Node2D
var _defense_ranges: DefenseRanges
var _potion_target: PotionTarget
var _cards := {}
var _potion_textures := {}
var _lab_bars := {}
var _lane_buttons := {}
var _buttons: Array[Button] = []
var _potion_art: Array[TextureRect] = []
var _potion_names: Array[Label] = []
var _potion_costs: Array[Label] = []
var _canvas: Control
var _stage: Control
var _field: Node2D
var _clock: Label
var _score_banner: Label
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
		for potion in catalog.get("potions", []): _cards[str(potion.id)] = potion
	_forfeited = not _debug_visual and _client.saved_forfeit() == _match_id
	_build()
	_start_prefetch()
	_forfeit.disabled = _forfeited
	if _debug_visual:
		_debug_render()
	else:
		_poll_state()

func _start_prefetch() -> void:
	UNIT.begin_prefetch()
	if UNIT._prefetch_pending.is_empty() and UNIT._prefetch_loading.is_empty(): return
	var root := get_tree().root
	if root.has_node("WoeAssetPrefetch"): return
	var pump := PrefetchPump.new()
	pump.name = "WoeAssetPrefetch"
	pump.unit_script = UNIT
	root.add_child(pump)

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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ARENA))
	if not _is_cd:
		_defense_ranges = DefenseRanges.new()
		_defense_ranges.configure(data)
		_stage.add_child(_defense_ranges)
	_potion_target = PotionTarget.new()
	_potion_target.size = Vector2(1920,1080)
	_potion_target.visible = false
	_potion_target.cast_requested.connect(_cast_potion)
	_potion_target.cancel_requested.connect(_cancel_potion)
	_stage.add_child(_potion_target)
	_field = Node2D.new()
	_stage.add_child(_field)
	_effects = EFFECTS.new()
	_stage.add_child(_effects)
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
			marker.position = Vector2(float(spawn.x)-70,float(spawn.y)-70)
			marker.size = Vector2(140,140)
			marker.text = ""
			for style in ["normal", "hover", "pressed", "focus", "disabled"]:
				marker.add_theme_stylebox_override(style, StyleBoxEmpty.new())
			marker.add_theme_font_size_override("font_size", 48)
			marker.modulate = Color(1,1,1,0.9)
			marker.pressed.connect(_deploy.bind(lane))
			marker.visible = false
			_stage.add_child(marker)
			_lane_buttons[team + ":" + lane] = marker
	_clock = Label.new()
	_clock.position = Vector2(660, 8)
	_clock.size = Vector2(600, 52)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.add_theme_font_size_override("font_size", 36)
	_clock.add_theme_color_override("font_color", Color("dc2424"))
	_clock.add_theme_color_override("font_outline_color", Color.WHITE)
	_clock.add_theme_constant_override("outline_size", 4)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_clock)
	var banner := TextureRect.new()
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.texture = SCORE_BANNER
	banner.position = Vector2(480, 62) if _is_cd else Vector2(680, 62)
	banner.size = Vector2(960, 72) if _is_cd else Vector2(560, 72)
	banner.stretch_mode = TextureRect.STRETCH_SCALE
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(banner)
	_score_banner = Label.new()
	_score_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_score_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_banner.add_theme_font_size_override("font_size", 24 if _is_cd else 28)
	_score_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(_score_banner)
	_notice = Label.new()
	_notice.position = Vector2(670,140)
	_notice.size = Vector2(580,35)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage.add_child(_notice)
	_result = Label.new()
	_result.position = Vector2(600,180)
	_result.size = Vector2(720,70)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 38)
	_stage.add_child(_result)
	var hud := HBoxContainer.new()
	hud.position = Vector2(480,930)
	hud.size = Vector2(960,135)
	hud.alignment = BoxContainer.ALIGNMENT_CENTER
	hud.add_theme_constant_override("separation", 8)
	_stage.add_child(hud)
	var potion_font := SystemFont.new()
	potion_font.font_names = PackedStringArray(["Arial", "Noto Sans", "sans-serif"])
	for i in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(170,120)
		button.add_theme_font_size_override("font_size", 24)
		MENU_ART.button(button)
		button.pressed.connect(_select.bind(i))
		hud.add_child(button)
		_buttons.append(button)
		var art := TextureRect.new()
		art.position = Vector2(38, 4)
		art.size = Vector2(94, 78)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.visible = false
		button.add_child(art)
		_potion_art.append(art)
		var potion_name := Label.new()
		potion_name.set_meta("minigame_native_typography", true)
		potion_name.position = Vector2(8, 82)
		potion_name.size = Vector2(154, 32)
		potion_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		potion_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		potion_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		potion_name.clip_text = true
		potion_name.add_theme_font_override("font", potion_font)
		potion_name.add_theme_font_size_override("font_size", 16)
		potion_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		potion_name.visible = false
		button.add_child(potion_name)
		_potion_names.append(potion_name)
		var potion_cost := Label.new()
		potion_cost.set_meta("minigame_native_typography", true)
		potion_cost.position = Vector2(133, 8)
		potion_cost.size = Vector2(25, 25)
		potion_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		potion_cost.add_theme_font_override("font", potion_font)
		potion_cost.add_theme_font_size_override("font_size", 20)
		potion_cost.add_theme_color_override("font_color", Color("ffe79a"))
		potion_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		potion_cost.visible = false
		button.add_child(potion_cost)
		_potion_costs.append(potion_cost)
	var zeal_box := VBoxContainer.new()
	zeal_box.position = Vector2(608, 800 if _is_cd else 827)
	zeal_box.size = Vector2(704, 98)
	zeal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(zeal_box)
	var zeal_title := HBoxContainer.new()
	zeal_title.alignment = BoxContainer.ALIGNMENT_CENTER
	zeal_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zeal_box.add_child(zeal_title)
	var icon := TextureRect.new()
	icon.texture = ZEAL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(36,36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zeal_title.add_child(icon)
	_zeal_label = Label.new()
	_zeal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zeal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zeal_title.add_child(_zeal_label)
	var meter_center := CenterContainer.new()
	meter_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zeal_box.add_child(meter_center)
	_zeal_meter = Meter.new()
	_zeal_meter.translucent_partial = true
	_zeal_meter.custom_minimum_size = Vector2(360,18)
	_zeal_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_center.add_child(_zeal_meter)
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
	_visual_clock.advance(delta)
	_drain_visual_events()
	if is_instance_valid(_zeal_meter):
		var whole := clampi(floori(float(_own.get("zeal", 0))), 0, 10)
		var fresh := _debug_visual or (Time.get_ticks_msec() - _zeal_sync_ms <= 2000 and _playback_ready)
		var blocked: bool = _finished or _missing_match or _acting or (_is_cd and (_awaiting_deploy_state or _snapshot.get("phase") == "intermission" or bool(_snapshot.get("regeneration_blocked", false))))
		if fresh and not blocked and whole < 10: _zeal_progress = minf(0.9999, _zeal_progress + delta / 3.0)
		_display_zeal = float(whole) + (_zeal_progress if whole < 10 else 0.0)
		_zeal_meter.value = _display_zeal
		_zeal_meter.queue_redraw()
	for marker in _lane_buttons.values():
		if marker.visible: marker.modulate.a = 0.65 + 0.35 * sin(_seconds * 5.5)
	if _debug_visual:
		_debug_step(delta)
		return
	if _finished:
		if not _other_recovery_busy and Time.get_ticks_msec() >= _other_recovery_next and not _client.saved_pending().is_empty():
			if str(_client.saved_pending().get("action", "")) == "start": _reconcile_pending_start()
			else: _reconcile_other_matches()
		return
	if _next_poll_ms > 0:
		_poll = maxf(0.0, float(_next_poll_ms - Time.get_ticks_msec()) / 1000.0)
	if _poll <= 0.0 and not _requesting and not _finished and not _missing_match and _valid(): _poll_state()

func _defer_poll(seconds: float) -> void:
	_poll = maxf(0.0, seconds)
	_next_poll_ms = Time.get_ticks_msec() + ceili(_poll * 1000.0)

func _poll_rtt_budget_ms() -> int:
	if _recent_poll_rtts.is_empty(): return 0
	var total := 0
	for value in _recent_poll_rtts: total += value
	return ceili(float(total) / float(_recent_poll_rtts.size()))

func _poll_state() -> void:
	if _requesting or not _valid(): return
	_requesting = true
	# Anchor a steady cadence to the start time. A rolling RTT allowance keeps
	# the long-term request rate at or below the previous completion-based rate.
	_defer_poll(maxf(1.0, _poll_period) + float(_poll_rtt_budget_ms()) / 1000.0)
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
		else: _defer_poll(8.0)
		return
	if int(result.get("code", 0)) != 200 or not _client.valid_match(result.get("data"), str(ConnectionGate.player_id)) or str(result.data.get("match_id", "")) != _match_id:
		_playback_ready = false
		_visual_events.clear()
		_notice.text = tr("WOE_ARENA_NETWORK")
		if int(result.get("code",0)) == 429:
			_poll_period = 4.0
			_rate_limit_until = Time.get_ticks_msec() + 4000
		_backoff = minf(8.0, maxf(1.0, _backoff * 2.0))
		_defer_poll(maxf(_backoff, 4.0) if int(result.get("code", 0)) == 429 else _backoff)
		return
	_backoff = 1.0 if _is_cd else POLL_INTERVAL
	_recent_poll_rtts.append(maxi(0, Time.get_ticks_msec() - request_start))
	while _recent_poll_rtts.size() > 8: _recent_poll_rtts.pop_front()
	if _poll_period > 1.0 and Time.get_ticks_msec() >= _rate_limit_until: _poll_period = 1.0
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
	_next_poll_ms = maxi(_rate_limit_until, request_start + ceili(maxf(1.0, _poll_period) * 1000.0) + _poll_rtt_budget_ms())
	_poll = maxf(0.0, float(_next_poll_ms - Time.get_ticks_msec()) / 1000.0)
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
		var laboratory_shown := 0
		for event in data.get("events", []):
			if not event is Dictionary: continue
			var seq := int(event.get("seq", 0))
			if seq <= _cursor: continue
			if seq != _cursor + 1: break
			_cursor = seq
			_remember_event(event)
			# Pages from startup, reconnect and long backlogs advance the cursor silently.
			var laboratory_event := str(event.get("type", "")) in ["potion_cast", "potion_damage", "potion_heal"] or (str(event.get("type", "")) == "death" and str(event.get("attackerKind", "")) == "potion") or (not _is_cd and (str(event.get("type", "")) == "lab_attack" or (str(event.get("type", "")) == "death" and str(event.get("attackerKind", "")) == "laboratory")))
			var window := maxi(10, ceili(_poll_period * 10.0)) + _delivery_ticks + 2
			if _playback_ready and seq > _silent_until_seq and int(event.get("tick", -100)) >= maxi(snapshot_tick, _last_snapshot_tick) - window and (laboratory_shown < 32 if laboratory_event else shown < 48):
				_queue_visual_event(event)
				if laboratory_event: laboratory_shown += 1
				else: shown += 1
	if consume_events: _playback_ready = true

func _queue_visual_event(event: Dictionary) -> void:
	if _finished or _visual_events.size() >= MAX_VISUAL_EVENTS:
		return
	var event_tick := int(event.get("tick", 0))
	var due := maxf(float(event_tick), _visual_clock.render_tick)
	if not _visual_events.is_empty():
		var previous: Dictionary = _visual_events.back()
		due = maxf(due, float(previous.due) + maxf(0.0, float(event_tick - int(previous.tick))))
	# Never build an unbounded visual backlog when events arrive late.
	due = minf(due, _visual_clock.render_tick + 20.0)
	_visual_events.append({"tick":event_tick, "due":due, "event":event.duplicate(true)})

func _drain_visual_events(force: bool = false) -> void:
	var count := 0
	while not _visual_events.is_empty() and count < MAX_VISUAL_EVENTS_PER_FRAME:
		if not force and float(_visual_events[0].due) > _visual_clock.render_tick:
			break
		var item: Dictionary = _visual_events.pop_front()
		_event(item.event)
		count += 1

func _clear_visuals() -> void:
	for child in _field.get_children(): child.queue_free()
	_units.clear()
	_corpses.clear()
	_known_units.clear()
	_visual_events.clear()
	_visual_clock = VISUAL_CLOCK.new()
	if is_instance_valid(_effects): _effects.clear()

func _remember(id: int, card: String, team: String, point: Vector2, unit_kind: String = "homunculus", element: String = "") -> void:
	if id <= 0 or card not in UNIT.IDS + UNIT.ENEMY_IDS or team not in ["blue", "red"]: return
	_known_units[id] = {"cardId":card, "team":team, "position":point, "kind":unit_kind, "element":element if not element.is_empty() else _element(card)}
	while _known_units.size() > 256: _known_units.erase(_known_units.keys()[0])

func _point(value: Variant) -> Vector2:
	return Vector2(float(value.get("x", 0)), float(value.get("y", 0))) if value is Dictionary else Vector2.ZERO

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _is_selected_potion():
		_cancel_potion()
		get_viewport().set_input_as_handled()

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
	elif kind == "tower_strike" and _is_cd:
		_effects.emit_effect("tower_strike", "gold", _point(event.get("position")), _point(event.get("targetPosition")), "red")
	elif kind == "potion_cast":
		var card_id := str(event.get("cardId", ""))
		var card: Dictionary = _cards.get(card_id, {})
		if card.get("kind") != "potion": return
		if not POTION_VISUALS.MAP.has(card_id): return
		var point := _point(event.get("position"))
		var element := str(POTION_VISUALS.MAP[card_id].element)
		_effects.emit_effect("potion_cast", element, point, point, str(event.get("team", "")), "", float(card.get("radius", 0)))
		_effects.show_potion_area(element, point, float(card.get("radius", 0)), float(card.get("duration_ticks", 0)) / 10.0, maxf(0.0, float(_last_snapshot_tick - int(event.get("tick", _last_snapshot_tick))) / 10.0))
	elif kind == "potion_heal":
		var target := _point(event.get("targetPosition"))
		var victim: Variant = _units.get(int(event.get("target", 0)))
		if is_instance_valid(victim) and victim.target_position.distance_to(target) < 80.0: target = victim.position
		_effects.emit_effect("impact", "blood", target, target)
		_damage(target, int(event.get("healing", 0)), "", true)
	elif kind == "potion_damage":
		var target := _point(event.get("targetPosition"))
		var victim: Variant = _units.get(int(event.get("target", 0)))
		if is_instance_valid(victim) and victim.target_position.distance_to(target) < 80.0:
			victim.hit()
			target = victim.position
		_effects.emit_effect("impact", "vitriol", target, target)
		_damage(target, int(event.get("damage", 0)))
	elif kind == "lab_attack" and not _is_cd and is_instance_valid(_defense_ranges) and not _finished:
		var lab_id := str(event.get("labId", ""))
		if not _defense_ranges.labs.has(lab_id) or not _defense_ranges.labs[lab_id].alive: return
		var lab: Dictionary = _defense_ranges.labs[lab_id]
		var target := _point(event.get("targetPosition"))
		var victim: Variant = _units.get(int(event.get("target", 0)))
		if is_instance_valid(victim) and victim.target_position.distance_to(target) < 80.0:
			victim.hit()
			target = victim.position
		_defense_ranges.flash(lab_id)
		_effects.emit_effect("lab_defense", "aether", lab.center, target, lab.team, lab_id)
		_damage(target, int(event.get("damage", 0)), lab_id)
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
	unit.visual_clock = _visual_clock
	_field.add_child(unit)
	unit.setup(data)
	_units[id] = unit
	return unit

func _damage(point: Vector2, amount: int, lab_id: String = "", healing: bool = false) -> void:
	if _field.get_child_count() >= 220: return
	var label := Label.new()
	if not lab_id.is_empty(): label.set_meta("defense_lab_id", lab_id)
	label.position = point + Vector2(-20,-65)
	label.text = ("+" if healing else "") + str(amount)
	label.add_theme_color_override("font_color", Color("83f5a3") if healing else Color("fff1a1"))
	_field.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 35, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)

func _render_snapshot() -> void:
	_visual_clock.observe(int(_snapshot.get("tick", 0)), float(Time.get_ticks_msec()) / 1000.0)
	var live := {}
	for data in _snapshot.get("units", []):
		if not data is Dictionary: continue
		var id := int(data.get("id",0))
		_remember(id, str(data.get("assetId", data.get("cardId", ""))), str(data.get("team", "")), Vector2(float(data.get("x",0)), float(data.get("y",0))), str(data.get("kind", "homunculus")), str(data.get("element", "")))
		var visual_data: Dictionary = data.duplicate()
		visual_data["snapshot_tick"] = int(_snapshot.get("tick", 0))
		var unit := _add_unit(visual_data)
		if is_instance_valid(unit):
			unit.update_state(visual_data)
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
	_sync_zeal_display()
	for lab in _snapshot.get("laboratories", []):
		if lab is Dictionary and _lab_bars.has(str(lab.get("id", ""))):
			var meter: Meter = _lab_bars[str(lab.id)]
			meter.value = float(lab.get("hp",0))
			meter.maximum = float(lab.get("maxHp",1000))
			meter.queue_redraw()
	var time_left := maxi(0, 180 - int(_snapshot.get("tick", 0)) / 10)
	if _is_cd:
		var elapsed := int(_snapshot.get("tick", 0)) / 10
		_clock.text = "%02d:%02d" % [elapsed / 60, elapsed % 60]
		_score_banner.text = tr("CD_WAVE_BANNER") % [int(_snapshot.get("wave", 0)), int(_snapshot.get("completedWaves", 0)), int(_snapshot.get("enemiesKilled", 0)), int(_snapshot.get("pendingSpawns", 0))]
		if _snapshot.get("phase") == "intermission": _notice.text = tr("CD_INTERMISSION") % (float(_snapshot.get("intermissionTicks", 0)) / 10.0) + "  " + tr("CD_REGEN_PAUSED")
		elif bool(_snapshot.get("regeneration_blocked", false)): _notice.text = tr("CD_CAP_REACHED")
	else:
		_clock.text = "%02d:%02d" % [time_left / 60, time_left % 60]
		var leader := _winning_team(_snapshot)
		_score_banner.text = tr("WOE_WINNING") % (tr("WOE_" + leader.to_upper()) if not leader.is_empty() else "-")
	var outcome: Variant = _snapshot.get("result")
	_finished = outcome is Dictionary
	if _finished: _visual_events.clear()
	if is_instance_valid(_defense_ranges):
		_defense_ranges.update_snapshot(_snapshot.get("laboratories", []), _snapshot.get("units", []), _finished)
		_effects.prune_lab_defense(_defense_ranges.labs)
		for child in _field.get_children():
			if child.has_meta("defense_lab_id"):
				var id := str(child.get_meta("defense_lab_id"))
				if not _defense_ranges.labs.has(id) or not _defense_ranges.labs[id].alive: child.queue_free()
	if _finished:
		if not _debug_visual and not _client.reconcile_terminal({"match_id":_match_id,"status":"FINISHED","snapshot":_snapshot}):
			_notice.text = tr("CD_UNAVAILABLE")
		var winner := str(outcome.get("winner", ""))
		_result.text = (tr("CD_RESULT") % [int(_server_score.get("completed_waves", _snapshot.get("completedWaves", 0))), tr("CD_REASON_" + str(outcome.get("reason", "laboratories")).to_upper())]) if _is_cd else (tr("WOE_DRAW") if winner.is_empty() or winner == "<null>" else (tr("WOE_VICTORY") if winner == _team else tr("WOE_DEFEAT")))
		_forfeit.disabled = true
		_selected = -1
	_update_hud()

# Match the server's timeout ordering: surviving laboratories, then HP fraction.
func _winning_team(snapshot: Dictionary) -> String:
	var result: Variant = snapshot.get("result")
	if result is Dictionary:
		var winner: Variant = result.get("winner")
		return winner if winner is String and winner in ["blue", "red"] else ""
	var labs: Variant = snapshot.get("laboratories")
	if not labs is Array: return ""
	var counts := {"blue":0, "red":0}
	var alive := {"blue":0, "red":0}
	var hp := {"blue":0.0, "red":0.0}
	for lab in labs:
		if not lab is Dictionary: return ""
		var team := str(lab.get("team", ""))
		var maximum := float(lab.get("maxHp", 0))
		if team not in counts or maximum <= 0.0: return ""
		counts[team] += 1
		var current := maxf(0.0, float(lab.get("hp", 0)))
		if current > 0.0: alive[team] += 1
		hp[team] += current / maximum
	if counts.blue != 2 or counts.red != 2: return ""
	if alive.blue != alive.red: return "blue" if alive.blue > alive.red else "red"
	if hp.blue == hp.red: return ""
	return "blue" if hp.blue > hp.red else "red"

# Stable, bounded visual spacing based only on nearby authoritative positions.
func _separate_units() -> void:
	var ids := _units.keys()
	ids.sort()
	var buckets := {}
	var counts := {}
	var ranks := {}
	for id in ids:
		var unit: Node2D = _units[id]
		var point: Vector2 = unit.target_position
		var cell := Vector2i(floori(point.x / 45.0), floori(point.y / 45.0))
		counts[id] = 0
		ranks[id] = 0
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for other_id in buckets.get(cell + Vector2i(dx, dy), []):
					var other: Node2D = _units[other_id]
					if point.distance_squared_to(other.target_position) < 45.0 * 45.0:
						counts[id] += 1
						counts[other_id] += 1
						ranks[id] += 1
		if not buckets.has(cell): buckets[cell] = []
		buckets[cell].append(id)
	for id in ids:
		var unit: Node2D = _units[id]
		if counts[id] == 0:
			unit.set_separation(Vector2.ZERO)
			continue
		var rank: int = ranks[id]
		var column := (rank % 5) - 2
		var row := (rank / 5) % 3
		unit.set_separation(Vector2(float(column) * 3.0, float(row - 1) * 2.0), float(rank % 3) * 3.0)

func _card_cost(card: Dictionary) -> float:
	return float(card.get("cost", 99) if _is_cd else card.get("woe_cost", card.get("cost", 99)))

func _is_selected_potion() -> bool:
	return _selected >= 0 and _cards.get(_selected_card, {}).get("kind") == "potion"

func _snapshot_zeal_progress() -> float:
	var old_zeal := float(_own.get("zeal", 0))
	return clampf(float(_own.get("zeal_regen_ticks", (old_zeal - floorf(old_zeal)) * 30.0)) / 30.0, 0.0, 0.9999)

func _sync_zeal_display() -> void:
	_zeal_progress = _snapshot_zeal_progress()
	_zeal_sync_ms = Time.get_ticks_msec()
	_display_zeal = float(clampi(floori(float(_own.get("zeal", 0))), 0, 10)) + _zeal_progress
	if is_instance_valid(_zeal_meter):
		_zeal_meter.value = _display_zeal
		_zeal_meter.queue_redraw()

func _update_hud() -> void:
	var zeal := clampi(floori(float(_own.get("zeal",0))), 0, 10)
	_zeal_label.text = "%s  %d / 10" % [tr("WOE_ZEAL"), zeal]
	if _is_cd and _snapshot.has("allied_cap"):
		_zeal_label.text += "\n" + (tr("CD_ALLIED_CAP") % [int(_snapshot.get("allied_count", 0)), int(_snapshot.allied_cap)])
	var capped := _is_cd and _snapshot.has("allied_cap") and int(_snapshot.get("allied_count", 0)) >= int(_snapshot.allied_cap)
	var slots: Array = _own.get("slots", [])
	if _selected >= 0 and (_selected >= slots.size() or str(slots[_selected]) != _selected_card or zeal < _card_cost(_cards.get(_selected_card, {})) or (capped and not _is_selected_potion())):
		_selected = -1
		_selected_card = ""
	for i in range(_buttons.size()):
		var button := _buttons[i]
		button.visible = i < slots.size()
		var id := str(slots[i]) if i < slots.size() else ""
		var card: Dictionary = _cards.get(id, {})
		var potion: bool = card.get("kind") == "potion"
		button.add_theme_font_size_override("font_size", 24)
		_potion_art[i].visible = not card.is_empty()
		_potion_names[i].visible = not card.is_empty()
		_potion_costs[i].visible = not card.is_empty()
		if potion:
			if not _potion_textures.has(id): _potion_textures[id] = load(str(card.get("texture", ""))) as Texture2D
			_potion_art[i].texture = _potion_textures[id]
			_potion_names[i].text = tr(str(card.get("name_key", "")))
		else:
			_potion_art[i].texture = UNIT.frame(id,"front",1) if not card.is_empty() else null
			_potion_names[i].text = id.capitalize() if not card.is_empty() else ""
		_potion_costs[i].text = str(int(_card_cost(card))) if not card.is_empty() else ""
		button.text = ""
		button.disabled = _returning or _finished or _missing_match or _forfeited or _acting or (capped and not potion) or (_is_cd and _awaiting_deploy_state) or card.is_empty() or zeal < _card_cost(card)
		button.modulate = Color("ffe38a") if _selected == i else (Color(0.65,0.7,0.75,1) if button.disabled else Color.WHITE)
	for key in _lane_buttons:
		var marker: Button = _lane_buttons[key]
		var lab: Meter = _lab_bars[key]
		var lane := str(key).get_slice(":", 1)
		marker.visible = not _returning and not _finished and not _missing_match and not _forfeited and not (_is_cd and _awaiting_deploy_state) and _selected >= 0 and not _is_selected_potion() and str(key).begins_with(_team + ":") and lab.value > 0 and (_is_cd or _debug_visual or lane in _own.get("allowedDeploymentLanes", []))
		marker.disabled = _acting
	if is_instance_valid(_potion_target):
		_potion_target.visible = _is_selected_potion() and not _returning and not _finished and not _missing_match and not _forfeited and not _acting and not (_is_cd and _awaiting_deploy_state)
		if _potion_target.visible:
			_potion_target.potion_id = _selected_card
			_potion_target.radius = float(_cards[_selected_card].get("radius", 0))
			_potion_target.queue_redraw()

func _select(slot: int) -> void:
	if _returning: return
	_selected = -1 if _selected == slot else slot
	var slots: Array = _own.get("slots", [])
	_selected_card = str(slots[_selected]) if _selected >= 0 and _selected < slots.size() else ""
	_update_hud()

func _deploy(lane: String) -> void:
	var slots: Array = _own.get("slots", [])
	if _acting or (_is_cd and _awaiting_deploy_state) or _selected < 0 or _selected >= slots.size() or _is_selected_potion(): return
	var slot := _selected
	_selected = -1
	if _debug_visual:
		_debug_deploy(str(slots[slot]), lane)
		return
	_action("match/deploy", {"match_id":_match_id,"slot":slot,"card_id":str(slots[slot]),"lane":lane})

func _cancel_potion() -> void:
	_selected = -1
	_selected_card = ""
	_potion_target.showing = false
	_update_hud()

func _cast_potion(point: Vector2) -> void:
	if not _is_selected_potion() or _acting or not point.is_finite() or point.x < 0 or point.x > 1920 or point.y < 0 or point.y > 1080: return
	var slot := _selected
	var card := _selected_card
	_cancel_potion()
	if _debug_visual: return
	_action("match/deploy", {"match_id":_match_id,"slot":slot,"card_id":card,"target_x":point.x,"target_y":point.y})

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
		var receipt_revision := int(result.data.get("revision", -1))
		_awaiting_deploy_state = receipt_revision < 0 or _revision < receipt_revision
		_deploy_receipt_revision = receipt_revision if _awaiting_deploy_state else -1
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
	if int(result.get("code", 0)) == 429:
		_poll_period = 4.0
		_rate_limit_until = Time.get_ticks_msec() + 4000
	if int(result.get("code", 0)) == 429: _defer_poll(maxf(_poll, 4.0))
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
	_snapshot = {"kind":"core_defense" if _is_cd else "woe", "tick":int(_seconds * 10), "wave":1 + int(_seconds / 30), "completedWaves":int(_seconds / 30), "enemiesKilled":0, "pendingSpawns":0, "units":_debug_units, "laboratories":[], "players":[{"id":str(ConnectionGate.player_id), "team":"blue", "zeal":10, "slots":[UNIT.IDS[_debug_index % UNIT.IDS.size()], UNIT.IDS[(_debug_index + 1) % UNIT.IDS.size()], UNIT.IDS[(_debug_index + 2) % UNIT.IDS.size()], UNIT.IDS[(_debug_index + 3) % UNIT.IDS.size()]]}], "result":null}
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
