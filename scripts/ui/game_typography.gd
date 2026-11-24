extends Node

const TITLE_FONT_PATH := "res://assets/fonts/bakula-font/BakulaRegular-LVMBy.ttf"
const BODY_FONT_PATH := "res://assets/fonts/MedievalFont/JimNightshade-Regular.ttf"
const SHARP_FONT_PATH := "res://assets/fonts/MedievalSharp/MedievalSharp-Regular.ttf"
const CHAT_FONT_PATH := "res://assets/fonts/old-newspaper-types-font/Oldnewspapertypes-449D.ttf"
const EXCLUDED_SCENES := ["res://scenes/MainMenu.tscn", "res://scenes/LoadoutGrid.tscn", "res://scenes/LoadoutLegacy.tscn"]
var _title_font: Font
var _body_font: Font
var _sharp_font: Font
var _chat_font: Font
var _tracked_text: Dictionary = {}
var _refresh_elapsed := 0.0

func _ready() -> void:
	_title_font = load(TITLE_FONT_PATH) as Font
	_body_font = load(BODY_FONT_PATH) as Font
	_sharp_font = load(SHARP_FONT_PATH) as Font
	_chat_font = load(CHAT_FONT_PATH) as Font
	var fallback := load("res://assets/fonts/liberation-serif/LiberationSerif-Regular.ttf") as Font
	if fallback != null:
		var fallbacks: Array[Font] = [fallback]
		if _title_font != null:
			_title_font.fallbacks = fallbacks
		if _body_font != null:
			_body_font.fallbacks = fallbacks
		if _sharp_font != null:
			_sharp_font.fallbacks = fallbacks
		if _chat_font != null:
			_chat_font.fallbacks = fallbacks
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.1:
		return
	_refresh_elapsed = 0.0
	for id in _tracked_text.keys():
		var node := instance_from_id(id)
		if not is_instance_valid(node) or not node.is_inside_tree():
			_tracked_text.erase(id)
			continue
		var state := str(TranslationServer.get_locale(), "|", node.text)
		if _tracked_text[id] != state:
			_tracked_text[id] = state
			_apply_font(node)

func _on_node_added(node: Node) -> void:
	if node is Control or node is PopupMenu:
		_apply_font_if_alive.call_deferred(node.get_instance_id())

func _apply_font_if_alive(id: int) -> void:
	var node := instance_from_id(id) as Node
	if is_instance_valid(node):
		_apply_font(node)

func _excluded(node: Node) -> bool:
	var current := node
	while current != null and current != get_tree().root:
		if current.scene_file_path in EXCLUDED_SCENES:
			return true
		current = current.get_parent()
	return false

func _apply_font(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or _excluded(node):
		return
	_restore_font_sizes(node)
	if node is Label or node is Button:
		_tracked_text[node.get_instance_id()] = str(TranslationServer.get_locale(), "|", node.text)
	var settings_control := false
	var chat_control := false
	var ancestor := node
	while ancestor != null:
		if ancestor.scene_file_path == "res://scenes/ui/Settings.tscn":
			settings_control = true
		if ancestor.has_meta("global_chat_font"):
			chat_control = true
		ancestor = ancestor.get_parent()
	if node is PopupMenu:
		var popup_font: Font = _chat_font if chat_control else (_body_font if settings_control or node.has_meta("localization_body_font") else _title_font)
		node.add_theme_font_override("font", popup_font)
		if popup_font == _body_font:
			_double_font_sizes(node, ["font_size"])
		return
	var control := node as Control
	if control == null or _title_font == null or _body_font == null:
		return
	var heading := control is BaseButton or control is TabBar or control is TabContainer
	if settings_control and control is BaseButton:
		heading = false
	if control is Label or control is RichTextLabel:
		var node_name := str(control.name).to_lower()
		heading = "title" in node_name or "header" in node_name or "heading" in node_name or "subtitle" in node_name
		var size_key := "normal_font_size" if control is RichTextLabel else "font_size"
		if control.get_theme_font_size(size_key) >= 24:
			heading = true
		if settings_control and control.name != "Title":
			heading = false
	if control.has_meta("localization_body_font"):
		heading = false
	var font: Font = _title_font if heading else _body_font
	if control.has_meta("medieval_sharp_font") or (not heading and control is Label and _is_numeric_text(control.text)):
		font = _sharp_font
	elif heading and TranslationServer.get_locale().begins_with("es") and _has_spanish_accents(_control_text(control)):
		font = _sharp_font
	if chat_control:
		font = _chat_font
	if control is RichTextLabel:
		for key in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
			control.add_theme_font_override(key, font)
	elif control is Label or control is BaseButton or control is LineEdit or control is TextEdit or control is ItemList or control is Tree or control is TabContainer or control is TabBar:
		control.add_theme_font_override("font", font)
	if font == _body_font:
		if control is RichTextLabel:
			_double_font_sizes(control, ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"])
		elif control is Label or control is BaseButton or control is LineEdit or control is TextEdit or control is ItemList or control is Tree or control is TabContainer or control is TabBar:
			_double_font_sizes(control, ["font_size"])

func _double_font_sizes(control: Node, keys: Array) -> void:
	var sizes := {}
	for key in keys:
		var original: int = control.get_theme_font_size(key)
		if original <= 0:
			continue
		sizes[key] = {"size": original, "override": control.has_theme_font_size_override(key)}
		control.add_theme_font_size_override(key, original * 2)
	if not sizes.is_empty():
		control.set_meta("typography_original_sizes", sizes)

func _restore_font_sizes(control: Node) -> void:
	if not control.has_meta("typography_original_sizes"):
		return
	var sizes: Dictionary = control.get_meta("typography_original_sizes")
	for key in sizes:
		var original: Dictionary = sizes[key]
		# Leave a later explicit size change alone.
		if control.get_theme_font_size(key) != int(original.size) * 2:
			continue
		if original.override:
			control.add_theme_font_size_override(key, original.size)
		else:
			control.remove_theme_font_size_override(key)
	control.remove_meta("typography_original_sizes")

func _control_text(control: Control) -> String:
	if control is Label or control is RichTextLabel or control is Button:
		return tr(control.text)
	return ""

func _has_spanish_accents(value: String) -> bool:
	for character in value:
		if "áéíóúüñÁÉÍÓÚÜÑ".contains(character):
			return true
	return false

func _is_numeric_text(value: String) -> bool:
	var text := value.strip_edges()
	if text.is_empty():
		return false
	var has_digit := false
	for character in text:
		if "0123456789".contains(character):
			has_digit = true
		elif not " +-.,%/:×x()".contains(character):
			return false
	return has_digit
