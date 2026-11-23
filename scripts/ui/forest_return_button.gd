extends Button

var _elapsed := 0.0

func _ready() -> void:
	name = "ReturnToForest"
	text = "FOREST_RETURN"
	custom_minimum_size = Vector2(170, 44)
	add_theme_font_size_override("font_size", 16)
	preload("res://scripts/ui/menu_art.gd").button(self)
	pressed.connect(SceneRouter.return_to_forest)
	visible = SceneRouter.forest_return_safe()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		visible = SceneRouter.forest_return_safe()

static func attach(parent: Node) -> Button:
	if not SceneRouter.forest_return_available():
		return null
	var button := load("res://scripts/ui/forest_return_button.gd").new() as Button
	parent.add_child(button)
	return button
