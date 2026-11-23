extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Zones := preload("res://scripts/forest/forest_zones.gd")
const ForestPlayer := preload("res://scripts/forest/forest_player.gd")
const Joystick := preload("res://scripts/forest/forest_touch_joystick.gd")
const REFERENCE_SIZE := Vector2(1920, 1080)

var _canvas: Control
var _world: Node2D
var _background: Sprite2D
var _player: Node2D
var _joystick: Control
var _polygon_fill: Polygon2D
var _polygon_line: Line2D
var _debug_label: Label
var _zone_index := 0
var _show_geometry := false

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
	_player = ForestPlayer.new()
	_player.name = "Summoner"
	_world.add_child(_player)
	_player.setup(selected)
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

func _set_zone(index: int) -> void:
	_zone_index = index
	var zone: Dictionary = Zones.ZONES[index]
	_background.texture = load(Zones.BACKGROUND_DIR + zone.image)
	var polygon := PackedVector2Array(zone.polygon)
	_polygon_fill.polygon = polygon
	_polygon_line.points = polygon
	_player.polygon = polygon
	_player.position = zone.spawn
	_player.blocked_visible = false
	_refresh_debug()

func _process(_delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_joystick):
		_player.joystick_vector = _joystick.vector

func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.has_feature("editor") or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F9:
		_set_zone((_zone_index + 1) % Zones.ZONES.size())
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F10:
		_show_geometry = not _show_geometry
		_refresh_debug()
		get_viewport().set_input_as_handled()

func _refresh_debug() -> void:
	_polygon_fill.visible = _show_geometry and OS.has_feature("editor")
	_polygon_line.visible = _polygon_fill.visible
	_player.show_debug = _polygon_fill.visible
	_debug_label.visible = _polygon_fill.visible
	_debug_label.text = "%s  |  F9: zone  F10: geometry" % Zones.ZONES[_zone_index].id
