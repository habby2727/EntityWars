extends Node2D

const IDS := ["neon", "luny", "mantillo", "nebulynx", "venam", "cedix", "flincho", "solcarp", "hyrox", "astralotl"]
const ENEMY_IDS := ["noxiris", "vitreous", "mortivane", "hexalith", "mycelion"]
static var _textures := {}
static var _sprite_bounds := {}
static var _prefetch_pending: Array[Dictionary] = []
static var _prefetch_loading := {}
static var _prefetch_started := false
var unit_id := 0
var card_id := ""
var team := "blue"
var unit_kind := "homunculus"
var target_position := Vector2.ZERO
var _move_origin := Vector2.ZERO
var _move_elapsed := 0.0
var _move_duration := 1.0
var _sample_elapsed := 1.0
var visual_clock: RefCounted
var _samples: Array[Dictionary] = []
var hp := 1.0
var max_hp := 1.0
var visual_offset := 0.0
var separation := Vector2.ZERO
var desired_separation := Vector2.ZERO
var bar_rise := 0.0
var dying := false
var death_time := 0.0
var strike_time := 0.0
var flash_time := 0.0
var animation_time := 0.0
var moving := false
var paralyzed_remaining := 0.0
var poison_remaining := 0.0
var blood_remaining := 0.0
var aether_remaining := 0.0
var sprite: Sprite2D
var _active_frame_index := -1

static func frame(card: String, facing: String, index: int) -> Texture2D:
	if card not in IDS and card not in ENEMY_IDS: return null
	if card in ENEMY_IDS: facing = "front"
	if facing not in ["front", "back"] or index < 1 or index > 3: return null
	var key := "%s:%s:%d" % [card, facing, index]
	if _textures.has(key): return _textures[key]
	var category := "enemies" if card in ENEMY_IDS else "homunculi"
	var path := "res://assets/forest/woe/%s/%s/move_%s_%02d.png" % [category, card, facing, index]
	var source := load(path) as Texture2D
	if source == null: return null
	var atlas := _make_frame(card, source)
	_textures[key] = atlas
	return atlas

static func _make_frame(card: String, source: Texture2D) -> AtlasTexture:
	# Bounds are precomputed for the complete animation, avoiding GPU readback.
	if _sprite_bounds.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/woe_sprite_bounds.json"))
		if parsed is Dictionary: _sprite_bounds = parsed
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	var bounds: Variant = _sprite_bounds.get(card, [])
	if bounds is Array and bounds.size() == 4:
		atlas.region = Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
	else:
		# Missing metadata falls back to the complete canvas, without stalling play.
		atlas.region = Rect2(Vector2.ZERO, source.get_size())
	return atlas

static func begin_prefetch() -> void:
	# Godot's headless dummy renderer does not safely initialize textures from
	# loader threads; it has no rendered frames that need warming up.
	if _prefetch_started or DisplayServer.get_name() == "headless": return
	_prefetch_started = true
	# Load idle frames first, then attack/death frames, with at most two loads
	# active. The same cache remains shared across matches and both modes.
	for index in range(1, 4):
		for card in IDS + ENEMY_IDS:
			for facing in (["front"] if card in ENEMY_IDS else ["front", "back"]):
				var key := "%s:%s:%d" % [card, facing, index]
				if _textures.has(key): continue
				var category := "enemies" if card in ENEMY_IDS else "homunculi"
				_prefetch_pending.append({"key":key, "card":card, "path":"res://assets/forest/woe/%s/%s/move_%s_%02d.png" % [category, card, facing, index]})

static func service_prefetch() -> void:
	if not _prefetch_started: return
	for path in _prefetch_loading.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		var item: Dictionary = _prefetch_loading[path]
		_prefetch_loading.erase(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var source := ResourceLoader.load_threaded_get(path) as Texture2D
			if source != null and not _textures.has(item.key): _textures[item.key] = _make_frame(item.card, source)
	while _prefetch_loading.size() < 2 and not _prefetch_pending.is_empty():
		var item: Dictionary = _prefetch_pending.pop_front()
		if _textures.has(item.key): continue
		if ResourceLoader.load_threaded_request(item.path, "Texture2D", false) == OK:
			_prefetch_loading[item.path] = item

func setup(data: Dictionary) -> void:
	unit_id = int(data.get("id", 0))
	card_id = str(data.get("assetId", data.get("cardId", "")))
	unit_kind = str(data.get("kind", "homunculus"))
	team = str(data.get("team", "blue"))
	visual_offset = float((unit_id * 7) % 19 - 9)
	target_position = Vector2(float(data.get("x", 0)), float(data.get("y", 0)))
	position = target_position
	_move_origin = position
	sprite = Sprite2D.new()
	add_child(sprite)
	_update_frame()
	update_state(data)
	_sample_elapsed = 1.0

func update_state(data: Dictionary) -> void:
	if dying: return
	var tick := int(data.get("snapshot_tick", 0))
	paralyzed_remaining = maxf(0.0, float(int(data.get("paralyzed_until", tick)) - tick) / 10.0)
	poison_remaining = maxf(0.0, float(int(data.get("poison_until", tick)) - tick) / 10.0)
	blood_remaining = maxf(0.0, float(int(data.get("blood_until", tick)) - tick) / 10.0)
	aether_remaining = maxf(0.0, float(int(data.get("aether_until", tick)) - tick) / 10.0)
	var next_position := Vector2(float(data.get("x", target_position.x)), float(data.get("y", target_position.y)))
	if visual_clock != null and data.has("snapshot_tick"):
		var sample_tick := int(data.snapshot_tick)
		if _samples.is_empty() or sample_tick > int(_samples.back().tick):
			_samples.append({"tick":sample_tick, "position":next_position, "paralyzed":int(data.get("paralyzed_until", sample_tick)) > sample_tick})
			while _samples.size() > 12: _samples.pop_front()
			target_position = next_position
	elif not next_position.is_equal_approx(target_position):
		_move_origin = position
		target_position = next_position
		_move_elapsed = 0.0
		# Spread movement over the snapshot interval, with a speed limit for
		# delayed responses. The server remains authoritative for combat.
		_move_duration = maxf(clampf(_sample_elapsed, 0.85, 1.5), position.distance_to(target_position) / 120.0)
	_sample_elapsed = 0.0
	hp = float(data.get("hp", hp))
	max_hp = maxf(1.0, float(data.get("maxHp", max_hp)))
	queue_redraw()

func _sample_position(tick: float) -> Vector2:
	if _samples.is_empty(): return target_position
	while _samples.size() > 2 and tick >= float(_samples[1].tick):
		_samples.pop_front()
	if tick <= float(_samples[0].tick): return _samples[0].position
	for i in range(1, _samples.size()):
		var next: Dictionary = _samples[i]
		if tick <= float(next.tick):
			var previous: Dictionary = _samples[i - 1]
			var weight := clampf((tick - float(previous.tick)) / maxf(1.0, float(next.tick - previous.tick)), 0.0, 1.0)
			return (previous.position as Vector2).lerp(next.position, weight)
	var last: Dictionary = _samples.back()
	if _samples.size() < 2 or bool(last.paralyzed): return last.position
	var previous: Dictionary = _samples[_samples.size() - 2]
	var duration := float(last.tick - previous.tick)
	if duration <= 0.0 or bool(previous.paralyzed): return last.position
	var velocity: Vector2 = (last.position - previous.position) / duration
	# At most 200 ms, capped at the same visual speed as recovery corrections.
	velocity = velocity.limit_length(12.0)
	return last.position + velocity * clampf(tick - float(last.tick), 0.0, 2.0)

func set_separation(offset: Vector2, bar_offset: float = 0.0) -> void:
	bar_rise = clampf(bar_offset, 0.0, 24.0)
	desired_separation = Vector2(clampf(offset.x, -20.0, 20.0), clampf(offset.y, -9.0, 9.0))

func attack() -> void:
	strike_time = 0.18

func hit() -> void:
	flash_time = 0.2

func die() -> void:
	if dying: return
	dying = true
	death_time = 2.5
	queue_redraw()

func _update_frame() -> void:
	if not is_instance_valid(sprite): return
	var facing := "front" if unit_kind == "enemy" else ("back" if team == "blue" else "front")
	var frame_index := 3 if dying else (2 if strike_time > 0.0 else 1)
	if frame_index == _active_frame_index: return
	var texture := frame(card_id, facing, frame_index)
	if texture != null and sprite.texture != texture:
		sprite.texture = texture
		var factor := (72.0 if unit_kind == "enemy" else 56.0) / maxf(1.0, texture.get_height())
		sprite.scale = Vector2.ONE * factor
	if texture != null: _active_frame_index = frame_index

func _process(delta: float) -> void:
	var had_paralysis := paralyzed_remaining > 0.0
	var had_poison := poison_remaining > 0.0
	var had_blood := blood_remaining > 0.0
	var had_aether := aether_remaining > 0.0
	animation_time += delta
	if dying:
		death_time -= delta
		if death_time <= 0.0:
			queue_free()
			return
		visible = int(death_time * 8.0) % 2 == 0
	else:
		_sample_elapsed += delta
		if paralyzed_remaining > 0.0:
			paralyzed_remaining = maxf(0.0, paralyzed_remaining - delta)
			_move_origin = position
			_move_elapsed = 0.0
			moving = false
		elif visual_clock != null and not _samples.is_empty():
			var previous := position
			position = position.move_toward(_sample_position(float(visual_clock.render_tick)), 120.0 * minf(delta, 0.1))
			moving = position.distance_squared_to(previous) > 0.000001
		else:
			_move_elapsed = minf(_move_elapsed + delta, _move_duration)
			var previous := position
			position = _move_origin.lerp(target_position, _move_elapsed / _move_duration)
			moving = position.distance_squared_to(previous) > 0.000001
		poison_remaining = maxf(0.0, poison_remaining - delta)
		blood_remaining = maxf(0.0, blood_remaining - delta)
		aether_remaining = maxf(0.0, aether_remaining - delta)
	var old_separation := separation
	separation = separation.lerp(desired_separation, 1.0 - exp(-delta * 5.0))
	if not separation.is_equal_approx(old_separation) or had_paralysis or had_poison != (poison_remaining > 0.0) or had_blood != (blood_remaining > 0.0) or had_aether != (aether_remaining > 0.0):
		queue_redraw()
	strike_time = maxf(0.0, strike_time - delta)
	flash_time = maxf(0.0, flash_time - delta)
	_update_frame()
	if is_instance_valid(sprite):
		var idle := sin(animation_time * (7.0 if moving else 3.0) + float(unit_id)) * (0.9 if moving else 2.0) if not dying else 0.0
		var recoil := (-5.0 if team == "blue" else 5.0) * (strike_time / 0.18)
		var next_position := Vector2(clampf(visual_offset + separation.x, -20.0, 20.0), idle + recoil - (36.0 if unit_kind == "enemy" else 28.0) + separation.y)
		if not sprite.position.is_equal_approx(next_position): sprite.position = next_position
		var tint := Color(0.72,0.72,0.76,clampf(death_time / 0.5, 0.0, 0.8)) if dying else (Color(2, 2, 2, 1) if flash_time > 0.0 else Color.WHITE)
		if sprite.modulate != tint: sprite.modulate = tint

func _draw() -> void:
	if dying: return
	var aura := Vector2(clampf(visual_offset + separation.x, -20.0, 20.0), -28.0 + separation.y)
	if blood_remaining > 0.0:
		draw_circle(aura, 27.0, Color(0.85,0.12,0.18,0.14))
		draw_arc(aura, 27.0, 0, TAU, 24, Color(0.94,0.31,0.35,0.5), 1.5)
	if aether_remaining > 0.0:
		draw_circle(aura, 30.0, Color(0.28,0.84,0.95,0.12))
		draw_arc(aura, 30.0, 0, TAU, 24, Color(0.7,0.48,1.0,0.5), 1.5)
	if poison_remaining > 0.0:
		draw_circle(aura, 27.0, Color(0.4,0.8,0.2,0.15))
		draw_arc(aura, 25.0, 0, TAU, 24, Color(0.65,0.35,0.9,0.6), 2.0)
	if paralyzed_remaining > 0.0:
		draw_circle(aura, 28.0, Color(0.3,0.7,1.0,0.16))
		for i in range(4):
			var angle := float(i) * TAU / 4.0 + sin(animation_time * 8.0) * 0.12
			var direction := Vector2.from_angle(angle)
			draw_line(aura + direction * 20.0, aura + direction * 32.0, Color(1.0,0.9,0.35,0.8), 2.0)
	var origin := Vector2(clampf(visual_offset + separation.x, -20.0, 20.0) - 24, -72 + separation.y - bar_rise)
	var border := Color("66bfff") if team == "blue" else Color("ff796c")
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(52, 9)), border)
	for i in range(6):
		var filled := clampf(hp / max_hp * 6.0 - float(i), 0.0, 1.0)
		draw_rect(Rect2(origin + Vector2(i * 8, 0), Vector2(7, 5)), Color("222b35"))
		if filled > 0.0: draw_rect(Rect2(origin + Vector2(i * 8, 0), Vector2(7 * filled, 5)), Color("8ff09f"))
