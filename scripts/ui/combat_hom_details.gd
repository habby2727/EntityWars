extends PanelContainer

const HomProgress := preload("res://scripts/domain/homunculus_progress.gd")
const Stats := preload("res://scripts/ui/stat_presentation.gd")
var _fighter: Dictionary = {}
var _owner_name := ""
var _portrait: TextureRect
var _heading: Label
var _details: Label

func _ready() -> void:
	position = Vector2(690, 170)
	custom_minimum_size = Vector2(540, 0)
	z_index = 80
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.07, 0.98)
	style.border_color = Color("c9a85c")
	style.set_border_width_all(2)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_heading = Label.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.add_theme_font_size_override("font_size", 21)
	header.add_child(_heading)
	var close := Button.new()
	close.text = "X"
	close.tooltip_text = "Close"
	close.pressed.connect(hide)
	header.add_child(close)
	var body := HBoxContainer.new()
	content.add_child(body)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(100, 100)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(_portrait)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(390, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_details = Label.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 17)
	scroll.add_child(_details)
	hide()

func show_fighter(fighter: Dictionary, texture: Texture2D, owner_name: String) -> void:
	_fighter = fighter
	_owner_name = owner_name
	_portrait.texture = texture
	refresh()
	show()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()

func refresh() -> void:
	if _fighter.is_empty() or _heading == null:
		return
	var hom: Dictionary = _fighter.get("hom_data", {})
	var progress: Dictionary = _fighter.get("hom_progress", {})
	var entry: Dictionary = progress.get(str(hom.get("id", "")), {})
	var level := clampi(int(entry.get("level", 0)), 0, 10)
	var mutation := str(entry.get("mutation_id", ""))
	var catalog := HomProgress.mutation_catalog()
	var spent := bool(_fighter.get("hom_spent", true))
	var energy := int(_fighter.get("hom_energy", 0))
	var state := tr("HOM_DETAIL_SACRIFICED") if spent else (tr("HOM_DETAIL_OVERCHARGED") if energy >= 6 else tr("HOM_DETAIL_READY") if energy >= 3 else tr("HOM_DETAIL_CHARGING"))
	var base := tr("HOM_DETAIL_BASE") % [hom.get("buff_atk", 0), hom.get("buff_def", 0), hom.get("buff_hp", 0)]
	var level_text := tr("HOM_DETAIL_LEVEL") % [int(level / 5.0), int(level / 3.0), level]
	var bonuses := HomProgress.effective_bonuses(hom, progress)
	var synergy: Dictionary = _fighter.get("hom_synergy", {})
	bonuses["power_flat"] = int(bonuses.get("power_flat", 0)) + int(synergy.get("power_flat", 0))
	bonuses["guard_flat"] = int(bonuses.get("guard_flat", 0)) + int(synergy.get("guard_flat", 0))
	var lines: Array[String] = []
	for key in synergy:
		lines.append(_describe_synergy(str(key), float(synergy[key])))
	var bonus_lines: Array[String] = []
	for key in bonuses:
		bonus_lines.append("%s: %s" % [GameLocalization.catalog("stat", str(key), "name", str(key).replace("_", " ").capitalize()), Stats.stat_value(str(key), bonuses[key])])
	_heading.text = "%s | %s" % [hom.get("name", "Homunculus"), _owner_name]
	_details.text = tr("HOM_DETAIL_TEXT").replace("\\n", "\n") % [GameLocalization.catalog("rarity", str(hom.get("rarity", "unknown")), "name", str(hom.get("rarity", "unknown")).capitalize()), level, energy, state, base, level_text, GameLocalization.catalog("mutation", mutation, "name", str(catalog.get(mutation, {}).get("name", tr("HOM_DETAIL_NONE")))), GameLocalization.catalog("mutation", mutation, "desc", str(catalog.get(mutation, {}).get("description", ""))), tr("HOM_DETAIL_ACTIVE") % ", ".join(bonus_lines) if not spent else tr("HOM_DETAIL_INACTIVE"), GameLocalization.catalog("type", str(_fighter.get("type", "")), "name", str(_fighter.get("type", "")).capitalize()), tr("HOM_DETAIL_SYNERGY") % ", ".join(lines) if not spent else tr("HOM_DETAIL_SYNERGY_INACTIVE")]

func _describe_synergy(key: String, value: float) -> String:
	match key:
		"power_flat": return tr("HOM_SYNERGY_POWER") % Stats.number(value)
		"guard_flat": return tr("HOM_SYNERGY_GUARD") % Stats.number(value)
		"tempo_flat": return tr("HOM_SYNERGY_TEMPO") % Stats.number(value)
		"incoming_mult": return tr("HOM_SYNERGY_INCOMING") % Stats.percent(value)
		"dot_true": return tr("HOM_SYNERGY_CORROSION") % Stats.number(value)
		"reflect_pct": return tr("HOM_SYNERGY_REFLECT") % Stats.percent(value)
		"type_adv_bonus": return tr("HOM_SYNERGY_TYPE") % Stats.percent(value)
		"item_effect_mult": return tr("HOM_SYNERGY_ITEM") % Stats.percent(value)
		"type_neutralize": return tr("HOM_SYNERGY_NEUTRAL") % (value * 100.0)
	return "%s: %s" % [key.replace("_", " ").capitalize(), Stats.stat_value(key, value)]
