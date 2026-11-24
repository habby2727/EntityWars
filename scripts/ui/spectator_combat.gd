extends Node
var host
var mode := ""
var pending_events: Array = []
var latest := {}
var playing := false
var epoch := 0
var title: Label

func _ready() -> void:
	host = get_parent()
	mode = str(SceneRouter._spectator_context.get("mode", ""))
	title = Label.new()
	title.text = tr("SPECTATING") % str(SceneRouter._spectator_context.get("username", ""))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-250, 200)
	title.size = Vector2(500, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(title)
	if mode == "dungeon": host._apply_dungeon_combat_visuals()
	SpectatorClient.updated.connect(_on_update)
	SpectatorClient.failed.connect(_on_failure)
	SpectatorClient.ready_to_observe()

func _on_failure(key: String) -> void:
	if is_instance_valid(title): title.text = tr(key)

func _on_update(data: Dictionary, initial: bool) -> void:
	if SceneRouter._spectator_context.is_empty(): return
	latest = data.get("snapshot", {}).duplicate(true)
	var events: Array = data.get("events", [])
	if initial or events.size() > 25 or bool(data.get("cursor_reset", false)):
		epoch += 1
		pending_events.clear()
		playing = false
		_render()
		for event in events:
			if event is Dictionary:
				var name := str(event.get("kind", "event")).replace("_", " ")
				host._append_combat_log(name, {"category":"system"})
		return
	pending_events.append_array(events)
	if pending_events.size() > 50:
		epoch += 1
		pending_events.clear()
		playing = false
		_render()
	elif not playing:
		_play()

func _render() -> void:
	if latest.is_empty() or not is_inside_tree(): return
	var outcome := str(latest.get("combat_state", {}).get("terminal_result", ""))
	title.text = tr("SPECTATING") % str(SceneRouter._spectator_context.get("username", ""))
	if outcome in ["WIN", "LOSS"]: title.text += "  |  " + tr("EXPEDITION_VICTORY" if outcome == "WIN" else "EXPEDITION_DEFEAT")
	elif str(latest.get("status", "")) not in ["", "ACTIVE"]: title.text += "  |  " + tr("SPECTATOR_ENDED")
	if mode == "hunt":
		SceneRouter._spectator_context["visual_zone_id"] = str(latest.get("zone_id", ""))
		host._online_hunt_session = latest.duplicate(true)
		host._online_hunt_revision = int(latest.get("combat_revision", 0))
		host._render_online_hunt(latest)
	else:
		host._dungeon_session = latest.duplicate(true)
		host._dungeon_render()
	for button in host.spell_buttons: button.disabled = true
	host.switch_weapon_btn.disabled = true
	host.ultra_button.disabled = true
	host.hom_decision.hide()
	if host._inspiration_panel != null: host._inspiration_panel.hide()

func _play() -> void:
	if playing or not is_inside_tree(): return
	playing = true
	var current := epoch
	while not pending_events.is_empty() and is_inside_tree() and current == epoch:
		var event: Dictionary = pending_events.pop_front()
		if mode == "hunt":
			if event.get("kind") == "player_cast": host._log_online_spell(str(event.get("spell_id", "")), true)
			else: host._log_online_hunt_event(event)
			var target := str(event.get("target", ""))
			var bar: ProgressBar = host.player_hp if target == "player" else host.enemy_hp if target == "boss" else null
			if bar != null and (event.has("hp") or int(event.get("actual_damage", event.get("damage", 0))) > 0):
				var after := int(event.hp) if event.has("hp") else maxi(0, int(bar.value) - int(event.get("actual_damage", event.get("damage", 0))))
				await get_tree().create_timer(0.26).timeout
				if not is_inside_tree() or current != epoch or SceneRouter._spectator_context.is_empty(): return
				host._set_display_hp(bar, after)
			elif bar == null and event.has("hp"):
				await get_tree().create_timer(0.26).timeout
				if not is_inside_tree() or current != epoch or SceneRouter._spectator_context.is_empty(): return
				for minion in host._solo_minions:
					if str(minion.get("id", "")) == target: minion.hp = int(event.hp); break
				host._update_solo_minion_views()
			await get_tree().create_timer(host._online_hunt_event_delay(event)).timeout
		else:
			await host._dungeon_present_events([event], str(ConnectionGate.player_id), int(ConnectionGate._generation), "", str(SceneRouter._spectator_context.get("observation_id", "")), 0, current)
	if current == epoch:
		playing = false
		_render()

func valid_playback(owner: String, generation: int, observation: String, playback_epoch: int) -> bool:
	return is_inside_tree() and playback_epoch == epoch and owner == str(ConnectionGate.player_id) and generation == int(ConnectionGate._generation) and observation == str(SceneRouter._spectator_context.get("observation_id", "")) and observation == SpectatorClient._observation
