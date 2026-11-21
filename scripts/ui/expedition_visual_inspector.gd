extends PanelContainer

const PHASES := ["EXPLORE", "COMBAT", "INSPIRATION", "REWARD", "ROUTE", "LOSS", "EXIT"]
const BACKGROUNDS := "res://assets/entities/expeditions/backgrounds/"
var host: Control
var enemies: Array = []
var homunculi: Array = []
var backgrounds: Array[String] = []
var phase_index := 0
var enemy_index := 0
var hom_index := 0
var background_index := 0
var phase_picker: OptionButton
var enemy_picker: OptionButton
var hom_picker: OptionButton
var background_picker: OptionButton
var asset_label: Label
var minimize_button: Button

func configure(scene: Control) -> void:
	host = scene
	if not _allowed(): return
	var enemy_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/expedition_enemies.json"))
	var hom_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/expedition_homunculi.json"))
	if enemy_data is Dictionary: enemies = enemy_data.get("enemies", [])
	if hom_data is Dictionary: homunculi = hom_data.get("homunculi", [])
	var directory := DirAccess.open(BACKGROUNDS)
	if directory != null:
		for filename in directory.get_files():
			if filename.ends_with(".ogv"): backgrounds.append(filename)
	backgrounds.sort()
	_build()
	_refresh()

func _allowed() -> bool:
	return is_instance_valid(host) and host.visual_debug and host._visual_debug_allowed()

func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.08, 0.94)
	style.border_color = Color("4faebc")
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	minimize_button = Button.new()
	minimize_button.name = "MinimizeInspector"
	minimize_button.text = "Minimize · F8"
	minimize_button.tooltip_text = "Minimize inspector (F8)"
	_style_button(minimize_button)
	minimize_button.pressed.connect(func(): host._set_visual_debug_view(1))
	row.add_child(minimize_button)
	phase_picker = OptionButton.new()
	phase_picker.add_theme_font_size_override("font_size", 18)
	for phase in PHASES: phase_picker.add_item(phase)
	phase_picker.item_selected.connect(set_phase)
	row.add_child(phase_picker)
	enemy_picker = _selector(row, "Enemy", enemies.map(func(e): return str(e.get("name", e.get("id", "")))), select_enemy)
	hom_picker = _selector(row, "Hom", homunculi.map(func(h): return str(h.get("name", h.get("id", "")))), select_hom)
	background_picker = _selector(row, "OGV", backgrounds, select_background)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	box.add_child(actions)
	var loadout_preview := Button.new()
	loadout_preview.name = "LoadoutPreview"
	loadout_preview.text = "Loadout preview"
	_style_button(loadout_preview)
	loadout_preview.pressed.connect(_preview_loadout)
	actions.add_child(loadout_preview)
	for entry in [["Suspense", "suspense"], ["Failure", "failure"], ["Success popup", "success"], ["Duplicate +20 XP", "duplicate"], ["Crystal popup", "crystal"], ["Exit dialog", "exit"]]:
		var button := Button.new()
		button.text = entry[0]
		_style_button(button)
		button.pressed.connect(preview_action.bind(entry[1]))
		actions.add_child(button)
	asset_label = Label.new()
	asset_label.add_theme_font_size_override("font_size", 16)
	asset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(asset_label)

func _preview_loadout() -> void:
	if not _allowed(): return
	var previous := SceneRouter._expedition_context.duplicate(true)
	SceneRouter._expedition_context = {"loadout":true, "visual_preview":true, "player_id":"visual-preview"}
	var preview := preload("res://scenes/LoadoutGrid.tscn").instantiate()
	preview.name = "ExpeditionLoadoutPreview"
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.z_index = 500
	host.add_child(preview)
	SceneRouter._expedition_context = previous

func _selector(row: HBoxContainer, title: String, labels: Array, callback: Callable) -> OptionButton:
	var caption := Label.new()
	caption.text = title
	row.add_child(caption)
	var previous := Button.new()
	previous.text = "‹"
	previous.custom_minimum_size.x = 32
	_style_button(previous)
	row.add_child(previous)
	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", 18)
	picker.custom_minimum_size.x = 220 if title != "OGV" else 360
	for i in labels.size(): picker.add_item("%d/%d %s" % [i + 1, labels.size(), str(labels[i])])
	picker.item_selected.connect(callback)
	row.add_child(picker)
	previous.pressed.connect(func(): if picker.item_count > 0: callback.call((picker.selected - 1 + picker.item_count) % picker.item_count))
	var next := Button.new()
	next.text = "›"
	next.custom_minimum_size.x = 32
	_style_button(next)
	row.add_child(next)
	next.pressed.connect(func(): if picker.item_count > 0: callback.call((picker.selected + 1) % picker.item_count))
	return picker

func _style_button(button: Button) -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("152d35")
	frame.border_color = Color("4faebc")
	frame.set_border_width_all(1)
	frame.set_content_margin_all(5)
	button.add_theme_stylebox_override("normal", frame)
	var hover := frame.duplicate() as StyleBoxFlat
	hover.bg_color = Color("28505a")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_font_size_override("font_size", 18)

func set_phase(index: int) -> void:
	if not _allowed() or index < 0 or index >= PHASES.size(): return
	phase_index = index
	phase_picker.select(index)
	_refresh()

func select_enemy(index: int) -> void:
	if not _allowed() or index < 0 or index >= enemies.size(): return
	enemy_index = index
	enemy_picker.select(index)
	_refresh()

func select_hom(index: int) -> void:
	if not _allowed() or index < 0 or index >= homunculi.size(): return
	hom_index = index
	hom_picker.select(index)
	_refresh()

func select_background(index: int) -> void:
	if not _allowed() or index < 0 or index >= backgrounds.size(): return
	background_index = index
	background_picker.select(index)
	_refresh()

func _refresh() -> void:
	if not _allowed() or enemies.is_empty() or homunculi.is_empty() or backgrounds.is_empty():
		if is_instance_valid(asset_label): asset_label.text = "Missing expedition manifest or OGV assets"
		return
	var enemy: Dictionary = enemies[enemy_index]
	if is_instance_valid(host.exit_confirmation): host.exit_confirmation.hide()
	var hom: Dictionary = homunculi[hom_index]
	var paths := [str(enemy.get("preview_texture", "")), str(enemy.get("texture", "")), str(hom.get("preview_texture", "")), str(hom.get("combat_texture", "")), BACKGROUNDS + backgrounds[background_index]]
	var missing: Array[String] = []
	for path in paths:
		if not ResourceLoader.exists(path): missing.append(path)
	host.debug_render(_sample())
	if host.background_key != backgrounds[background_index]: missing.append(BACKGROUNDS + backgrounds[background_index])
	if PHASES[phase_index] == "EXPLORE" and host.body.get_child_count() > 0:
		var row: Node = host.body.get_child(0)
		if row.get_child_count() > 0 and (row.get_child(0).get_child(0).get_child(0) as TextureRect).texture == null: missing.append(str(enemy.preview_texture))
	if PHASES[phase_index] in ["COMBAT", "INSPIRATION", "EXIT"] and is_instance_valid(host.combat_view):
		if host.combat_view.enemy_sprite.texture == null: missing.append(str(enemy.texture))
		if host.combat_view.player_hom_sprite.texture == null: missing.append(str(hom.combat_texture))
	if PHASES[phase_index] == "REWARD" and (not is_instance_valid(host.capture_sprite) or host.capture_sprite.texture == null): missing.append(str(hom.combat_texture))
	asset_label.text = "%s  |  %d/%d %s (%s)  |  %d/%d %s (%s)  |  %d/%d %s\n%s" % [PHASES[phase_index], enemy_index + 1, enemies.size(), str(enemy.get("name", "")), str(enemy.get("id", "")), hom_index + 1, homunculi.size(), str(hom.get("name", "")), str(hom.get("id", "")), background_index + 1, backgrounds.size(), backgrounds[background_index], "MISSING: " + ", ".join(missing) if not missing.is_empty() else "Preview / gameplay assets available"]
	if PHASES[phase_index] == "EXIT": host.exit_confirmation.popup_centered()

func _sample() -> Dictionary:
	var enemy: Dictionary = enemies[enemy_index]
	var other: Dictionary = enemies[(enemy_index + 1) % enemies.size()]
	var hom: Dictionary = homunculi[hom_index]
	var phase: String = PHASES[phase_index]
	var inspiration := phase == "INSPIRATION"
	var player := {"id":"sulfur_01", "type":"sulfur", "hp":78, "max_hp":104, "hom_id":hom.id, "hom_energy":4, "inspiration":2, "inspiration_used":false, "inspiration_pending":inspiration, "inspiration_offers":["steady_script", "ward_glyph", "rift_touch"], "spell_ids":["cinder_fist", "furnace_rush", "ash_temper", "brimstone_crash"], "cooldowns":{"furnace_rush":2}, "status":{"shield":0.15, "hom_stun":1}, "expedition_passive":{"markers":["sample_marker"], "modifiers":[{"kind":"power_flat", "amount":2, "duration":"exchange"}]}}
	var npc := {"id":enemy.id, "type":enemy.types[0], "expedition_types":enemy.types, "texture":enemy.texture, "hom_id":hom.id, "hom_texture":hom.combat_texture, "hom_type":hom.type, "hom_energy":4, "hp":67, "max_hp":100, "status":{"poison":2, "vuln":0.1}, "inspiration":1}
	var choices := []
	for i in 2:
		var e: Dictionary = enemy if i == 0 else other
		choices.append({"choice":i, "id":e.id, "name":e.name, "types":e.types, "preview_texture":e.preview_texture})
	var candidate := {"id":hom.id, "name":hom.name, "type":hom.type, "rarity":hom.rarity, "preview_texture":hom.preview_texture}
	return {"run_id":"visual-only", "status":"LOSS" if phase == "LOSS" else "ACTIVE", "revision":1, "phase":"COMBAT" if phase in ["COMBAT", "INSPIRATION", "EXIT"] else phase, "background_key":backgrounds[background_index], "choices":choices, "directions":["left", "forward", "right"], "loadout":{"homunculus_id":hom.id}, "reward_homunculus":{"id":hom.id,"type":hom.type,"preview_texture":hom.preview_texture,"combat_texture":hom.combat_texture}, "capture_candidate":candidate, "capture_closed":false, "capture_attempts_remaining":2, "combat_state":{"turn":3, "player":player, "npc":npc, "weapons":[{"id":"bismuth_talisman"}, {"id":"wind_amulet"}], "active_weapon_slot":1, "terminal_result":null}, "battle_log":[{"kind":"spell", "actor":"player", "spell_id":"cinder_fist"}, {"kind":"damage", "actor":"player", "amount":18}]}

func preview_action(action: String) -> void:
	if not _allowed(): return
	if action == "exit":
		host.exit_confirmation.popup_centered()
		return
	if action in ["suspense", "failure"]:
		if PHASES[phase_index] != "REWARD": set_phase(PHASES.find("REWARD"))
		if action == "failure":
			host._set_capture_heading("EXPEDITION_CAPTURE_FAILED")
			host.message.text = host.tr("EXPEDITION_CAPTURE_FAILED")
		else:
			host._start_capture_animation()
			var epoch: int = host.playback_epoch
			get_tree().create_timer(3.0).timeout.connect(func():
				if _allowed() and host.playback_epoch == epoch:
					host.playing_events = false
					host._stop_capture_animation())
		return
	var hom: Dictionary = homunculi[hom_index]
	if action == "crystal":
		host.debug_popup(host.tr("EXPEDITION_CRYSTAL_GAINED"), host._texture("res://assets/entities/expeditions/capture.png", "res://assets/entities/expeditions/"), "+1")
	elif action in ["success", "duplicate"]:
		host.debug_popup(host.tr("EXPEDITION_DUPLICATE_XP" if action == "duplicate" else "EXPEDITION_CAPTURE_SUCCESS"), host._texture(str(hom.preview_texture), "res://assets/entities/gameplay/homunculus/"), str(hom.name))
