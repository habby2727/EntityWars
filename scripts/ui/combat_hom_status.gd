extends PanelContainer

var _title: Label
var _bar: ProgressBar
var _state: Label

func _ready() -> void:
	custom_minimum_size = Vector2(240, 0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.025, 0.06, 0.09, 0.94)
	frame.border_color = Color("c9a85c")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(3)
	frame.set_content_margin_all(5)
	add_theme_stylebox_override("panel", frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	add_child(content)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color("dfc980"))
	content.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(228, 15)
	_bar.max_value = 6
	_bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("10202a")
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("4bb7d6")
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", background)
	_bar.add_theme_stylebox_override("fill", fill)
	content.add_child(_bar)
	_state = Label.new()
	_state.add_theme_font_size_override("font_size", 17)
	_state.add_theme_color_override("font_color", Color("b9e8f3"))
	content.add_child(_state)

var _localized_fighter: Dictionary = {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and not _localized_fighter.is_empty():
		set_fighter(_localized_fighter)

func set_fighter(fighter: Dictionary) -> void:
	if _title == null:
		return
	_localized_fighter = fighter.duplicate(true)
	var energy := int(fighter.get("hom_energy", 0))
	var spent := bool(fighter.get("hom_spent", false))
	_title.text = "%s  |  %s" % [fighter.get("hom_name", "Homunculus"), tr("HOM_SPENT") if spent else tr("HOM_ACTIVE")]
	_bar.value = 0 if spent else energy
	_state.text = tr("HOM_SACRIFICED") if spent else "%d / 6  |  %s" % [energy, tr("HOM_OVERCHARGED") if energy >= 6 else tr("HOM_READY") if energy >= 3 else tr("HOM_CHARGING")]
	tooltip_text = tr("HOM_STATUS_HINT").replace("\\n", "\n") % energy
	modulate = Color(0.65, 0.65, 0.65) if spent else Color.WHITE
