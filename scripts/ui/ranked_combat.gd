extends Node

var host
var backend: BackendClient
var match_id := ""
var request_id := ""
var request_kind := ""
var state := {}
var event_cursor := 0
var chat_cursor := 0
var next_poll := 0.0
var pending := {}
var pending_path := ""
var choice := {}
var chat_box: VBoxContainer
var chat_log: RichTextLabel
var chat_input: LineEdit
var chat_toggle: Button
var chat_send: Button
var last_chat := 0.0
var chat_pending := {}
var header: Label
var event_queue: Array = []
var event_delay := 0.0
var highlights_shown := false

func _ready() -> void:
	host = get_parent()
	match_id = str(SceneRouter._ranked_context.get("match_id", ""))
	header = Label.new()
	header.position = Vector2(760, 70)
	header.size = Vector2(400, 50)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.text = "Connecting to Ranked..."
	host.add_child(header)
	for bar in [host.player_hp, host.enemy_hp]:
		if bar.get_node_or_null("CombatTypeIcon") == null:
			var icon = preload("res://scripts/ui/combat_type_icon.gd").new()
			icon.name = "CombatTypeIcon"
			icon.position = Vector2(-30, -3)
			bar.add_child(icon)
	_setup_chat()
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
	chat_toggle = Button.new()
	chat_toggle.text = "Match chat"
	chat_toggle.position = Vector2(1715, 25)
	chat_toggle.size = Vector2(170, 40)
	host.add_child(chat_toggle)
	chat_box = VBoxContainer.new()
	chat_box.position = Vector2(1500, 70)
	chat_box.size = Vector2(385, 215)
	chat_box.z_index = 100
	chat_box.hide()
	host.add_child(chat_box)
	chat_log = RichTextLabel.new()
	chat_log.custom_minimum_size = Vector2(385, 150)
	chat_log.scroll_following = true
	chat_log.bbcode_enabled = false
	chat_box.add_child(chat_log)
	var row := HBoxContainer.new()
	chat_box.add_child(row)
	chat_input = LineEdit.new()
	chat_input.max_length = 200
	chat_input.placeholder_text = "Private match message"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(chat_input)
	chat_send = Button.new()
	chat_send.text = "Send"
	row.add_child(chat_send)
	chat_toggle.pressed.connect(func(): chat_box.visible = not chat_box.visible)
	chat_send.pressed.connect(_send_chat)
	chat_input.text_submitted.connect(func(_text): _send_chat())

func _on_identity(data: Dictionary) -> void:
	if str(data.get("player_id", "")) == backend._verified_player_id and not backend._verified_player_id.is_empty():
		next_poll = 0.0

func _on_auth_changed(_token: String) -> void:
	request_id = ""
	request_kind = ""
	header.text = "Reconnect to recover this match"
	state.clear()
	refresh_controls()

func _send(method: String, path: String, body: Variant, kind: String) -> bool:
	if not request_id.is_empty() or backend.token.is_empty() or backend._verified_player_id.is_empty():
		return false
	request_id = backend.request_api(method, path, body)
	if request_id.is_empty():
		return false
	request_kind = kind
	return true

func _poll() -> void:
	var url := "/pvp/match/state?match_id=%s&after=%d&chat_after=%d" % [match_id.uri_encode(), event_cursor, chat_cursor]
	if _send("GET", url, null, "state"):
		refresh_controls()

func _process(delta: float) -> void:
	next_poll -= delta
	event_delay -= delta
	if event_delay <= 0.0 and not event_queue.is_empty():
		_present_event(event_queue.pop_front())
		event_delay = 0.35
	if str(state.get("status", "")) == "FINISHED" and event_queue.is_empty() and not highlights_shown:
		highlights_shown = true
		host._show_highlights()
	if not state.is_empty() and str(state.get("status", "")) == "ACTIVE":
		var seconds := maxi(0, ceili(float(state.get("deadline", 0)) / 1000.0 - Time.get_unix_time_from_system()))
		var waiting := bool(state.get("ready", {}).get("player", false)) or not pending.is_empty()
		header.text = "%s  •  %02d:%02d" % ["Waiting for opponent" if waiting else "Choose your action", seconds / 60, seconds % 60]
	if request_id.is_empty() and next_poll <= 0.0:
		next_poll = 3.0
		_poll()
	chat_send.disabled = not request_id.is_empty() or Time.get_unix_time_from_system() < last_chat + 10.0

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
		chat_input.clear()
		chat_pending.clear()
		next_poll = 0.0
		refresh_controls()
		return
	if data.get("match_id", "") != match_id:
		header.text = "Match unavailable"
		return
	state = data.duplicate(true)
	if kind in ["decision", "forfeit"]:
		pending.clear()
		pending_path = ""
	elif kind == "state" and not pending.is_empty():
		if str(state.get("status", "")) != "ACTIVE" or (not pending_path.ends_with("forfeit") and (bool(state.get("ready", {}).get("player", false)) or int(state.get("combat_revision", -1)) != int(pending.get("combat_revision", -2)))):
			pending.clear()
			pending_path = ""
		elif not pending_path.is_empty():
			_send("POST", pending_path, pending, "forfeit" if pending_path.ends_with("forfeit") else "decision")
	_render()

func _fighter(data: Dictionary) -> Dictionary:
	var fighter := data.duplicate(true)
	fighter["id"] = str(data.get("entity_id", ""))
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
	host._update_ui()
	var anomaly: Variant = state.get("physical_anomaly")
	if anomaly is Dictionary and not anomaly.is_empty():
		host._physical_anomaly_label.set_meta("active_anomaly", anomaly.duplicate(true))
		host._render_physical_anomaly(anomaly)
		host._physical_anomaly_label.show()
	else:
		host._physical_anomaly_label.hide()
	host.player_name.text = str(state.player.get("display_name", "Player"))
	host.enemy_name.text = str(state.enemy.get("display_name", "Opponent"))
	for event in state.get("events", []):
		if not event is Dictionary or int(event.get("id", 0)) <= event_cursor:
			continue
		event_cursor = int(event.id)
		event_queue.append(event.duplicate(true))
	for message in state.get("chat", []):
		if message is Dictionary and int(message.get("id", 0)) > chat_cursor:
			chat_cursor = int(message.id)
			var sender := str(state.player.get("display_name", "Player")) if str(message.get("player_id", "")) == str(state.player.get("player_id", "")) else str(state.enemy.get("display_name", "Opponent"))
			chat_log.add_text("%s: %s\n" % [sender, str(message.get("text", ""))])
	if host._battle_over:
		var result: Dictionary = state.get("result", {})
		header.text = "%s  |  MP %+d" % [str(result.get("result", "draw")).to_upper(), int(result.get("mp_delta", 0))]
		host.next_turn_btn.text = "Return"
		host.next_turn_btn.show()
	else:
		host.next_turn_btn.hide()
	_refresh_inspiration()
	host._refresh_spell_buttons()
	refresh_controls()

func _present_event(source: Dictionary) -> void:
	var event := source.duplicate(true)
	var actor := str(event.get("actor", ""))
	var target := str(event.get("target", ""))
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
	if str(event.get("kind", "")) in ["damage", "hom_attack", "delayed_damage"] and target in ["player", "enemy"]:
		var sprite: Control = host.player_entity if target == "player" else host.enemy_entity
		var amount := int(event.get("damage", event.get("amount", 0)))
		host._animate_hit(sprite, amount, int((host.player if target == "player" else host.enemy).get("max_hp", 1)))
		host._record_highlight("damage", amount, "%s → %s" % [str(event.get("actor", "")), str(event.get("target", ""))])
	host._log_presenter.append(host.log_box, int(event.get("turn", 0)), str(event.get("kind", "event")).replace("_", " "), event)

func refresh_controls() -> void:
	if host == null:
		return
	var locked := state.is_empty() or str(state.get("status", "")) != "ACTIVE" or bool(state.get("ready", {}).get("player", false)) or not request_id.is_empty() or not pending.is_empty() or not choice.is_empty() or bool(state.get("player", {}).get("inspiration_pending", false)) or bool(state.get("enemy", {}).get("inspiration_pending", false))
	for button in host.spell_buttons:
		button.disabled = button.disabled or locked
	host.switch_weapon_btn.disabled = host.switch_weapon_btn.disabled or locked
	host.ultra_button.disabled = host.ultra_button.disabled or locked
	var inspiration_locked := state.is_empty() or str(state.get("status", "")) != "ACTIVE" or not bool(state.get("player", {}).get("inspiration_pending", false)) or bool(state.get("ready", {}).get("player", false)) or not request_id.is_empty() or not pending.is_empty() or not choice.is_empty()
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
	if not request_id.is_empty() or not pending.is_empty():
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
	if not request_id.is_empty() or not pending.is_empty() or str(state.get("status", "")) != "ACTIVE":
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
	_send("POST", "/pvp/match/chat", chat_pending, "chat")

func back() -> void:
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
