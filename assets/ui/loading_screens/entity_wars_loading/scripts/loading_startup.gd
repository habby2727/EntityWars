extends Control

const SCREENS := [
	"res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_portal.tscn",
	"res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_chaos.tscn",
	"res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_laboratory.tscn",
]
const DESTINATION := "res://scenes/MainMenu.tscn"

func _ready() -> void:
	var frame := AspectRatioContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.ratio = 16.0 / 9.0
	add_child(frame)
	var screen := (load(SCREENS[randi() % SCREENS.size()]) as PackedScene).instantiate()
	frame.add_child(screen)
	screen.load_failed.connect(_on_load_failed)
	screen.call_deferred("load_scene_threaded", DESTINATION)

func _on_load_failed(path: String) -> void:
	push_error("Loading screen failed to load: " + path)
	var error := get_tree().change_scene_to_file(DESTINATION)
	if error != OK:
		push_error("Could not open the main menu.")
