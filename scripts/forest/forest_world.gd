extends Control

const ResourceBars := preload("res://scripts/ui/lab_resource_bars.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Zones := preload("res://scripts/forest/forest_zones.gd")
const ForestPlayer := preload("res://scripts/forest/forest_player.gd")
const NPCs := preload("res://scripts/forest/forest_npcs.gd")
const Presence := preload("res://scripts/forest/forest_presence_client.gd")
const Remote := preload("res://scripts/forest/forest_remote_summoner.gd")
const ForestNPC := preload("res://scripts/forest/forest_npc.gd")
const Joystick := preload("res://scripts/forest/forest_touch_joystick.gd")
const REFERENCE_SIZE := Vector2(1920, 1080)
const PORTAL_LOCK_MS := 350
const INTERACTION_DISTANCE := 145.0

class MaskButton extends Button:
	func _draw() -> void:
		var c := size * 0.5
		var shape := PackedVector2Array([c + Vector2(-20, -12), c + Vector2(-15, -19), c + Vector2(0, -16), c + Vector2(15, -19), c + Vector2(20, -12), c + Vector2(17, 7), c + Vector2(9, 16), c + Vector2(0, 19), c + Vector2(-9, 16), c + Vector2(-17, 7)])
		draw_colored_polygon(shape, Color("d0ba7b"))
		draw_polyline(shape + PackedVector2Array([shape[0]]), Color("4c6558"), 2.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-14,-5), c + Vector2(-5,-7), c + Vector2(-6,0), c + Vector2(-12,0)]), Color("172b2c"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(14,-5), c + Vector2(5,-7), c + Vector2(6,0), c + Vector2(12,0)]), Color("172b2c"))
		draw_line(c + Vector2(-5,9), c + Vector2(5,9), Color("4c6558"), 2.0, true)


var _resource_catalog := AssetCatalog.new()
var _resource_rows := {}

var _canvas: Control
var _world: Node2D
var _actors: Node2D
var _background: Sprite2D
var _player: Node2D
var _joystick: Control
var _polygon_fill: Polygon2D
var _polygon_line: Line2D
var _portal_debug: Node2D
var _debug_label: Label
var _zones: Array = []
var _catalog_valid := false
var _zone_index := 0
var _show_geometry := false
var _transition_until := 0
var _transition_generation := 0
var _npcs: Array[Node2D] = []
var _talk_button: Button
var _dialogue: PanelContainer
var _dialogue_name: Label
var _dialogue_text: Label
var _talking_to: Node2D
var _action_row: HBoxContainer
var _mask_button: Button
var _name_backend: BackendClient
var _verified_name := ""
var _name_generation := -1
var _name_client_generation := -1
var _safe_modes := false
var _safe_check_elapsed := 0.0
var _presence: Node
var _remotes := {}
var _selected_remote := ""
var _portal_deadline := 0
var _handoff_pending := false
var _quest := {}
var _quest_active = null
var _quest_can_accept := false
var _quest_cooldown := 0
var _quest_error := ""
var _quest_catalog := []
var _quest_request := ""
var _quest_request_kind := ""
var _quest_zone := ""
var _quest_owner := ""
var _quest_generation := 0
var _quest_zone_generation := 0
var _quest_request_zone_generation := 0
var _quest_request_client_generation := -1
var _quest_pending_actions := {}
var _quest_pending_request_key := ""
var _quest_server_time := 0
var _quest_tick := 0
var _quest_timer: Timer

func _ready() -> void:
	_zones = Zones.runtime_zones()
	_catalog_valid = not _zones.is_empty()
	if not _catalog_valid:
		_zones = Zones.ZONES
	var had_restore := not SceneRouter._forest_restore.is_empty()
	var restore := SceneRouter.consume_forest_restore() if had_restore else {}
	if had_restore and restore.is_empty():
		SceneRouter.go_to_lab_hub.call_deferred()
		return
	var selected := SceneRouter.forest_selected_summoner()
	if selected not in ForestPlayer.FILES:
		SceneRouter.go_to_lab_hub.call_deferred()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	add_child(aspect)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect.add_child(_canvas)
	_canvas.resized.connect(_resize_world)
	_world = Node2D.new()
	_world.name = "World"
	_canvas.add_child(_world)
	_background = Sprite2D.new()
	_background.name = "Background"
	_background.centered = false
	_world.add_child(_background)
	_polygon_fill = Polygon2D.new()
	_polygon_fill.color = Color(0.15, 0.85, 0.30, 0.15)
	_world.add_child(_polygon_fill)
	_polygon_line = Line2D.new()
	_polygon_line.default_color = Color(0.2, 1.0, 0.35, 0.9)
	_polygon_line.width = 3.0
	_polygon_line.closed = true
	_world.add_child(_polygon_line)
	_portal_debug = Node2D.new()
	_portal_debug.name = "PortalDebug"
	_world.add_child(_portal_debug)
	_actors = Node2D.new()
	_actors.name = "Actors"
	_actors.y_sort_enabled = true
	_world.add_child(_actors)
	_player = ForestPlayer.new()
	_player.name = "Summoner"
	_actors.add_child(_player)
	_player.setup(selected)
	_setup_nameplate()
	_player.exit_attempt.connect(_on_exit_attempt)
	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "FOREST_LEAVE"
	leave.anchor_left = 0.5
	leave.anchor_right = 0.5
	leave.offset_left = -86
	leave.offset_right = 86
	leave.offset_top = 20
	leave.offset_bottom = 55
	leave.add_theme_font_size_override("font_size", 20)
	leave.pressed.connect(_leave_forest)
	_canvas.add_child(leave)
	var resources := VBoxContainer.new()
	resources.name = "ForestResourceBars"
	resources.position = Vector2(20, 20)
	resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(resources)
	_resource_rows = ResourceBars.build(resources, _resource_catalog, true, -10)
	ResourceBars.update(_resource_rows, {})
	_build_mask_button()
	_joystick = Joystick.new()
	_joystick.name = "TouchJoystick"
	_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick.offset_left = 28
	_joystick.offset_top = -252
	_joystick.offset_right = 252
	_joystick.offset_bottom = -28
	_canvas.add_child(_joystick)
	_debug_label = Label.new()
	_debug_label.position = Vector2(400, 30)
	_debug_label.add_theme_font_size_override("font_size", 22)
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_debug_label)
	_build_dialogue()
	var quest_file := FileAccess.open("res://data/static/forest_quests.json", FileAccess.READ)
	if quest_file:
		var quest_data = JSON.parse_string(quest_file.get_as_text())
		if quest_data is Dictionary:
			_quest_catalog = quest_data.get("npcs", [])
	_quest_timer = Timer.new()
	_quest_timer.one_shot = true
	_quest_timer.timeout.connect(_fetch_quest)
	add_child(_quest_timer)
	UIThemeFactory.apply_theme_to(self)
	MenuArt.button(leave)
	MenuArt.button(_talk_button)
	MenuArt.button(_dialogue.get_node("Margin/Contents/Close"))
	if not restore.is_empty():
		if not _set_zone(_zone_index_for_id(str(restore.zone_id)), restore.foot_position):
			SceneRouter.go_to_lab_hub.call_deferred()
			return
		_player.facing = restore.facing
	else:
		_set_zone(0)
	_resize_world()
	_start_presence(selected)
	SocialClient.state_changed.connect(_update_social_remotes)
	DuelClient.state_changed.connect(_update_social_remotes)
	DuelClient.accepted.connect(_on_duel_accepted)
	DuelClient.match_started.connect(_on_duel_recover)

func _setup_nameplate() -> void:
	if ConnectionGate.debug_lab_navigation_allowed():
		_player.set_display_name(tr("FOREST_SUMMONER"))
		return
	_name_backend = BackendClient.new()
	_name_backend.name = "ForestIdentityClient"
	_name_backend.auto_dev_login = false
	_name_backend.auto_flush = false
	_name_backend.state_updated.connect(_on_name_state)
	_name_backend.auth_changed.connect(_on_name_auth_changed)
	_name_backend.api_completed.connect(_on_quest_response)
	add_child(_name_backend)

func _on_name_auth_changed(_token: String) -> void:
	_clear_verified_name()

func _clear_verified_name() -> void:
	_clear_quest()
	_verified_name = ""
	_name_generation = -1
	_name_client_generation = -1
	ResourceBars.update(_resource_rows, {})
	if is_instance_valid(_player):
		_player.set_display_name("")

func _on_name_state(state: Dictionary) -> void:
	if not _name_session_matches() or str(state.get("player_id", "")) != ConnectionGate.player_id or not state.get("display_name") is String:
		_clear_verified_name()
		return
	var value: String = state.display_name
	if value.strip_edges().is_empty():
		_clear_verified_name()
		return
	ResourceBars.update(_resource_rows, state)
	_sync_quest_pending_identity()
	_verified_name = value
	_name_generation = ConnectionGate._generation
	_name_client_generation = _name_backend._session_generation
	_player.set_display_name(value)
	if is_instance_valid(_presence) and _presence.entered and _quest.is_empty():
		_fetch_quest.call_deferred()

func _name_session_matches() -> bool:
	return is_instance_valid(_name_backend) and not ConnectionGate.blocked() and not ConnectionGate.debug_lab_navigation_allowed() and not str(ConnectionGate.player_id).is_empty() and not str(ConnectionGate.token).is_empty() and _name_backend.token == ConnectionGate.token and _name_backend._verified_player_id == ConnectionGate.player_id and SceneRouter.forest_selected_summoner() != ""

func _refresh_nameplate() -> void:
	if ConnectionGate.debug_lab_navigation_allowed():
		_verified_name = ""
		_name_generation = -1
		_name_client_generation = -1
		var fallback := tr("FOREST_SUMMONER")
		if _player._display_name != fallback:
			_player.set_display_name(fallback)
	elif not _name_session_matches() or _name_generation != ConnectionGate._generation or _name_client_generation != _name_backend._session_generation:
		if not _verified_name.is_empty() or not _player._display_name.is_empty():
			_clear_verified_name()

func _build_mask_button() -> void:
	_mask_button = MaskButton.new()
	_mask_button.name = "ChangeSummoner"
	_mask_button.anchor_left = 1.0
	_mask_button.anchor_right = 1.0
	_mask_button.offset_left = -90
	_mask_button.offset_right = -24
	_mask_button.offset_top = 18
	_mask_button.offset_bottom = 84
	_mask_button.custom_minimum_size = Vector2(66, 66)
	_mask_button.tooltip_text = tr("FOREST_CHANGE_SUMMONER")
	_mask_button.accessibility_name = tr("FOREST_CHANGE_SUMMONER")
	_mask_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.11, 0.11, 0.94) if state != "hover" else Color(0.14, 0.24, 0.20, 0.98)
		if state == "disabled": style.bg_color = Color(0.06, 0.07, 0.07, 0.65)
		style.border_color = Color("b9a773") if state != "focus" else Color("f1e0a4")
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		_mask_button.add_theme_stylebox_override(state, style)
	_mask_button.pressed.connect(_change_summoner)
	_canvas.add_child(_mask_button)

func forest_change_allowed(zone_id: String, foot: Vector2, facing: int) -> bool:
	return is_instance_valid(_player) and not _player.exit_pending and not _player.transition_locked and not _player.dialogue_locked and not _dialogue.visible and zone_id == str(_zones[_zone_index].id) and foot == _player.position and facing == _player.facing and not SceneRouter.forest_selected_summoner().is_empty() and SceneRouter._forest_modes_safe()

func _change_summoner() -> void:
	if _handoff_pending: return
	if forest_change_allowed(str(_zones[_zone_index].id), _player.position, _player.facing):
		await _prepare_handoff("suspend")
		if not is_inside_tree(): return
		SceneRouter.change_summoner_from_forest(str(_zones[_zone_index].id), _player.position, _player.facing)
		_resume_if_still_here()

func _resize_world() -> void:
	if is_instance_valid(_world):
		_world.scale = _canvas.size / REFERENCE_SIZE

func _zone_index_for_id(zone_id: String) -> int:
	var found := -1
	for i in _zones.size():
		if str(_zones[i].get("id", "")) == zone_id:
			if found != -1:
				return -1
			found = i
	return found

func _set_zone(index: int, arrival: Vector2 = Vector2.INF) -> bool:
	if index < 0 or index >= _zones.size():
		return false
	var zone: Dictionary = _zones[index]
	var polygon := PackedVector2Array(zone.get("polygon", []))
	var spawn: Vector2 = zone.get("spawn", Vector2.INF) if arrival == Vector2.INF else arrival
	var path := Zones.BACKGROUND_DIR + str(zone.get("image", ""))
	if not Zones.contains_point(polygon, spawn) or not ResourceLoader.exists(path):
		return false
	var texture := load(path) as Texture2D
	if texture == null:
		return false
	_zone_index = index
	_quest_zone_generation += 1
	_quest = {}
	_quest_error = ""
	_deselect_remote()
	_background.texture = texture
	_polygon_fill.polygon = polygon
	_polygon_line.points = polygon
	_player.polygon = polygon
	_player.position = spawn
	_player.blocked_visible = false
	_close_dialogue()
	_spawn_npcs(zone)
	_build_portal_debug(zone)
	_refresh_debug()
	_fetch_quest.call_deferred()
	return true

func _build_portal_debug(zone: Dictionary) -> void:
	for child in _portal_debug.get_children():
		child.queue_free()
	for portal in zone.get("portals", []):
		var rect: Array = portal.get("corridor", [])
		if rect.size() != 4:
			continue
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color(1.0, 0.8, 0.25, 0.95)
		line.closed = true
		line.points = PackedVector2Array([Vector2(rect[0], rect[1]), Vector2(rect[2], rect[1]), Vector2(rect[2], rect[3]), Vector2(rect[0], rect[3])])
		_portal_debug.add_child(line)
		var label := Label.new()
		label.text = str(portal.get("destination", ""))
		label.position = Vector2(rect[0] + 5, rect[1] + 5)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portal_debug.add_child(label)

func _on_exit_attempt(direction: String, foot: Vector2, candidate: Vector2) -> void:
	if _player.exit_pending or _player.transition_locked or _zone_index < 0 or _zone_index >= _zones.size():
		return
	var zone: Dictionary = _zones[_zone_index]
	var source_id := str(zone.get("id", ""))
	if _zone_index_for_id(source_id) != _zone_index or foot.distance_to(_player.position) > 0.01 or not Geometry2D.is_point_in_polygon(foot, _player.polygon):
		return
	var valid_crossing := false
	match direction:
		"north": valid_crossing = candidate.y <= 0.0 and candidate.y < foot.y and candidate.x >= 0.0 and candidate.x <= REFERENCE_SIZE.x
		"south": valid_crossing = candidate.y >= REFERENCE_SIZE.y and candidate.y > foot.y and candidate.x >= 0.0 and candidate.x <= REFERENCE_SIZE.x
		"west": valid_crossing = candidate.x <= 0.0 and candidate.x < foot.x and candidate.y >= 0.0 and candidate.y <= REFERENCE_SIZE.y
		"east": valid_crossing = candidate.x >= REFERENCE_SIZE.x and candidate.x > foot.x and candidate.y >= 0.0 and candidate.y <= REFERENCE_SIZE.y
	if not valid_crossing:
		return
	for portal in zone.get("portals", []):
		if str(portal.get("id", "")) != direction or str(portal.get("direction", "")) != direction:
			continue
		var rect: Array = portal.get("corridor", [])
		if rect.size() != 4 or foot.x < rect[0] or foot.x > rect[2] or foot.y < rect[1] or foot.y > rect[3]:
			continue
		var destination_id := str(portal.get("destination", ""))
		var target := _zone_index_for_id(destination_id)
		var arrival = portal.get("arrival", null)
		if target < 0 or destination_id == source_id or not arrival is Vector2:
			return
		var target_zone: Dictionary = _zones[target]
		var target_polygon := PackedVector2Array(target_zone.get("polygon", []))
		if not arrival.is_finite() or target_polygon.size() < 3 or not Geometry2D.is_point_in_polygon(arrival, target_polygon) or not ResourceLoader.exists(Zones.BACKGROUND_DIR + str(target_zone.get("image", ""))):
			return
		if is_instance_valid(_presence) and _presence.entered:
			var delta := candidate - foot
			var ratio := 0.0
			match direction:
				"north": ratio = -foot.y / delta.y
				"south": ratio = (REFERENCE_SIZE.y - foot.y) / delta.y
				"west": ratio = -foot.x / delta.x
				"east": ratio = (REFERENCE_SIZE.x - foot.x) / delta.x
			if ratio < 0.0 or ratio > 1.0:
				return
			var crossing := foot + delta * ratio
			match direction:
				"north": crossing.y = 0.0
				"south": crossing.y = REFERENCE_SIZE.y
				"west": crossing.x = 0.0
				"east": crossing.x = REFERENCE_SIZE.x
			if crossing.x < rect[0] or crossing.x > rect[2] or crossing.y < rect[1] or crossing.y > rect[3]:
				return
			if _presence.portal(direction, crossing, foot, _player.facing):
				_player.exit_pending = true
				_portal_deadline = Time.get_ticks_msec() + 3000
				_reset_touch()
			return
		_player.exit_pending = true
		_transition_generation += 1
		_complete_portal.call_deferred(_transition_generation, source_id, destination_id, arrival, direction)
		return

func _complete_portal(generation: int, source_id: String, destination_id: String, arrival: Vector2, direction: String) -> void:
	if generation != _transition_generation or not _player.exit_pending or str(_zones[_zone_index].get("id", "")) != source_id:
		return
	var target := _zone_index_for_id(destination_id)
	if not _set_zone(target, arrival):
		_player.exit_pending = false
		return
	match direction:
		"north": _player.facing = 2
		"south": _player.facing = 0
		"east": _player.facing = 1
		"west": _player.facing = 3
	_reset_touch()
	_player.exit_pending = false
	_player.transition_locked = true
	_transition_until = Time.get_ticks_msec() + PORTAL_LOCK_MS

func _reset_touch() -> void:
	_joystick.vector = Vector2.ZERO
	_joystick._finger = -1
	_joystick.queue_redraw()
	_player.joystick_vector = Vector2.ZERO

func _process(_delta: float) -> void:
	if is_instance_valid(_talking_to) and str(_talking_to.npc_id).begins_with("quest_") and str(_quest.get("state", "")) in ["ACTIVE", "OFFERED"]:
		_update_dialogue_text()
	if is_instance_valid(_player) and is_instance_valid(_joystick):
		var moving: bool = _joystick.vector.length_squared() > 0.0001
		for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			moving = moving or Input.is_physical_key_pressed(key)
		var chat_panel = GlobalChatClient._panel
		if moving or _player.exit_pending or _player.transition_locked or _player.dialogue_locked or not SocialClient.available() or not (SocialClient.enabled or DuelClient.enabled) or SocialClient._popup._panel.visible or (is_instance_valid(chat_panel) and (chat_panel._panel.visible or chat_panel._online_panel.visible)):
			_deselect_remote()
		_safe_check_elapsed += _delta
		if _safe_check_elapsed >= 0.5:
			_safe_check_elapsed = 0.0
			_safe_modes = SceneRouter._forest_modes_safe()
		_mask_button.disabled = not _safe_modes or SceneRouter.forest_selected_summoner().is_empty() or _player.exit_pending or _player.transition_locked or _player.dialogue_locked or _dialogue.visible
		_refresh_nameplate()
		if _player.transition_locked and Time.get_ticks_msec() >= _transition_until:
			_player.transition_locked = false
		if _portal_deadline > 0 and Time.get_ticks_msec() >= _portal_deadline:
			_portal_deadline = 0
			_player.exit_pending = false
			_reset_touch()
			if is_instance_valid(_presence): _presence._drop()
		if is_instance_valid(_presence) and _presence.entered and not _player.exit_pending and not _player.transition_locked and not _player.dialogue_locked and not _handoff_pending:
			_presence.move(_player.position, _player.facing)
		_player.joystick_vector = _joystick.vector
		var nearby_npc := _nearest_npc() if not _dialogue.visible and not _player.exit_pending and not _player.transition_locked and not _handoff_pending else null
		for npc in _npcs:
			npc.show_interaction_hint(npc == nearby_npc)
		_talk_button.visible = nearby_npc != null and (DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))

func _build_dialogue() -> void:
	_talk_button = Button.new()
	_talk_button.name = "TalkButton"
	_talk_button.text = "FOREST_TALK"
	_talk_button.anchor_left = 0.78
	_talk_button.anchor_right = 0.97
	_talk_button.anchor_top = 0.82
	_talk_button.anchor_bottom = 0.91
	_talk_button.add_theme_font_size_override("font_size", 24)
	_talk_button.pressed.connect(_interact_nearest)
	_canvas.add_child(_talk_button)
	_dialogue = PanelContainer.new()
	_dialogue.name = "Dialogue"
	_dialogue.anchor_left = 0.27
	_dialogue.anchor_right = 0.73
	_dialogue.anchor_top = 0.65
	_dialogue.anchor_bottom = 0.94
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.075, 0.075, 0.96)
	panel.border_color = Color("9cb891")
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(12)
	_dialogue.add_theme_stylebox_override("panel", panel)
	_canvas.add_child(_dialogue)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_dialogue.add_child(margin)
	var contents := VBoxContainer.new()
	contents.name = "Contents"
	contents.add_theme_constant_override("separation", 8)
	margin.add_child(contents)
	_dialogue_name = Label.new()
	_dialogue_name.name = "Title"
	_dialogue_name.add_theme_font_size_override("font_size", 28)
	contents.add_child(_dialogue_name)
	_dialogue_text = Label.new()
	_dialogue_text.name = "Text"
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_text.add_theme_font_size_override("font_size", 22)
	contents.add_child(_dialogue_text)
	_action_row = HBoxContainer.new()
	_action_row.name = "Actions"
	_action_row.add_theme_constant_override("separation", 8)
	contents.add_child(_action_row)
	var close := Button.new()
	close.name = "Close"
	close.text = "FOREST_CLOSE"
	close.custom_minimum_size = Vector2(200, 48)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(_close_dialogue)
	contents.add_child(close)
	_dialogue.hide()

func _spawn_npcs(zone: Dictionary) -> void:
	for npc in _npcs:
		_actors.remove_child(npc)
		npc.queue_free()
	_npcs.clear()
	var protected: Array[Vector2] = [zone.spawn]
	for source in _zones:
		for portal in source.portals:
			if portal.destination == zone.id:
				protected.append(portal.arrival)
	for data in NPCs.NPCS:
		if data.zone != zone.id:
			continue
		var npc := ForestNPC.new()
		npc.name = data.id
		_actors.add_child(npc)
		npc.setup(data, _player.polygon, zone.portals, protected)
		_npcs.append(npc)

func _nearest_npc() -> Node2D:
	var nearest: Node2D = null
	var best := INTERACTION_DISTANCE
	for npc in _npcs:
		var distance: float = _player.position.distance_to(npc.position)
		if distance <= best:
			best = distance
			nearest = npc
	return nearest

func _interact_nearest() -> void:
	_open_dialogue(_nearest_npc())

func _open_dialogue(npc: Node2D) -> void:
	if npc == null or npc not in _npcs or _player.position.distance_to(npc.position) > INTERACTION_DISTANCE or _player.exit_pending or _player.transition_locked:
		return
	_deselect_remote()
	_close_dialogue()
	_talking_to = npc
	npc.paused = true
	_player.dialogue_locked = true
	_reset_touch()
	_update_dialogue_text()
	_build_npc_actions()
	_dialogue.show()
	_talk_button.hide()
	if str(npc.npc_id).begins_with("quest_"):
		_fetch_quest()

func _build_npc_actions() -> void:
	for child in _action_row.get_children():
		_action_row.remove_child(child)
		child.queue_free()
	if not is_instance_valid(_talking_to):
		return
	if str(_talking_to.npc_id).begins_with("quest_"):
		var state := str(_quest.get("state", ""))
		if state in ["OFFERED", "ACTIVE", "COMPLETED"]:
			var quest_button := Button.new()
			var kind := "accept" if state == "OFFERED" else ("cancel" if state == "ACTIVE" else "claim")
			quest_button.text = "FOREST_QUEST_" + kind.to_upper()
			quest_button.disabled = not _quest_request.is_empty() or (kind == "accept" and not _quest_can_accept)
			if kind == "cancel":
				quest_button.pressed.connect(_confirm_quest_cancel)
			else:
				quest_button.pressed.connect(_quest_submit.bind(kind))
			_action_row.add_child(quest_button)
			MenuArt.button(quest_button)
		return
	var action := ""
	for data in NPCs.NPCS:
		if data.id == _talking_to.npc_id:
			action = data.action_id
			break
	var options := ["guide_inventory", "guide_trade"] if action == "guide" else ([action] if action in ["forge", "lab", "expeditions", "world_gate", "ranked", "woe", "core_defense", "duels_travel"] else [])
	for option in options:
		var button := Button.new()
		button.name = "Action_" + option
		button.text = "FOREST_ACTION_" + str(option).to_upper()
		button.custom_minimum_size = Vector2(160, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(_open_npc_action.bind(option))
		_action_row.add_child(button)
		MenuArt.button(button)

func forest_action_allowed(action: String, zone_id: String, foot: Vector2, facing: int) -> bool:
	if not _dialogue.visible or not is_instance_valid(_talking_to) or _talking_to not in _npcs or _player.exit_pending or _player.transition_locked:
		return false
	if zone_id != str(_zones[_zone_index].id) or foot != _player.position or facing != _player.facing or foot.distance_to(_talking_to.position) > INTERACTION_DISTANCE:
		return false
	for data in NPCs.NPCS:
		if data.id == _talking_to.npc_id and data.zone == zone_id:
			return (data.action_id == "guide" and action in ["guide_inventory", "guide_trade"]) or (data.action_id == action and action in ["forge", "lab", "expeditions", "world_gate", "ranked", "woe", "core_defense", "duels_travel"])
	return false

func _open_npc_action(action: String) -> void:
	if _handoff_pending: return
	if not forest_action_allowed(action, str(_zones[_zone_index].id), _player.position, _player.facing) or not SceneRouter._forest_modes_safe():
		return
	if action == "duels_travel":
		if is_instance_valid(_presence) and _presence.entered:
			if _presence.travel_to_duels(_player.position, _player.facing):
				_close_dialogue()
				_player.exit_pending = true
				_portal_deadline = Time.get_ticks_msec() + 3000
				_reset_touch()
		elif not is_instance_valid(_presence):
			_player.exit_pending = true
			_transition_generation += 1
			_complete_portal.call_deferred(_transition_generation, "central_clearing", "duel_clearing", Vector2(960, 700), "north")
		return
	if action in ["woe", "core_defense"] and ConnectionGate.debug_lab_navigation_allowed():
		SceneRouter.begin_woe_debug(action, str(_zones[_zone_index].id), _player.position, _player.facing)
		return
	if action == "core_defense":
		if _canvas.get_node_or_null("CoreDefenseBrowser") != null: return
		var browser = preload("res://scripts/ui/core_defense_browser.gd").new()
		browser.name = "CoreDefenseBrowser"
		browser.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var half_width := minf(360.0, _canvas.size.x * 0.46)
		var half_height := minf(310.0, _canvas.size.y * 0.46)
		browser.offset_left = -half_width
		browser.offset_right = half_width
		browser.offset_top = -half_height
		browser.offset_bottom = half_height
		_canvas.add_child(browser)
		browser.admitted.connect(_core_defense_admitted)
		return
	if action == "woe":
		if _canvas.get_node_or_null("WOEBrowser") != null: return
		var browser = preload("res://scripts/ui/woe_browser.gd").new()
		browser.name = "WOEBrowser"
		browser.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var half_width := minf(360.0, _canvas.size.x * 0.46)
		var half_height := minf(310.0, _canvas.size.y * 0.46)
		browser.offset_left = -half_width
		browser.offset_right = half_width
		browser.offset_top = -half_height
		browser.offset_bottom = half_height
		_canvas.add_child(browser)
		browser.admitted.connect(_woe_admitted)
		return
	await _prepare_handoff("suspend")
	if not is_inside_tree(): return
	SceneRouter.open_from_forest(action, str(_zones[_zone_index].id), _player.position, _player.facing)
	_resume_if_still_here()


# Invitation consent and membership are checked by the invitation cache.
func forest_invitation_allowed(zone_id: String, foot: Vector2, facing: int) -> bool:
	return is_instance_valid(_player) and not _player.exit_pending and not _player.transition_locked and zone_id == str(_zones[_zone_index].id) and foot == _player.position and facing == _player.facing and not SceneRouter.forest_selected_summoner().is_empty() and SceneRouter._forest_modes_safe()

func invitation_handoff(kind: String, room: Dictionary) -> void:
	if _handoff_pending or not is_instance_valid(_player) or not forest_invitation_allowed(str(_zones[_zone_index].id), _player.position, _player.facing): return
	var identity := WoeClient.identity()
	var context := {"verified_owner":str(ConnectionGate.player_id), "summoner_id":SceneRouter.forest_selected_summoner(), "zone_id":str(_zones[_zone_index].id), "foot_position":_player.position, "facing":_player.facing, "debug":false, "identity_generation":ConnectionGate._generation}
	await _prepare_handoff("suspend")
	if not is_inside_tree(): return
	if identity == WoeClient.identity() and forest_invitation_allowed(str(context.zone_id), context.foot_position, int(context.facing)) and SceneRouter.begin_invited_minigame(kind, room, context):
		MinigameInvitationCache.invitation_navigation_complete(kind, room)
	_resume_if_still_here()

func _woe_admitted(room: Dictionary) -> void:
	if _handoff_pending or not (WoeClient.valid_room(room, str(ConnectionGate.player_id)) or WoeClient.valid_match(room, str(ConnectionGate.player_id))) or not forest_action_allowed("woe", str(_zones[_zone_index].id), _player.position, _player.facing): return
	var identity: String = WoeClient.identity()
	await _prepare_handoff("suspend")
	if not is_inside_tree(): return
	if identity == WoeClient.identity():
		SceneRouter.begin_woe(room, str(_zones[_zone_index].id), _player.position, _player.facing)
	_resume_if_still_here()

func _core_defense_admitted(room: Dictionary) -> void:
	if _handoff_pending or not (CoreDefenseClient.valid_room(room, str(ConnectionGate.player_id)) or CoreDefenseClient.valid_match(room, str(ConnectionGate.player_id))) or not forest_action_allowed("core_defense", str(_zones[_zone_index].id), _player.position, _player.facing): return
	var identity: String = CoreDefenseClient.identity()
	await _prepare_handoff("suspend")
	if not is_inside_tree(): return
	if identity == CoreDefenseClient.identity():
		SceneRouter.begin_core_defense(room, str(_zones[_zone_index].id), _player.position, _player.facing)
	_resume_if_still_here()

func _update_dialogue_text() -> void:
	if is_instance_valid(_talking_to):
		if str(_talking_to.npc_id).begins_with("quest_"):
			_dialogue_name.text = tr("FOREST_QUEST_TITLE")
			var objective := tr("FOREST_QUEST_OBJECTIVE_" + str(_quest.get("objective", "")).to_upper()) % int(_quest.get("target", 0))
			var state := str(_quest.get("state", ""))
			var details := ""
			if state == "OFFERED":
				var elapsed := maxi(0, Time.get_ticks_msec() - _quest_tick)
				var duration := maxi(0, mini(int(_quest.get("available_duration_ms", 0)), int(_quest.get("expires_at", 0)) - _quest_server_time - elapsed))
				details = tr("FOREST_QUEST_" + str(_quest.get("difficulty", "")).to_upper()) + " — " + _quest_format_time(duration) + " — " + tr("FOREST_QUEST_MYSTERY")
				var now := _quest_server_time + elapsed
				if _quest_cooldown > now:
					details += "\n" + (tr("FOREST_QUEST_COOLDOWN") % _quest_format_time(_quest_cooldown - now))
				elif _quest_active is Dictionary:
					details += "\n" + (tr("FOREST_QUEST_ACTIVE_ELSEWHERE") % str(_quest_active.get("zone", "")))
			elif state == "ACTIVE":
				var remaining := maxi(0, int(_quest.get("expires_at", 0)) - (_quest_server_time + Time.get_ticks_msec() - _quest_tick))
				details = "%s/%s — %s" % [int(_quest.get("progress", 0)), int(_quest.get("target", 0)), _quest_format_time(remaining)]
			elif state == "COMPLETED":
				var reward: Dictionary = _quest.get("reward", {})
				for resource in reward:
					details = "%s %s" % [reward[resource], tr("FOREST_QUEST_RESOURCE_" + str(resource).to_upper())]
			_dialogue_text.text = objective + "\n" + details + ("\n" + _quest_error if not _quest_error.is_empty() else "")
			return
		var key: String = str(_talking_to.npc_id).to_upper()
		_dialogue_name.text = tr("FOREST_NPC_%s_NAME" % key)
		_dialogue_text.text = tr("FOREST_NPC_%s_DIALOGUE" % key)

func _quest_format_time(ms: int) -> String:
	var seconds := int(ceil(float(ms) / 1000.0))
	if seconds < 60:
		return tr("FOREST_QUEST_SECONDS") % seconds
	return tr("FOREST_QUEST_HOURS_MINUTES") % [seconds / 3600, (seconds % 3600) / 60]

func _confirm_quest_cancel() -> void:
	var quest_id := str(_quest.get("quest_id", ""))
	var owner := str(ConnectionGate.player_id)
	var generation := int(ConnectionGate._generation)
	var dialog := ConfirmationDialog.new()
	dialog.borderless = true
	dialog.transparent = true
	dialog.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	dialog.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	var panel := _dialogue.get_theme_stylebox("panel").duplicate() as StyleBox
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	dialog.add_theme_stylebox_override("panel", panel)
	dialog.dialog_text = tr("FOREST_QUEST_CANCEL_CONFIRM")
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	MenuArt.button(dialog.get_ok_button())
	MenuArt.button(dialog.get_cancel_button())
	add_child(dialog)
	dialog.confirmed.connect(func():
		if str(_quest.get("quest_id", "")) == quest_id and owner == str(ConnectionGate.player_id) and generation == int(ConnectionGate._generation) and is_instance_valid(_talking_to) and str(_talking_to.npc_id) == str(_quest.get("npc_id", "")):
			_quest_submit("cancel")
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _close_dialogue() -> void:
	if is_instance_valid(_dialogue) and _dialogue.visible and is_instance_valid(_joystick):
		_reset_touch()
	if is_instance_valid(_talking_to):
		_talking_to.paused = false
	_talking_to = null
	if is_instance_valid(_dialogue):
		_dialogue.hide()
	if is_instance_valid(_player):
		_player.dialogue_locked = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_dialogue_text()
		if is_instance_valid(_mask_button):
			_mask_button.tooltip_text = tr("FOREST_CHANGE_SUMMONER")
			_mask_button.accessibility_name = tr("FOREST_CHANGE_SUMMONER")
		if is_instance_valid(_player):
			_refresh_nameplate()

func _unhandled_input(event: InputEvent) -> void:
	if _handoff_pending: return
	if event is InputEventScreenDrag:
		_deselect_remote()
	var clicked: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if clicked and not _dialogue.visible:
		var point: Vector2 = _world.get_global_transform().affine_inverse() * event.position
		_deselect_remote()
		if (SocialClient.enabled or DuelClient.enabled) and SocialClient.available() and is_instance_valid(_presence) and _presence.entered and not _player.transition_locked:
			for id in _remotes:
				var avatar: Node2D = _remotes[id]
				if not bool(avatar.get("busy")) and Rect2(-45, -130, 90, 130).has_point(point - avatar.position):
					_selected_remote = id
					_update_social_remotes()
					get_viewport().set_input_as_handled()
					return
		for npc in _npcs:
			if npc.hit_test(point) and _player.position.distance_to(npc.position) <= INTERACTION_DISTANCE:
				_open_dialogue(npc)
				get_viewport().set_input_as_handled()
				return

func _unhandled_key_input(event: InputEvent) -> void:
	if _handoff_pending: return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] or event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_deselect_remote()
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if event.keycode == KEY_E or event.physical_keycode == KEY_E:
		if _dialogue.visible:
			_close_dialogue()
		else:
			_interact_nearest()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE and _dialogue.visible:
		_close_dialogue()
		get_viewport().set_input_as_handled()
		return
	if not OS.has_feature("editor"):
		return
	if event.keycode == KEY_F9 and ConnectionGate.debug_lab_navigation_allowed() and (not is_instance_valid(_presence) or _presence.socket == null):
		_transition_generation += 1
		_player.exit_pending = false
		_player.transition_locked = false
		_reset_touch()
		_set_zone((_zone_index + 1) % _zones.size())
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F10:
		_show_geometry = not _show_geometry
		_refresh_debug()
		get_viewport().set_input_as_handled()

func _refresh_debug() -> void:
	_polygon_fill.visible = _show_geometry and OS.has_feature("editor")
	_polygon_line.visible = _polygon_fill.visible
	_portal_debug.visible = _polygon_fill.visible
	_player.show_debug = _polygon_fill.visible
	_debug_label.visible = _polygon_fill.visible
	_debug_label.text = "%s  |  F9: zone  F10: geometry" % _zones[_zone_index].id


func _start_presence(selected: String) -> void:
	if not _catalog_valid or ConnectionGate.debug_lab_navigation_allowed():
		return
	_presence = Presence.new()
	# Continue checking identity while ConnectionGate temporarily disables a scene.
	_presence.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_presence)
	_presence.snapshot.connect(_on_presence_snapshot)
	_presence.correction.connect(_on_presence_correction)
	_presence.peer_joined.connect(_on_peer_joined)
	_presence.peer_busy.connect(_on_peer_busy)
	_presence.peer_moved.connect(_on_peer_moved)
	_presence.peer_cosmetic.connect(_on_peer_cosmetic)
	_presence.peer_left.connect(_on_peer_left)
	_presence.peer_chat.connect(_on_peer_chat)
	_presence.disconnected.connect(_clear_remotes)
	_presence.disconnected.connect(_clear_quest)
	_presence.configure(_zones, selected)

func _on_presence_snapshot(state: Dictionary, peers: Array) -> void:
	var target := _zone_index_for_id(str(state.zone_id))
	if not _set_zone(target, Vector2(state.x, state.y)):
		_presence._drop()
		return
	_clear_remotes()
	_player.facing = int(state.facing)
	if state.has("display_name"):
		_player.set_display_name(state.display_name)
	_player.exit_pending = false
	_portal_deadline = 0
	_reset_touch()
	_player.transition_locked = true
	_transition_until = Time.get_ticks_msec() + PORTAL_LOCK_MS
	for peer in peers:
		_on_peer_joined(peer)
	_fetch_quest()

func _on_presence_correction(state: Dictionary) -> void:
	_deselect_remote()
	if str(_zones[_zone_index].id) != str(state.zone_id) and not _set_zone(_zone_index_for_id(str(state.zone_id)), Vector2(state.x, state.y)):
		_presence._drop()
		return
	_player.position = Vector2(state.x, state.y)
	_player.facing = int(state.facing)
	_player.exit_pending = false
	_portal_deadline = 0
	_reset_touch()
	_player.transition_locked = true
	_transition_until = Time.get_ticks_msec() + PORTAL_LOCK_MS

func _on_peer_joined(data: Dictionary) -> void:
	var id: String = data.player_id
	if _remotes.has(id) or id == ConnectionGate.player_id:
		return
	var avatar := Remote.new()
	_actors.add_child(avatar)
	avatar.setup(data)
	_remotes[id] = avatar
	_update_social_remotes()

func _on_peer_busy(data: Dictionary) -> void:
	var id := str(data.player_id)
	if not _remotes.has(id): return
	if bool(data.busy) and _selected_remote == id: _deselect_remote()
	var avatar = _remotes[id]
	avatar.set_busy(data)
	if bool(data.busy):
		var bubble = avatar.get_node_or_null("SpeechBubble")
		if bubble != null: bubble.clear_message()
	_update_social_remotes()

func _on_peer_moved(id: String, sequence: int, point: Vector2, direction: int) -> void:
	if _remotes.has(id): _remotes[id].move_to(sequence, point, direction)

func _on_peer_cosmetic(id: String, cosmetic: String) -> void:
	if _remotes.has(id): _remotes[id].set_cosmetic(cosmetic)

func _on_peer_chat(id: String, message_id: int, message: String, created_at: int, expires_at: int, server_now: int) -> void:
	var avatar: Node = _player if id == str(ConnectionGate.player_id) else _remotes.get(id)
	if not is_instance_valid(avatar): return
	var bubble = avatar.get_node_or_null("SpeechBubble")
	if bubble == null:
		bubble = preload("res://scripts/forest/forest_speech_bubble.gd").new()
		avatar.add_child(bubble)
	bubble.show_message(message_id, message, created_at, expires_at, server_now)

func _on_peer_left(id: String) -> void:
	if _selected_remote == id: _deselect_remote()
	if _remotes.has(id):
		var avatar: Node = _remotes[id]
		_remotes.erase(id)
		_actors.remove_child(avatar)
		avatar.queue_free()

func _clear_remotes() -> void:
	_deselect_remote()
	if is_instance_valid(_player):
		var bubble = _player.get_node_or_null("SpeechBubble")
		if bubble != null: bubble.clear_message()
	for avatar in _remotes.values():
		if is_instance_valid(avatar):
			if avatar.get_parent() != null: avatar.get_parent().remove_child(avatar)
			avatar.queue_free()
	_remotes.clear()
	if _portal_deadline > 0 and is_instance_valid(_joystick) and is_instance_valid(_player):
		_reset_touch()
	_portal_deadline = 0
	if is_instance_valid(_player): _player.exit_pending = false

func _deselect_remote() -> void:
	if not _selected_remote.is_empty() and _remotes.has(_selected_remote) and is_instance_valid(_remotes[_selected_remote]):
		_remotes[_selected_remote].set_friend_action("", Callable())
		_remotes[_selected_remote].set_duel_action(false)
	_selected_remote = ""

func _update_social_remotes() -> void:
	for id in _remotes:
		var avatar = _remotes[id]
		if not is_instance_valid(avatar): continue
		var is_friend: bool = SocialClient.enabled and SocialClient.friends.has(id)
		avatar.set_friend_marker(is_friend)
		if avatar.busy:
			avatar.set_friend_action("", Callable())
			avatar.set_duel_action(false)
			continue
		if id != _selected_remote: continue
		var pending_duel := not DuelClient.outgoing.is_empty() or not DuelClient.incoming.is_empty() or not DuelClient.accepted_invites.is_empty()
		avatar.set_duel_action(DuelClient.enabled, DuelClient.request_duel.bind(id), DuelClient.cooldown_seconds(id), pending_duel)
		if not SocialClient.enabled or is_friend:
			avatar.set_friend_action("", Callable())
			continue
		var incoming: Dictionary = SocialClient.incoming_for(id)
		var outgoing: Dictionary = SocialClient.outgoing_for(id)
		if not incoming.is_empty():
			avatar.set_friend_action("review", SocialClient._popup.open_request.bind(str(incoming.request_id)))
		elif not outgoing.is_empty():
			avatar.set_friend_action("pending", Callable(), SocialClient.cooldown_seconds(id))
		else:
			avatar.set_friend_action("add", SocialClient.request_friend.bind(id), SocialClient.cooldown_seconds(id))

func _on_duel_recover(invite_id: String, match_id: String) -> void:
	if _handoff_pending or not is_instance_valid(_presence) or not _presence.entered or not SceneRouter._forest_modes_safe():
		DuelClient._reported_match = ""
		return
	var owner := str(ConnectionGate.player_id)
	var generation: int = ConnectionGate._generation
	_handoff_pending = true
	_reset_touch()
	_player.set_process(false)
	var acknowledged: bool = await _presence.handoff("suspend")
	if not is_inside_tree(): return
	if acknowledged and owner == str(ConnectionGate.player_id) and generation == ConnectionGate._generation and invite_id == DuelClient._tracked_invite:
		var invitation := {"invite_id":invite_id, "status":"ACCEPTED", "challenger_id":owner, "recipient_id":"", "expires_at":0}
		SceneRouter.begin_friendly_preparation(invitation, str(_zones[_zone_index].id), _player.position, _player.facing, match_id)
	if get_tree().current_scene == self: DuelClient._reported_match = ""
	_resume_if_still_here()

func _on_duel_accepted(invite: Dictionary) -> void:
	if _handoff_pending or not is_instance_valid(_presence) or not _presence.entered or not SceneRouter._forest_modes_safe(): return
	if _dialogue.visible or _player.exit_pending or _player.transition_locked: return
	var owner := str(ConnectionGate.player_id)
	var generation: int = ConnectionGate._generation
	var invite_id := str(invite.get("invite_id", ""))
	_handoff_pending = true
	_reset_touch()
	_player.set_process(false)
	var acknowledged: bool = await _presence.handoff("suspend")
	if not is_inside_tree(): return
	if acknowledged and owner == str(ConnectionGate.player_id) and generation == ConnectionGate._generation and not DuelClient.accepted_invites.is_empty() and str(DuelClient.accepted_invites[0].get("invite_id", "")) == invite_id and int(invite.get("expires_at", 0)) > DuelClient.server_now():
		SceneRouter.begin_friendly_preparation(invite, str(_zones[_zone_index].id), _player.position, _player.facing)
	_resume_if_still_here()

func spectator_handoff(context: Dictionary) -> void:
	if _handoff_pending or not is_instance_valid(_presence) or not _presence.entered or not SceneRouter._forest_modes_safe(): return
	var owner := str(ConnectionGate.player_id)
	var generation := int(ConnectionGate._generation)
	_handoff_pending = true
	_reset_touch()
	_player.set_process(false)
	var acknowledged: bool = await _presence.handoff("suspend")
	if not is_inside_tree(): return
	if acknowledged and owner == str(ConnectionGate.player_id) and generation == int(ConnectionGate._generation):
		SceneRouter._forest_return = {"verified_owner":owner, "summoner_id":SceneRouter.forest_selected_summoner(), "zone_id":str(_zones[_zone_index].id), "foot_position":_player.position, "facing":_player.facing, "debug":false, "identity_generation":generation}
		SceneRouter.begin_spectating(context)
		if SceneRouter._spectator_context.is_empty(): SceneRouter._clear_forest_return()
	_resume_if_still_here()

func _prepare_handoff(kind: String) -> void:
	if _handoff_pending: return
	_handoff_pending = true
	_reset_touch()
	_player.set_process(false)
	if is_instance_valid(_presence):
		await _presence.handoff(kind)

func _resume_if_still_here() -> void:
	if is_inside_tree() and get_tree().current_scene == self:
		_handoff_pending = false
		_player.set_process(true)
		if is_instance_valid(_presence):
			_presence.shutdown()
			_presence.queue_free()
			_presence = null
		_start_presence(SceneRouter.forest_selected_summoner())

func _leave_forest() -> void:
	if _handoff_pending: return
	await _prepare_handoff("leave")
	if not is_inside_tree(): return
	SceneRouter.leave_forest()
	_resume_if_still_here()

func _exit_tree() -> void:
	_resource_catalog.free()
	if is_instance_valid(_presence): _presence.shutdown()

func _fetch_quest() -> void:
	if is_instance_valid(_name_backend) and _quest_request_client_generation != _name_backend._session_generation:
		_quest_request = ""
		_quest_pending_request_key = ""
	if not is_inside_tree() or not is_instance_valid(_name_backend) or not is_instance_valid(_presence) or not _presence.entered or not _name_session_matches() or not _quest_request.is_empty():
		return
	_sync_quest_pending_identity()
	_quest_zone = str(_zones[_zone_index].id)
	_quest_owner = str(ConnectionGate.player_id)
	_quest_generation = int(ConnectionGate._generation)
	_quest_request_zone_generation = _quest_zone_generation
	_quest_request_kind = "get"
	_quest_request_client_generation = _name_backend._session_generation
	_quest_request = _name_backend.request_api("GET", "/forest/quests", null)
	if is_instance_valid(_talking_to):
		_build_npc_actions()

func _sync_quest_pending_identity() -> void:
	if not is_instance_valid(_name_backend):
		_quest_pending_actions.clear()
		return
	if str(ConnectionGate.player_id).is_empty():
		return
	for key in _quest_pending_actions.keys():
		var pending: Dictionary = _quest_pending_actions[key]
		if str(pending.owner) != str(ConnectionGate.player_id) or str(pending.server) != str(_name_backend.base_url):
			_quest_pending_actions.erase(key)

func _clear_quest() -> void:
	_quest = {}
	_quest_active = null
	_quest_can_accept = false
	_quest_cooldown = 0
	_quest_error = ""
	_quest_zone_generation += 1
	if is_instance_valid(_quest_timer):
		_quest_timer.stop()
	for npc in _npcs.duplicate():
		if str(npc.npc_id).begins_with("quest_"):
			if npc == _talking_to:
				_close_dialogue()
			_npcs.erase(npc)
			npc.queue_free()

func _quest_submit(kind: String) -> void:
	var expected := {"accept":"OFFERED", "cancel":"ACTIVE", "claim":"COMPLETED"}
	if not _quest_request.is_empty() or not expected.has(kind) or str(_quest.get("state", "")) != expected[kind]:
		return
	_sync_quest_pending_identity()
	var quest_id := str(_quest.quest_id)
	var key := JSON.stringify([kind, quest_id, str(ConnectionGate.player_id), str(_name_backend.base_url)])
	if not _quest_pending_actions.has(key):
		_quest_pending_actions[key] = {"kind":kind, "quest_id":quest_id, "action_id":_name_backend._make_uuid(), "owner":str(ConnectionGate.player_id), "server":str(_name_backend.base_url)}
	var pending: Dictionary = _quest_pending_actions[key]
	_quest_zone = str(_zones[_zone_index].id)
	_quest_owner = str(ConnectionGate.player_id)
	_quest_generation = int(ConnectionGate._generation)
	_quest_request_zone_generation = _quest_zone_generation
	_quest_request_kind = kind
	_quest_request_client_generation = _name_backend._session_generation
	_quest_pending_request_key = key
	_quest_request = _name_backend.request_api("POST", "/forest/quests/" + str(pending.kind), {"quest_id":pending.quest_id, "client_action_id":pending.action_id})
	_build_npc_actions()

func _on_quest_response(request_id: String, ok: bool, data: Dictionary) -> void:
	if request_id != _quest_request or _quest_request.is_empty():
		return
	var kind := _quest_request_kind
	_quest_request = ""
	if kind != "get":
		var error := str(data.get("error", ""))
		var status := int(data.get("http_status", 0))
		var uncertain := not ok and (error in ["network_error", "bad_json"] or status == 408 or status >= 500)
		if not uncertain:
			_quest_pending_actions.erase(_quest_pending_request_key)
		_quest_pending_request_key = ""
	_sync_quest_pending_identity()
	if _quest_owner != str(ConnectionGate.player_id) or _quest_generation != int(ConnectionGate._generation) or _quest_request_zone_generation != _quest_zone_generation or _quest_zone != str(_zones[_zone_index].id):
		_fetch_quest()
		return
	if not ok:
		var error := str(data.get("error", ""))
		if error in ["QUEST_ACTIVE_EXISTS", "QUEST_CANCEL_COOLDOWN", "QUEST_UNAVAILABLE"]:
			_quest_error = tr("FOREST_" + error)
			_fetch_quest()
		if str(data.get("error", "")) == "QUEST_STORAGE_FULL" and is_instance_valid(_dialogue_text):
			_dialogue_text.text = tr("FOREST_QUEST_STORAGE_FULL")
		_build_npc_actions()
		return
	if kind != "get":
		_quest_error = ""
		if kind == "claim":
			_name_backend.refresh_state()
		_fetch_quest()
		return
	_quest_server_time = int(data.get("server_time_unix_ms", 0))
	_quest_tick = Time.get_ticks_msec()
	_quest_active = data.get("active_quest")
	_quest_can_accept = bool(data.get("can_accept", false))
	_quest_cooldown = int(data.get("cooldown_until", 0))
	var value = data.get("quest")
	_quest = value if value is Dictionary else {}
	for npc in _npcs.duplicate():
		if str(npc.npc_id).begins_with("quest_") and (not _quest.has("npc_id") or npc.npc_id != _quest.npc_id):
			if npc == _talking_to:
				_close_dialogue()
			_npcs.erase(npc)
			npc.queue_free()
	if not _quest.is_empty() and not _npcs.any(func(n): return n.npc_id == _quest.npc_id):
		for data_npc in _quest_catalog:
			if str(data_npc.id) == str(_quest.npc_id) and str(data_npc.zone) == _quest_zone:
				var npc_data: Dictionary = data_npc.duplicate()
				npc_data.position = Vector2(data_npc.position[0], data_npc.position[1])
				npc_data.stationary = true
				var npc := ForestNPC.new()
				npc.name = data_npc.id
				_actors.add_child(npc)
				var protected: Array[Vector2] = []
				npc.setup(npc_data, _player.polygon, _zones[_zone_index].portals, protected)
				_npcs.append(npc)
				break
	if is_instance_valid(_talking_to) and str(_talking_to.npc_id).begins_with("quest_"):
		_update_dialogue_text()
		_build_npc_actions()
	var next_day := (int(_quest_server_time / 86400000) + 1) * 86400000
	var deadlines: Array = [next_day, _quest_cooldown]
	if _quest_active is Dictionary:
		deadlines.append(int(_quest_active.get("expires_at", 0)))
	if str(_quest.get("state", "")) == "COMPLETED":
		deadlines.append(int(_quest.get("completed_at", 0)) + 86400000)
	for deadline in deadlines:
		if int(deadline) > _quest_server_time:
			next_day = mini(next_day, int(deadline))
	_quest_timer.start(maxf(0.1, float(next_day - _quest_server_time) / 1000.0 + 0.1))
