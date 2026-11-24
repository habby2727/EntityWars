extends Control

const MAX_EFFECTS := 12
const COLORS := {"sulfur": Color("d9b300"), "mercury": Color("a7b0bd"), "sodium": Color("d8d8d8"), "aether": Color("7a5cff"), "vitriol": Color("39c34a"), "gold": Color("d4af37")}

var element := ""
var mode := "hit"
var progress := 0.0
var origin := Vector2.ZERO
var center := Vector2.ZERO

static func hit(target: Control, element_type: String) -> void:
	if not is_instance_valid(target) or element_type not in COLORS: return
	var effect = new()
	effect.element = element_type
	effect.center = target.size * 0.5
	_spawn(target, effect)

static func passive(hom: Control, owner: Control) -> void:
	if not is_instance_valid(hom) or not is_instance_valid(owner): return
	var effect = new()
	effect.mode = "passive"
	effect.center = owner.size * 0.5
	effect.origin = owner.get_global_transform().affine_inverse() * (hom.get_global_transform() * (hom.size * 0.5))
	_spawn(owner, effect)

static func clear(target: Control) -> void:
	if not is_instance_valid(target): return
	for child in target.get_children():
		if child.has_meta("combat_vfx"): child.queue_free()

static func _spawn(target: Control, effect: Control) -> void:
	var count := 0
	for child in target.get_children():
		if child.has_meta("combat_vfx"): count += 1
	if count >= MAX_EFFECTS:
		effect.free()
		return
	effect.set_meta("combat_vfx", true)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(effect)
	var tween := effect.create_tween()
	tween.tween_method(Callable(effect, "_advance"), 0.0, 1.0, 0.36)
	tween.tween_callback(Callable(effect, "queue_free"))

func _advance(value: float) -> void:
	progress = value
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - progress
	if mode == "passive":
		for i in 6:
			var offset := Vector2(cos(float(i) * TAU / 6.0), sin(float(i) * TAU / 6.0)) * (10.0 * (1.0 - progress))
			draw_circle(origin.lerp(center, progress) + offset, 3.0, Color(0.45, 1.0, 0.62, alpha))
		if progress > 0.65: draw_arc(center, 10.0 + 25.0 * (progress - 0.65), 0.0, TAU, 24, Color(0.45, 1.0, 0.62, alpha), 2.0, true)
		return
	var color: Color = COLORS.get(element, Color.WHITE)
	color.a = alpha
	if element == "aether":
		draw_arc(center, 12.0 + 55.0 * progress, 0.0, TAU, 32, color, 3.0, true)
		return
	for i in 8:
		var angle := float(i) * TAU / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		var point := center + direction * (10.0 + 48.0 * progress)
		match element:
			"mercury": draw_line(point - direction.rotated(0.55) * 12.0, point + direction.rotated(0.55) * 12.0, color, 3.0, true)
			"sodium": draw_colored_polygon(PackedVector2Array([point + direction * 8.0, point + direction.rotated(2.4) * 5.0, point + direction.rotated(-2.4) * 5.0]), color)
			"sulfur": draw_colored_polygon(PackedVector2Array([point + Vector2(0, -9), point + Vector2(-4, 5), point + Vector2(4, 5)]), color)
			"vitriol": draw_circle(point, 4.0 * alpha, color)
			_: draw_line(point, point + direction * 10.0, color, 2.5, true)
