extends Control

const REG_PATH := "res://scripts/data_registry.gd"
const PREVIEW_256_DIR := "res://assets/entities/previews_256/"

var reg: Node = preload(REG_PATH).new()

var entity_list: ItemList = null
var entity_preview: TextureRect = null
var entity_name: Label = null
var entity_desc: RichTextLabel = null

var homunculus_list: ItemList = null
var homunculus_name: Label = null
var homunculus_desc: RichTextLabel = null

var equip1: OptionButton = null
var equip2: OptionButton = null
var side1: OptionButton = null
var side2: OptionButton = null
var atk_tech: OptionButton = null
var def_tech: OptionButton = null

var status_label: Label = null
var save_btn: Button = null
var reset_btn: Button = null

# Normaliza IDs TEMP -> nombres de previews
const PREVIEW_ALIASES := {
	"anomaly":"sulfur",
	"arbiter":"gold",
	"quicksprite":"aether",
	"bastion":"sodium",
	"igniter":"mercury",
	"corroder":"vitriol",
	# canonical
	"sulfur":"sulfur","mercury":"mercury","sodium":"sodium","aether":"aether","vitriol":"vitriol","gold":"gold",
}

var entities: Array = []
var homunculi: Array = []
var items: Array = []
var tech_atk: Array = []
var tech_def: Array = []

func _ready() -> void:
	# resolve scene node refs for this legacy loadout scene
	if entity_list == null:
		entity_list = get_node_or_null("Scroll/Root/Body/LeftPanel/LeftMargin/Left/EntityGrid")
	if entity_preview == null:
		entity_preview = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/EntityRow/EntityFrame/EntityPreview")
	if entity_name == null:
		entity_name = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/EntityRow/EntityInfo/EntityName")
	if entity_desc == null:
		entity_desc = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/EntityRow/EntityInfo/EntityDesc")
	if homunculus_list == null:
		homunculus_list = get_node_or_null("Scroll/Root/Body/LeftPanel/LeftMargin/Left/HomunculusList")
	if homunculus_name == null:
		homunculus_name = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/HomInfo/HomunculusName")
	if homunculus_desc == null:
		homunculus_desc = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/HomInfo/HomunculusDesc")
	if equip1 == null:
		equip1 = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/Grid/Equip1")
	if equip2 == null:
		equip2 = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/Grid/Equip2")
	if side1 == null:
		side1 = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/Grid/Side1")
	if side2 == null:
		side2 = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/Grid/Side2")
	if atk_tech == null:
		atk_tech = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/Grid/AtkTech")
	if def_tech == null:
		def_tech = get_node_or_null("Scroll/Root/Body/RightPanel/RightMargin/Right/Grid/DefTech")
	if save_btn == null:
		save_btn = get_node_or_null("Scroll/Root/Bottom/SaveBtn")
	if reset_btn == null:
		reset_btn = get_node_or_null("Scroll/Root/Bottom/ResetBtn")
	if status_label == null:
		status_label = get_node_or_null("Scroll/Root/Bottom/Status")

	add_child(reg)
	if reg.has_method("load_all"):
		reg.call("load_all")
	_load_data_from_registry()
	_wire_ui()
	_load_saved_or_defaults()
	_update_status("Ready.")

func _load_data_from_registry() -> void:
	entities = []
	homunculi = []
	items = []
	tech_atk = []
	tech_def = []

	var ent_dict: Dictionary = {}
	var _ent_any = reg.get("entities")
	if typeof(_ent_any) == TYPE_DICTIONARY:
		ent_dict = _ent_any
	if ent_dict.is_empty() and reg.has_method("get_entities"):
		ent_dict = reg.call("get_entities")

	for k in ent_dict.keys():
		var v = ent_dict[k]
		var d: Dictionary = {}
		if typeof(v) == TYPE_DICTIONARY:
			d = v
		else:
			d = { "name": String(k) }
		d["id"] = k
		entities.append(d)
	entities.sort_custom(func(a,b): return String(a.get("id","")) < String(b.get("id","")))

	var hom_dict: Dictionary = {}
	var _hom_any = reg.get("homunculi")
	if typeof(_hom_any) == TYPE_DICTIONARY:
		hom_dict = _hom_any
	if hom_dict.is_empty() and reg.has_method("get_homunculi"):
		hom_dict = reg.call("get_homunculi")

	for k in hom_dict.keys():
		var v = hom_dict[k]
		var d: Dictionary = {}
		if typeof(v) == TYPE_DICTIONARY:
			d = v
		else:
			d = { "name": String(k) }
		d["id"] = k
		homunculi.append(d)
	homunculi.sort_custom(func(a,b): return String(a.get("id","")) < String(b.get("id","")))

	var item_dict: Dictionary = {}
	var _item_any = reg.get("items")
	if typeof(_item_any) == TYPE_DICTIONARY:
		item_dict = _item_any
	if item_dict.is_empty() and reg.has_method("get_items"):
		item_dict = reg.call("get_items")

	for k in item_dict.keys():
		var v = item_dict[k]
		var d: Dictionary = {}
		if typeof(v) == TYPE_DICTIONARY:
			d = v
		else:
			d = { "name": String(k) }
		d["id"] = k
		items.append(d)
	items.sort_custom(func(a,b): return String(a.get("id","")) < String(b.get("id","")))

	var tech_dict: Dictionary = {}
	var _tech_any = reg.get("techniques")
	if typeof(_tech_any) == TYPE_DICTIONARY:
		tech_dict = _tech_any
	if tech_dict.is_empty() and reg.has_method("get_techniques"):
		tech_dict = reg.call("get_techniques")

	for k in tech_dict.keys():
		var v = tech_dict[k]
		var d: Dictionary = {}
		if typeof(v) == TYPE_DICTIONARY:
			d = v
		else:
			d = { "name": String(k), "kind": "" }
		d["id"] = k
		if String(d.get("kind","")).to_lower() == "attack":
			tech_atk.append(d)
		elif String(d.get("kind","")).to_lower() == "defense":
			tech_def.append(d)

	tech_atk.sort_custom(func(a,b): return String(a.get("id","")) < String(b.get("id","")))
	tech_def.sort_custom(func(a,b): return String(a.get("id","")) < String(b.get("id","")))

func _wire_ui() -> void:
	entity_list.clear()
	entity_list.max_columns = 2
	entity_list.icon_mode = ItemList.ICON_MODE_TOP
	entity_list.fixed_column_width = 260
	entity_list.fixed_icon_size = Vector2i(192, 192)

	for e in entities:
		var display_name := String(e.get("name", e.get("id","")))
		var raw_id := String(e.get("id",""))
		var icon_tex: Texture2D = _load_entity_preview(raw_id)
		entity_list.add_item(display_name, icon_tex)

	entity_list.item_selected.connect(_on_entity_selected)

	homunculus_list.clear()
	for h in homunculi:
		homunculus_list.add_item(String(h.get("name", h.get("id",""))))
	homunculus_list.item_selected.connect(_on_homunculus_selected)

	_fill_option_with_items(equip1)
	_fill_option_with_items(equip2)
	_fill_option_with_items(side1)
	_fill_option_with_items(side2)

	_fill_option(atk_tech, tech_atk)
	_fill_option(def_tech, tech_def)

	save_btn.pressed.connect(_save_loadout)
	reset_btn.pressed.connect(_reset_to_defaults)

func _normalize_id(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	s = s.replace("(temp)", "")
	s = s.replace("temp", "")
	s = s.replace("[temp]", "")
	s = s.replace("(", "").replace(")", "")
	s = s.replace("[", "").replace("]", "")
	s = s.strip_edges()
	if s.find(" ") != -1:
		var parts := s.split(" ", false)
		if parts.size() > 0:
			s = parts[parts.size()-1]
	var cleaned := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			cleaned += ch
	return cleaned

func _load_entity_preview(raw_id: String) -> Texture2D:
	var id := _normalize_id(raw_id)
	if PREVIEW_ALIASES.has(id):
		id = String(PREVIEW_ALIASES[id])

	# Robust filename fallback (supports gold.png, gold_01.png, etc.)
	var candidates := [
		PREVIEW_256_DIR + id + ".png",
		PREVIEW_256_DIR + id + "_01.png",
		PREVIEW_256_DIR + id + "_1.png",
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _fill_option_with_items(ob: OptionButton) -> void:
	ob.clear()
	for it in items:
		ob.add_item(String(it.get("name", it.get("id",""))))

func _fill_option(ob: OptionButton, arr: Array) -> void:
	ob.clear()
	for t in arr:
		ob.add_item(String(t.get("name", t.get("id",""))))

func _load_saved_or_defaults() -> void:
	var path := "user://loadout.json"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var txt := f.get_as_text()
		var data = JSON.parse_string(txt)
		if typeof(data) == TYPE_DICTIONARY:
			_apply_loadout_dict(data)
			_update_status("Loaded saved loadout.")
			return
	_reset_to_defaults()

func _reset_to_defaults() -> void:
	if entities.size() > 0:
		entity_list.select(0)
		_on_entity_selected(0)
	if homunculi.size() > 0:
		homunculus_list.select(0)
		_on_homunculus_selected(0)
	if items.size() >= 2:
		equip1.select(0)
		equip2.select(1 if items.size() > 1 else 0)
		side1.select(0)
		side2.select(1 if items.size() > 1 else 0)
	if tech_atk.size() > 0:
		atk_tech.select(0)
	if tech_def.size() > 0:
		def_tech.select(0)
	_update_status("Defaults set.")

func _apply_loadout_dict(d: Dictionary) -> void:
	var ent_id := String(d.get("entity_id",""))
	var ent_idx := _find_idx_by_id(entities, ent_id)
	if ent_idx >= 0:
		entity_list.select(ent_idx)
		_on_entity_selected(ent_idx)

	var hom_id := String(d.get("homunculus_id",""))
	var hom_idx := _find_idx_by_id(homunculi, hom_id)
	if hom_idx >= 0:
		homunculus_list.select(hom_idx)
		_on_homunculus_selected(hom_idx)

	_select_option_by_text(equip1, String(d.get("equip1","")))
	_select_option_by_text(equip2, String(d.get("equip2","")))
	_select_option_by_text(side1, String(d.get("side1","")))
	_select_option_by_text(side2, String(d.get("side2","")))

	_select_option_by_text(atk_tech, String(d.get("atk_tech","")))
	_select_option_by_text(def_tech, String(d.get("def_tech","")))

func _find_idx_by_id(arr: Array, id: String) -> int:
	for i in range(arr.size()):
		if String(arr[i].get("id","")) == id:
			return i
	return -1

func _select_option_by_text(ob: OptionButton, text: String) -> void:
	if text == "":
		return
	for i in range(ob.item_count):
		if ob.get_item_text(i) == text:
			ob.select(i)
			return

func _on_entity_selected(idx: int) -> void:
	if idx < 0 or idx >= entities.size():
		return
	var e: Dictionary = entities[idx]
	var raw_id := String(e.get("id",""))
	var display_name := String(e.get("name", e.get("id","")))
	entity_name.text = display_name

	var tlist: Array = []
	var _t = e.get("types", [])
	if typeof(_t) == TYPE_ARRAY:
		tlist = _t
	var types_str := ""
	if tlist.size() > 0:
		types_str = ", ".join(tlist)

	entity_desc.text = "[b]Types:[/b] %s\n[b]Base:[/b] HP %s | ATK %s | DEF %s\n[b]Desc:[/b] %s" % [
		types_str,
		str(e.get("hp", "?")),
		str(e.get("atk", "?")),
		str(e.get("def", "?")),
		str(e.get("desc", ""))
	]

	entity_preview.texture = _load_entity_preview(raw_id)

func _on_homunculus_selected(idx: int) -> void:
	if idx < 0 or idx >= homunculi.size():
		return
	var h: Dictionary = homunculi[idx]
	homunculus_name.text = String(h.get("name", h.get("id","")))
	homunculus_desc.text = String(h.get("desc", ""))

func _save_loadout() -> void:
	var d := _current_loadout_dict()
	var path := "user://loadout.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t"))
	_update_status("Saved to user://loadout.json")

func _current_loadout_dict() -> Dictionary:
	var ent_id := ""
	if entity_list.get_selected_items().size() > 0:
		ent_id = String(entities[entity_list.get_selected_items()[0]].get("id",""))
	var hom_id := ""
	if homunculus_list.get_selected_items().size() > 0:
		hom_id = String(homunculi[homunculus_list.get_selected_items()[0]].get("id",""))
	return {
		"entity_id": ent_id,
		"homunculus_id": hom_id,
		"equip1": equip1.get_item_text(equip1.selected) if equip1.selected >= 0 else "",
		"equip2": equip2.get_item_text(equip2.selected) if equip2.selected >= 0 else "",
		"side1": side1.get_item_text(side1.selected) if side1.selected >= 0 else "",
		"side2": side2.get_item_text(side2.selected) if side2.selected >= 0 else "",
		"atk_tech": atk_tech.get_item_text(atk_tech.selected) if atk_tech.selected >= 0 else "",
		"def_tech": def_tech.get_item_text(def_tech.selected) if def_tech.selected >= 0 else "",
	}

func _update_status(msg: String) -> void:
	status_label.text = msg
