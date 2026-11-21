extends Control

const TypeIcon := preload("res://scripts/ui/combat_type_icon.gd")
const StatusIcons := preload("res://scripts/ui/combat_status_icons.gd")
const Inspiration := preload("res://scripts/ui/combat_inspiration.gd")
const HomStatus := preload("res://scripts/ui/combat_hom_status.gd")
const SpellView := preload("res://scripts/ui/spell_presentation.gd")
const MenuArt := preload("res://scripts/ui/menu_art.gd")
var host: Control
var session := {}
var registry: Node
var controls: Array[BaseButton] = []
var spell_buttons: Array[Button] = []
var weapon_buttons: Array[Button] = []
var inspiration_buttons: Array[Button] = []
var decline_button: Button
var hom_attack: CheckButton
var player_sprite: TextureRect
var player_hom_sprite: TextureRect
var enemy_sprite: TextureRect
var player_hp: ProgressBar
var enemy_hp: ProgressBar
var log: RichTextLabel

func _exit_tree() -> void:
	if is_instance_valid(registry): registry.free()

func configure(scene: Control, data: Dictionary) -> void:
	host = scene
	session = data.duplicate(true)
	registry = preload("res://scripts/data_registry.gd").new()
	_build()

func _build() -> void:
	var state: Dictionary = session.get("combat_state", {})
	var player: Dictionary = state.get("player", {})
	var enemy: Dictionary = state.get("npc", {})
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 5)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	var actors := HBoxContainer.new()
	actors.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(actors)
	actors.add_child(_fighter(player, false, state))
	actors.add_child(_fighter(enemy, true, state))
	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size.y = 112
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.01, 0.025, 0.04, 0.92)
	log_style.border_color = Color("397d89")
	log_style.set_border_width_all(1)
	log_style.set_content_margin_all(6)
	log_panel.add_theme_stylebox_override("panel", log_style)
	main.add_child(log_panel)
	log = RichTextLabel.new()
	log.fit_content = false
	log.scroll_following = true
	log.add_theme_font_size_override("normal_font_size", 18)
	log_panel.add_child(log)
	for event in session.get("battle_log", []):
		if event is Dictionary: _append_event(event)
	var weapons := HBoxContainer.new()
	weapons.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_child(weapons)
	var equipped: Array = state.get("weapons", [])
	for i in 2:
		var item_id := str(equipped[i].get("id", "")) if i < equipped.size() and equipped[i] is Dictionary and equipped[i].get("id") != null else ""
		var item: Dictionary = registry.get_items().get(item_id, {})
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.76))
		button.text = "%s %d: %s%s" % [tr("EXPEDITION_WEAPON"), i + 1, GameLocalization.catalog("item", item_id, "name", str(item.get("name", item_id))) if not item_id.is_empty() else "—", " ✓" if int(state.get("active_weapon_slot", 0)) == i + 1 else ""]
		button.disabled = item_id.is_empty() or int(state.get("active_weapon_slot", 0)) == i + 1 or bool(player.get("inspiration_pending", false))
		button.pressed.connect(_switch.bind(i + 1))
		MenuArt.button(button)
		weapons.add_child(button)
		weapon_buttons.append(button)
		controls.append(button)
	hom_attack = CheckButton.new()
	hom_attack.add_theme_font_size_override("font_size", 20)
	hom_attack.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.76))
	hom_attack.text = tr("EXPEDITION_HOM_ATTACK")
	hom_attack.disabled = player.get("hom_id") == null or int(player.get("hom_energy", 0)) < 3 or bool(player.get("inspiration_pending", false))
	hom_attack.tooltip_text = tr("EXPEDITION_HOM_HINT")
	weapons.add_child(hom_attack)
	controls.append(hom_attack)
	var spells := HBoxContainer.new()
	spells.add_theme_constant_override("separation", 8)
	main.add_child(spells)
	var ids: Array = player.get("spell_ids", [])
	for i in 4:
		var id := str(ids[i]) if i < ids.size() else ""
		var spell: Dictionary = registry.get_spell_by_id(id)
		var cooldown := int(player.get("cooldowns", {}).get(id, 0))
		var button := _spell_button(spell, cooldown)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = spell.is_empty() or cooldown > 0 or bool(player.get("inspiration_pending", false))
		button.pressed.connect(_cast.bind(id))
		var slot := VBoxContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spells.add_child(slot)
		slot.add_child(button)
		var detail := Button.new()
		detail.add_theme_font_size_override("font_size", 18)
		detail.text = tr("EXPEDITION_SPELL_DETAIL")
		detail.disabled = spell.is_empty()
		MenuArt.button(detail)
		detail.pressed.connect(_details.bind(spell))
		slot.add_child(detail)
		spell_buttons.append(button)
		controls.append(button)
	if bool(player.get("inspiration_pending", false)):
		_build_inspiration(main, player)

func _fighter(fighter: Dictionary, enemy: bool, state: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	var title := Label.new()
	title.text = name_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	box.add_child(title)
	var types := HBoxContainer.new()
	types.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(types)
	for type_id in fighter.get("expedition_types", [fighter.get("type", "")]):
		var icon := TypeIcon.new()
		types.add_child(icon)
		icon.configure(str(type_id))
		var label := Label.new()
		label.text = GameLocalization.catalog("type", str(type_id), "name", str(type_id).capitalize())
		types.add_child(label)
	var hp := ProgressBar.new()
	hp.max_value = maxi(1, int(fighter.get("max_hp", 1)))
	hp.value = int(fighter.get("hp", 0))
	hp.show_percentage = false
	hp.custom_minimum_size.y = 24
	hp.tooltip_text = "%d / %d HP" % [int(hp.value), int(hp.max_value)]
	box.add_child(hp)
	if enemy: enemy_hp = hp
	else: player_hp = hp
	var hp_label := Label.new()
	hp_label.text = "%d / %d HP" % [int(hp.value), int(hp.max_value)]
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_child(hp_label)
	var icons := StatusIcons.new()
	box.add_child(icons)
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
	box.add_child(inspiration)
	inspiration.set_fighter({"inspiration":fighter.get("inspiration", 0), "inspiration_used_this_battle":fighter.get("inspiration_used", false)})
	var images := HBoxContainer.new()
	images.alignment = BoxContainer.ALIGNMENT_CENTER
	images.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(images)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(250, 160)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.flip_h = enemy
	portrait.texture = host._texture(path, "res://assets/entities/")
	images.add_child(portrait)
	if enemy: enemy_sprite = portrait
	else:
		player_sprite = portrait
		var hom_id := str(fighter.get("hom_id", ""))
		var hom: Dictionary = registry.get_homunculus_collection().get(hom_id, {})
		var hom_path := str(hom.get("combat_texture", ""))
		if hom_path.is_empty():
			var legacy := {"cinder":"Cinder", "chimera":"Chimera", "drakon":"Drakon", "mothy":"Mothy", "nighty":"Nighty", "pyritc":"Pyro", "silphide":"Silphide", "sodium":"Sodi"}
			hom_path = "res://assets/entities/gameplay/homunculus/ingame/1024/%s.png" % str(legacy.get(hom_id, ""))
		var hom_image := TextureRect.new()
		player_hom_sprite = hom_image
		hom_image.custom_minimum_size = Vector2(150, 120)
		hom_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hom_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hom_image.texture = host._texture(hom_path, "res://assets/entities/gameplay/homunculus/ingame/1024/")
		images.add_child(hom_image)
		var hom_meter := HomStatus.new()
		var hom_data := {"hom_name":str(hom.get("name", hom_id)), "hom_energy":fighter.get("hom_energy", 0)}
		hom_meter.ready.connect(func(): hom_meter.set_fighter(hom_data), CONNECT_ONE_SHOT)
		box.add_child(hom_meter)
	return box

func _spell_button(spell: Dictionary, cooldown: int = 0) -> Button:
	var button := Button.new()
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.76))
	button.custom_minimum_size = Vector2(230, 90)
	var id := str(spell.get("id", ""))
	button.text = "%s\n%s  |  %s%%  |  CD %d" % [GameLocalization.catalog("spell", id, "name", str(spell.get("name", id))), str(roundi(float(spell.get("power_mult", 0)) * 100)) + "%", roundi(float(spell.get("accuracy", 0)) * 100), cooldown]
	button.tooltip_text = SpellView.detail(spell, "Equipped") if not spell.is_empty() else ""
	button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not spell.is_empty(): _details(spell))
	MenuArt.button(button)
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
	dialog.title = GameLocalization.catalog("spell", str(spell.get("id", "")), "name", str(spell.get("name", "")))
	dialog.dialog_text = SpellView.detail(spell, "Equipped")
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
	var line := "%s: %s" % [tr("EXPEDITION_PLAYER" if actor == "player" else "EXPEDITION_ENEMY") if actor in ["player", "npc"] else "•", translated]
	if event.has("spell_id"):
		var id := str(event.spell_id)
		var spell: Dictionary = registry.get_spell_by_id(id)
		line += " — " + GameLocalization.catalog("spell", id, "name", str(spell.get("name", id)))
	if event.has("status"):
		var status_id := str(event.status)
		line += " — " + GameLocalization.catalog("status_name", status_id, "name", status_id.replace("_", " ").capitalize())
	if event.has("item_id"):
		var item_id := str(event.item_id)
		var item: Dictionary = registry.get_items().get(item_id, {})
		line += " — " + GameLocalization.catalog("item", item_id, "name", str(item.get("name", item_id)))
	if event.has("passive_id"): line += " — " + str(event.passive_id).replace("_", " ").capitalize()
	if event.get("target") in ["player", "npc"]: line += " → " + tr("EXPEDITION_PLAYER" if event.target == "player" else "EXPEDITION_ENEMY")
	if event.has("amount"): line += " (%s)" % str(event.amount)
	elif event.has("value") and (event.value is int or event.value is float): line += " (%s)" % str(event.value)
	if event.has("source"): line += " [%s]" % str(event.source).replace("_", " ")
	if kind == "spell" and not bool(event.get("hit", true)): line += " — " + tr("EXPEDITION_MISS")
	log.append_text(line + "\n")

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
			hp.value = int(event.hp)
			(hp.get_child(0) as Label).text = "%d / %d HP" % [int(hp.value), int(hp.max_value)]
		if kind in ["spell", "hom_attack", "damage", "evade", "hom_miss"]:
			var sprite := player_sprite if (actor == "player" if kind in ["spell", "hom_attack", "hom_miss"] else target == "player") else enemy_sprite
			if is_instance_valid(sprite):
				sprite.modulate = Color(1.8, 1.4, 1.4)
				var tween := create_tween()
				tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)
		await get_tree().create_timer(0.12).timeout
