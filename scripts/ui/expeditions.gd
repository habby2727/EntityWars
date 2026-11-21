extends Control

const MenuArt := preload("res://scripts/ui/menu_art.gd")
const Recovery := preload("res://scripts/net/expedition_recovery.gd")
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

func _ready() -> void:
	UIThemeFactory.apply_theme_scaled(self, clampf(minf(get_viewport_rect().size.x / 1920.0, get_viewport_rect().size.y / 1080.0), 0.65, 1.0))
	$Background.hide()
	_build_ui()
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
	var back := Button.new()
	back.text = tr("UI_BACK_UPPER")
	MenuArt.button(back)
	back.pressed.connect(SceneRouter.go_to_world_gate)
	top.add_child(back)
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
	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)

func _auth_changed(_token: String) -> void:
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
	poll += delta
	if poll < 2.0: return
	poll = 0.0
	if not account_id.is_empty() and request.is_empty() and not get_node("/root/ConnectionGate").blocked() and (state_data.is_empty() or not pending.is_empty()):
		_refresh()
	if not state_data.is_empty(): _update_status()

func _refresh() -> void:
	if account_id.is_empty() or backend._verified_player_id != account_id or not request.is_empty(): return
	request_kind = "state"
	request = backend.request_api("GET", "/expeditions/state", null)
	if request.is_empty(): message.text = tr("EXPEDITION_CONNECTION")

func _completed(id: String, ok: bool, data: Dictionary) -> void:
	if id != request or id.is_empty(): return
	request = ""
	if account_id.is_empty() or backend._verified_player_id != account_id or backend.token.is_empty():
		_auth_changed("")
		return
	if not ok:
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
	if received is Dictionary and not session.is_empty() and str(received.get("run_id", "")) == str(session.get("run_id", "")) and int(received.get("revision", 0)) < int(session.get("revision", 0)):
		message.text = tr("EXPEDITION_BAD_STATE")
		return
	if request_kind != "state" and not _valid_action_response(received):
		message.text = tr("EXPEDITION_BAD_STATE")
		state_data.clear()
		return
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
	elif not pending.is_empty():
		_reconcile_pending()
		if not pending.is_empty(): return
	message.text = last_error
	last_error = ""
	_render()

func _valid_action_response(received: Variant) -> bool:
	if not received is Dictionary or pending.is_empty(): return false
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
	request_kind = kind
	request = backend.request_api("POST", "/expeditions/" + kind, payload)
	if request.is_empty(): message.text = tr("EXPEDITION_CONNECTION")

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
	for child in body.get_children(): child.queue_free()

func _render() -> void:
	_clear_body()
	_update_status()
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

func _select(index: int) -> void:
	if not request.is_empty() or not pending.is_empty() or account_id != backend._verified_player_id or str(session.get("phase", "")) != "EXPLORE": return
	var payload := {"run_id": str(session.get("run_id", "")), "expected_revision": int(session.get("revision", 0)), "choice": index, "client_action_id": backend._make_uuid()}
	if not Recovery.save_pending(account_id, "select", payload):
		message.text = tr("EXPEDITION_SAVE_ERROR")
		return
	pending = Recovery.load_pending(account_id)
	_clear_body()
	_refresh()

func _render_combat() -> void:
	var combat: Dictionary = session.get("combat_state", {})
	var player: Dictionary = combat.get("player", {})
	var enemy: Dictionary = combat.get("npc", {})
	var enemies: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/expedition_enemies.json"))
	if enemies is Dictionary:
		for record in enemies.get("enemies", []):
			if record is Dictionary and str(record.get("id", "")) == str(enemy.get("id", "")):
				enemy = enemy.duplicate(true)
				enemy["name"] = record.get("name", enemy.get("id", ""))
				break
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(row)
	var player_type := str(player.get("type", ""))
	var player_path := "res://assets/entities/gameplay/ingame-entities/%s/%s_2_5d_1024.png" % [player_type, player_type]
	var hom_id := str(session.get("loadout", {}).get("homunculus_id", ""))
	var registry := preload("res://scripts/data_registry.gd").new()
	var entity: Dictionary = registry.get_entities().get(str(player.get("id", "")), {})
	if not entity.is_empty():
		player = player.duplicate(true)
		player["name"] = GameLocalization.catalog("entity", str(player.get("id", "")), "name", str(entity.get("name", "")))
	var hom: Dictionary = registry.get_homunculus_collection().get(hom_id, {})
	registry.free()
	row.add_child(_actor(player, player_path, false))
	var hom_path := str(hom.get("combat_texture", ""))
	if hom_path.is_empty():
		var legacy := {"cinder":"Cinder", "chimera":"Chimera", "drakon":"Drakon", "mothy":"Mothy", "nighty":"Nighty", "pyritc":"Pyro", "silphide":"Silphide", "sodium":"Sodi"}
		hom_path = "res://assets/entities/gameplay/homunculus/ingame/1024/%s.png" % str(legacy.get(hom_id, ""))
	var hom_image := TextureRect.new()
	hom_image.texture = _texture(hom_path, "res://assets/entities/gameplay/homunculus/ingame/1024/")
	hom_image.custom_minimum_size = Vector2(180, 220)
	hom_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hom_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hom_image.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(hom_image)
	row.add_child(_actor(enemy, str(enemy.get("texture", "")), true))
	message.text = tr("EXPEDITION_COMBAT_PREVIEW")

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
