extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Recovery := preload("res://scripts/net/expedition_recovery.gd")
const SeenRewards := preload("res://scripts/net/expedition_rewards_seen.gd")
const BACKGROUNDS := "res://assets/entities/expeditions/backgrounds/"
var backend: BackendClient
var account_id := ""
var request := ""
var request_kind := ""
var session := {}
var pending := {}
var state_data := {}
var background_key := ""
var video: VideoStreamPlayer
var video_clip: Control
var content: VBoxContainer
var status: Label
var message: Label
var body: Control
var retry: Button
var poll := 0.0
var received_ticks := 0
var resumed := false
var last_error := ""
var countdown_refresh := false
var playing_events := false
var playback_epoch := 0
var replaying_pending := false
var combat_view: Control
var back_button: Button
var exit_button: Button
var exit_confirmation: ConfirmationDialog
var capture_sprite: TextureRect
var capture_tween: Tween
var capture_started := 0
var reward_popup: CanvasLayer
var phase_buttons: Array[Button] = []
var visual_debug := false
var visual_debug_entry: Button
var visual_inspector: Control

func _ready() -> void:
	UIThemeFactory.apply_theme_scaled(self, clampf(minf(get_viewport_rect().size.x / 1920.0, get_viewport_rect().size.y / 1080.0), 0.65, 1.0))
	$Background.hide()
	_build_ui()
	if _visual_debug_allowed():
		status.text = "VISUAL DEBUG · OFFLINE"
		return
	backend = BackendClient.new()
	backend.auto_dev_login = false
	backend.state_updated.connect(_identity_changed)
	backend.auth_changed.connect(_auth_changed)
	backend.api_completed.connect(_completed)
	add_child(backend)
	status.text = tr("EXPEDITION_VERIFY")

func _exit_tree() -> void:
	if is_instance_valid(video):
		video.stop()
		video.stream = null

func _visual_debug_allowed() -> bool:
	return OS.has_feature("editor") and get_node("/root/ConnectionGate").debug_lab_navigation_allowed()

func _enter_visual_debug() -> void:
	if not _visual_debug_allowed() or backend != null or visual_debug: return
	visual_debug = true
	visual_debug_entry.hide()
	retry.hide()
	visual_inspector = preload("res://scripts/ui/expedition_visual_inspector.gd").new()
	content.add_child(visual_inspector)
	content.move_child(visual_inspector, body.get_index())
	visual_inspector.configure(self)

func debug_render(sample: Dictionary) -> void:
	if not visual_debug or not _visual_debug_allowed(): return
	_stop_capture_animation()
	playing_events = false
	playback_epoch += 1
	if is_instance_valid(reward_popup): reward_popup.queue_free()
	reward_popup = null
	session = sample.duplicate(true)
	state_data = {"mana":4, "crystals":3, "server_time_unix_ms":0, "next_regeneration_at":null, "remaining_cooldown_ms":0}
	received_ticks = Time.get_ticks_msec()
	resumed = true
	_render()
	status.text = "VISUAL DEBUG · OFFLINE"
	if is_instance_valid(combat_view): combat_view.lock_controls()

func debug_popup(title: String, texture: Texture2D, detail: String) -> void:
	if not visual_debug or not _visual_debug_allowed() or texture == null: return
	if is_instance_valid(reward_popup): reward_popup.queue_free()
	var popup := preload("res://scripts/ui/expedition_reward_popup.gd").new()
	reward_popup = popup
	add_child(popup)
	popup.acknowledged.connect(func(): reward_popup = null; popup.queue_free())
	popup.show_reward(title, texture, detail)

func _build_ui() -> void:
	video_clip = Control.new()
	video_clip.clip_contents = true
	video_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(video_clip)
	var fallback := ColorRect.new()
	fallback.color = Color("111722")
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_clip.add_child(fallback)
	video = VideoStreamPlayer.new()
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.finished.connect(func(): if video.stream != null: video.play())
	video_clip.add_child(video)
	resized.connect(_fit_video)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	back_button = Button.new()
	back_button.text = tr("UI_BACK_UPPER")
	MenuArt.button(back_button)
	back_button.pressed.connect(SceneRouter.go_to_world_gate)
	top.add_child(back_button)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 24)
	top.add_child(status)
	retry = Button.new()
	retry.text = tr("EXPEDITION_RETRY")
	MenuArt.button(retry)
	retry.pressed.connect(_refresh)
	top.add_child(retry)
	if _visual_debug_allowed():
		visual_debug_entry = Button.new()
		visual_debug_entry.text = "VISUAL DEBUG"
		MenuArt.button(visual_debug_entry)
		visual_debug_entry.pressed.connect(_enter_visual_debug)
		top.add_child(visual_debug_entry)
	exit_button = Button.new()
	exit_button.text = tr("EXPEDITION_EXIT")
	MenuArt.button(exit_button)
	exit_button.pressed.connect(_confirm_exit)
	top.add_child(exit_button)
	exit_button.hide()
	exit_confirmation = ConfirmationDialog.new()
	exit_confirmation.title = tr("EXPEDITION_EXIT")
	exit_confirmation.dialog_text = tr("EXPEDITION_EXIT_CONFIRM")
	exit_confirmation.confirmed.connect(func(): _send_phase_action("exit"))
	add_child(exit_confirmation)
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)

func _auth_changed(_token: String) -> void:
	playback_epoch += 1
	playing_events = false
	_stop_capture_animation()
	if is_instance_valid(reward_popup): reward_popup.queue_free()
	reward_popup = null
	account_id = ""
	request = ""
	session.clear()
	pending.clear()
	state_data.clear()
	resumed = false
	last_error = ""
	SceneRouter._expedition_context.clear()
	_set_background("")
	_clear_body()
	status.text = tr("EXPEDITION_VERIFY")

func _identity_changed(state: Dictionary) -> void:
	var identity := str(state.get("player_id", ""))
	if backend == null or identity.is_empty() or identity != backend._verified_player_id or backend.token.is_empty():
		_auth_changed("")
		return
	if account_id != identity:
		account_id = identity
		session.clear()
		pending = Recovery.load_pending(account_id)
		_refresh()

func _process(delta: float) -> void:
	if video.is_playing(): _fit_video()
	if visual_debug:
		if not _visual_debug_allowed():
			visual_debug = false
			playing_events = false
			_stop_capture_animation()
			_set_background("")
			_clear_body()
			if is_instance_valid(visual_inspector): visual_inspector.queue_free()
			if is_instance_valid(reward_popup): reward_popup.queue_free()
			status.text = "Visual debug unavailable"
		return
	if playing_events and get_node("/root/ConnectionGate").blocked():
		playback_epoch += 1
		playing_events = false
		_stop_capture_animation()
		state_data.clear()
	poll += delta
	if poll < 2.0: return
	poll = 0.0
	if not playing_events and not account_id.is_empty() and request.is_empty() and not get_node("/root/ConnectionGate").blocked() and (state_data.is_empty() or not pending.is_empty()):
		_refresh()
	if not state_data.is_empty(): _update_status()

func _refresh() -> void:
	if visual_debug or backend == null: return
	if playing_events or is_instance_valid(reward_popup) or account_id.is_empty() or backend._verified_player_id != account_id or not request.is_empty(): return
	request_kind = "state"
	request = backend.request_api("GET", "/expeditions/state", null)
	if is_instance_valid(combat_view): combat_view.lock_controls()
	_update_controls()
	if request.is_empty(): message.text = tr("EXPEDITION_CONNECTION")

func _completed(id: String, ok: bool, data: Dictionary) -> void:
	if id != request or id.is_empty(): return
	request = ""
	if account_id.is_empty() or backend._verified_player_id != account_id or backend.token.is_empty():
		_auth_changed("")
		return
	if not ok:
		if request_kind == "capture":
			playback_epoch += 1
			playing_events = false
			_stop_capture_animation()
		last_error = str(data.get("error", tr("EXPEDITION_CONNECTION")))
		message.text = last_error
		if request_kind != "state" and int(data.get("http_status", 0)) in [400, 404, 409]:
			if Recovery.clear(account_id): pending.clear()
		state_data.clear()
		return
	var received: Variant = data.get("session")
	if received != null and (not received is Dictionary or str(received.get("run_id", "")).is_empty() or int(received.get("revision", 0)) < 1):
		message.text = tr("EXPEDITION_BAD_STATE")
		return
	if received is Dictionary and not session.is_empty() and str(received.get("run_id", "")) == str(session.get("run_id", "")) and int(received.get("revision", 0)) < int(session.get("revision", 0)) and not (replaying_pending and request_kind in ["capture", "advance", "skip"]):
		message.text = tr("EXPEDITION_BAD_STATE")
		return
	if request_kind != "state" and not _valid_action_response(received):
		message.text = tr("EXPEDITION_BAD_STATE")
		state_data.clear()
		return
	if request_kind == "capture" and playing_events and not replaying_pending:
		var capture_epoch := playback_epoch
		var capture_owner := account_id
		var remaining := maxf(0.0, 3.0 - float(Time.get_ticks_msec() - capture_started) / 1000.0)
		if remaining > 0: await get_tree().create_timer(remaining).timeout
		if not is_inside_tree() or capture_epoch != playback_epoch or capture_owner != account_id or backend._verified_player_id != capture_owner or get_node("/root/ConnectionGate").blocked():
			if is_inside_tree() and capture_epoch == playback_epoch and capture_owner == account_id:
				playing_events = false
				state_data.clear()
			return
		playing_events = false
		_stop_capture_animation()
	if request_kind in ["turn", "inspiration"] and not replaying_pending and data.get("events") is Array and not data.events.is_empty():
		playing_events = true
		playback_epoch += 1
		var epoch := playback_epoch
		var identity := account_id
		var action_id := str(pending.get("payload", {}).get("client_action_id", ""))
		if is_instance_valid(combat_view):
			await combat_view.present_events(data.events, epoch)
		if not is_inside_tree() or epoch != playback_epoch or identity != account_id or backend._verified_player_id != identity or action_id != str(pending.get("payload", {}).get("client_action_id", "")) or get_node("/root/ConnectionGate").blocked():
			if is_inside_tree() and epoch == playback_epoch and identity == account_id:
				playing_events = false
				state_data.clear()
			return
		playing_events = false
	var response_kind := request_kind
	var response_events: Array = data.get("events", []) if data.get("events") is Array else []
	var older_replay := replaying_pending and received is Dictionary and not session.is_empty() and str(received.get("run_id", "")) == str(session.get("run_id", "")) and int(received.get("revision", 0)) < int(session.get("revision", 0))
	if not older_replay:
		state_data = data.duplicate(true)
		received_ticks = Time.get_ticks_msec()
		countdown_refresh = false
		session = received.duplicate(true) if received is Dictionary else {}
	if request_kind != "state":
		resumed = true
		if not Recovery.clear(account_id):
			message.text = tr("EXPEDITION_SAVE_ERROR")
			return
		pending.clear()
		replaying_pending = false
		if response_kind == "exit":
			SceneRouter._expedition_context.clear()
			SceneRouter.go_to_world_gate()
			return
	elif not pending.is_empty():
		_reconcile_pending()
		if not pending.is_empty(): return
	message.text = last_error
	last_error = ""
	_render()
	if response_kind in ["capture", "advance"] and not response_events.is_empty():
		_present_reward(response_events[0])
	elif response_kind == "state" and session.get("latest_reward") is Dictionary:
		_present_reward(session.latest_reward)

func _valid_action_response(received: Variant) -> bool:
	if pending.is_empty(): return false
	if request_kind == "exit": return received == null
	if not received is Dictionary: return false
	var payload: Dictionary = pending.get("payload", {})
	if request_kind == "start": return int(received.get("revision", 0)) >= 1
	return str(received.get("run_id", "")) == str(payload.get("run_id", "")) and int(received.get("revision", 0)) == int(payload.get("expected_revision", 0)) + 1

func _reconcile_pending() -> void:
	if pending.has("error"):
		message.text = tr("EXPEDITION_SAVE_ERROR")
		return
	var kind := str(pending.get("kind", ""))
	var payload: Dictionary = pending.get("payload", {})
	if kind == "start" and not session.is_empty():
		resumed = true
		if Recovery.clear(account_id): pending.clear()
		return
	if kind == "select":
		if session.is_empty() or str(session.get("run_id", "")) != str(payload.get("run_id", "")) or int(session.get("revision", 0)) > int(payload.get("expected_revision", 0)):
			if Recovery.clear(account_id): pending.clear()
			return
		if int(session.get("revision", 0)) != int(payload.get("expected_revision", 0)):
			message.text = tr("EXPEDITION_BAD_STATE")
			return
	if kind in ["turn", "inspiration", "capture", "skip", "advance"] and not session.is_empty():
		if str(session.get("run_id", "")) != str(payload.get("run_id", "")):
			message.text = tr("EXPEDITION_BAD_STATE")
			return
		var revision := int(session.get("revision", 0))
		if revision > int(payload.get("expected_revision", 0)) and kind not in ["capture", "advance"]:
			if Recovery.clear(account_id): pending.clear()
			return
		if revision < int(payload.get("expected_revision", 0)):
			message.text = tr("EXPEDITION_BAD_STATE")
			return
	replaying_pending = true
	request_kind = kind
	request = backend.request_api("POST", "/expeditions/" + kind, payload)
	_update_controls()
	if request.is_empty(): message.text = tr("EXPEDITION_CONNECTION")

func send_combat_decision(kind: String, decision: Dictionary) -> void:
	if visual_debug: return
	if kind not in ["turn", "inspiration"] or playing_events or not request.is_empty() or not pending.is_empty() or state_data.is_empty() or account_id.is_empty() or backend._verified_player_id != account_id or backend.token.is_empty() or get_node("/root/ConnectionGate").blocked() or str(session.get("phase", "")) != "COMBAT": return
	var combat: Dictionary = session.get("combat_state", {})
	if combat.get("terminal_result") != null or bool(combat.get("player", {}).get("inspiration_pending", false)) != (kind == "inspiration"): return
	var payload := {"run_id": str(session.get("run_id", "")), "expected_revision": int(session.get("revision", 0)), "client_action_id": backend._make_uuid(), "decision": decision.duplicate(true)}
	if not Recovery.save_pending(account_id, kind, payload):
		message.text = tr("EXPEDITION_SAVE_ERROR")
		return
	pending = Recovery.load_pending(account_id)
	replaying_pending = false
	request_kind = kind
	request = backend.request_api("POST", "/expeditions/" + kind, payload)
	if is_instance_valid(combat_view): combat_view.lock_controls()
	_update_controls()
	if request.is_empty():
		state_data.clear()
		message.text = tr("EXPEDITION_CONNECTION")

func _update_controls() -> void:
	if not is_instance_valid(exit_button): return
	var active := not session.is_empty() and str(session.get("status", "")) == "ACTIVE"
	var busy: bool = playing_events or not pending.is_empty() or not request.is_empty() or is_instance_valid(reward_popup) or account_id.is_empty() or backend == null or backend._verified_player_id != account_id or get_node("/root/ConnectionGate").blocked()
	exit_button.visible = active
	exit_button.disabled = busy
	back_button.visible = not active
	retry.disabled = busy
	for button in phase_buttons:
		if is_instance_valid(button): button.disabled = busy or bool(button.get_meta("unavailable", false))

func _confirm_exit() -> void:
	if exit_button.disabled or not exit_button.visible: return
	exit_confirmation.popup_centered()

func _send_phase_action(kind: String, direction: String = "") -> void:
	if visual_debug: return
	if kind not in ["capture", "skip", "advance", "exit"] or playing_events or not request.is_empty() or not pending.is_empty() or is_instance_valid(reward_popup) or state_data.is_empty() or account_id.is_empty() or backend._verified_player_id != account_id or backend.token.is_empty() or get_node("/root/ConnectionGate").blocked() or str(session.get("status", "")) != "ACTIVE": return
	var phase := str(session.get("phase", ""))
	if kind in ["capture", "skip"] and phase != "REWARD": return
	if kind == "advance" and (phase != "ROUTE" or direction not in ["left", "forward", "right"] or direction not in session.get("directions", [])): return
	if kind == "capture" and (_candidate().is_empty() or bool(session.get("capture_closed", true)) or int(session.get("capture_attempts_remaining", 0)) < 1 or int(state_data.get("crystals", 0)) < 1): return
	var payload := {"run_id":str(session.get("run_id", "")), "expected_revision":int(session.get("revision", 0)), "client_action_id":backend._make_uuid()}
	if kind == "advance": payload["direction"] = direction
	if not Recovery.save_pending(account_id, kind, payload):
		message.text = tr("EXPEDITION_SAVE_ERROR")
		return
	pending = Recovery.load_pending(account_id)
	replaying_pending = false
	request_kind = kind
	if kind == "capture": _start_capture_animation()
	request = backend.request_api("POST", "/expeditions/" + kind, payload)
	if is_instance_valid(combat_view): combat_view.lock_controls()
	_update_controls()
	if request.is_empty():
		playback_epoch += 1
		playing_events = false
		_stop_capture_animation()
		state_data.clear()
		message.text = tr("EXPEDITION_CONNECTION")

func _start_capture_animation() -> void:
	playing_events = true
	playback_epoch += 1
	capture_started = Time.get_ticks_msec()
	if not is_instance_valid(capture_sprite): return
	capture_sprite.pivot_offset = capture_sprite.size * 0.5
	capture_tween = create_tween().set_loops(6)
	capture_tween.tween_property(capture_sprite, "rotation", -0.07, 0.25).set_trans(Tween.TRANS_SINE)
	capture_tween.parallel().tween_property(capture_sprite, "scale", Vector2(1.05, 1.05), 0.25)
	capture_tween.parallel().tween_property(capture_sprite, "modulate", Color(1.35, 1.35, 1.5), 0.25)
	capture_tween.tween_property(capture_sprite, "rotation", 0.07, 0.25).set_trans(Tween.TRANS_SINE)
	capture_tween.parallel().tween_property(capture_sprite, "scale", Vector2.ONE, 0.25)
	capture_tween.parallel().tween_property(capture_sprite, "modulate", Color.WHITE, 0.25)
	message.text = tr("EXPEDITION_CAPTURE_SUSPENSE")

func _stop_capture_animation() -> void:
	if is_instance_valid(capture_tween): capture_tween.kill()
	capture_tween = null
	if is_instance_valid(capture_sprite):
		capture_sprite.rotation = 0.0
		capture_sprite.scale = Vector2.ONE
		capture_sprite.modulate = Color.WHITE
	capture_started = 0

func _candidate(id: String = "") -> Dictionary:
	var candidate: Variant = session.get("capture_candidate")
	if id.is_empty() and candidate is Dictionary: id = str(candidate.get("id", ""))
	if id.is_empty(): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/expedition_homunculi.json"))
	if not data is Dictionary: return {}
	for record in data.get("homunculi", []):
		if record is Dictionary and str(record.get("id", "")) == id:
			var preview := "res://assets/entities/gameplay/homunculus/%s_pv.png" % id
			var combat := "res://assets/entities/gameplay/homunculus/ingame/1024/%s.png" % id
			if record.get("preview_texture") != preview or record.get("combat_texture") != combat or not ResourceLoader.exists(preview) or not ResourceLoader.exists(combat): return {}
			if candidate is Dictionary and str(candidate.get("id", "")) == id and (candidate.get("preview_texture") != preview or candidate.get("type") != record.get("type") or candidate.get("rarity") != record.get("rarity")): return {}
			return record
	return {}

func _present_reward(event: Variant) -> void:
	if visual_debug: return
	if not event is Dictionary or account_id.is_empty() or is_instance_valid(reward_popup): return
	var kind := str(event.get("kind", ""))
	if kind == "capture_failure":
		message.text = tr("EXPEDITION_CAPTURE_FAILED")
		return
	if kind != "capture_success" and not (kind == "crystal_drop" and bool(event.get("granted", false))): return
	var reward_id := str(event.get("reward_id", ""))
	if reward_id.is_empty() or SeenRewards.has_seen(account_id, reward_id): return
	var texture: Texture2D
	var title := ""
	var detail := ""
	if kind == "crystal_drop":
		if int(event.get("amount", 0)) != 1 or str(event.get("asset_key", "")) != "res://assets/entities/expeditions/capture.png": return
		texture = _texture(str(event.asset_key), "res://assets/entities/expeditions/")
		title = tr("EXPEDITION_CRYSTAL_GAINED")
		detail = "+1"
	else:
		var hom := _candidate(str(event.get("candidate_id", "")))
		if hom.is_empty() or event.get("preview_texture") != hom.get("preview_texture"): return
		texture = _texture(str(hom.preview_texture), "res://assets/entities/gameplay/homunculus/")
		var duplicate := bool(event.get("duplicate", false))
		if duplicate and int(event.get("duplicate_xp", 0)) != 20: return
		title = tr("EXPEDITION_DUPLICATE_XP" if duplicate else "EXPEDITION_CAPTURE_SUCCESS")
		detail = str(hom.get("name", ""))
	if texture == null: return
	var popup := preload("res://scripts/ui/expedition_reward_popup.gd").new()
	reward_popup = popup
	add_child(popup)
	var popup_owner := account_id
	popup.acknowledged.connect(func():
		if popup_owner != account_id or not SeenRewards.mark_seen(popup_owner, reward_id):
			message.text = tr("EXPEDITION_SAVE_ERROR")
			return
		reward_popup = null
		popup.queue_free()
		_update_controls())
	popup.show_reward(title, texture, detail)
	_update_controls()

func _update_status() -> void:
	var elapsed := maxi(0, Time.get_ticks_msec() - received_ticks)
	var regen_at: Variant = state_data.get("next_regeneration_at")
	var regen := maxi(0, int(regen_at) - int(state_data.get("server_time_unix_ms", 0)) - elapsed) if regen_at != null else 0
	var cooldown := maxi(0, int(state_data.get("remaining_cooldown_ms", 0)) - elapsed)
	status.text = tr("EXPEDITION_BALANCE") % [int(state_data.get("mana", 0)), int(state_data.get("crystals", 0)), _duration(regen), _duration(cooldown)]
	if session.is_empty() and not countdown_refresh and ((int(state_data.get("remaining_cooldown_ms", 0)) > 0 and cooldown == 0) or (state_data.get("next_regeneration_at") != null and regen == 0)):
		countdown_refresh = true
		call_deferred("_refresh")

func _duration(ms: int) -> String:
	var seconds := int(ceil(ms / 1000.0))
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]

func _clear_body() -> void:
	phase_buttons.clear()
	capture_sprite = null
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func _render() -> void:
	_clear_body()
	_update_status()
	_update_controls()
	if session.is_empty():
		_set_background("")
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.add_child(center)
		var start := Button.new()
		start.text = tr("EXPEDITION_START")
		start.custom_minimum_size = Vector2(300, 70)
		start.disabled = int(state_data.get("mana", 0)) < 1 or int(state_data.get("remaining_cooldown_ms", 0)) > 0
		MenuArt.button(start)
		start.pressed.connect(func(): SceneRouter.go_to_expedition_loadout(account_id))
		center.add_child(start)
		return
	if not resumed:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.add_child(center)
		var resume := Button.new()
		resume.text = tr("EXPEDITION_RESUME")
		resume.custom_minimum_size = Vector2(300, 70)
		MenuArt.button(resume)
		resume.pressed.connect(func(): resumed = true; _render())
		center.add_child(resume)
		return
	_set_background(str(session.get("background_key", "")))
	match str(session.get("phase", "")):
		"EXPLORE": _render_choices()
		"COMBAT": _render_combat()
		"REWARD": _render_terminal(true)
		"ROUTE": _render_route()
		"LOSS": _render_terminal(false)
		_: message.text = tr("EXPEDITION_PHASE_UNAVAILABLE") % str(session.get("phase", ""))

func _render_choices() -> void:
	var choices: Variant = session.get("choices", [])
	if not choices is Array or choices.size() != 2:
		message.text = tr("EXPEDITION_BAD_STATE")
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 100)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	for i in 2:
		var choice: Variant = choices[i]
		if not choice is Dictionary or int(choice.get("choice", -1)) != i: continue
		var button := Button.new()
		button.flat = true
		button.custom_minimum_size = Vector2(360, 500)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_select.bind(i))
		row.add_child(button)
		phase_buttons.append(button)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(box)
		var portrait := TextureRect.new()
		portrait.texture = _texture(str(choice.get("preview_texture", "")), "res://assets/entities/expeditions/preview/")
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(portrait)
		box.add_child(_label("%s\n%s" % [str(choice.get("name", "")), _types(choice.get("types", []))], 28))
	_update_controls()

func _select(index: int) -> void:
	if visual_debug: return
	if backend == null or account_id.is_empty() or not request.is_empty() or not pending.is_empty() or account_id != backend._verified_player_id or str(session.get("phase", "")) != "EXPLORE": return
	var payload := {"run_id": str(session.get("run_id", "")), "expected_revision": int(session.get("revision", 0)), "choice": index, "client_action_id": backend._make_uuid()}
	if not Recovery.save_pending(account_id, "select", payload):
		message.text = tr("EXPEDITION_SAVE_ERROR")
		return
	pending = Recovery.load_pending(account_id)
	_clear_body()
	_refresh()

func _render_combat() -> void:
	combat_view = preload("res://scripts/ui/expedition_combat.gd").new()
	combat_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(combat_view)
	combat_view.configure(self, session)
	message.text = ""

func _render_terminal(won: bool) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	box.add_child(_label(tr("EXPEDITION_VICTORY" if won else "EXPEDITION_DEFEAT"), 48))
	var candidate: Variant = session.get("capture_candidate")
	if won and candidate is Dictionary:
		var hom := _candidate()
		if not hom.is_empty():
			capture_sprite = TextureRect.new()
			capture_sprite.custom_minimum_size = Vector2(400, 400)
			capture_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			capture_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			capture_sprite.texture = _texture(str(hom.combat_texture), "res://assets/entities/gameplay/homunculus/ingame/1024/")
			box.add_child(capture_sprite)
			box.add_child(_label("%s  |  %s  |  %s %s" % [GameLocalization.catalog("homunculus", str(hom.id), "name", str(hom.name)), _types([hom.type]), tr("EXPEDITION_RARITY"), str(hom.rarity)], 26))
			box.add_child(_label(tr("EXPEDITION_CAPTURE_COUNTS") % [int(session.get("capture_attempts_remaining", 0)), int(state_data.get("crystals", 0))], 22))
			var capture := Button.new()
			capture.custom_minimum_size.y = 54
			capture.add_theme_font_size_override("font_size", 22)
			capture.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.76))
			capture.text = tr("EXPEDITION_CAPTURE")
			capture.set_meta("unavailable", bool(session.get("capture_closed", true)) or int(session.get("capture_attempts_remaining", 0)) < 1 or int(state_data.get("crystals", 0)) < 1)
			MenuArt.button(capture)
			capture.pressed.connect(func(): _send_phase_action("capture"))
			box.add_child(capture)
			phase_buttons.append(capture)
		else:
			message.text = tr("EXPEDITION_BAD_STATE")
	if won:
		var skip := Button.new()
		skip.custom_minimum_size.y = 54
		skip.add_theme_font_size_override("font_size", 22)
		skip.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.76))
		skip.text = tr("EXPEDITION_SKIP")
		MenuArt.button(skip)
		skip.pressed.connect(func(): _send_phase_action("skip"))
		box.add_child(skip)
		phase_buttons.append(skip)
	if not won:
		var back := Button.new()
		back.text = tr("UI_BACK_UPPER")
		back.disabled = visual_debug
		MenuArt.button(back)
		back.pressed.connect(SceneRouter.go_to_world_gate)
		box.add_child(back)
	_update_controls()

func _render_route() -> void:
	var directions: Variant = session.get("directions", [])
	if not directions is Array or directions != ["left", "forward", "right"]:
		message.text = tr("EXPEDITION_BAD_STATE")
		return
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(center)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 42)
	center.add_child(row)
	for direction in directions:
		var arrow := Button.new()
		arrow.custom_minimum_size = Vector2(240, 150)
		arrow.add_theme_font_size_override("font_size", 34)
		arrow.text = ("←" if direction == "left" else "↑" if direction == "forward" else "→") + "\n" + tr("EXPEDITION_DIRECTION_" + str(direction).to_upper())
		MenuArt.button(arrow)
		arrow.pressed.connect(_send_phase_action.bind("advance", str(direction)))
		row.add_child(arrow)
		phase_buttons.append(arrow)
	_update_controls()

func _actor(fighter: Dictionary, path: String, flipped: bool) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 480)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait := TextureRect.new()
	portrait.texture = _texture(path, "res://assets/entities/")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.flip_h = flipped
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(portrait)
	var types: Variant = fighter.get("expedition_types", fighter.get("types", [fighter.get("type", "")]))
	box.add_child(_label("%s  |  HP %s / %s\n%s" % [str(fighter.get("name", fighter.get("id", ""))), str(fighter.get("hp", 0)), str(fighter.get("max_hp", 0)), _types(types)], 24))
	return box

func _label(value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label

func _types(value: Variant) -> String:
	if not value is Array: return ""
	var names: Array[String] = []
	for item in value: names.append(GameLocalization.catalog("type", str(item), "name", str(item).capitalize()))
	return "  /  ".join(names)

func _texture(path: String, prefix: String) -> Texture2D:
	if not path.begins_with(prefix) or path.contains("..") or not ResourceLoader.exists(path): return null
	return load(path) as Texture2D

func _set_background(key: String) -> void:
	if key == background_key: return
	video.stop()
	video.stream = null
	background_key = ""
	if key.is_empty(): return
	if key.contains("/") or key.contains("\\") or key.contains("..") or not key.ends_with(".ogv"): return
	var path := BACKGROUNDS + key
	if not ResourceLoader.exists(path):
		message.text = tr("EXPEDITION_VIDEO_MISSING")
		return
	video.stream = load(path) as VideoStream
	if video.stream != null:
		background_key = key
		video.play()
		_fit_video()

func _fit_video() -> void:
	if not is_instance_valid(video) or video.stream == null: return
	var texture := video.get_video_texture()
	var dimensions := Vector2(texture.get_size()) if texture != null else Vector2.ZERO
	if dimensions.x <= 0 or dimensions.y <= 0: return
	var viewport := video_clip.size
	var factor := maxf(viewport.x / dimensions.x, viewport.y / dimensions.y)
	video.size = dimensions * factor
	video.position = (viewport - video.size) * 0.5
