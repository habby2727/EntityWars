extends Node2D

const Catalog := preload("res://scripts/forest/forest_npcs.gd")
static var _texture_cache := {}
var npc_id := ""
var paused := false
var stationary := false
var moving := false
var moving_left := false
var polygon := PackedVector2Array()
var safe_points: Array[Vector2] = []
var corridors: Array = []
var _textures: Array[Texture2D] = []
var _bounds: Array[Rect2i] = []
var _scale := 1.0
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _speed := 0.0
var _wait := 0.0
var _bob := 0.0
var _rng := RandomNumberGenerator.new()
var _interaction_hint: PanelContainer

func setup(data: Dictionary, area: PackedVector2Array, portals: Array, protected: Array[Vector2]) -> void:
	npc_id = data.id
	stationary = bool(data.get("stationary", false))
	position = data.position
	_home = position
	polygon = area
	corridors = portals
	safe_points = protected
	_rng.randomize()
	_wait = _rng.randf_range(18.0, 24.0)
	var max_height := 0
	for file in [data.front, data.side]:
		var path := Catalog.DIR + str(file)
		if not _texture_cache.has(path):
			var texture := load(path) as Texture2D
			_texture_cache[path] = [texture, texture.get_image().get_used_rect()]
		var cached: Array = _texture_cache[path]
		_textures.append(cached[0])
		_bounds.append(cached[1])
		max_height = maxi(max_height, cached[1].size.y)
	_scale = 75.0 / maxf(1.0, max_height)
	_interaction_hint = PanelContainer.new()
	_interaction_hint.name = "InteractionHint"
	_interaction_hint.position = Vector2(-43, -120)
	_interaction_hint.size = Vector2(86, 30)
	_interaction_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.09, 0.08, 0.95)
	style.border_color = Color("bba66b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_interaction_hint.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "Press E"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_hint.add_child(label)
	add_child(_interaction_hint)
	_interaction_hint.hide()
	if npc_id == "war_of_entities":
		var nameplate := Label.new()
		nameplate.name = "Nameplate"
		nameplate.text = "War of Entities"
		nameplate.position = Vector2(-110, -155)
		nameplate.size = Vector2(220, 30)
		nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nameplate.add_theme_font_size_override("font_size", 20)
		add_child(nameplate)
	elif stationary:
		var marker := Label.new()
		marker.text = "!"
		marker.position = Vector2(-8, -118)
		marker.add_theme_color_override("font_color", Color("ffd86b"))
		marker.add_theme_font_size_override("font_size", 28)
		add_child(marker)

func show_interaction_hint(show_hint: bool) -> void:
	if is_instance_valid(_interaction_hint):
		_interaction_hint.visible = show_hint

func _process(delta: float) -> void:
	_bob += delta
	if not paused and not stationary:
		if moving:
			position.x = move_toward(position.x, _target.x, _speed * delta)
			if is_equal_approx(position.x, _target.x):
				moving = false
				_wait = _rng.randf_range(18.0, 24.0)
		else:
			_wait -= delta
			if _wait <= 0.0:
				_start_patrol()
	queue_redraw()

func _start_patrol() -> void:
	# Keep the patrol close to its initial position; try either direction.
	var distance := _rng.randf_range(30.0, 60.0)
	var sign_value := 1.0 if _rng.randi_range(0, 1) == 0 else -1.0
	for sign_try in [sign_value, -sign_value]:
		var destination := position + Vector2(sign_try * distance, 0)
		if absf(destination.x - _home.x) > 60.0:
			continue
		if _safe_path(position, destination):
			_target = destination
			moving_left = _target.x < position.x
			moving = not is_equal_approx(_target.x, position.x)
			if moving:
				_speed = absf(_target.x - position.x) / _rng.randf_range(1.0, 2.0)
				return
	_wait = _rng.randf_range(18.0, 24.0)

func _safe_path(start: Vector2, finish: Vector2) -> bool:
	var steps := maxi(1, ceili(start.distance_to(finish) / 3.0))
	for i in range(steps + 1):
		var point := start.lerp(finish, float(i) / steps)
		if not Geometry2D.is_point_in_polygon(point, polygon):
			return false
		for safe in safe_points:
			if point.distance_to(safe) < 150.0:
				return false
		for portal in corridors:
			var rect: Array = portal.corridor
			if Rect2(Vector2(rect[0], rect[1]), Vector2(rect[2]-rect[0], rect[3]-rect[1])).grow(40).has_point(point):
				return false
	return true

func hit_test(point: Vector2) -> bool:
	return Rect2(position + Vector2(-55, -105), Vector2(110, 125)).has_point(point)

func _draw() -> void:
	if _textures.is_empty():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 20.0, Color(0.01, 0.02, 0.02, 0.35))
	draw_set_transform(Vector2.ZERO)
	var index := 1 if moving and not paused else 0
	var used := _bounds[index]
	var xscale := -_scale if index == 1 and moving_left else _scale
	draw_set_transform(Vector2(0, -4.0 + sin(_bob * 2.8) * 1.5), 0.0, Vector2(xscale, _scale))
	draw_texture(_textures[index], Vector2(-used.get_center().x, -used.end.y))
	draw_set_transform(Vector2.ZERO)
