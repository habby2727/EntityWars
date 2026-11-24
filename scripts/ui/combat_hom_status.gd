extends PanelContainer

var _title: Label
var _bar: ProgressBar
var _state: Label
var _type_row: HBoxContainer
var _type_icon: Control
var _attack_name: Label
static var _captured_catalog := {}

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
	_type_row = HBoxContainer.new()
	_type_row.name = "HomTypeAndAttack"
	_type_row.add_theme_constant_override("separation", 4)
	content.add_child(_type_row)
	_type_icon = preload("res://scripts/ui/combat_type_icon.gd").new()
	_type_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_row.add_child(_type_icon)
	_attack_name = Label.new()
	_attack_name.name = "AttackName"
	_attack_name.clip_text = true
	_attack_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_name.add_theme_font_size_override("font_size", 16)
	_attack_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_row.add_child(_attack_name)
	_type_row.hide()
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
	var hom: Dictionary = fighter.get("hom_data", {}) if fighter.get("hom_data", {}) is Dictionary else {}
	if hom.is_empty():
		if _captured_catalog.is_empty():
			var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/expedition_homunculi.json"))
			if data is Dictionary:
				for item in data.get("homunculi", []):
					if item is Dictionary: _captured_catalog[str(item.get("id", ""))] = item
		hom = _captured_catalog.get(str(fighter.get("hom_id", "")), {})
	var passive: Variant = hom.get("passive", {})
	if passive is Dictionary and not str(hom.get("type", "")).is_empty():
		var language := "es" if TranslationServer.get_locale().begins_with("es") else "en"
		var names: Dictionary = passive.get("name", {})
		var descriptions: Dictionary = passive.get("description", {})
		var attack_name := str(names.get(language, names.get("en", "")))
		set_expedition_type(str(hom.type), attack_name)
		tooltip_text = "%s\n%s\n%s" % [attack_name, str(descriptions.get(language, descriptions.get("en", ""))), tr("HOM_ATTACK_SUMMARY")]
	else:
		_type_row.hide()
	modulate = Color(0.65, 0.65, 0.65) if spent else Color.WHITE

# Expedition homunculi have their own elemental affinity and named passive.
func set_expedition_type(type_id: String, attack_name: String) -> void:
	if type_id.is_empty() or _title == null: return
	custom_minimum_size.x = 190
	_bar.custom_minimum_size.x = 178
	_title.add_theme_font_size_override("font_size", 16)
	_state.add_theme_font_size_override("font_size", 16)
	_type_icon.configure(type_id)
	_attack_name.text = attack_name
	_type_row.show()

func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "TooltipPanel"
	panel.set_meta("combat_font", true)
	var label := Label.new()
	label.text = for_text
	label.custom_minimum_size.x = 420
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)
	return panel
