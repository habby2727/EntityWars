extends Control
## Standalone preview only: simulated progress, never wired to actual scene loading.
## LEFT/RIGHT or SPACE to switch the three designs; R to reset progress.

const SCREENS: Array[PackedScene] = [
    preload("res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_portal.tscn"),
    preload("res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_chaos.tscn"),
    preload("res://assets/ui/loading_screens/entity_wars_loading/scenes/loading_laboratory.tscn")
]

var index: int = 0
var elapsed: float = 0.0
var screen: Control = null


func _ready() -> void:
    _show_variant()


func _show_variant() -> void:
    if is_instance_valid(screen):
        screen.queue_free()
    screen = SCREENS[index].instantiate() as Control
    add_child(screen)
    elapsed = 0.0
    screen.call("set_progress", 0.0)


func _process(delta: float) -> void:
    elapsed += delta
    if is_instance_valid(screen):
        screen.call("set_progress", minf(1.0, elapsed / 7.0))


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_RIGHT or event.keycode == KEY_SPACE:
            index = (index + 1) % SCREENS.size()
            _show_variant()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_LEFT:
            index = (index + SCREENS.size() - 1) % SCREENS.size()
            _show_variant()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_R:
            _show_variant()
            get_viewport().set_input_as_handled()
