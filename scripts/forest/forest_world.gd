extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const FRONT_TEXTURES := {
	"wizard": "res://assets/forest/summoners/Wizard_front.png",
	"witch": "res://assets/forest/summoners/Witch_Front.png",
	"cyberghost": "res://assets/forest/summoners/Cyberghost_Front.png"
}

func _ready() -> void:
	var selected := SceneRouter.forest_selected_summoner()
	if selected not in FRONT_TEXTURES:
		SceneRouter.go_to_lab_hub.call_deferred()
		return
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_WIDTH_CONTROLS_HEIGHT
	add_child(aspect)
	var canvas := Control.new()
	aspect.add_child(canvas)
	var background := TextureRect.new()
	background.name = "CentralClearing"
	background.texture = load("res://assets/forest/backgrounds/Central_Clearing.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var avatar := TextureRect.new()
	avatar.name = "Summoner"
	avatar.texture = load(FRONT_TEXTURES[selected])
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.anchor_left = 0.41
	avatar.anchor_top = 0.52
	avatar.anchor_right = 0.59
	avatar.anchor_bottom = 0.94
	canvas.add_child(avatar)
	var leave := Button.new()
	leave.text = "FOREST_LEAVE"
	leave.anchor_left = 0.02
	leave.anchor_top = 0.025
	leave.anchor_right = 0.20
	leave.anchor_bottom = 0.09
	leave.add_theme_font_size_override("font_size", 24)
	leave.pressed.connect(SceneRouter.leave_forest)
	canvas.add_child(leave)
	UIThemeFactory.apply_theme_to(self)
	MenuArt.button(leave)
