extends Node

var _track: StyleBoxTexture
var _thumb: StyleBoxTexture

func _ready() -> void:
	var track_art := load("res://assets/ui/new-elements/scrollbar_track_vertical_32x96.png") as Texture2D
	var thumb_art := load("res://assets/ui/new-elements/scrollbar_thumb_vertical_32x96.png") as Texture2D
	if track_art == null or thumb_art == null:
		return
	_track = _style(track_art, 0.0)
	_thumb = _style(thumb_art, 32.0)
	get_tree().node_added.connect(_on_node_added)
	_apply_existing(get_tree().root)

func _style(art: Texture2D, height: float) -> StyleBoxTexture:
	var image := art.get_image()
	var width := 32 if OS.has_feature("android") else 16
	image.resize(width, 48, Image.INTERPOLATE_LANCZOS)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(image)
	box.texture_margin_top = 16.0
	box.texture_margin_bottom = 16.0
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.content_margin_left = width / 2.0
	box.content_margin_right = width / 2.0
	box.content_margin_top = height / 2.0
	box.content_margin_bottom = height / 2.0
	return box

func _apply_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_apply_existing(child)

func _on_node_added(node: Node) -> void:
	if OS.has_feature("android") and node is Control:
		_configure_touch_scroll.call_deferred(node.get_instance_id())
	if node is VScrollBar:
		var bar := node as VScrollBar
		bar.add_theme_stylebox_override("scroll", _track)
		bar.add_theme_stylebox_override("scroll_focus", _track)
		for key in ["grabber", "grabber_highlight", "grabber_pressed"]:
			bar.add_theme_stylebox_override(key, _thumb)

func _configure_touch_scroll(id: int) -> void:
	var control := instance_from_id(id) as Control
	if not is_instance_valid(control) or not control.is_inside_tree() or control is ScrollContainer or control is ScrollBar:
		return
	var parent := control.get_parent()
	var in_scroll := false
	var in_supported_scene := false
	while parent != null:
		if parent is ScrollContainer:
			in_scroll = parent.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			break
		parent = parent.get_parent()
	parent = control.get_parent()
	while parent != null:
		var path := parent.scene_file_path
		if path.begins_with("res://scenes/ui/WorldZone") or path in ["res://scenes/ui/WorldGate.tscn", "res://scenes/ui/LabStructures.tscn", "res://scenes/ui/Inventory.tscn", "res://scenes/LoadoutGrid.tscn", "res://scenes/Combat.tscn"]:
			in_supported_scene = true
		parent = parent.get_parent()
	if in_scroll and in_supported_scene and control.mouse_filter == Control.MOUSE_FILTER_STOP:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
