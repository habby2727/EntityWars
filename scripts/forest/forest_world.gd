extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Zones := preload("res://scripts/forest/forest_zones.gd")
const ForestPlayer := preload("res://scripts/forest/forest_player.gd")
const Joystick := preload("res://scripts/forest/forest_touch_joystick.gd")
const REFERENCE_SIZE := Vector2(1920, 1080)
const PORTAL_LOCK_MS := 350

var _canvas: Control
var _world: Node2D
var _background: Sprite2D
var _player: Node2D
var _joystick: Control
var _polygon_fill: Polygon2D
var _polygon_line: Line2D
var _portal_debug: Node2D
var _debug_label: Label
var _zone_index := 0
var _show_geometry := false
var _transition_until := 0
var _transition_generation := 0

func _ready() -> void:
	var selected := SceneRouter.forest_selected_summoner()
	if selected not in ForestPlayer.FILES:
		SceneRouter.go_to_lab_hub.call_deferred()
		return
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	add_child(aspect)
	_canvas = Control.new()
	_canvas.name = "Canvas"
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
	_player = ForestPlayer.new()
	_player.name = "Summoner"
	_world.add_child(_player)
	_player.setup(selected)
	_player.exit_attempt.connect(_on_exit_attempt)
	var leave := Button.new()
	leave.name = "LeaveButton"
	leave.text = "FOREST_LEAVE"
	leave.anchor_left = 0.02
	leave.anchor_top = 0.025
	leave.anchor_right = 0.20
	leave.anchor_bottom = 0.09
	leave.add_theme_font_size_override("font_size", 24)
	leave.pressed.connect(SceneRouter.leave_forest)
	_canvas.add_child(leave)
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
	UIThemeFactory.apply_theme_to(self)
	MenuArt.button(leave)
	_set_zone(0)
	_resize_world()

func _resize_world() -> void:
	if is_instance_valid(_world):
		_world.scale = _canvas.size / REFERENCE_SIZE

func _zone_index_for_id(zone_id: String) -> int:
	var found := -1
	for i in Zones.ZONES.size():
		if str(Zones.ZONES[i].get("id", "")) == zone_id:
			if found != -1:
				return -1
			found = i
	return found

func _set_zone(index: int, arrival: Vector2 = Vector2.INF) -> bool:
	if index < 0 or index >= Zones.ZONES.size():
		return false
	var zone: Dictionary = Zones.ZONES[index]
	var polygon := PackedVector2Array(zone.get("polygon", []))
	var spawn: Vector2 = zone.get("spawn", Vector2.INF) if arrival == Vector2.INF else arrival
	var path := Zones.BACKGROUND_DIR + str(zone.get("image", ""))
	if polygon.size() < 3 or not spawn.is_finite() or not Geometry2D.is_point_in_polygon(spawn, polygon) or not ResourceLoader.exists(path):
		return false
	var texture := load(path) as Texture2D
	if texture == null:
		return false
	_zone_index = index
	_background.texture = texture
	_polygon_fill.polygon = polygon
	_polygon_line.points = polygon
	_player.polygon = polygon
	_player.position = spawn
	_player.blocked_visible = false
	_build_portal_debug(zone)
	_refresh_debug()
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
	if _player.exit_pending or _player.transition_locked or _zone_index < 0 or _zone_index >= Zones.ZONES.size():
		return
	var zone: Dictionary = Zones.ZONES[_zone_index]
	var source_id := str(zone.get("id", ""))
	if _zone_index_for_id(source_id) != _zone_index or foot.distance_to(_player.position) > 0.01 or not Geometry2D.is_point_in_polygon(foot, _player.polygon):
		return
	var valid_crossing := false
	match direction:
		"north": valid_crossing = candidate.y <= 0.0 and candidate.y < foot.y and absf(candidate.x - foot.x) < 0.0001
		"south": valid_crossing = candidate.y >= REFERENCE_SIZE.y and candidate.y > foot.y and absf(candidate.x - foot.x) < 0.0001
		"west": valid_crossing = candidate.x <= 0.0 and candidate.x < foot.x and absf(candidate.y - foot.y) < 0.0001
		"east": valid_crossing = candidate.x >= REFERENCE_SIZE.x and candidate.x > foot.x and absf(candidate.y - foot.y) < 0.0001
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
		var target_zone: Dictionary = Zones.ZONES[target]
		var target_polygon := PackedVector2Array(target_zone.get("polygon", []))
		if not arrival.is_finite() or target_polygon.size() < 3 or not Geometry2D.is_point_in_polygon(arrival, target_polygon) or not ResourceLoader.exists(Zones.BACKGROUND_DIR + str(target_zone.get("image", ""))):
			return
		_player.exit_pending = true
		_transition_generation += 1
		_complete_portal.call_deferred(_transition_generation, source_id, destination_id, arrival, direction)
		return

func _complete_portal(generation: int, source_id: String, destination_id: String, arrival: Vector2, direction: String) -> void:
	if generation != _transition_generation or not _player.exit_pending or str(Zones.ZONES[_zone_index].get("id", "")) != source_id:
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
	if is_instance_valid(_player) and is_instance_valid(_joystick):
		if _player.transition_locked and Time.get_ticks_msec() >= _transition_until:
			_player.transition_locked = false
		_player.joystick_vector = _joystick.vector

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.has_feature("editor") or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F9:
		_transition_generation += 1
		_player.exit_pending = false
		_player.transition_locked = false
		_reset_touch()
		_set_zone((_zone_index + 1) % Zones.ZONES.size())
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
	_debug_label.text = "%s  |  F9: zone  F10: geometry" % Zones.ZONES[_zone_index].id
