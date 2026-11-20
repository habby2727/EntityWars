extends Control

const SCREENS := [
	"res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_portal.tscn",
	"res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_chaos.tscn",
	"res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_laboratory.tscn",
]
const DESTINATION := "res://scenes/MainMenu.tscn"

func _ready() -> void:
	var screen := (load(SCREENS[randi() % SCREENS.size()]) as PackedScene).instantiate()
	if OS.has_feature("android"):
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
		var fill := screen.get_node("ProgressFill") as Control
		var background := screen.get_node("Background") as TextureRect
		var original := Rect2(Vector2(fill.anchor_left, fill.anchor_top), Vector2(fill.anchor_right - fill.anchor_left, fill.anchor_bottom - fill.anchor_top))
		fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
		screen.resized.connect(_align_progress.bind(screen, background, fill, original))
		_align_progress.call_deferred(screen, background, fill, original)
	else:
		var frame := AspectRatioContainer.new()
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.ratio = 16.0 / 9.0
		frame.stretch_mode = AspectRatioContainer.STRETCH_COVER
		add_child(frame)
		frame.add_child(screen)
	screen.load_failed.connect(_on_load_failed)
	screen.call_deferred("load_scene_threaded", DESTINATION)

func _align_progress(screen: Control, background: TextureRect, fill: Control, original: Rect2) -> void:
	if background.texture == null or screen.size.x <= 0.0 or screen.size.y <= 0.0:
		return
	var texture_size := background.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var factor := maxf(screen.size.x / texture_size.x, screen.size.y / texture_size.y)
	var drawn_size := texture_size * factor
	var origin := (screen.size - drawn_size) / 2.0
	fill.position = origin + original.position * drawn_size
	fill.size = original.size * drawn_size

func _on_load_failed(path: String) -> void:
	push_error("Loading screen failed to load: " + path)
	var error := get_tree().change_scene_to_file(DESTINATION)
	if error != OK:
		push_error("Could not open the main menu.")
