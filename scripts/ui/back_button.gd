extends Button
class_name BackButton

@export var target: String = "main_menu"

func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func _on_pressed() -> void:
	match target:
		"lab_hub":
			SceneRouter.go_to_lab_hub()
		"lab_structures":
			SceneRouter.go_to_lab_structures("")
		"inventory":
			SceneRouter.go_to_inventory()
		"loadout":
			SceneRouter.go_to_loadout()
		"combat":
			SceneRouter.go_to_combat()
		"trade_hall":
			SceneRouter.go_to_trade_hall()
		"world_gate":
			SceneRouter.go_to_world_gate()
		_:
			SceneRouter.go_to_main_menu()
