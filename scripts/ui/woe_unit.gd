extends Node2D

const IDS := ["neon", "luny", "mantillo", "nebulynx", "venam", "cedix", "flincho", "solcarp", "hyrox", "astralotl"]
const ENEMY_IDS := ["noxiris", "vitreous", "mortivane", "hexalith", "mycelion"]
static var _textures := {}
var unit_id := 0
var card_id := ""
var team := "blue"
var unit_kind := "homunculus"
var target_position := Vector2.ZERO
var _move_origin := Vector2.ZERO
var _move_elapsed := 0.0
var _move_duration := 1.0
var _sample_elapsed := 1.0
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
var sprite: Sprite2D

static func frame(card: String, facing: String, index: int) -> Texture2D:
	if card not in IDS and card not in ENEMY_IDS: return null
	if card in ENEMY_IDS: facing = "front"
	if facing not in ["front", "back"] or index < 1 or index > 3: return null
	var key := "%s:%s:%d" % [card, facing, index]
	if _textures.has(key): return _textures[key]
	# All six PNGs share a canvas. Preserve that registration with one union crop
	# and scale, so an animation frame cannot shift or resize the creature.
	var sources := {}
	var common := Rect2i()
	for direction in (["front"] if card in ENEMY_IDS else ["front", "back"]):
		for number in range(1, 4):
			var category := "enemies" if card in ENEMY_IDS else "homunculi"
			var path := "res://assets/forest/woe/%s/%s/move_%s_%02d.png" % [category, card, direction, number]
			var source := load(path) as Texture2D
			if source == null: continue
			sources["%s:%s:%d" % [card, direction, number]] = source
			var bounds := source.get_image().get_used_rect()
			if bounds.size.x > 0 and bounds.size.y > 0:
				common = bounds if common.size == Vector2i.ZERO else common.merge(bounds)
	for source_key in sources:
		var source: Texture2D = sources[source_key]
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(common) if common.size != Vector2i.ZERO else Rect2(Vector2.ZERO, source.get_size())
		_textures[source_key] = atlas
	return _textures.get(key)

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
	var next_position := Vector2(float(data.get("x", target_position.x)), float(data.get("y", target_position.y)))
	if not next_position.is_equal_approx(target_position):
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

func _update_frame() -> void:
	if not is_instance_valid(sprite): return
	var facing := "front" if unit_kind == "enemy" else ("back" if team == "blue" else "front")
	var frame_index := 3 if dying else (2 if strike_time > 0.0 else 1)
	var texture := frame(card_id, facing, frame_index)
	if texture != null:
		sprite.texture = texture
		var factor := (72.0 if unit_kind == "enemy" else 56.0) / maxf(1.0, texture.get_height())
		sprite.scale = Vector2.ONE * factor

func _process(delta: float) -> void:
	animation_time += delta
	if dying:
		death_time -= delta
		if death_time <= 0.0:
			queue_free()
			return
		visible = int(death_time * 8.0) % 2 == 0
	else:
		_sample_elapsed += delta
		_move_elapsed = minf(_move_elapsed + delta, _move_duration)
		var previous := position
		position = _move_origin.lerp(target_position, _move_elapsed / _move_duration)
		moving = position.distance_squared_to(previous) > 0.000001
	separation = separation.lerp(desired_separation, 1.0 - exp(-delta * 5.0))
	queue_redraw()
	strike_time = maxf(0.0, strike_time - delta)
	flash_time = maxf(0.0, flash_time - delta)
	_update_frame()
	if is_instance_valid(sprite):
		var idle := sin(animation_time * (7.0 if moving else 3.0) + float(unit_id)) * (0.9 if moving else 2.0) if not dying else 0.0
		var recoil := (-5.0 if team == "blue" else 5.0) * (strike_time / 0.18)
		sprite.position = Vector2(clampf(visual_offset + separation.x, -20.0, 20.0), idle + recoil - (36.0 if unit_kind == "enemy" else 28.0) + separation.y)
		sprite.modulate = Color(0.72,0.72,0.76,clampf(death_time / 0.5, 0.0, 0.8)) if dying else (Color(2, 2, 2, 1) if flash_time > 0.0 else Color.WHITE)

func _draw() -> void:
	if dying: return
	var origin := Vector2(clampf(visual_offset + separation.x, -20.0, 20.0) - 24, -72 + separation.y - bar_rise)
	var border := Color("66bfff") if team == "blue" else Color("ff796c")
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(52, 9)), border)
	for i in range(6):
		var filled := clampf(hp / max_hp * 6.0 - float(i), 0.0, 1.0)
		draw_rect(Rect2(origin + Vector2(i * 8, 0), Vector2(7, 5)), Color("222b35"))
		if filled > 0.0: draw_rect(Rect2(origin + Vector2(i * 8, 0), Vector2(7 * filled, 5)), Color("8ff09f"))
