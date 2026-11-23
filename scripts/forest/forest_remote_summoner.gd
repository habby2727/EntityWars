extends Node2D

const ForestPlayer := preload("res://scripts/forest/forest_player.gd")
static var _assets := {}
var facing := 0
var _textures: Array = []
var _bounds: Array = []
var _scale := 1.0
var _bob := 0.0
var _from := Vector2.ZERO
var _target := Vector2.ZERO
var _elapsed := 0.2
var last_seq := -1
var _label: Label

func setup(data: Dictionary) -> void:
	_label = Label.new()
	_label.name = "Nameplate"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("outline_size", 4)
	_label.text = data.display_name
	add_child(_label)
	set_cosmetic(data.summoner_id)
	position = Vector2(data.x, data.y)
	_from = position
	_target = position
	facing = int(data.facing)

func set_cosmetic(id: String) -> void:
	if id not in ForestPlayer.FILES:
		return
	if not _assets.has(id):
		var textures: Array = []
		var bounds: Array = []
		var height := 0
		for filename in ForestPlayer.FILES[id]:
			var texture := load(ForestPlayer.SUMMONER_DIR + filename) as Texture2D
			if texture == null:
				return
			var rect := texture.get_image().get_used_rect()
			textures.append(texture)
			bounds.append(rect)
			height = maxi(height, rect.size.y)
		_assets[id] = {"textures": textures, "bounds": bounds, "height": height}
	_textures = _assets[id].textures
	_bounds = _assets[id].bounds
	_scale = 120.0 / maxf(1.0, float(_assets[id].height))
	_label.position = Vector2(-150, -float(_assets[id].height) * _scale - 44)
	_label.size = Vector2(300, 30)
	queue_redraw()

func move_to(seq: int, point: Vector2, direction: int) -> void:
	if seq <= last_seq:
		return
	last_seq = seq
	_from = position
	_target = point
	_elapsed = 0.0
	facing = direction

func _process(delta: float) -> void:
	_bob += delta
	_elapsed = minf(_elapsed + delta, 0.2)
	position = _from.lerp(_target, _elapsed / 0.2)
	queue_redraw()

func _draw() -> void:
	if _textures.is_empty():
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 27.0, Color(0.01, 0.02, 0.02, 0.35))
	draw_set_transform(Vector2.ZERO)
	var index := 1 if facing == 3 else facing
	var used: Rect2i = _bounds[index]
	var direction_scale := Vector2(-_scale if facing == 3 else _scale, _scale)
	draw_set_transform(Vector2(0, -5.0 + sin(_bob * 2.8) * 2.0), 0.0, direction_scale)
	draw_texture(_textures[index], Vector2(-used.get_center().x, -used.end.y))
	draw_set_transform(Vector2.ZERO)
