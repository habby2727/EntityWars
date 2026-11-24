extends Node2D

const ForestPlayer := preload("res://scripts/forest/forest_player.gd")
static var _assets := {}
var facing := 0
var busy := false
var _busy_icon: Control
var _textures: Array = []
var _bounds: Array = []
var _scale := 1.0
var _bob := 0.0
var _from := Vector2.ZERO
var _target := Vector2.ZERO
var _elapsed := 0.2
var last_seq := -1
var _label: Label
var _friend_glyph: Control
var _friend_action: Button
var _duel_action: Button
var _friend_mode := ""
var _friend_callback := Callable()

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
	set_busy(data)

func set_busy(data: Dictionary) -> void:
	busy = bool(data.get("busy", false))
	position = Vector2(data.x, data.y)
	_from = position
	_target = position
	_elapsed = 0.2
	last_seq = -1
	facing = int(data.facing)
	_label.text = str(data.display_name)
	set_cosmetic(str(data.summoner_id))
	if not is_instance_valid(_busy_icon):
		_busy_icon = Control.new()
		_busy_icon.name = "BusyIndicator"
		_busy_icon.size = Vector2(26, 26)
		_busy_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		_busy_icon.tooltip_text = tr("FOREST_FIGHTING")
		add_child(_busy_icon)
		var glyph: Control = preload("res://scripts/ui/duel_swords.gd").new()
		glyph.size = _busy_icon.size
		_busy_icon.add_child(glyph)
	_busy_icon.visible = busy
	if busy:
		set_friend_action("", Callable())
		set_duel_action(false)

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
	if busy or seq <= last_seq:
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
	if is_instance_valid(_busy_icon):
		_busy_icon.position = Vector2(-13, _label.position.y - 29 + sin(_bob * TAU / 1.5) * 2.0)
	queue_redraw()

func set_friend_marker(value: bool) -> void:
	if value and not is_instance_valid(_friend_glyph):
		_friend_glyph = preload("res://scripts/ui/social_glyph.gd").new()
		_friend_glyph.size = Vector2(20, 20)
		add_child(_friend_glyph)
	if is_instance_valid(_friend_glyph):
		_friend_glyph.visible = value
		var width := minf(_label.size.x, _label.get_theme_font("font").get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x)
		_friend_glyph.position = Vector2(-width * 0.5 - 23, _label.position.y + 5)

func set_friend_action(mode: String, callback: Callable, cooldown_seconds: int = 0) -> void:
	if busy: mode = ""
	if is_instance_valid(_friend_action) and mode == _friend_mode:
		if callback != _friend_callback:
			if _friend_callback.is_valid() and _friend_action.pressed.is_connected(_friend_callback): _friend_action.pressed.disconnect(_friend_callback)
			_friend_callback = callback
			if callback.is_valid(): _friend_action.pressed.connect(callback)
		_friend_action.disabled = mode == "pending" or cooldown_seconds > 0 or SocialClient._mutation_busy or not SocialClient._pending_body.is_empty()
		_friend_action.tooltip_text = tr("SOCIAL_COOLDOWN_SECONDS") % cooldown_seconds if cooldown_seconds > 0 else tr("SOCIAL_ADD" if mode == "add" else "SOCIAL_REVIEW")
		return
	_friend_mode = mode
	_friend_callback = callback
	if is_instance_valid(_friend_action):
		_friend_action.queue_free()
		_friend_action = null
	if mode.is_empty():
		return
	_friend_action = Button.new()
	_friend_action.name = "FriendAction"
	_friend_action.position = Vector2(-78, _label.position.y - 78)
	_friend_action.size = Vector2(72, 72)
	_friend_action.custom_minimum_size = Vector2(72, 72)
	_friend_action.focus_mode = Control.FOCUS_NONE
	_friend_action.tooltip_text = tr("SOCIAL_ADD" if mode == "add" else ("SOCIAL_CANCEL" if mode == "pending" else "SOCIAL_REVIEW"))
	_friend_action.disabled = mode == "pending" or cooldown_seconds > 0 or SocialClient._mutation_busy or not SocialClient._pending_body.is_empty()
	if cooldown_seconds > 0: _friend_action.tooltip_text = tr("SOCIAL_COOLDOWN_SECONDS") % cooldown_seconds
	if callback.is_valid(): _friend_action.pressed.connect(callback)
	add_child(_friend_action)
	if mode == "add":
		var glyph: Control = preload("res://scripts/ui/social_glyph.gd").new()
		glyph.plus = true
		glyph.position = Vector2(22, 22)
		glyph.size = Vector2(28, 28)
		_friend_action.add_child(glyph)
	else:
		_friend_action.text = tr("SOCIAL_PENDING" if mode == "pending" else "SOCIAL_REVIEW")
		_friend_action.add_theme_font_size_override("font_size", 13)

func set_duel_action(show_action: bool, callback: Callable = Callable(), cooldown_seconds: int = 0, pending: bool = false) -> void:
	if not show_action or busy:
		if is_instance_valid(_duel_action): _duel_action.hide()
		return
	if not is_instance_valid(_duel_action):
		_duel_action = Button.new()
		_duel_action.name = "DuelAction"
		_duel_action.position = Vector2(6, _label.position.y - 78)
		_duel_action.size = Vector2(72, 72)
		_duel_action.custom_minimum_size = Vector2(72, 72)
		_duel_action.focus_mode = Control.FOCUS_NONE
		add_child(_duel_action)
		var glyph: Control = preload("res://scripts/ui/duel_swords.gd").new()
		glyph.position = Vector2(20, 20)
		glyph.size = Vector2(32, 32)
		_duel_action.add_child(glyph)
		if callback.is_valid(): _duel_action.pressed.connect(callback)
	_duel_action.show()
	_duel_action.disabled = pending or cooldown_seconds > 0 or DuelClient._mutation_busy or not DuelClient._pending_body.is_empty()
	_duel_action.modulate = Color(0.55, 0.55, 0.55) if _duel_action.disabled else Color.WHITE
	_duel_action.tooltip_text = tr("SOCIAL_COOLDOWN_SECONDS") % cooldown_seconds if cooldown_seconds > 0 else tr("DUEL_CHALLENGE")

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
