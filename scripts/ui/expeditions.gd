extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Recovery := preload("res://scripts/net/expedition_recovery.gd")
const SeenRewards := preload("res://scripts/net/expedition_rewards_seen.gd")
const BACKGROUNDS := "res://assets/entities/expeditions/backgrounds/"
var spectator_mode := false
var spectator_events: Array = []
var spectator_latest := {}
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
var background_shade: ColorRect
var content: VBoxContainer
var status: Label
var mana_bar: ProgressBar
var crystal_bar: ProgressBar
var mana_text: Label
var crystal_text: Label
var mana_prompt := false
var mana_continue_requested := false
var message: Label
var body: Control
var retry: Button
var poll := 0.0
var received_ticks := 0
var last_error := ""
var countdown_refresh := false
var playing_events := false
var playback_epoch := 0
var combat_view: Control
var back_button: Button
var exit_button: Button
var exit_confirmation: ConfirmationDialog
var capture_sprite: TextureRect
var capture_heading: Label
var capture_tween: Tween
var capture_started := 0
var reward_popup: CanvasLayer
var victory_rewards_acknowledged := {}
var phase_buttons: Array[Button] = []
var visual_debug := false
var visual_debug_entry: Button
var visual_inspector: Control
var visual_debug_view := 0 # 0: expanded, 1: minimized, 2: clean
var visual_debug_restore: Button
var lease := ""
var lease_run := ""
var lease_token := ""
var heartbeat_http: HTTPRequest
var heartbeat_timer: Timer
var heartbeat_in_flight := false
var forfeited := false
var recovery_required := false
var recovery_conflict := false

func _android_ui() -> bool:
	return OS.has_feature("android") or (OS.is_debug_build() and OS.get_environment("UI_ANDROID_PREVIEW") == "1")

func _ready() -> void:
	UIThemeFactory.apply_theme_scaled(self, clampf(minf(get_viewport_rect().size.x / 1920.0, get_viewport_rect().size.y / 1080.0), 0.65, 1.0))
	$Background.hide()
	_build_ui()
	spectator_mode = str(SceneRouter._spectator_context.get("mode", "")) == "expedition"
	if spectator_mode:
		back_button.pressed.disconnect(SceneRouter.go_to_world_gate)
		back_button.pressed.connect(SceneRouter.finish_spectating)
		back_button.text = tr("SPECTATOR_LEAVE")
		status.text = tr("SPECTATING") % str(SceneRouter._spectator_context.get("username", ""))
		mana_bar.get_parent().hide()
		crystal_bar.get_parent().hide()
		retry.hide()
		exit_button.hide()
		SpectatorClient.updated.connect(_spectator_update)
		SpectatorClient.failed.connect(_spectator_failure)
		SpectatorClient.ready_to_observe()
		return
	var observer_indicator := preload("res://scripts/ui/spectator_indicator.gd").new()
	content.add_child(observer_indicator)
	Recovery.clear_legacy()
	if _visual_debug_allowed():
		status.text = "VISUAL DEBUG · OFFLINE"
		return
	backend = BackendClient.new()
	backend.auto_dev_login = false
	backend.state_updated.connect(_identity_changed)
	backend.auth_changed.connect(_auth_changed)
	backend.api_completed.connect(_completed)
	add_child(backend)
	heartbeat_http = HTTPRequest.new()
	heartbeat_http.process_mode = Node.PROCESS_MODE_ALWAYS
	heartbeat_http.timeout = 4.0
	heartbeat_http.max_redirects = 0
	add_child(heartbeat_http)
	heartbeat_http.request_completed.connect(_heartbeat_completed)
	heartbeat_timer = Timer.new()
	heartbeat_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	heartbeat_timer.wait_time = 5.0
	heartbeat_timer.timeout.connect(_heartbeat)
	add_child(heartbeat_timer)
	status.text = tr("EXPEDITION_VERIFY")
	if SceneRouter._expedition_forfeit_notice:
		SceneRouter._expedition_forfeit_notice = false
		_forfeit()

func _exit_tree() -> void:
	if not lease.is_empty() or request_kind == "start" and not request.is_empty():
		SceneRouter._expedition_forfeit_notice = true
		SceneRouter._expedition_context.clear()
	_stop_lease()
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
	visual_debug_restore = Button.new()
	visual_debug_restore.name = "VisualDebugRestore"
	visual_debug_restore.text = "F8 +"
	visual_debug_restore.tooltip_text = "Expand inspector (F8)"
	visual_debug_restore.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	visual_debug_restore.offset_left = -74
	visual_debug_restore.offset_top = -46
	visual_debug_restore.offset_right = -12
	visual_debug_restore.offset_bottom = -10
	visual_debug_restore.z_index = 100
	visual_debug_restore.add_theme_font_size_override("font_size", 18)
	var restore_style := StyleBoxFlat.new()
	restore_style.bg_color = Color(0.025, 0.05, 0.08, 0.92)
	restore_style.border_color = Color("4faebc")
	restore_style.set_border_width_all(1)
	restore_style.set_corner_radius_all(4)
	visual_debug_restore.add_theme_stylebox_override("normal", restore_style)
	visual_debug_restore.add_theme_stylebox_override("hover", restore_style)
	visual_debug_restore.add_theme_stylebox_override("pressed", restore_style)
	visual_debug_restore.pressed.connect(func(): _set_visual_debug_view(0))
	add_child(visual_debug_restore)
	visual_debug_restore.hide()
	visual_inspector.configure(self)

func _input(event: InputEvent) -> void:
	if not visual_debug or not _visual_debug_allowed(): return
	if event is InputEventKey and event.keycode == KEY_F8 and event.pressed and not event.echo:
		_set_visual_debug_view((visual_debug_view + 1) % 3)
		get_viewport().set_input_as_handled()

func _set_visual_debug_view(view: int) -> void:
	if not visual_debug or not _visual_debug_allowed() or not is_instance_valid(visual_inspector) or view not in [0, 1, 2]: return
	visual_debug_view = view
	visual_inspector.visible = view == 0
	visual_debug_restore.visible = view == 1
	retry.visible = view != 0
	retry.disabled = true
	if view == 0:
		status.text = "VISUAL DEBUG · OFFLINE"
	else:
		_update_status()

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
	_render()
	if visual_debug_view == 0: status.text = "VISUAL DEBUG · OFFLINE"
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
	background_shade = ColorRect.new()
	background_shade.color = Color(0.2, 0.2, 0.2, 0.55)
	background_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background_shade)
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
	if _android_ui(): back_button.custom_minimum_size = Vector2(140, 64)
	MenuArt.button(back_button)
	back_button.pressed.connect(SceneRouter.go_to_world_gate)
	top.add_child(back_button)
	preload("res://scripts/ui/forest_return_button.gd").attach(top)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 24)
	top.add_child(status)
	mana_bar = _make_resource_bar(top, "res://assets/entities/expeditions/mana.png", 6, Color("318bd3"))
	mana_text = mana_bar.get_node("Amount")
	crystal_bar = _make_resource_bar(top, "res://assets/entities/expeditions/capture.png", 5, Color("e469a6"))
	crystal_text = crystal_bar.get_node("Amount")
	retry = Button.new()
	retry.text = tr("EXPEDITION_RETRY")
	if _android_ui(): retry.custom_minimum_size = Vector2(140, 64)
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
	if _android_ui(): exit_button.custom_minimum_size = Vector2(140, 64)
	MenuArt.button(exit_button)
	exit_button.pressed.connect(_confirm_exit)
	top.add_child(exit_button)
	exit_button.hide()
	exit_confirmation = ConfirmationDialog.new()
	exit_confirmation.title = tr("EXPEDITION_EXIT")
	exit_confirmation.borderless = true
	exit_confirmation.transparent = true
	exit_confirmation.add_theme_stylebox_override("embedded_border", StyleBoxEmpty.new())
	exit_confirmation.add_theme_stylebox_override("embedded_unfocused_border", StyleBoxEmpty.new())
	exit_confirmation.min_size = Vector2i(750, 320)
	exit_confirmation.ok_button_text = tr("UI_CONFIRM")
	exit_confirmation.cancel_button_text = tr("COMBAT_STAY")
	exit_confirmation.dialog_text = tr("EXPEDITION_RISK_WARNING")
	exit_confirmation.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exit_confirmation.add_theme_stylebox_override("panel", MenuArt.frame("panel_horizontal.png", Vector4(64, 50, 64, 45)))
	exit_confirmation.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_confirmation.get_label().add_theme_font_size_override("font_size", 22)
	MenuArt.button(exit_confirmation.get_ok_button())
	MenuArt.button(exit_confirmation.get_cancel_button())
	var exit_shade := ColorRect.new()
	exit_shade.color = Color(0, 0, 0, 0.72)
	exit_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exit_shade.hide()
	add_child(exit_shade)
	exit_confirmation.about_to_popup.connect(exit_shade.show)
	exit_confirmation.visibility_changed.connect(func(): exit_shade.visible = exit_confirmation.visible)
	exit_confirmation.confirmed.connect(func(): _send_phase_action("exit"))
	add_child(exit_confirmation)
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)
	_set_background("")

func _make_resource_bar(parent: Control, icon_path: String, capacity: int, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(icon_path): icon.texture = load(icon_path)
	row.add_child(icon)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(106, 26)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = capacity
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("17232c")
	background.border_color = Color("b9a66c")
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var amount := Label.new()
	amount.name = "Amount"
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override("font_size", 17)
	amount.add_theme_constant_override("outline_size", 3)
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(amount)
	return bar

func _stop_lease() -> void:
	lease = ""
	lease_run = ""
	lease_token = ""
	state_data.erase("lease")
	heartbeat_in_flight = false
	if is_instance_valid(heartbeat_timer): heartbeat_timer.stop()
	if is_instance_valid(heartbeat_http): heartbeat_http.cancel_request()

func _forfeit() -> void:
	if spectator_mode: return
	if forfeited: return
	forfeited = true
	_stop_lease()
	playback_epoch += 1
	playing_events = false
	_stop_capture_animation()
	if is_instance_valid(reward_popup): reward_popup.queue_free()
	reward_popup = null
	pending.clear()
	request = ""
	session.clear()
	SceneRouter._expedition_context.clear()
	_clear_body()
	if is_instance_valid(combat_view): combat_view.lock_controls()
	message.text = tr("EXPEDITION_FORFEITED")
	status.text = tr("EXPEDITION_FORFEITED")
	exit_button.hide()
	back_button.show()
	retry.disabled = true

func connection_gate_lost() -> void:
	if spectator_mode:
		SpectatorClient.pause_for_recovery()
		return
	if lease.is_empty() and pending.is_empty(): return
	recovery_required = true
	playback_epoch += 1
	playing_events = false
	_stop_capture_animation()
	if is_instance_valid(combat_view): combat_view.lock_controls()
	_update_controls()

func connection_gate_recover() -> void:
	if spectator_mode:
		if SpectatorClient.recover_after_gate(): ConnectionGate.recovery_completed()
	else: ConnectionGate.recovery_completed()

func _heartbeat() -> void:
	if spectator_mode: return
	if lease.is_empty() or forfeited or heartbeat_in_flight: return
	var gate = get_node("/root/ConnectionGate")
	if backend == null or backend.token != lease_token or (gate.blocked() and gate.state != gate.State.RECONNECTING): return
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + lease_token, "X-Expedition-Lease: " + lease, preload("res://scripts/net/client_build.gd").header()])
	heartbeat_in_flight = true
	var err := heartbeat_http.request(backend.base_url + "/expeditions/heartbeat", headers, HTTPClient.METHOD_POST, JSON.stringify({"run_id":lease_run}))
	if err != OK: heartbeat_in_flight = false

func _heartbeat_completed(result: int, code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	heartbeat_in_flight = false
	if lease.is_empty() or forfeited: return
	if backend == null or backend.token != lease_token: return
	if result != HTTPRequest.RESULT_SUCCESS or code >= 500 or code in [408, 429]:
		return
	if code == 409 and str(pending.get("kind", "")) == "exit":
		recovery_required = true
		return
	if code != 200:
		_forfeit()
		return
	var result_data: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
	if str(session.get("run_id", "")) != lease_run or not result_data is Dictionary or int(result_data.get("expires_at", 0)) <= int(result_data.get("server_time_unix_ms", 0)):
		_forfeit()

func _auth_changed(_token: String) -> void:
	if not lease.is_empty() or not pending.is_empty():
		if _token.is_empty():
			_forfeit()
		else:
			request = ""
			connection_gate_lost()
		return
	account_id = ""
	request = ""
	session.clear()
	pending.clear()
	state_data.clear()
	if not forfeited: status.text = tr("EXPEDITION_VERIFY")

func _identity_changed(state: Dictionary) -> void:
	var identity := str(state.get("player_id", ""))
	if backend == null or identity.is_empty() or identity != backend._verified_player_id or backend.token.is_empty():
		if account_id.is_empty(): _auth_changed("")
		return
	if not account_id.is_empty() and account_id != identity:
		_forfeit()
		return
	if account_id != identity and not forfeited:
		account_id = identity
		var start_payload: Dictionary = SceneRouter._expedition_context.get("pending_start", {})
		SceneRouter._expedition_context.erase("pending_start")
		if not start_payload.is_empty() and str(SceneRouter._expedition_context.get("player_id", "")) == identity:
			pending = {"kind":"start", "payload":start_payload.duplicate(true)}
			request_kind = "start"
			request = backend.request_api("POST", "/expeditions/start", start_payload)
			if request.is_empty():
				recovery_required = true
				message.text = tr("EXPEDITION_CONNECTION")
		else:
			_refresh()

func _process(delta: float) -> void:
	if video.is_playing(): _fit_video()
	if spectator_mode: return
	if visual_debug:
		if not _visual_debug_allowed():
			visual_debug = false
			playing_events = false
			_stop_capture_animation()
			_set_background("")
			_clear_body()
			if is_instance_valid(visual_inspector): visual_inspector.queue_free()
			if is_instance_valid(visual_debug_restore): visual_debug_restore.queue_free()
			if is_instance_valid(reward_popup): reward_popup.queue_free()
			status.text = "Visual debug unavailable"
		return
	if forfeited: return
	var gate = get_node("/root/ConnectionGate")
	if not lease.is_empty() and not gate.blocked():
		if backend.token.is_empty() or (not backend._verified_player_id.is_empty() and backend._verified_player_id != account_id) or (not gate.player_id.is_empty() and gate.player_id != account_id):
			_forfeit()
			return
		if backend._verified_player_id == account_id and gate.player_id == account_id:
			lease_token = backend.token
	poll += delta
	if poll < 2.0: return
	poll = 0.0
	if not playing_events and not account_id.is_empty() and request.is_empty() and not get_node("/root/ConnectionGate").blocked() and (recovery_required or state_data.is_empty() or not pending.is_empty()):
		_refresh()
	if not state_data.is_empty(): _update_status()

func _refresh() -> void:
	if spectator_mode: return
	if visual_debug or backend == null: return
	if recovery_conflict or playing_events or is_instance_valid(reward_popup) or account_id.is_empty() or backend._verified_player_id != account_id or not request.is_empty(): return
	if get_node("/root/ConnectionGate").blocked(): return
	if not pending.is_empty():
		# A lost start response cannot recover its server-generated lease safely.
		if str(pending.get("kind", "")) == "start" and lease.is_empty(): return
		var payload: Dictionary = pending.get("payload", {})
		if lease.is_empty() or str(payload.get("run_id", "")) != lease_run or str(payload.get("client_action_id", "")).is_empty() or int(payload.get("expected_revision", 0)) != int(session.get("revision", 0)):
			_forfeit()
			return
		request_kind = str(pending.kind)
		request = backend.request_api("POST", "/expeditions/" + request_kind, payload, false, false, false, lease)
	else:
		request_kind = "state"
		request = backend.request_api("GET", "/expeditions/state", null, false, false, false, lease)
	if is_instance_valid(combat_view): combat_view.lock_controls()
	_update_controls()
	if request.is_empty():
		countdown_refresh = false
		recovery_required = true
		message.text = tr("EXPEDITION_CONNECTION")
		_update_controls()

func _completed(id: String, ok: bool, data: Dictionary) -> void:
	if ok and not spectator_mode and id == request and not id.is_empty() and backend != null and backend._verified_player_id == account_id and account_id == str(ConnectionGate.player_id): GlobalChatClient.apply_combat_spectators(data)
	if id != request or id.is_empty(): return
	request = ""
	if account_id.is_empty() or backend._verified_player_id != account_id or backend.token.is_empty():
		if not backend._verified_player_id.is_empty() and backend._verified_player_id != account_id: _forfeit()
		else: recovery_required = true
		return
	if not ok:
		var http_status := int(data.get("http_status", 0))
		if http_status == 0 or http_status >= 500 or http_status in [408, 429]:
			countdown_refresh = false
			connection_gate_lost()
			message.text = tr("EXPEDITION_CONNECTION")
			return
		if request_kind == "select" and http_status == 400 and str(data.get("error", "")) == "Not enough expedition mana.":
			pending.clear()
			mana_prompt = true
			_refresh()
			return
		if request_kind == "buy_mana" and http_status == 400:
			pending.clear()
			var error := str(data.get("error", ""))
			var key := "EXPEDITION_MANA_INSUFFICIENT" if error == "Insufficient essence." else "EXPEDITION_MANA_LIMIT" if error == "Expedition mana purchase limit reached." else "EXPEDITION_MANA_FULL_NOTICE" if error == "Expedition mana is full." else ""
			last_error = tr(key) if not key.is_empty() else error
			message.text = last_error
			_refresh()
			return
		if request_kind == "start" and int(data.get("http_status", 0)) == 400:
			pending.clear()
			last_error = str(data.get("error", tr("EXPEDITION_BAD_STATE")))
			state_data.clear()
			_refresh()
			return
		var error := str(data.get("error", ""))
		if (http_status in [401, 403, 404] or (http_status == 409 and (error == "Expedition lease expired or unavailable." or error == "Expedition action no longer available."))) and (not lease.is_empty() or not pending.is_empty()):
			_forfeit()
		else:
			message.text = error if not error.is_empty() else tr("EXPEDITION_CONNECTION")
			recovery_required = true
			recovery_conflict = http_status >= 400 and http_status < 500
		return
	var received: Variant = data.get("session")
	if request_kind != "start" and lease.is_empty() and received is Dictionary:
		_forfeit()
		return
	if request_kind == "start":
		var issued := str(data.get("lease", ""))
		var pattern := RegEx.new()
		pattern.compile("^[a-f0-9]{64}$")
		if not lease.is_empty() or not received is Dictionary or str(received.get("run_id", "")).is_empty() or pattern.search(issued) == null:
			_forfeit()
			return
		lease = issued
		lease_run = str(received.run_id)
		lease_token = backend.token
		heartbeat_timer.start()
	elif not lease.is_empty() and received is Dictionary and str(received.get("run_id", "")) != lease_run:
		_forfeit()
		return
	elif not lease.is_empty() and received == null and request_kind != "exit":
		_forfeit()
		return
	if received != null and (not received is Dictionary or str(received.get("run_id", "")).is_empty() or int(received.get("revision", 0)) < 1):
		_forfeit()
		return
	if received is Dictionary and not session.is_empty() and str(received.get("run_id", "")) == str(session.get("run_id", "")) and int(received.get("revision", 0)) < int(session.get("revision", 0)):
		_forfeit()
		return
	if request_kind != "state" and not _valid_action_response(received):
		_forfeit()
		return
	if received is Dictionary and received.get("status") == "LOSS": _stop_lease()
	if request_kind == "capture" and playing_events:
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
	if request_kind in ["turn", "inspiration"] and data.get("events") is Array and not data.events.is_empty():
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
	if response_kind == "state":
		recovery_required = false
		if mana_continue_requested:
			mana_prompt = float(data.get("mana", 0)) < 0.3
			mana_continue_requested = false
	var response_events: Array = data.get("events", []) if data.get("events") is Array else []
	state_data = data.duplicate(true)
	state_data.erase("lease")
	received_ticks = Time.get_ticks_msec()
	countdown_refresh = false
	session = received.duplicate(true) if received is Dictionary else {}
	if session.get("status") == "ACTIVE" and float(data.get("mana", 0)) < 0.3 and str(session.get("phase", "")) != "COMBAT": mana_prompt = true
	if request_kind != "state":
		pending.clear()
		if response_kind == "exit":
			_stop_lease()
			SceneRouter._expedition_context.clear()
			SceneRouter.go_to_world_gate()
			return
	if session.get("status") == "LOSS": _stop_lease()
	if response_kind == "buy_mana": backend.refresh_state()
	message.text = last_error
	last_error = ""
	_render()
	if str(session.get("phase", "")) == "REWARD" and session.get("victory_reward") is Dictionary and _present_victory_reward(session.victory_reward):
		pass
	elif response_kind in ["capture", "advance"] and not response_events.is_empty():
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

func send_combat_decision(kind: String, decision: Dictionary) -> void:
	if spectator_mode: return
	if visual_debug: return
	if kind not in ["turn", "inspiration"] or recovery_required or playing_events or not request.is_empty() or not pending.is_empty() or state_data.is_empty() or account_id.is_empty() or backend._verified_player_id != account_id or backend.token.is_empty() or get_node("/root/ConnectionGate").blocked() or str(session.get("phase", "")) != "COMBAT": return
	var combat: Dictionary = session.get("combat_state", {})
	if combat.get("terminal_result") != null or bool(combat.get("player", {}).get("inspiration_pending", false)) != (kind == "inspiration"): return
	var payload := {"run_id": str(session.get("run_id", "")), "expected_revision": int(session.get("revision", 0)), "client_action_id": backend._make_uuid(), "decision": decision.duplicate(true)}
	pending = {"kind":kind, "payload":payload}
	request_kind = kind
	request = backend.request_api("POST", "/expeditions/" + kind, payload, false, false, false, lease)
	if is_instance_valid(combat_view): combat_view.lock_controls()
	_update_controls()
	if request.is_empty():
		recovery_required = true
		message.text = tr("EXPEDITION_CONNECTION")

func _update_controls() -> void:
	if not is_instance_valid(exit_button): return
	var active := not session.is_empty() and str(session.get("status", "")) == "ACTIVE"
	var busy: bool = recovery_required or playing_events or not pending.is_empty() or not request.is_empty() or is_instance_valid(reward_popup) or account_id.is_empty() or backend == null or backend._verified_player_id != account_id or get_node("/root/ConnectionGate").blocked()
	exit_button.visible = active
	exit_button.disabled = busy
	back_button.visible = not active
	retry.disabled = busy
	for button in phase_buttons:
		if is_instance_valid(button): button.disabled = busy or bool(button.get_meta("unavailable", false))

func _confirm_exit() -> void:
	if spectator_mode: return
	if exit_button.disabled or not exit_button.visible: return
	exit_confirmation.popup_centered(Vector2i(750, 300))

func _send_phase_action(kind: String, direction: String = "") -> void:
	if spectator_mode: return
	if visual_debug: return
	if kind not in ["capture", "skip", "advance", "exit", "buy_mana"] or recovery_required or playing_events or not request.is_empty() or not pending.is_empty() or is_instance_valid(reward_popup) or state_data.is_empty() or account_id.is_empty() or backend._verified_player_id != account_id or backend.token.is_empty() or get_node("/root/ConnectionGate").blocked() or str(session.get("status", "")) != "ACTIVE": return
	var phase := str(session.get("phase", ""))
	if kind == "buy_mana" and not mana_prompt: return
	if kind in ["capture", "skip"] and phase != "REWARD": return
	if kind == "advance" and (phase != "ROUTE" or direction not in ["left", "forward", "right"] or direction not in session.get("directions", [])): return
	if kind == "capture" and (_candidate().is_empty() or str(session.get("capture_candidate", {}).get("id", "")) != str(session.get("reward_homunculus", {}).get("id", "")) or bool(session.get("capture_closed", true)) or int(session.get("capture_attempts_remaining", 0)) < 1 or int(state_data.get("crystals", 0)) < 1): return
	var payload := {"run_id":str(session.get("run_id", "")), "expected_revision":int(session.get("revision", 0)), "client_action_id":backend._make_uuid()}
	if kind == "advance": payload["direction"] = direction
	pending = {"kind":kind, "payload":payload}
	request_kind = kind
	if kind == "capture": _start_capture_animation()
	request = backend.request_api("POST", "/expeditions/" + kind, payload, false, false, false, lease)
	if is_instance_valid(combat_view): combat_view.lock_controls()
	_update_controls()
	if request.is_empty():
		playback_epoch += 1
		playing_events = false
		_stop_capture_animation()
		recovery_required = true
		message.text = tr("EXPEDITION_CONNECTION")

func _start_capture_animation() -> void:
	_set_capture_heading("EXPEDITION_CAPTURE_SUSPENSE")
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

func _set_capture_heading(key: String) -> void:
	if is_instance_valid(capture_heading): capture_heading.text = tr(key)

func _present_victory_reward(reward: Dictionary) -> bool:
	if visual_debug or account_id.is_empty() or is_instance_valid(reward_popup): return false
	var reward_id := str(reward.get("reward_id", ""))
	var tier := str(reward.get("tier", ""))
	var grants: Variant = reward.get("grants")
	if reward_id.is_empty() or victory_rewards_acknowledged.has(account_id + ":" + reward_id) or SeenRewards.has_seen(account_id, reward_id) or tier not in ["normal", "difficult", "very_difficult", "exceptional"] or not grants is Dictionary: return false
	var owner := account_id
	var panel = preload("res://scripts/ui/shared_reward_panel.gd")
	var close := func():
		if owner == account_id:
			victory_rewards_acknowledged[owner + ":" + reward_id] = true
			SeenRewards.mark_seen(owner, reward_id)
		if is_instance_valid(reward_popup): reward_popup.queue_free()
		reward_popup = null
		_update_controls()
	var reward_body: VBoxContainer = panel.result_popup(self, tr("EXPEDITION_REWARD_" + tier.to_upper()), tr("EXPEDITION_CONTINUE"), close)
	reward_popup = reward_body.get_parent().get_parent().get_parent().get_parent() as CanvasLayer
	panel.reward_rows(self, reward_body, grants)
	_update_controls()
	return true

func _present_reward(event: Variant) -> void:
	if visual_debug: return
	if not event is Dictionary or account_id.is_empty() or is_instance_valid(reward_popup): return
	var kind := str(event.get("kind", ""))
	if kind == "capture_failure":
		_set_capture_heading("EXPEDITION_CAPTURE_FAILED")
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
	var mana := float(state_data.get("mana", 0))
	mana_bar.value = mana
	crystal_bar.value = int(state_data.get("crystals", 0))
	mana_text.text = "%s/6" % (str(int(mana)) if mana == floor(mana) else str(mana))
	crystal_text.text = "%d/5" % int(state_data.get("crystals", 0))
	mana_bar.tooltip_text = tr("EXPEDITION_MANA_TOOLTIP") % (tr("EXPEDITION_MANA_FULL") if regen_at == null else _duration(regen))
	crystal_bar.tooltip_text = tr("EXPEDITION_CRYSTALS_TOOLTIP")
	if not state_data.is_empty() and (not visual_debug or visual_debug_view != 0): status.text = ""
	if not countdown_refresh and not recovery_required and not recovery_conflict and request.is_empty() and pending.is_empty() and (not is_instance_valid(combat_view) or combat_view.pending_hom_decision.is_empty()) and not playing_events and not is_instance_valid(reward_popup) and not get_node("/root/ConnectionGate").blocked() and ((session.is_empty() and int(state_data.get("remaining_cooldown_ms", 0)) > 0 and cooldown == 0) or (state_data.get("next_regeneration_at") != null and regen == 0) or (mana_prompt and state_data.get("next_mana_purchase_at") != null and int(state_data.get("next_mana_purchase_at")) <= int(state_data.get("server_time_unix_ms", 0)) + elapsed)):
		countdown_refresh = true
		call_deferred("_refresh")

func _duration(ms: int) -> String:
	var seconds := int(ceil(ms / 1000.0))
	return "%02d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]

func _clear_body() -> void:
	capture_heading = null
	phase_buttons.clear()
	capture_sprite = null
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func _render() -> void:
	background_shade.color = Color(0.2, 0.2, 0.2, 0.55) if session.is_empty() else Color(0, 0, 0, 0.38)
	background_shade.visible = str(session.get("phase", "")) not in ["EXPLORE", "COMBAT"]
	var retained_icons: Array = []
	if str(session.get("phase", "")) == "COMBAT" and is_instance_valid(combat_view):
		var previous: Dictionary = combat_view.session
		var old_combat: Dictionary = previous.get("combat_state", {})
		var new_combat: Dictionary = session.get("combat_state", {})
		if previous.get("run_id") == session.get("run_id") and old_combat.get("floor") == new_combat.get("floor") and old_combat.get("npc", {}).get("id") == new_combat.get("npc", {}).get("id") and int(new_combat.get("turn", 0)) >= int(old_combat.get("turn", 0)):
			retained_icons = combat_view.take_status_icons()
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
	_set_background(str(session.get("background_key", "")))
	if mana_prompt and session.get("status") == "ACTIVE":
		_render_mana_prompt()
		return
	match str(session.get("phase", "")):
		"EXPLORE": _render_choices()
		"COMBAT": _render_combat(retained_icons)
		"REWARD": _render_terminal(true)
		"ROUTE": _render_route()
		"LOSS": _render_terminal(false)
		_: message.text = tr("EXPEDITION_PHASE_UNAVAILABLE") % str(session.get("phase", ""))

func _render_mana_prompt() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	box.add_child(_label(tr("EXPEDITION_MANA_EMPTY"), 32))
	box.add_child(_label(tr("EXPEDITION_MANA_PURCHASES") % int(state_data.get("mana_purchases_remaining", 0)), 20))
	var buy := Button.new()
	buy.text = tr("EXPEDITION_MANA_BUY")
	buy.custom_minimum_size = Vector2(320, 56)
	buy.set_meta("unavailable", float(state_data.get("mana", 0)) > 5.0 or int(state_data.get("mana_purchases_remaining", 0)) <= 0)
	MenuArt.button(buy)
	buy.pressed.connect(func(): _send_phase_action("buy_mana"))
	box.add_child(buy)
	phase_buttons.append(buy)
	var proceed := Button.new()
	proceed.text = tr("EXPEDITION_CONTINUE")
	proceed.custom_minimum_size = Vector2(320, 56)
	proceed.set_meta("unavailable", float(state_data.get("mana", 0)) < 0.3)
	MenuArt.button(proceed)
	proceed.pressed.connect(func():
		mana_continue_requested = true
		_refresh())
	box.add_child(proceed)
	phase_buttons.append(proceed)
	_update_controls()

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
	if spectator_mode: return
	if visual_debug: return
	if backend == null or recovery_required or account_id.is_empty() or not request.is_empty() or not pending.is_empty() or account_id != backend._verified_player_id or str(session.get("phase", "")) != "EXPLORE": return
	var payload := {"run_id": str(session.get("run_id", "")), "expected_revision": int(session.get("revision", 0)), "choice": index, "client_action_id": backend._make_uuid()}
	pending = {"kind":"select", "payload":payload}
	request_kind = "select"
	request = backend.request_api("POST", "/expeditions/select", payload, false, false, false, lease)
	_update_controls()
	if request.is_empty():
		recovery_required = true
		message.text = tr("EXPEDITION_CONNECTION")

func _spectator_failure(key: String) -> void:
	if spectator_mode and is_instance_valid(status): status.text = tr(key)

func _spectator_update(data: Dictionary, initial: bool) -> void:
	if not spectator_mode or SceneRouter._spectator_context.is_empty(): return
	spectator_latest = data.get("snapshot", {}).duplicate(true)
	var events: Array = data.get("events", [])
	if initial:
		session = spectator_latest.duplicate(true)
		session["battle_log"] = events
		_set_background(str(session.get("background_key", "")))
		_render_combat()
		combat_view.lock_controls()
		return
	if bool(data.get("cursor_reset", false)) or spectator_events.size() + events.size() > 50:
		playback_epoch += 1
		spectator_events.clear()
		playing_events = false
		_spectator_reconcile()
		return
	spectator_events.append_array(events)
	if not playing_events: _spectator_play()

func _spectator_play() -> void:
	if playing_events or not is_instance_valid(combat_view): return
	playing_events = true
	var current := playback_epoch
	while not spectator_events.is_empty() and is_inside_tree() and current == playback_epoch:
		var event: Dictionary = spectator_events.pop_front()
		await combat_view.present_events([event], current)
	if current == playback_epoch:
		playing_events = false
		_spectator_reconcile()

func _spectator_reconcile() -> void:
	if not is_instance_valid(combat_view) or spectator_latest.is_empty(): return
	session = spectator_latest.duplicate(true)
	var outcome := str(session.get("combat_state", {}).get("terminal_result", ""))
	if outcome in ["WIN", "LOSS"]: status.text = (tr("SPECTATING") % str(SceneRouter._spectator_context.get("username", ""))) + "  |  " + tr("EXPEDITION_VICTORY" if outcome == "WIN" else "EXPEDITION_DEFEAT")
	combat_view.apply_spectator_snapshot(session)

func _render_combat(retained_icons: Array = []) -> void:
	combat_view = preload("res://scripts/ui/expedition_combat.gd").new()
	combat_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(combat_view)
	combat_view.configure(self, session, retained_icons)
	message.text = ""

func _render_terminal(won: bool) -> void:
	var center := CenterContainer.new()
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	if _android_ui():
		var scroll := ScrollContainer.new()
		scroll.name = "RewardScroll"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.add_child(scroll)
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(center)
	else:
		body.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(box)
	capture_heading = _label(tr("EXPEDITION_VICTORY" if won else "EXPEDITION_DEFEAT"), 48)
	box.add_child(capture_heading)
	var candidate: Variant = session.get("capture_candidate")
	var reward: Variant = session.get("reward_homunculus")
	if won and reward is Dictionary:
		var hom := _candidate(str(reward.get("id", "")))
		if not hom.is_empty() and (reward.get("combat_texture") != hom.get("combat_texture") or reward.get("type") != hom.get("type") or reward.get("preview_texture") != hom.get("preview_texture")): hom = {}
		if not hom.is_empty():
			capture_sprite = TextureRect.new()
			capture_sprite.custom_minimum_size = Vector2(400, 400)
			capture_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			capture_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			capture_sprite.texture = _texture(str(hom.combat_texture), "res://assets/entities/gameplay/homunculus/ingame/1024/")
			box.add_child(capture_sprite)
			box.add_child(_label("%s  |  %s  |  %s %s" % [GameLocalization.catalog("homunculus", str(hom.id), "name", str(hom.name)), _types([hom.type]), tr("EXPEDITION_RARITY"), str(hom.rarity)], 26))
			if candidate is Dictionary and str(candidate.get("id", "")) == str(hom.get("id", "")) and not _candidate().is_empty():
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
		var allowed: Variant = session.get("allowed_directions", directions)
		if direction == "right" and allowed is Array and not direction in allowed:
			arrow.set_meta("unavailable", true)
			arrow.tooltip_text = tr("EXPEDITION_RIGHT_LIMIT")
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
	if key.is_empty(): key = "@initiate"
	if key == background_key: return
	video.stop()
	video.stream = null
	background_key = ""
	if key != "@initiate" and (key.contains("/") or key.contains("\\") or key.contains("..") or not key.ends_with(".ogv")): return
	var path := "res://assets/entities/expeditions/initiate_bg.ogv" if key == "@initiate" else BACKGROUNDS + key
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

func forest_return_safe() -> bool:
	if not lease.is_empty() or not lease_run.is_empty() or not pending.is_empty() or not request.is_empty() or recovery_required or recovery_conflict or playing_events or heartbeat_in_flight or is_instance_valid(reward_popup) or forfeited or visual_debug:
		return false
	if not session.is_empty() and str(session.get("status", "")) != "LOSS":
		return false
	if _visual_debug_allowed() and backend == null:
		return true
	return not state_data.is_empty() and backend != null and not account_id.is_empty() and backend._verified_player_id == account_id and account_id == ConnectionGate.player_id and not backend.token.is_empty() and not ConnectionGate.blocked()
