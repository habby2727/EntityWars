extends Node

var _art: Texture2D
var _track: StyleBoxTexture
var _thumb: StyleBoxTexture

func _ready() -> void:
	_art = load("res://assets/ui/new-elements/scrollbar_vertical.png") as Texture2D
	if _art == null:
		return
	_track = _style(Rect2(0, 90, 122, 200), 16.0, 0.0)
	_thumb = _style(Rect2(18, 312, 86, 280), 16.0, 32.0)
	get_tree().node_added.connect(_on_node_added)
	_apply_existing(get_tree().root)

func _style(region: Rect2, width: float, height: float) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = _art
	atlas.region = region
	var box := StyleBoxTexture.new()
	box.texture = atlas
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
	if node is VScrollBar:
		var bar := node as VScrollBar
		bar.add_theme_stylebox_override("scroll", _track)
		bar.add_theme_stylebox_override("scroll_focus", _track)
		for key in ["grabber", "grabber_highlight", "grabber_pressed"]:
			bar.add_theme_stylebox_override(key, _thumb)
