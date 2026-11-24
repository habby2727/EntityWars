extends PanelContainer

const BUBBLE_WIDTH := 300.0
const PADDING := 8.0
const MAX_LINES := 8
var _label: Label
var _deadline_ticks := 0
var _last_message_id := 0
var _last_created := 0
var _layout_text := ""
var _layout_font: Font
var _layout_font_size := 0

func _ready() -> void:
	name = "SpeechBubble"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	custom_minimum_size = Vector2(BUBBLE_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(PADDING)
	add_theme_stylebox_override("panel", style)
	_label = Label.new()
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_horizontal = Control.SIZE_FILL
	_label.size_flags_vertical = Control.SIZE_FILL
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.clip_text = true
	_label.max_lines_visible = MAX_LINES
	_label.custom_minimum_size = Vector2(BUBBLE_WIDTH - 2.0 * PADDING, 0)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_label)
	hide()

func show_message(message_id: int, text: String, created_at: int, expires_at: int, server_now: int) -> void:
	if message_id <= _last_message_id or created_at < _last_created or expires_at <= server_now: return
	_last_message_id = message_id
	_last_created = created_at
	_deadline_ticks = Time.get_ticks_msec() + mini(10000, expires_at - server_now)
	_label.text = text
	preload("res://scripts/ui/social_spanish_font.gd").apply(_label, text)
	_resize_for_text()
	show()
	_update_position()

func clear_message() -> void:
	_deadline_ticks = 0
	hide()

func _process(_delta: float) -> void:
	if not visible: return
	if Time.get_ticks_msec() >= _deadline_ticks:
		hide()
		return
	_resize_for_text()
	_update_position()

func _resize_for_text() -> void:
	var font := _label.get_theme_font("font")
	var font_size := _label.get_theme_font_size("font_size")
	if _layout_text == _label.text and _layout_font == font and _layout_font_size == font_size:
		return
	_layout_text = _label.text
	_layout_font = font
	_layout_font_size = font_size
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var text_size := font.get_multiline_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_WIDTH - 2.0 * PADDING, font_size, MAX_LINES, flags)
	var height := ceilf(maxf(font.get_height(font_size), text_size.y) + 2.0 * PADDING)
	var target := Vector2(BUBBLE_WIDTH, height)
	if custom_minimum_size != target:
		custom_minimum_size = target
	if size != target:
		size = target

func _update_position() -> void:
	var owner := get_parent()
	var nameplate := owner.get_node_or_null("Nameplate") as Control
	if nameplate == null: return
	var top := nameplate.position.y
	for node_name in ["FriendAction", "DuelAction"]:
		var action := owner.get_node_or_null(node_name) as Control
		if action != null and action.visible: top = minf(top, action.position.y)
	position = Vector2(-size.x * 0.5, top - size.y - 8)
