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
	image.resize(16, 48, Image.INTERPOLATE_LANCZOS)
	var box := StyleBoxTexture.new()
	box.texture = ImageTexture.create_from_image(image)
	box.texture_margin_top = 16.0
	box.texture_margin_bottom = 16.0
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = height / 2.0
	box.content_margin_bottom = height / 2.0
	return box

func _apply_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_apply_existing(child)

func _on_node_added(node: Node) -> void:
	if node is VScrollBar:
		var bar := node as VScrollBar
		bar.add_theme_stylebox_override("scroll", _track)
		bar.add_theme_stylebox_override("scroll_focus", _track)
		for key in ["grabber", "grabber_highlight", "grabber_pressed"]:
			bar.add_theme_stylebox_override(key, _thumb)
