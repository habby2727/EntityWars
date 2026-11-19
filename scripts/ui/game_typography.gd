extends Node

const TITLE_FONT_PATH := "res://assets/fonts/bakula-font/BakulaRegular-LVMBy.ttf"
const BODY_FONT_PATH := "res://assets/fonts/old-newspaper-types-font/Oldnewspapertypes-449D.ttf"
const EXCLUDED_SCENES := ["res://scenes/MainMenu.tscn", "res://scenes/LoadoutGrid.tscn", "res://scenes/LoadoutLegacy.tscn"]
var _title_font: Font
var _body_font: Font

func _ready() -> void:
	_title_font = load(TITLE_FONT_PATH) as Font
	_body_font = load(BODY_FONT_PATH) as Font
	var fallback := load("res://assets/fonts/liberation-serif/LiberationSerif-Regular.ttf") as Font
	if fallback != null:
		var fallbacks: Array[Font] = [fallback]
		if _title_font != null:
			_title_font.fallbacks = fallbacks
		if _body_font != null:
			_body_font.fallbacks = fallbacks
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Control or node is PopupMenu:
		_apply_font_if_alive.call_deferred(node.get_instance_id())

func _apply_font_if_alive(id: int) -> void:
	var node := instance_from_id(id) as Node
	if is_instance_valid(node):
		_apply_font(node)

func touch_size(control: Node) -> float:
	var scale_factor := control.get_viewport().get_screen_transform().get_scale()
	var pixels := 48.0 * maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	return pixels / maxf(0.01, minf(absf(scale_factor.x), absf(scale_factor.y)))

func apply_touch_size(control: Control) -> void:
	if not OS.has_feature("android") or not control.is_inside_tree():
		return
	var target := touch_size(control)
	control.custom_minimum_size = control.custom_minimum_size.max(Vector2(target, target))
	if control is BaseButton or control is LineEdit:
		control.add_theme_font_size_override("font_size", maxi(control.get_theme_font_size("font_size"), roundi(target * 0.32)))

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
	var settings_control := false
	var ancestor := node
	while ancestor != null:
		if ancestor.scene_file_path == "res://scenes/ui/Settings.tscn":
			settings_control = true
			break
		ancestor = ancestor.get_parent()
	if node is PopupMenu:
		node.add_theme_font_override("font", _body_font if settings_control or node.has_meta("localization_body_font") else _title_font)
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
	if control is RichTextLabel:
		for key in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
			control.add_theme_font_override(key, font)
	elif control is Label or control is BaseButton or control is LineEdit or control is TextEdit or control is ItemList or control is Tree or control is TabContainer or control is TabBar:
		control.add_theme_font_override("font", font)
