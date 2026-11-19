extends Node

var host
var backend: BackendClient
var match_id := ""
var request_id := ""
var chat_attempted := false
var request_kind := ""
var state := {}
var event_cursor := 0
var chat_cursor := 0
var next_poll := 0.0
var pending := {}
var pending_path := ""
var choice := {}
var chat_input: LineEdit
var chat_send: Button
var chat_log: RichTextLabel
var combat_tab: Button
var chat_tab: Button
var unread_indicator: Panel
var last_chat := 0.0
var chat_pending := {}
var header: Label
var timer_panel: PanelContainer
var timer_label: Label
var event_queue: Array = []
var event_delay := 0.0
var event_presenting := false
var hp_initialized := false
var hp_reconcile_pending := false
var playback_generation := 0
var highlights_shown := false
var result_popup_shown := false
var debug_visual := false

func _ready() -> void:
	host = get_parent()
	debug_visual = bool(SceneRouter._ranked_context.get("debug_visual", false)) and ConnectionGate.debug_lab_navigation_allowed()
	match_id = str(SceneRouter._ranked_context.get("match_id", ""))
	header = Label.new()
	header.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header.offset_left = -250
	header.offset_right = 250
	header.offset_top = 376
	header.offset_bottom = 400
	header.add_theme_color_override("font_color", Color.WHITE)
	header.add_theme_color_override("font_outline_color", Color.BLACK)
	header.add_theme_constant_override("outline_size", 3)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.text = "Connecting to Ranked..."
	host.add_child(header)
	timer_panel = PanelContainer.new()
	timer_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_panel.offset_left = -105
	timer_panel.offset_right = 105
	timer_panel.offset_top = 254
	timer_panel.offset_bottom = 326
	host.ultra_button.offset_top = 330
	host.ultra_button.offset_bottom = 374
	timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.add_theme_stylebox_override("panel", preload("res://scripts/ui/menu_art.gd")._button_frame("boton-loadout-opciones.png"))
	timer_panel.hide()
	host.add_child(timer_panel)
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 40)
	timer_label.add_theme_color_override("font_color", Color("dc2020"))
	timer_label.add_theme_color_override("font_outline_color", Color.WHITE)
	timer_label.add_theme_constant_override("outline_size", 3)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.add_child(timer_label)
	for bar in [host.player_hp, host.enemy_hp]:
		if bar.get_node_or_null("CombatTypeIcon") == null:
			var icon = preload("res://scripts/ui/combat_type_icon.gd").new()
			icon.name = "CombatTypeIcon"
			icon.position = Vector2(-30, -3)
			bar.add_child(icon)
	_setup_chat()
	if debug_visual:
		header.text = "PVP_DEBUG_PREVIEW"
		timer_panel.show()
		timer_label.text = "01:30"
		chat_input.editable = false
		chat_send.disabled = true
		for button in host.spell_buttons:
			button.disabled = true
		host.switch_weapon_btn.disabled = true
		host.ultra_button.disabled = true
		return
	host.spell_panel.hide()
	host.switch_weapon_btn.disabled = true
	host.ultra_button.disabled = true
	host.confirm_popup.get_node("Panel/VBox/Body").text = "Leave this ranked match? This forfeits the match."
	backend = BackendClient.new()
	backend.base_url = host.backend_url
	backend.auto_dev_login = false
	backend.state_updated.connect(_on_identity)
	backend.auth_changed.connect(_on_auth_changed)
	backend.api_completed.connect(_on_response)
	add_child(backend)

func _setup_chat() -> void:
	host.log_box.offset_top += 40
	host.log_box.offset_bottom = -144
	chat_log = RichTextLabel.new()
	chat_log.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	chat_log.offset_left = host.log_box.offset_left
	chat_log.offset_right = host.log_box.offset_right
	chat_log.offset_top = host.log_box.offset_top
	chat_log.offset_bottom = host.log_box.offset_bottom
	chat_log.scroll_following = true
	chat_log.add_theme_font_override("normal_font", load("res://assets/fonts/liberation-serif/LiberationSerif-Regular.ttf"))
	chat_log.add_theme_font_size_override("normal_font_size", 20)
	chat_log.hide()
	host.add_child(chat_log)
	var tabs := HBoxContainer.new()
	tabs.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tabs.offset_left = -296
	tabs.offset_right = 296
	tabs.offset_top = -306
	tabs.offset_bottom = -270
	host.add_child(tabs)
	combat_tab = Button.new()
	combat_tab.text = "Combat Log"
	combat_tab.toggle_mode = true
	combat_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(combat_tab)
	chat_tab = Button.new()
	chat_tab.text = "Chat"
	chat_tab.toggle_mode = true
	chat_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(chat_tab)
	unread_indicator = Panel.new()
	unread_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unread_style := StyleBoxFlat.new()
	unread_style.bg_color = Color("ffd52a")
	unread_style.set_corner_radius_all(6)
	unread_indicator.add_theme_stylebox_override("panel", unread_style)
	chat_tab.add_child(unread_indicator)
	unread_indicator.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	unread_indicator.offset_left = -20
	unread_indicator.offset_right = -8
	unread_indicator.offset_top = 5
	unread_indicator.offset_bottom = 17
	unread_indicator.hide()
	combat_tab.pressed.connect(func(): _select_log_tab(false))
	chat_tab.pressed.connect(func(): _select_log_tab(true))
	_select_log_tab(false)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -296
	row.offset_right = 296
	row.offset_top = -140
	row.offset_bottom = -96
	row.add_theme_constant_override("separation", 6)
	host.add_child(row)
	chat_input = LineEdit.new()
	chat_input.max_length = 200
	chat_input.placeholder_text = "Write a match message..."
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0, 0, 0, 0.85)
	input_style.content_margin_left = 8
	input_style.content_margin_right = 8
	chat_input.add_theme_stylebox_override("normal", input_style)
	chat_input.add_theme_stylebox_override("focus", input_style)
	chat_input.add_theme_color_override("font_color", Color.WHITE)
	chat_input.add_theme_color_override("font_placeholder_color", Color(0.75, 0.75, 0.75))
	row.add_child(chat_input)
	chat_send = Button.new()
	chat_send.text = "Send"
	chat_send.custom_minimum_size.x = 90
	row.add_child(chat_send)
	chat_send.pressed.connect(_send_chat)
	chat_input.text_submitted.connect(func(_text): _send_chat())

func _select_log_tab(show_chat: bool) -> void:
	host.log_box.visible = not show_chat
	chat_log.visible = show_chat
	if show_chat:
		unread_indicator.hide()
	combat_tab.set_pressed_no_signal(not show_chat)
	chat_tab.set_pressed_no_signal(show_chat)

func _on_identity(data: Dictionary) -> void:
	if str(data.get("player_id", "")) == backend._verified_player_id and not backend._verified_player_id.is_empty():
		next_poll = 0.0

func _on_auth_changed(_token: String) -> void:
	playback_generation += 1
	event_queue.clear()
	event_presenting = false
	event_delay = 0.0
	hp_reconcile_pending = false
	hp_initialized = false
	request_id = ""
	request_kind = ""
	header.text = "Reconnect to recover this match"
	state.clear()
	timer_panel.hide()
	refresh_controls()

func _send(method: String, path: String, body: Variant, kind: String, replay: bool = false) -> bool:
	if not request_id.is_empty() or backend.token.is_empty() or backend._verified_player_id.is_empty():
		return false
	request_id = backend.request_api(method, path, body, false, false, replay)
	if request_id.is_empty():
		return false
	if kind == "chat":
		chat_attempted = true
	request_kind = kind
	return true

func _poll() -> void:
	var url := "/pvp/match/state?match_id=%s&after=%d&chat_after=%d" % [match_id.uri_encode(), event_cursor, chat_cursor]
	_send("GET", url, null, "state")

func _process(delta: float) -> void:
	if debug_visual:
		return
	next_poll -= delta
	event_delay -= delta
	if event_delay <= 0.0 and not event_presenting and not event_queue.is_empty():
		_present_event(event_queue.pop_front())
		event_delay = 0.35
	if hp_reconcile_pending and event_queue.is_empty() and not event_presenting and event_delay <= 0.0:
		hp_reconcile_pending = false
		_render()
	if str(state.get("status", "")) == "FINISHED" and event_queue.is_empty() and not event_presenting and event_delay <= 0.0 and not highlights_shown:
		_render()
		highlights_shown = true
		host._show_highlights()
		_show_result_popup()
	if not state.is_empty() and str(state.get("status", "")) == "ACTIVE":
		var seconds := maxi(0, ceili(float(state.get("deadline", 0)) / 1000.0 - Time.get_unix_time_from_system()))
		timer_panel.show()
		timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if request_id.is_empty() and not chat_pending.is_empty() and pending.is_empty():
		_send("POST", "/pvp/match/chat", chat_pending, "chat", chat_attempted)
	if request_id.is_empty() and next_poll <= 0.0:
		next_poll = 3.0
		_poll()
	chat_send.disabled = not chat_pending.is_empty() or (not request_id.is_empty() and request_kind != "state") or Time.get_unix_time_from_system() < last_chat + 10.0

func _on_response(id: String, ok: bool, data: Dictionary) -> void:
	if id != request_id:
		return
	var kind := request_kind
	request_id = ""
	request_kind = ""
	if not ok:
		if int(data.get("http_status", 0)) >= 400 and int(data.get("http_status", 0)) < 500:
			pending.clear()
			pending_path = ""
			if kind == "chat":
				chat_pending.clear()
		header.text = "Connection error — recovering match"
		next_poll = 1.0
		refresh_controls()
		return
	if kind == "chat":
		last_chat = Time.get_unix_time_from_system()
		if chat_input.text == str(chat_pending.get("text", "")):
			chat_input.clear()
		chat_pending.clear()
		chat_attempted = false
		next_poll = 0.0
		refresh_controls()
		return
	if data.get("match_id", "") != match_id:
		header.text = "Match unavailable"
		return
	state = data.duplicate(true)
	if str(state.get("status", "")) == "ACTIVE":
		header.text = ""
	if kind in ["decision", "forfeit"]:
		pending.clear()
		pending_path = ""
	elif kind == "state" and not pending.is_empty():
		if str(state.get("status", "")) != "ACTIVE" or (not pending_path.ends_with("forfeit") and (bool(state.get("ready", {}).get("player", false)) or int(state.get("combat_revision", -1)) != int(pending.get("combat_revision", -2)))):
			pending.clear()
			pending_path = ""
		elif not pending_path.is_empty():
			_send("POST", pending_path, pending, "forfeit" if pending_path.ends_with("forfeit") else "decision", true)
	_render()

func _fighter(data: Dictionary) -> Dictionary:
	var fighter := data.duplicate(true)
	fighter["id"] = str(data.get("entity_id", ""))
	var entity: Dictionary = host._find_by_id(host._entities, fighter["id"])
	if not entity.is_empty():
		fighter["name"] = str(entity.get("name", data.get("name", "")))
	var statuses := {"poison": 0, "stun": 0, "shield_pct": 0.0, "atk_boost": 0.0, "vuln_pct": 0.0, "atk_down": 0.0, "hom_stun": 0, "reflect_pct": 0.0, "tempo_bonus": 0.0}
	statuses.merge(data.get("status", {}), true)
	fighter["status"] = statuses
	if data.get("trap") is Dictionary:
		fighter["strategic_trap"] = data.trap.duplicate(true)
	if data.get("heal_suppression") is Dictionary:
		fighter["strategic_heal_suppression"] = data.heal_suppression.duplicate(true)
	fighter["hom_synergy"] = {}
	var weapons: Array = data.get("weapon_ids", [])
	for i in 2:
		var weapon_id := str(weapons[i]) if i < weapons.size() and weapons[i] != null else ""
		fighter["equip_%d" % (i + 1)] = host._find_by_id(host._items, weapon_id)
	return fighter

func _strategic_effects(fighter: Dictionary) -> Array:
	var effects: Array = []
	for delayed in fighter.get("delayed_damage", []):
		var amount := int(delayed.get("amount", 0))
		var due_turn := int(delayed.get("due_turn", 0))
		effects.append({"icon": "hourglass", "label": str(amount), "tooltip": "Delayed damage: %d at the end of exchange %d." % [amount, due_turn]})
	if fighter.has("strategic_trap"):
		var trap: Dictionary = fighter.strategic_trap
		var remaining := maxi(0, int(trap.get("expires_turn", 0)) - int(state.get("turn", 0)))
		effects.append({"icon": "trap", "label": "%dT" % remaining, "tooltip": "Counter trap: %d%% of direct damage; %d exchanges remaining." % [roundi(float(trap.get("value", 0)) * 100), remaining]})
	if fighter.has("strategic_heal_suppression"):
		var remaining := maxi(0, int(fighter.strategic_heal_suppression.get("expires_turn", 0)) - int(state.get("turn", 0)))
		effects.append({"icon": "heal_block", "label": "%dT" % remaining, "tooltip": "Healing reduced by 50%%; %d exchanges remaining." % remaining})
	return effects

func _render() -> void:
	if not state.get("player") is Dictionary or not state.get("enemy") is Dictionary:
		return
	for event in state.get("events", []):
		if not event is Dictionary or int(event.get("id", 0)) <= event_cursor:
			continue
		event_cursor = int(event.id)
		var queued: Dictionary = event.duplicate(true)
		queued["_initial_snapshot"] = not hp_initialized
		event_queue.append(queued)
		hp_reconcile_pending = true
	var preserve_hp := hp_initialized and (event_presenting or not event_queue.is_empty() or event_delay > 0.0)
	var old_player_hp := int(host.player_hp.value)
	var old_enemy_hp := int(host.enemy_hp.value)
	host.player = _fighter(state.player)
	host.enemy = _fighter(state.enemy)
	host._battle_index = int(state.get("battle_index", 1))
	host._player_wins = int(state.get("score", {}).get("player", 0))
	host._enemy_wins = int(state.get("score", {}).get("enemy", 0))
	host._sudden_death = bool(state.get("sudden_death", false))
	host._turn = int(state.get("turn", 0))
	host._combat_started = true
	host._battle_over = str(state.get("status", "")) != "ACTIVE"
	host.player_indicators.set_extra_effects(_strategic_effects(host.player))
	host.enemy_indicators.set_extra_effects(_strategic_effects(host.enemy))
	if preserve_hp:
		var player_final: int = int(host.player.hp)
		var enemy_final: int = int(host.enemy.hp)
		host.player.hp = old_player_hp
		host.enemy.hp = old_enemy_hp
		host._update_ui()
		host.player.hp = player_final
		host.enemy.hp = enemy_final
	else:
		host._update_ui()
		hp_initialized = true
	var anomaly: Variant = state.get("physical_anomaly")
	if anomaly is Dictionary and not anomaly.is_empty():
		host._physical_anomaly_label.set_meta("active_anomaly", anomaly.duplicate(true))
		host._render_physical_anomaly(anomaly)
		host._physical_anomaly_label.show()
	else:
		host._physical_anomaly_label.hide()
	host.player_name.text = str(state.player.get("display_name", "Player"))
	host.enemy_name.text = str(state.enemy.get("display_name", "Opponent"))
	for message in state.get("chat", []):
		if message is Dictionary and int(message.get("id", 0)) > chat_cursor:
			chat_cursor = int(message.id)
			_append_chat_message(message)
	if host._battle_over and not preserve_hp:
		timer_panel.hide()
		var result: Dictionary = state.get("result", {})
		header.text = "%s  |  MP %+d" % [str(result.get("result", "draw")).to_upper(), int(result.get("mp_delta", 0))]
		host.next_turn_btn.text = "Return"
		host.next_turn_btn.show()
	else:
		host.next_turn_btn.hide()
	_refresh_inspiration()
	host._refresh_spell_buttons()
	refresh_controls()

func _append_chat_message(message: Dictionary) -> void:
	var sender_id := str(message.get("player_id", ""))
	var sender := "Player"
	if sender_id == str(state.player.get("player_id", "")):
		sender = str(state.player.get("display_name", "Player"))
	elif sender_id == str(state.enemy.get("player_id", "")):
		sender = str(state.enemy.get("display_name", "Opponent"))
	chat_log.add_text("%s: %s\n" % [sender, str(message.get("text", ""))])
	if not chat_log.visible and sender_id != str(state.player.get("player_id", "")):
		unread_indicator.show()

func _present_event(source: Dictionary) -> void:
	var event := source.duplicate(true)
	var actor := str(event.get("actor", ""))
	var target := str(event.get("target", ""))
	if target not in ["player", "enemy"] and event.has("hp") and actor in ["player", "enemy"]:
		target = actor
	if actor in ["player", "enemy"]:
		var fighter: Dictionary = host.player if actor == "player" else host.enemy
		if str(event.get("kind", "")) in ["hom_attack", "hom_miss"]:
			event["actor_kind"] = "homunculus"
			event["parent"] = str(fighter.get("name", ""))
			event["parent_color"] = "69d7e8" if actor == "player" else "f2a078"
		event["actor"] = str(fighter.get("hom_name", "")) if str(event.get("actor_kind", "")) == "homunculus" else str(fighter.get("name", ""))
		event["actor_color"] = "69d7e8" if actor == "player" else "f2a078"
	if target in ["player", "enemy"]:
		var victim: Dictionary = host.player if target == "player" else host.enemy
		event["target"] = str(victim.get("name", ""))
		event["target_color"] = "69d7e8" if target == "player" else "f2a078"
	if str(event.get("kind", "")) == "spell" and actor in ["player", "enemy"]:
		host._animate_lunge(host.player_entity if actor == "player" else host.enemy_entity, 12.0 if actor == "player" else -12.0, false)
	elif str(event.get("kind", "")) in ["hom_attack", "hom_miss"] and actor in ["player", "enemy"]:
		host._animate_lunge(host.player_hom if actor == "player" else host.enemy_hom, 12.0 if actor == "player" else -12.0, false)
	host._log_presenter.append(host.log_box, int(event.get("turn", 0)), str(event.get("kind", "event")).replace("_", " "), event)
	if target not in ["player", "enemy"] or bool(source.get("_initial_snapshot", false)):
		return
	var bar: ProgressBar = host.player_hp if target == "player" else host.enemy_hp
	var sprite: Control = host.player_entity if target == "player" else host.enemy_entity
	var kind := str(event.get("kind", ""))
	var before := int(bar.value)
	var after := before
	if source.has("hp"):
		after = clampi(int(source.hp), 0, int(bar.max_value))
	elif kind in ["damage", "hom_attack", "delayed_damage", "reflect", "reflection", "poison", "dot", "dot_true", "true_on_hit", "recoil", "counter_trap_triggered"]:
		after = maxi(0, before - int(source.get("actual_damage", source.get("damage", source.get("amount", 0)))))
	if after == before:
		return
	var lost := maxi(0, before - after)
	if lost > 0:
		host._animate_hit(sprite, lost, int(bar.max_value))
		host._show_damage_number(sprite, lost)
		host._record_highlight("damage", lost, "%s ? %s" % [str(event.get("actor", "")), str(event.get("target", ""))])
	event_presenting = true
	var generation := playback_generation
	await get_tree().create_timer(0.26).timeout
	if not is_inside_tree() or generation != playback_generation:
		return
	host._set_display_hp(bar, after)
	event_presenting = false
	if event_queue.is_empty() and event_delay <= 0.0:
		_render()

func refresh_controls() -> void:
	if host == null:
		return
	var action_request := not request_id.is_empty() and request_kind not in ["state", "chat"]
	var locked := state.is_empty() or str(state.get("status", "")) != "ACTIVE" or bool(state.get("ready", {}).get("player", false)) or action_request or not pending.is_empty() or not choice.is_empty() or bool(state.get("player", {}).get("inspiration_pending", false)) or bool(state.get("enemy", {}).get("inspiration_pending", false))
	for button in host.spell_buttons:
		button.disabled = button.disabled or locked
	host.switch_weapon_btn.disabled = host.switch_weapon_btn.disabled or locked
	host.ultra_button.disabled = host.ultra_button.disabled or locked
	var inspiration_locked := state.is_empty() or str(state.get("status", "")) != "ACTIVE" or not bool(state.get("player", {}).get("inspiration_pending", false)) or bool(state.get("ready", {}).get("player", false)) or action_request or not pending.is_empty() or not choice.is_empty()
	for card in host._inspiration_cards:
		card.disabled = inspiration_locked
	(host._inspiration_panel.get_node("Content/Cancel") as Button).disabled = inspiration_locked

func spell(index: int) -> void:
	if index < 0 or index >= host.spell_buttons.size() or host.spell_buttons[index].disabled:
		return
	var ids: Array = state.get("player", {}).get("spell_ids", [])
	if index >= ids.size():
		return
	var decision := {"turn": int(state.get("turn", 0)) + 1, "spell_id": str(ids[index]), "ultra": host._ultra_armed and host._ultra_available(host.player)}
	_queue_action(decision)

func switch_weapon() -> void:
	if host.switch_weapon_btn.disabled:
		return
	var slot := 2 if int(state.player.get("active_weapon_slot", 1)) == 1 else 1
	_queue_action({"turn": int(state.get("turn", 0)) + 1, "switch_slot": slot})

func _queue_action(decision: Dictionary) -> void:
	if (not request_id.is_empty() and request_kind not in ["state", "chat"]) or not pending.is_empty():
		return
	if host._hom_ready(host.player):
		choice = decision
		host.hom_decision.show()
		host.get_node("HomDecision/Attack").text = "Attack (BOOST)" if int(host.player.get("hom_energy", 0)) >= 6 else "Attack"
		refresh_controls()
	else:
		_submit_decision(decision)

func hom_choice(action: String) -> void:
	if choice.is_empty() or action not in ["hold", "attack", "sacrifice"]:
		return
	choice["hom_action"] = action
	var decision := choice.duplicate(true)
	choice.clear()
	host.hom_decision.hide()
	_submit_decision(decision)

func _submit_decision(decision: Dictionary) -> void:
	if (not request_id.is_empty() and request_kind not in ["state", "chat"]) or not pending.is_empty() or str(state.get("status", "")) != "ACTIVE":
		return
	pending = {"match_id": match_id, "client_action_id": backend._make_uuid(), "combat_revision": int(state.get("combat_revision", 0)), "decision": decision}
	pending_path = "/pvp/match/decision"
	host._ultra_armed = false
	if not _send("POST", pending_path, pending, "decision"):
		next_poll = 0.0
	refresh_controls()

func _refresh_inspiration() -> void:
	var p: Dictionary = state.get("player", {})
	var offers: Array = p.get("inspiration_offers", [])
	if str(state.get("status", "")) != "ACTIVE" or not bool(p.get("inspiration_pending", false)) or bool(state.get("ready", {}).get("player", false)) or offers.size() != 3:
		host._inspiration_panel.hide()
		return
	host._inspiration_options.clear()
	for i in 3:
		var spell: Dictionary = host._reg.get_spell_by_id(str(offers[i]))
		host._inspiration_options.append(spell)
		host._inspiration_cards[i].text = str(spell.get("name", offers[i])) + "\n\n" + host._spell_description(spell)
		host._inspiration_cards[i].tooltip_text = host._spell_description(spell)
		host._inspiration_cards[i].get_node("TypeIcon").call("configure", str(spell.get("primary_type", spell.get("type", ""))))
	host._inspiration_panel.show()

func choose_inspiration(index: int) -> void:
	if index >= 0 and index < host._inspiration_options.size() and not host._inspiration_cards[index].disabled:
		_submit_decision({"kind": "choose", "spell_id": str(host._inspiration_options[index].get("id", ""))})

func decline_inspiration() -> void:
	if not (host._inspiration_panel.get_node("Content/Cancel") as Button).disabled:
		_submit_decision({"kind": "decline"})

func _send_chat() -> void:
	if chat_send.disabled or chat_input.text.strip_edges().is_empty():
		return
	if chat_pending.is_empty() or str(chat_pending.get("text", "")) != chat_input.text:
		chat_pending = {"match_id": match_id, "client_message_id": backend._make_uuid(), "text": chat_input.text}
		chat_attempted = false
	_select_log_tab(true)
	if request_id.is_empty() and pending.is_empty():
		_send("POST", "/pvp/match/chat", chat_pending, "chat", chat_attempted)
	chat_send.disabled = true

func back() -> void:
	if debug_visual:
		SceneRouter._ranked_context.clear()
		SceneRouter.go_to_loadout()
		return
	if str(state.get("status", "")) == "FINISHED":
		return_to_loadout()
	else:
		host.confirm_popup.popup_centered(Vector2i(600, 240))

func forfeit() -> void:
	if str(state.get("status", "")) == "FINISHED":
		return_to_loadout()
		return
	if not request_id.is_empty() or not pending.is_empty():
		header.text = "Wait for the pending request before forfeiting"
		return
	pending = {"match_id": match_id, "client_action_id": backend._make_uuid()}
	pending_path = "/pvp/match/forfeit"
	if not _send("POST", pending_path, pending, "forfeit"):
		next_poll = 0.0
	refresh_controls()

func return_to_loadout() -> void:
	if str(state.get("status", "")) != "FINISHED":
		return
	SceneRouter._ranked_context.clear()
	SceneRouter.go_to_loadout()

func _show_result_popup() -> void:
	if result_popup_shown:
		return
	var result: Dictionary = state.get("result", {})
	if result.is_empty():
		return
	result_popup_shown = true
	var outcome := str(result.get("result", "draw"))
	var body: VBoxContainer = host._result_popup("VICTORY" if outcome == "win" else "DEFEAT" if outcome == "loss" else "DRAW")
	var delta := int(result.get("mp_delta", 0))
	var amount := Label.new()
	amount.text = "%+d MP" % delta
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size", 42)
	amount.add_theme_color_override("font_color", Color("80e8a3") if delta > 0 else Color("f08787") if delta < 0 else Color("e7d293"))
	body.add_child(amount)
	var accent := Label.new()
	accent.text = "*  +  *" if delta > 0 else "-  *  -" if delta < 0 else "*  -  *"
	accent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	accent.add_theme_color_override("font_color", Color("80e8a3") if delta > 0 else Color("f08787") if delta < 0 else Color("e7d293"))
	body.add_child(accent)
	if result.has("mp_total_after"):
		var league := str(result.get("league", ""))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := "res://assets/ui/pvp/league_icons_128x128/%s_league.png" % league.to_lower()
		if ResourceLoader.exists(path):
			icon.texture = load(path) as Texture2D
		body.add_child(icon)
		var rank := Label.new()
		rank.text = "%s League - Division %s\nCurrent MP: %d" % [league, str(result.get("division", "")), int(result.mp_total_after)]
		rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank.add_theme_font_size_override("font_size", 22)
		body.add_child(rank)
