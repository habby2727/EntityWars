extends Control

const REG_PATH := "res://scripts/data_registry.gd"
const ENTITY_PREVIEW_DIR := "res://assets/entities/previews_256/"
const HOM_PREVIEW_DIR := "res://assets/homunculi/previews_256/"
const SAVE_PATH := "user://loadout.json"

@onready var entities_grid: GridContainer = %EntitiesGrid
@onready var hom_grid: GridContainer = %HomunculiGrid

@onready var preview: TextureRect = %Preview
@onready var name_lbl: Label = %Name
@onready var types_lbl: Label = %Types
@onready var stats_lbl: Label = %Stats
@onready var desc_lbl: RichTextLabel = %Desc

@onready var atk_tech: OptionButton = %AtkTech
@onready var def_tech: OptionButton = %DefTech

@onready var btn_save: Button = %Save
@onready var btn_reset: Button = %Reset
@onready var btn_play: Button = %Play

var reg: Object
var selected_entity_id: String = ""
var selected_hom_id: String = ""

func _ready() -> void:
	_load_registry()
	_build_grids()
	_build_techniques()
	_wire_buttons()
	_try_load_saved()

func _load_registry() -> void:
	if not ResourceLoader.exists(REG_PATH):
		push_error("Missing registry script: " + REG_PATH)
		reg = null
		return
	var script := load(REG_PATH)
	reg = script.new()
	# Be defensive: support either method name.
	if reg.has_method("load_defaults"):
		reg.call("load_defaults")
	elif reg.has_method("load_default_data"):
		reg.call("load_default_data")

func _build_grids() -> void:
	_clear_children(entities_grid)
	_clear_children(hom_grid)

	var entities: Array = []
	var homs: Array = []
	if reg != null:
		if reg.has_method("get_entities"):
			entities = reg.call("get_entities")
		elif "entities" in reg:
			entities = reg.entities
		if reg.has_method("get_homunculi"):
			homs = reg.call("get_homunculi")
		elif "homunculi" in reg:
			homs = reg.homunculi

	if entities.is_empty():
		# Fallback: show your current 6 IDs so the UI is still testable.
		entities = [
			{"id":"aether","name":"Aether"},
			{"id":"gold","name":"Gold"},
			{"id":"vitriol","name":"Vitriol"},
			{"id":"sodium","name":"Sodium"},
			{"id":"mercury","name":"Mercury"},
			{"id":"sulfur","name":"Sulfur"},
		]

	for e in entities:
		var card := _make_card(e.get("id",""), e.get("name","Entity"), true)
		entities_grid.add_child(card)

	if homs.is_empty():
		homs = [
			{"id":"cinder_imp","name":"Cinder Imp"},
			{"id":"corroder","name":"Corroder"},
			{"id":"bastion","name":"Bastion"},
		]
	for h in homs:
		var card2 := _make_card(h.get("id",""), h.get("name","Homunculus"), false)
		hom_grid.add_child(card2)

func _make_card(id: String, display_name: String, is_entity: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(160, 190)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.text = ""
	b.focus_mode = Control.FOCUS_NONE

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.theme_override_constants["separation"] = 6
	b.add_child(v)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(160, 160)
	v.add_child(frame)

	var tr := TextureRect.new()
	tr.name = "PreviewTex"
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.anchors_preset = Control.PRESET_FULL_RECT
	tr.anchor_right = 1.0
	tr.anchor_bottom = 1.0
	frame.add_child(tr)

	var tex := _load_preview(id, is_entity)
	if tex != null:
		tr.texture = tex

	var lbl := Label.new()
	lbl.text = display_name
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)

	b.pressed.connect(func():
		if is_entity:
			_select_entity(id)
		else:
			_select_homunculus(id)
	)
	return b

func _load_preview(id: String, is_entity: bool) -> Texture2D:
	if id == "":
		return null
	var path := (ENTITY_PREVIEW_DIR if is_entity else HOM_PREVIEW_DIR) + id + "_01.png"
	if ResourceLoader.exists(path):
		return load(path)
	# Also support old naming (no _01)
	var path2 := (ENTITY_PREVIEW_DIR if is_entity else HOM_PREVIEW_DIR) + id + ".png"
	if ResourceLoader.exists(path2):
		return load(path2)
	return null

func _select_entity(id: String) -> void:
	selected_entity_id = id
	var tex := _load_preview(id, true)
	if tex != null:
		preview.texture = tex
	name_lbl.text = id.capitalize()
	types_lbl.text = "Types: —"
	stats_lbl.text = "Base: HP ? | ATK ? | DEF ?"
	desc_lbl.text = "Desc: —"

func _select_homunculus(id: String) -> void:
	selected_hom_id = id
	# For now show homunculus preview if it exists; otherwise keep entity preview.
	var tex := _load_preview(id, false)
	if tex != null:
		preview.texture = tex

func _build_techniques() -> void:
	atk_tech.clear()
	def_tech.clear()

	# Minimal beta defaults (can be overwritten by registry later).
	var atk = ["Rite of Embers", "Mercurial Slash", "Aether Pierce"]
	var deff = ["Bulwark Rite", "Ward of Sodium", "Vitriol Veil"]

	for i in atk.size():
		atk_tech.add_item(atk[i], i)
	for j in deff.size():
		def_tech.add_item(deff[j], j)

	atk_tech.select(0)
	def_tech.select(0)

func _wire_buttons() -> void:
	btn_save.pressed.connect(_save)
	btn_reset.pressed.connect(_reset_defaults)
	btn_play.pressed.connect(func(): print("TODO: start Bo3 (hook to combat scene)"))

func _save() -> void:
	var data := {
		"entity_id": selected_entity_id,
		"homunculus_id": selected_hom_id,
		"attack_tech": atk_tech.get_item_text(atk_tech.selected),
		"defense_tech": def_tech.get_item_text(def_tech.selected),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Failed to write " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("Saved to ", SAVE_PATH)

func _try_load_saved() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	if d.get("entity_id","") != "":
		_select_entity(d["entity_id"])
	if d.get("homunculus_id","") != "":
		_select_homunculus(d["homunculus_id"])

func _reset_defaults() -> void:
	selected_entity_id = ""
	selected_hom_id = ""
	preview.texture = null
	name_lbl.text = "(Select an entity)"
	types_lbl.text = "Types: —"
	stats_lbl.text = "Base: HP ? | ATK ? | DEF ?"
	desc_lbl.text = "Desc: —"

func _clear_children(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()