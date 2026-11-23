extends Node2D

const SPEED := 220.0
const MAX_STEP := 2.0
const SUMMONER_DIR := "res://assets/forest/summoners/"
const FILES := {
	"wizard": ["Wizard_front.png", "Wizard_side_right.png", "Wizard_back.png"],
	"witch": ["Witch_Front.png", "Witch_Side_Right.png", "Witch_Back.png"],
	"cyberghost": ["Cyberghost_Front.png", "Cyberghost_Side_Right.png", "Cyberghost_Back.png"]
}
var polygon := PackedVector2Array()
var textures: Array[Texture2D] = []
var bounds: Array[Rect2i] = []
var sprite_scale := 1.0
var facing := 0 # 0 front, 1 right, 2 back, 3 left
var joystick_vector := Vector2.ZERO
var blocked_point := Vector2.ZERO
var blocked_visible := false
var show_debug := false
var _bob_time := 0.0

func setup(summoner_id: String) -> void:
	var max_height := 0
	for file in FILES[summoner_id]:
		var texture := load(SUMMONER_DIR + file) as Texture2D
		textures.append(texture)
		var rect := texture.get_image().get_used_rect()
		bounds.append(rect)
		max_height = maxi(max_height, rect.size.y)
	# A single scale for all directions keeps each character's proportions stable.
	sprite_scale = 120.0 / maxf(1.0, max_height)
	queue_redraw()

func _process(delta: float) -> void:
	_bob_time += delta
	var input := joystick_vector
	var focus := get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit):
		var keyboard := Vector2(
			int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		input = (input + keyboard).limit_length(1.0)
	if input.length_squared() > 0.0001:
		_update_facing(input)
		move_by(input * SPEED * minf(delta, 0.25))
	else:
		blocked_visible = false
	queue_redraw()

func _update_facing(input: Vector2) -> void:
	var horizontal := absf(input.x)
	var vertical := absf(input.y)
	# Retain the current axis on equal diagonals to avoid jittering between sprites.
	var use_horizontal := horizontal > vertical * 1.15 or (horizontal >= vertical / 1.15 and facing in [1, 3])
	if use_horizontal:
		facing = 1 if input.x >= 0.0 else 3
	else:
		facing = 2 if input.y < 0.0 else 0

func move_by(displacement: Vector2) -> void:
	if polygon.size() < 3:
		return
	var steps := maxi(1, ceili(displacement.length() / MAX_STEP))
	var step := displacement / steps
	blocked_visible = false
	for i in steps:
		var candidate := position + step
		if Geometry2D.is_point_in_polygon(candidate, polygon):
			position = candidate
			continue
		blocked_point = candidate
		blocked_visible = true
		var along_x := position + Vector2(step.x, 0)
		if Geometry2D.is_point_in_polygon(along_x, polygon):
			position = along_x
		var along_y := position + Vector2(0, step.y)
		if Geometry2D.is_point_in_polygon(along_y, polygon):
			position = along_y

func _draw() -> void:
	if textures.is_empty():
		return
	# Ellipse rendered in reference space; its position never follows the bob.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 27.0, Color(0.01, 0.02, 0.02, 0.35))
	draw_set_transform(Vector2.ZERO)
	var texture_index := 1 if facing == 3 else facing
	var used := bounds[texture_index]
	var bob := sin(_bob_time * 2.8) * 2.0
	var direction_scale := Vector2(-sprite_scale if facing == 3 else sprite_scale, sprite_scale)
	draw_set_transform(Vector2(0, -5.0 + bob), 0.0, direction_scale)
	draw_texture(textures[texture_index], Vector2(-used.get_center().x, -used.end.y))
	draw_set_transform(Vector2.ZERO)
	if show_debug:
		draw_circle(Vector2.ZERO, 6.0, Color.YELLOW)
		if blocked_visible:
			draw_circle(blocked_point - position, 7.0, Color.RED)
