extends HBoxContainer
var label: Label
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	var eye: Control = preload("res://scripts/ui/spectator_eye.gd").new()
	eye.custom_minimum_size = Vector2(20, 20)
	eye.size = Vector2(20, 20)
	add_child(eye)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	GlobalChatClient.updated.connect(_refresh)
	_refresh()
func _refresh() -> void:
	var names: Array = GlobalChatClient.spectators
	visible = not names.is_empty()
	label.text = tr("SPECTATOR_VIEWERS") + ": " + ", ".join(PackedStringArray(names.slice(0, 8)))
