extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const SUMMONERS := {
	"wizard": ["FOREST_SUMMONER_WIZARD", "res://assets/forest/summoners/Wizard_front.png"],
	"witch": ["FOREST_SUMMONER_WITCH", "res://assets/forest/summoners/Witch_Front.png"],
	"cyberghost": ["FOREST_SUMMONER_CYBERGHOST", "res://assets/forest/summoners/Cyberghost_Front.png"]
}
var _selected := ""
var _cards := {}
var _confirm: Button
var _change_mode := false
var _change_check_elapsed := 0.0

func _ready() -> void:
	_change_mode = not SceneRouter._forest_change.is_empty()
	if not SceneRouter._forest_access_allowed():
		if _change_mode:
			SceneRouter.forest_change_available()
		SceneRouter.go_to_lab_hub.call_deferred()
		return
	if _change_mode and not SceneRouter.forest_change_available():
		SceneRouter.go_to_lab_hub.call_deferred()
		return
	_selected = SceneRouter.forest_selected_summoner()
	var backdrop := ColorRect.new()
	backdrop.color = Color("101c21")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	add_child(aspect)
	var canvas := Control.new()
	aspect.add_child(canvas)
	var background := TextureRect.new()
	background.texture = load("res://assets/forest/backgrounds/Central_Clearing.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.modulate = Color(0.35, 0.45, 0.46, 1)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var title := Label.new()
	title.name = "Title"
	title.text = "FOREST_CHOOSE_SUMMONER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	_set_rect(title, 0.1, 0.07, 0.9, 0.165)
	canvas.add_child(title)
	var row := HBoxContainer.new()
	row.name = "Cards"
	row.add_theme_constant_override("separation", 26)
	_set_rect(row, 0.16, 0.18, 0.84, 0.78)
	canvas.add_child(row)
	for id in SUMMONERS:
		var card := Button.new()
		card.name = id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_ALL
		card.pressed.connect(_select.bind(id))
		row.add_child(card)
		_cards[id] = card
		var portrait := TextureRect.new()
		portrait.texture = load(SUMMONERS[id][1])
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_rect(portrait, 0.07, 0.05, 0.93, 0.78)
		card.add_child(portrait)
		var label := Label.new()
		label.name = "Name"
		label.text = SUMMONERS[id][0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 25)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_rect(label, 0.02, 0.78, 0.98, 0.89)
		card.add_child(label)
		var hint := Label.new()
		hint.name = "Hint"
		hint.text = "FOREST_SELECT"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 19)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_rect(hint, 0.05, 0.90, 0.95, 0.98)
		card.add_child(hint)
	var back := Button.new()
	back.text = "SETTINGS_BACK"
	back.add_theme_font_size_override("font_size", 24)
	_set_rect(back, 0.16, 0.80, 0.34, 0.88)
	back.pressed.connect(_cancel_selection)
	canvas.add_child(back)
	_confirm = Button.new()
	_confirm.text = "UI_CONFIRM" if _change_mode else "FOREST_CONFIRM"
	_confirm.add_theme_font_size_override("font_size", 24)
	_set_rect(_confirm, 0.60, 0.80, 0.84, 0.88)
	_confirm.pressed.connect(_confirm_selection)
	canvas.add_child(_confirm)
	UIThemeFactory.apply_theme_to(self)
	MenuArt.button(back)
	MenuArt.button(_confirm)
	_refresh()

func _cancel_selection() -> void:
	if _change_mode:
		SceneRouter.finish_forest_change("", false)
	else:
		SceneRouter.leave_forest()

func _confirm_selection() -> void:
	if _change_mode:
		SceneRouter.finish_forest_change(_selected, true)
	else:
		SceneRouter.enter_forest(_selected)

func _process(delta: float) -> void:
	if not _change_mode:
		return
	if not is_instance_valid(_confirm):
		if SceneRouter._forest_access_allowed():
			SceneRouter._forest_change.clear()
			SceneRouter.go_to_lab_hub.call_deferred()
		return
	_change_check_elapsed += delta
	if _change_check_elapsed < 0.25:
		return
	_change_check_elapsed = 0.0
	var available := SceneRouter.forest_change_available()
	_confirm.disabled = _selected not in SUMMONERS or not available
	if not available and SceneRouter._forest_change.is_empty() and SceneRouter._forest_access_allowed():
		SceneRouter.go_to_lab_hub.call_deferred()

func _set_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom

func _select(id: String) -> void:
	_selected = id
	_refresh()

func _refresh() -> void:
	_confirm.disabled = _selected not in SUMMONERS
	for id in _cards:
		var card: Button = _cards[id]
		var selected: bool = id == _selected
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.04, 0.09, 0.10, 0.91) if state == "normal" else Color(0.10, 0.19, 0.19, 0.95)
			style.border_color = Color("e0ca80") if selected else Color("577c70")
			style.set_border_width_all(5 if selected else 2)
			style.set_corner_radius_all(16)
			card.add_theme_stylebox_override(state, style)
		(card.get_node("Hint") as Label).modulate = Color("f5df9b") if selected else Color("b4c5b9")
