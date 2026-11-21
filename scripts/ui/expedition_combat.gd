extends Control

const TypeIcon := preload("res://scripts/ui/combat_type_icon.gd")
const StatusIcons := preload("res://scripts/ui/combat_status_icons.gd")
const Inspiration := preload("res://scripts/ui/combat_inspiration.gd")
const HomStatus := preload("res://scripts/ui/combat_hom_status.gd")
const SpellView := preload("res://scripts/ui/spell_presentation.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
const LogPresenter := preload("res://scripts/ui/combat_log_presenter.gd")

class GroundShadow extends Control:
	func _draw() -> void:
		# Concentric translucent ellipses give the edge a soft fade.
		draw_set_transform(size * 0.5, 0.0, size * 0.5)
		for i in 16:
			draw_circle(Vector2.ZERO, 1.0 - i / 16.0, Color(0, 0, 0, 0.085), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)

var log_presenter := LogPresenter.new()
var host: Control
var session := {}
var registry: Node
var controls: Array[BaseButton] = []
var spell_buttons: Array[Button] = []
var weapon_buttons: Array[Button] = []
var inspiration_buttons: Array[Button] = []
var decline_button: Button
var hom_attack: Button
var player_sprite: TextureRect
var player_hom_sprite: TextureRect
var enemy_sprite: TextureRect
var enemy_hom_sprite: TextureRect
var player_hp: ProgressBar
var enemy_hp: ProgressBar
var log: RichTextLabel
var animation_tweens := {}
var animation_original := {}
var displayed_weapon_slot := 0

func _exit_tree() -> void:
	if is_instance_valid(registry): registry.free()

func configure(scene: Control, data: Dictionary) -> void:
	host = scene
	session = data.duplicate(true)
	registry = preload("res://scripts/data_registry.gd").new()
	_build()

const ITEM_ICONS := {"bismuth_talisman":"talisman_bismuth.png", "wind_amulet":"wind_amulet.png", "saltstone_charm":"saltstone_charm.png", "mirror_sigel":"mirror.png", "vitriol_vial":"vitriol.png", "gilded_scale":"gilded_scale.png", "mercury_lens":"mercury_lens.png", "aether_knot":"aether_knot.png"}
var stage: Control
var shadow_layer: Control

func _place(node: Control, pos: Vector2, dimensions: Vector2) -> void:
	stage.add_child(node)
	node.position = pos
	node.size = dimensions

func _fit_stage() -> void:
	if not is_instance_valid(stage): return
	var factor := minf(size.x / 1920.0, size.y / 900.0)
	stage.scale = Vector2.ONE * factor
	stage.position = Vector2((size.x - 1920.0 * factor) / 2.0, 0)

func _build() -> void:
	var state: Dictionary = session.get("combat_state", {})
	var player: Dictionary = state.get("player", {})
	var enemy: Dictionary = state.get("npc", {})
	stage = Control.new()
	stage.name = "CombatPresentation"
	stage.size = Vector2(1920, 900)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(_fit_stage)
	_fit_stage()
	shadow_layer = Control.new()
	shadow_layer.name = "GroundShadows"
	shadow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow_layer.size = Vector2(1920, 900)
	stage.add_child(shadow_layer)
	_fighter(player, false, state)
	_fighter(enemy, true, state)
	var log_panel := PanelContainer.new()
	log_panel.name = "BattleLog"
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.01, 0.025, 0.04, 0.92)
	log_style.border_color = Color("b9a66c")
	log_style.set_border_width_all(2)
	log_style.set_content_margin_all(8)
	log_panel.add_theme_stylebox_override("panel", log_style)
	_place(log_panel, Vector2(650, 665), Vector2(620, 210))
	var log_box := VBoxContainer.new()
	log_panel.add_child(log_box)
	var heading := Label.new()
	heading.text = "%s  %d" % [tr("EXPEDITION_TURN"), int(state.get("turn", 0))]
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_box.add_child(heading)
	log = RichTextLabel.new()
	log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log.scroll_following = true
	log.add_theme_font_size_override("normal_font_size", 18)
	log_box.add_child(log)
	log.meta_clicked.connect(_log_spell_clicked)
	log.meta_hover_started.connect(_log_spell_hover)
	log.meta_hover_ended.connect(func(_meta): log.tooltip_text = "")
	for event in session.get("battle_log", []):
		if event is Dictionary: _append_event(event)
	var equipped: Array = state.get("weapons", [])
	var active := int(state.get("active_weapon_slot", 0))
	displayed_weapon_slot = active
	for i in 2:
		var item_id := str(equipped[i].get("id", "")) if i < equipped.size() and equipped[i] is Dictionary and equipped[i].get("id") != null else ""
		var item: Dictionary = registry.get_items().get(item_id, {})
		var button := Button.new()
		button.name = "WeaponSlot%d" % (i + 1)
		button.flat = true
		button.tooltip_text = GameLocalization.catalog("item", item_id, "name", str(item.get("name", item_id)))
		button.disabled = item_id.is_empty() or active == i + 1 or bool(player.get("inspiration_pending", false))
		button.pressed.connect(_switch.bind(i + 1))
		_place(button, Vector2(400 + i * 112, 765), Vector2(104, 104))
		var frame := TextureRect.new()
		frame.texture = preload("res://assets/ui/new-elements/marco-slot-small.png")
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.modulate = Color.WHITE if active == i + 1 else Color(0.6, 0.6, 0.6)
		button.add_child(frame)
		var icon := TextureRect.new()
		var path := "res://assets/entities/builds/" + str(ITEM_ICONS.get(item_id, item_id + ".png"))
		if not item_id.is_empty() and ResourceLoader.exists(path): icon.texture = load(path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 16; icon.offset_top = 16; icon.offset_right = -16; icon.offset_bottom = -16
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		weapon_buttons.append(button)
		controls.append(button)
	# Draw only equipment supplied by the server.
	var npc_weapons: Variant = enemy.get("weapons", [])
	if npc_weapons is Array:
		for i in mini(npc_weapons.size(), 2):
			var entry: Variant = npc_weapons[i]
			var item_id := str(entry.get("id", "")) if entry is Dictionary and entry.get("id") != null else ""
			if item_id.is_empty(): continue
			var item: Dictionary = registry.get_items().get(item_id, {})
			var slot := Control.new()
			slot.name = "EnemyWeaponSlot%d" % (i + 1)
			slot.tooltip_text = "%s  |  +%d" % [GameLocalization.catalog("item", item_id, "name", str(item.get("name", item_id))), int(entry.get("level", 0))]
			_place(slot, Vector2(1296 + i * 112, 765), Vector2(104, 104))
			var frame := TextureRect.new()
			frame.texture = preload("res://assets/ui/new-elements/marco-slot-small.png")
			frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(frame)
			var icon := TextureRect.new()
			var path := "res://assets/entities/builds/" + str(ITEM_ICONS.get(item_id, item_id + ".png"))
			if ResourceLoader.exists(path): icon.texture = load(path)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 16; icon.offset_top = 16; icon.offset_right = -16; icon.offset_bottom = -16
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
			var level_label := Label.new()
			level_label.text = "+%d" % int(entry.get("level", 0))
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			level_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			level_label.add_theme_font_size_override("font_size", 17)
			level_label.add_theme_constant_override("outline_size", 3)
			level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(level_label)
	var panel := PanelContainer.new()
	panel.name = "SpellPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.07, 0.08, 0.9)
	panel_style.border_color = Color("68756b")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", panel_style)
	_place(panel, Vector2(660, 0), Vector2(600, 156))
	var grid := GridContainer.new()
	grid.name = "SpellGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	var ids: Array = player.get("spell_ids", [])
	for i in 4:
		var id := str(ids[i]) if i < ids.size() else ""
		var spell: Dictionary = registry.get_spell_by_id(id)
		var cooldown := int(player.get("cooldowns", {}).get(id, 0))
		var button := _spell_button(spell, cooldown)
		button.custom_minimum_size = Vector2(0, 67)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = spell.is_empty() or cooldown > 0 or bool(player.get("inspiration_pending", false))
		button.pressed.connect(_cast.bind(id))
		grid.add_child(button)
		spell_buttons.append(button)
		controls.append(button)
	var switch := Button.new()
	switch.name = "SwitchWeapon"
	switch.text = tr("EXPEDITION_WEAPON") + "  ?"
	var other := 2 if active == 1 else 1
	switch.disabled = other > equipped.size() or (equipped[other - 1] as Dictionary).get("id") == null or bool(player.get("inspiration_pending", false))
	MenuArt.button(switch)
	switch.pressed.connect(_switch.bind(other))
	_place(switch, Vector2(760, 160), Vector2(400, 42))
	controls.append(switch)
	hom_attack = Button.new()
	hom_attack.toggle_mode = true
	MenuArt.button(hom_attack)
	hom_attack.add_theme_stylebox_override("hover_pressed", hom_attack.get_theme_stylebox("pressed"))
	hom_attack.add_theme_font_size_override("font_size", 20)
	hom_attack.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.76))
	hom_attack.text = tr("EXPEDITION_HOM_ATTACK")
	hom_attack.disabled = player.get("hom_id") == null or int(player.get("hom_energy", 0)) < 3 or bool(player.get("inspiration_pending", false))
	hom_attack.tooltip_text = tr("EXPEDITION_HOM_HINT")
	_place(hom_attack, Vector2(20, 788), Vector2(300, 55))
	controls.append(hom_attack)
	if bool(player.get("inspiration_pending", false)):
		var offers := VBoxContainer.new()
		_place(offers, Vector2(580, 300), Vector2(760, 180))
		_build_inspiration(offers, player)

func _add_ground_shadow(sprite: TextureRect, is_hom: bool, enemy: bool) -> void:
	if sprite.texture == null: return
	var shadow := GroundShadow.new()
	shadow.name = ("Enemy" if enemy else "Player") + ("HomShadow" if is_hom else "EntityShadow")
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.size = Vector2(210, 52) if is_hom else Vector2(360, 72)
	shadow.position = Vector2(sprite.position.x + (sprite.size.x - shadow.size.x) * 0.5, sprite.position.y + sprite.size.y - shadow.size.y * 0.5)
	shadow_layer.add_child(shadow)

func _fighter(fighter: Dictionary, enemy: bool, state: Dictionary) -> void:
	var id := str(fighter.get("id", ""))
	var name_text := id
	var path := ""
	if enemy:
		path = str(fighter.get("texture", ""))
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/expedition_enemies.json"))
		if manifest is Dictionary:
			for record in manifest.get("enemies", []):
				if record.get("id") == id: name_text = str(record.get("name", id)); break
	else:
		var entity: Dictionary = registry.get_entities().get(id, {})
		name_text = GameLocalization.catalog("entity", id, "name", str(entity.get("name", id)))
		var element := str(fighter.get("type", ""))
		path = "res://assets/entities/gameplay/ingame-entities/%s/%s_2_5d_1024.png" % [element, element]
	var hom_id := str(fighter.get("hom_id", ""))
	var hom: Dictionary = host._candidate(hom_id) if enemy else registry.get_homunculus_collection().get(hom_id, {})
	var hom_path := str(hom.get("combat_texture", ""))
	if not enemy and hom_path.is_empty():
		var legacy := {"cinder":"Cinder", "chimera":"Chimera", "drakon":"Drakon", "mothy":"Mothy", "nighty":"Nighty", "pyritc":"Pyro", "silphide":"Silphide", "sodium":"Sodi"}
		hom_path = "res://assets/entities/gameplay/homunculus/ingame/1024/%s.png" % str(legacy.get(hom_id, ""))
	if enemy and (fighter.get("hom_texture") != hom.get("combat_texture") or fighter.get("hom_type") != hom.get("type")): hom_path = ""
	var hom_image := TextureRect.new()
	hom_image.name = "EnemyHomunculus" if enemy else "PlayerHomunculus"
	hom_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hom_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hom_image.flip_h = enemy
	hom_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hom_image.texture = host._texture(hom_path, "res://assets/entities/gameplay/homunculus/ingame/1024/") if not hom_path.is_empty() else null
	_place(hom_image, Vector2(1640 if enemy else 40, 445), Vector2(240, 225))
	_add_ground_shadow(hom_image, true, enemy)
	if enemy: enemy_hom_sprite = hom_image
	else: player_hom_sprite = hom_image
	var portrait := TextureRect.new()
	portrait.name = "EnemyEntity" if enemy else "PlayerEntity"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.flip_h = enemy
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = host._texture(path, "res://assets/entities/")
	_place(portrait, Vector2(1200 if enemy else 320, 250), Vector2(420, 420))
	_add_ground_shadow(portrait, false, enemy)
	if enemy: enemy_sprite = portrait
	else: player_sprite = portrait
	var x := 1300.0 if enemy else 400.0
	var title_row := HBoxContainer.new()
	title_row.name = "EnemyNameRow" if enemy else "PlayerNameRow"
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 4)
	_place(title_row, Vector2(x - 70, 665), Vector2(360, 28))
	var types: Array = fighter.get("expedition_types", [fighter.get("type", "")])
	for type_id in types:
		var type_icon := TypeIcon.new()
		title_row.add_child(type_icon)
		type_icon.configure(str(type_id))
	var title := Label.new()
	title.text = name_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_constant_override("outline_size", 3)
	title_row.add_child(title)
	var hp := ProgressBar.new()
	hp.max_value = maxi(1, int(fighter.get("max_hp", 1)))
	hp.value = int(fighter.get("hp", 0))
	hp.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("15232a")
	bg.border_color = Color("b9a66c")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	hp.add_theme_stylebox_override("background", bg)
	_place(hp, Vector2(x, 695), Vector2(220, 24))
	if enemy: enemy_hp = hp
	else: player_hp = hp
	var hp_label := Label.new()
	hp_label.name = "HealthValue"
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 18)
	hp_label.add_theme_constant_override("outline_size", 2)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_child(hp_label)
	_update_hp(hp)
	var icons := StatusIcons.new()
	icons.name = "EnemyStatus" if enemy else "PlayerStatus"
	_place(icons, Vector2(1280 if enemy else 40, 40), Vector2(600, 64))
	var normalized: Dictionary = fighter.get("status", {}).duplicate(true)
	for pair in [["shield", "shield_pct"], ["reflect", "reflect_pct"], ["vuln", "vuln_pct"]]: normalized[pair[1]] = normalized.get(pair[0], 0)
	var extra := []
	for delayed in state.get("strategic_delayed", []):
		if str(delayed.get("target", "")) == ("npc" if enemy else "player"): extra.append({"icon":"hourglass", "label":str(delayed.get("amount", 0)), "tooltip":tr("EXPEDITION_DELAYED") % int(delayed.get("due_turn", 0))})
	for field in ["strategic_trap", "strategic_heal_suppression"]:
		if fighter.has(field): extra.append({"icon":"trap" if field == "strategic_trap" else "heal_block", "label":"%dT" % maxi(0, int(fighter[field].get("expires_turn", 0)) - int(state.get("turn", 0))), "tooltip":field.replace("_", " ").capitalize()})
	var passive: Variant = fighter.get("expedition_passive")
	if passive is Dictionary:
		for marker in passive.get("markers", []):
			extra.append({"icon":"type", "label":"•", "tooltip":str(marker).replace("_", " ").capitalize()})
		for modifier in passive.get("modifiers", []):
			if modifier is Dictionary:
				var modifier_type := str(modifier.get("stat", modifier.get("kind", ""))).replace("_", " ").capitalize()
				var amount := str(modifier.get("amount", ""))
				var duration := str(modifier.get("expires_at", modifier.get("duration", "")))
				extra.append({"icon":"power", "label":amount, "tooltip":"%s: %s  %s" % [modifier_type, amount, duration]})
	var anomaly: Variant = state.get("physical_anomaly")
	if anomaly is Dictionary and not anomaly.is_empty():
		var affinity := str(fighter.get("type", ""))
		var modifier := 15 if affinity == str(anomaly.get("favored_type", "")) else -15 if affinity == str(anomaly.get("weakened_type", "")) else 0
		if modifier != 0: extra.append({"icon":"type", "label":("+" if modifier > 0 else "") + str(modifier) + "%", "tooltip":tr("ANOMALY_TOOLTIP_GAIN") % [GameLocalization.catalog("type", str(anomaly.get("favored_type", "")), "name", str(anomaly.get("favored_type", "")).capitalize()), GameLocalization.catalog("type", str(anomaly.get("weakened_type", "")), "name", str(anomaly.get("weakened_type", "")).capitalize()), int(anomaly.get("remaining_exchanges", 0))]})
	icons.set_boss_effects(true, extra)
	icons.set_fighter(0, {"status":normalized, "spell_neutralize_active":fighter.get("spell_neutralize_active", 0), "spell_neutralize_pending":fighter.get("spell_neutralize_pending", 0)})
	var inspiration := Inspiration.new()
	_place(inspiration, Vector2(x, 725), Vector2(200, 26))
	inspiration.set_fighter({"inspiration":fighter.get("inspiration", 0), "inspiration_used_this_battle":fighter.get("inspiration_used", false)})
	if not hom_id.is_empty() and not hom_path.is_empty():
		var meter := HomStatus.new()
		meter.name = "EnemyHomunculusMeter" if enemy else "PlayerHomunculusMeter"
		_place(meter, Vector2(1670 if enemy else 30, 690), Vector2(240, 90))
		meter.scale = Vector2(0.9, 0.9)
		var hom_name := GameLocalization.catalog("homunculus", hom_id, "name", str(hom.get("name", hom_id)))
		var hom_passive: Variant = hom.get("passive", {})
		var passive_name := ""
		if hom_passive is Dictionary and hom_passive.get("name") is Dictionary:
			passive_name = str(hom_passive.name.get(TranslationServer.get_locale().substr(0, 2), hom_passive.name.get("en", "")))
		meter.set_fighter({"hom_name":hom_name, "hom_energy":clampi(int(fighter.get("hom_energy", 0)), 0, 6)})
		meter.set_expedition_type(str(hom.get("type", fighter.get("hom_type", ""))), passive_name)
		meter.size = Vector2(190, 90)

func _update_hp(hp: ProgressBar) -> void:
	var ratio := hp.value / hp.max_value
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.2) if ratio < 0.25 else Color(0.95, 0.8, 0.2) if ratio < 0.5 else Color(0.2, 0.85, 0.35)
	fill.set_corner_radius_all(3)
	hp.add_theme_stylebox_override("fill", fill)
	(hp.get_node("HealthValue") as Label).text = "%d / %d HP" % [int(hp.value), int(hp.max_value)]

func _spell_button(spell: Dictionary, cooldown: int = 0) -> Button:
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.76))
	button.custom_minimum_size = Vector2(230, 90)
	var id := str(spell.get("id", ""))
	button.text = "%s\n%s  |  %s%%  |  CD %d" % [GameLocalization.catalog("spell", id, "name", str(spell.get("name", id))), str(roundi(float(spell.get("power_mult", 0)) * 100)) + "%", roundi(float(spell.get("accuracy", 0)) * 100), cooldown]
	button.tooltip_text = SpellView.detail(spell, "Equipped") if not spell.is_empty() else ""
	button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not spell.is_empty(): _details(spell))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.19, 0.20, 0.20, 0.85) if state == "hover" else Color(0.09, 0.09, 0.10, 0.8) if state == "disabled" else Color(0.12, 0.13, 0.14, 0.8)
		style.border_color = Color("65776b") if state != "disabled" else Color("343e38")
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.set_content_margin_all(4)
		button.add_theme_stylebox_override(state, style)
	var types := [spell.get("primary_type"), spell.get("secondary_type")] if spell.get("type") == "hybrid" else [spell.get("type", "universal")]
	for i in types.size():
		var icon := TypeIcon.new()
		icon.position = Vector2(5 + 25 * i, 3)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		icon.configure(str(types[i]))
	return button

func _details(spell: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.borderless = true
	dialog.transparent = true
	dialog.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	dialog.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	dialog.title = GameLocalization.catalog("spell", str(spell.get("id", "")), "name", str(spell.get("name", "")))
	dialog.dialog_text = dialog.title + "\n\n" + SpellView.detail(spell, "Equipped")
	dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.get_label().vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.get_label().add_theme_font_size_override("font_size", 24)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(700, 550))

func _build_inspiration(main: VBoxContainer, player: Dictionary) -> void:
	var offers: Variant = player.get("inspiration_offers", [])
	if not offers is Array or offers.size() != 3: return
	var title := Label.new()
	title.text = tr("EXPEDITION_INSPIRATION")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(title)
	var row := HBoxContainer.new()
	main.add_child(row)
	for offer in offers:
		var id := str(offer)
		var spell: Dictionary = registry.get_spell_by_id(id)
		var button := _spell_button(spell)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = spell.is_empty()
		button.pressed.connect(func(): host.send_combat_decision("inspiration", {"kind":"choose", "spell_id":id}))
		row.add_child(button)
		controls.append(button)
		inspiration_buttons.append(button)
	var decline := Button.new()
	decline.add_theme_font_size_override("font_size", 20)
	decline.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.76))
	decline_button = decline
	decline.text = tr("EXPEDITION_DECLINE")
	MenuArt.button(decline)
	decline.pressed.connect(func(): host.send_combat_decision("inspiration", {"kind":"decline"}))
	row.add_child(decline)
	controls.append(decline)

func _cast(id: String) -> void:
	var state: Dictionary = session.get("combat_state", {})
	var decision := {"turn": int(state.get("turn", 0)) + 1, "spell_id":id, "hom_action":"attack" if hom_attack.button_pressed else "hold"}
	host.send_combat_decision("turn", decision)

func _switch(slot: int) -> void:
	host.send_combat_decision("turn", {"turn":int(session.get("combat_state", {}).get("turn", 0)) + 1, "switch_slot":slot})

func lock_controls() -> void:
	for control in controls: control.disabled = true

func _append_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	var actor := str(event.get("actor", event.get("side", "")))
	var event_key := "EXPEDITION_EVENT_" + kind.to_upper()
	var translated := tr(event_key)
	if translated == event_key: translated = kind.replace("_", " ").capitalize()
	var category := "switch" if kind == "switch" else "miss" if kind in ["miss", "evade", "hom_miss"] or (kind == "spell" and not bool(event.get("hit", true))) else "homunculus" if kind in ["hom_attack", "hom_dot", "hom_passive"] else "damage" if kind in ["damage", "poison", "true_on_hit", "dot_true", "delayed_damage"] else "heal" if kind == "heal" else "debuff" if kind == "status_applied" else "inspiration" if kind.begins_with("inspiration") else "system"
	var formatted := {"category":category, "actor":tr("EXPEDITION_PLAYER" if actor == "player" else "EXPEDITION_ENEMY") if actor in ["player", "npc"] else translated, "actor_color":"69d7e8" if actor == "player" else "f2a078" if actor == "npc" else "cdd3d9", "verb":(": " + translated) if actor in ["player", "npc"] else ""}
	if event.has("spell_id"):
		var id := str(event.spell_id)
		var spell: Dictionary = registry.get_spell_by_id(id)
		formatted.verb += " - "
		formatted["spell_id"] = id
		formatted["spell_name"] = str(spell.get("name", id))
	var suffix := ""
	if event.has("status"):
		var status_id := str(event.status)
		suffix += " - " + GameLocalization.catalog("status_name", status_id, "name", status_id.replace("_", " ").capitalize())
	if event.has("item_id"):
		var item_id := str(event.item_id)
		var item: Dictionary = registry.get_items().get(item_id, {})
		suffix += " - " + GameLocalization.catalog("item", item_id, "name", str(item.get("name", item_id)))
	if event.has("passive_id"): suffix += " - " + str(event.passive_id).replace("_", " ").capitalize()
	if event.get("target") in ["player", "npc"]: suffix += " - " + tr("EXPEDITION_PLAYER" if event.target == "player" else "EXPEDITION_ENEMY")
	for field in ["amount", "actual_damage", "damage", "actual_bonus_damage", "value"]:
		if event.has(field) and (event[field] is int or event[field] is float):
			suffix += " (%s)" % str(event[field])
			break
	if event.has("hp") and (event.hp is int or event.hp is float): suffix += " - HP %s" % str(event.hp)
	if event.has("source"): suffix += " [%s]" % str(event.source).replace("_", " ")
	if kind == "spell" and not bool(event.get("hit", true)): suffix += " - " + tr("EXPEDITION_MISS")
	formatted["suffix"] = suffix
	log_presenter.append(log, int(event.get("turn", -1)), "", formatted)

func _log_spell_clicked(meta: Variant) -> void:
	var spell: Dictionary = registry.get_spell_by_id(str(meta))
	if not spell.is_empty(): _details(spell)

func _log_spell_hover(meta: Variant) -> void:
	var spell: Dictionary = registry.get_spell_by_id(str(meta))
	log.tooltip_text = SpellView.detail(spell, "Equipped") if not spell.is_empty() else ""

# Presentation only. Keep each node's original transform when events overlap.
func _begin_animation(node: Control) -> Tween:
	if not animation_original.has(node):
		animation_original[node] = {"position":node.position, "scale":node.scale, "modulate":node.modulate}
	if animation_tweens.has(node) and is_instance_valid(animation_tweens[node]):
		animation_tweens[node].kill()
	var original: Dictionary = animation_original[node]
	node.position = original.position
	node.scale = original.scale
	node.modulate = original.modulate
	var tween := create_tween()
	animation_tweens[node] = tween
	return tween

func _animate_lunge(node: Control, distance: float) -> void:
	if not is_instance_valid(node): return
	var tween := _begin_animation(node)
	var original: Dictionary = animation_original[node]
	tween.tween_property(node, "position", original.position + Vector2(distance, 0), 0.22)
	tween.tween_property(node, "position", original.position, 0.28)

func _animate_pulse(node: Control, color: Color, factor: float = 1.05) -> void:
	if not is_instance_valid(node): return
	var tween := _begin_animation(node)
	var original: Dictionary = animation_original[node]
	tween.set_parallel(true)
	tween.tween_property(node, "scale", original.scale * factor, 0.22)
	tween.tween_property(node, "modulate", original.modulate.lerp(color, 0.55), 0.22)
	tween.chain().tween_property(node, "scale", original.scale, 0.28)
	tween.parallel().tween_property(node, "modulate", original.modulate, 0.28)

func _animate_item(slot: int) -> void:
	if slot < 1 or slot > weapon_buttons.size(): return
	var button := weapon_buttons[slot - 1]
	if button.get_child_count() < 2: return
	var icon := button.get_child(1) as TextureRect
	if icon != null and icon.texture != null:
		icon.pivot_offset = icon.size / 2.0
		_animate_pulse(icon, Color(1.8, 1.6, 0.8), 1.12)

func _animate_npc_item() -> void:
	var slot := stage.get_node_or_null("EnemyWeaponSlot1") as Control
	if not is_instance_valid(slot) or slot.get_child_count() < 2: return
	var icon := slot.get_child(1) as TextureRect
	if icon != null and icon.texture != null:
		icon.pivot_offset = icon.size / 2.0
		_animate_pulse(icon, Color(1.8, 1.6, 0.8), 1.12)

func _animate_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	var actor := str(event.get("actor", ""))
	var target := str(event.get("side", event.get("target", "")))
	if target not in ["player", "npc"] and actor in ["player", "npc"] and kind in ["damage", "hom_attack", "hom_dot", "true_on_hit", "dot_true", "delayed_damage"]:
		target = "npc" if actor == "player" else "player"
	if kind == "spell" and actor in ["player", "npc"]:
		var spell: Dictionary = registry.get_spell_by_id(str(event.get("spell_id", "")))
		var sprite := player_sprite if actor == "player" else enemy_sprite
		if str(spell.get("category", "")) == "attack": _animate_lunge(sprite, 20.0 if actor == "player" else -20.0)
		else: _animate_pulse(sprite, Color(0.68, 0.85, 1.0))
	elif kind in ["hom_attack", "hom_miss"] and actor in ["player", "npc"]:
		_animate_lunge(player_hom_sprite if actor == "player" else enemy_hom_sprite, 14.0 if actor == "player" else -14.0)
	elif kind == "evade" and actor in ["player", "npc"]:
		_animate_lunge(player_sprite if actor == "player" else enemy_sprite, -12.0 if actor == "player" else 12.0)
		if actor == "player": _animate_item(displayed_weapon_slot)
	if kind == "switch" and actor == "player":
		displayed_weapon_slot = int(event.get("slot", displayed_weapon_slot))
		_animate_item(displayed_weapon_slot)
	elif kind in ["true_on_hit", "dot_true"] and actor == "player":
		_animate_item(displayed_weapon_slot)
	elif actor == "npc" and event.get("item_id") == session.get("combat_state", {}).get("npc", {}).get("item_id") and (kind in ["true_on_hit", "dot_true"] or event.get("source") == "weapon"):
		_animate_npc_item()
	if target in ["player", "npc"]:
		var sprite := player_sprite if target == "player" else enemy_sprite
		if kind in ["damage", "hom_attack", "hom_dot", "true_on_hit", "dot_true", "delayed_damage", "reflect", "poison", "ward_convert", "recoil"]:
			_animate_pulse(sprite, Color(1.8, 0.35, 0.35), 1.02)
		elif kind in ["heal", "status_applied"]:
			_animate_pulse(sprite, Color(0.68, 1.0, 0.75))

func _event_delay(kind: String) -> float:
	if kind in ["spell", "hom_attack", "hom_miss", "damage", "heal", "evade", "miss", "switch"]:
		return 0.65
	if kind in ["poison", "hom_dot", "true_on_hit", "dot_true", "delayed_damage", "reflect", "ward_convert", "recoil", "status_applied", "hom_passive"]:
		return 0.5
	return 0.3

func _show_damage_number(sprite: Control, damage: int) -> void:
	if damage <= 0 or not is_instance_valid(sprite): return
	var label := Label.new()
	label.text = "-%d" % damage
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.18, 0.18))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(120, 40)
	label.top_level = true
	add_child(label)
	var offset := 0
	for child in get_children():
		if child is Label and child.has_meta("floating_damage") and child.get_meta("floating_damage") == sprite.get_instance_id(): offset += 1
	label.set_meta("floating_damage", sprite.get_instance_id())
	var rect := sprite.get_global_transform() * Rect2(Vector2.ZERO, sprite.size)
	var viewport_rect := get_viewport_rect()
	var pos := Vector2(rect.get_center().x - 60.0, rect.position.y - 42.0 - (offset % 4) * 18.0)
	pos.x = clampf(pos.x, viewport_rect.position.x, viewport_rect.end.x - 120.0)
	pos.y = clampf(pos.y, viewport_rect.position.y + 55.0, viewport_rect.end.y - 40.0)
	label.global_position = pos
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(label.queue_free)

func present_events(events: Array, epoch: int) -> void:
	lock_controls()
	for value in events:
		if not is_inside_tree() or epoch != host.playback_epoch: return
		if not value is Dictionary: continue
		var event: Dictionary = value
		_append_event(event)
		var actor := str(event.get("actor", ""))
		var kind := str(event.get("kind", ""))
		var target := str(event.get("side", event.get("target", "")))
		if target not in ["player", "npc"] and actor in ["player", "npc"] and kind in ["damage", "hom_attack", "hom_dot", "true_on_hit", "dot_true", "delayed_damage"]: target = "npc" if actor == "player" else "player"
		if event.has("hp") and target in ["player", "npc"]:
			var hp := player_hp if target == "player" else enemy_hp
			var damage := maxi(0, int(hp.value) - int(event.hp))
			_show_damage_number(player_sprite if target == "player" else enemy_sprite, damage)
			hp.value = int(event.hp)
			_update_hp(hp)
		_animate_event(event)
		await get_tree().create_timer(_event_delay(kind)).timeout
