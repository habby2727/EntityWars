extends Control

const TypeIcon := preload("res://scripts/ui/combat_type_icon.gd")
const MAX_EFFECTS := 12
const COLORS := {"sulfur": Color("d9b300"), "mercury": Color("a7b0bd"), "sodium": Color("d8d8d8"), "aether": Color("7a5cff"), "vitriol": Color("39c34a"), "gold": Color("d4af37")}

var elements: Array[String] = []
var mode := "hit"
var progress := 0.0
var origin := Vector2.ZERO
var radius := 110.0
var has_origin := false

static func hit(target: Control, element_type: String, secondary_type: String = "") -> void:
	if not is_instance_valid(target) or element_type not in COLORS: return
	var effect = new()
	effect.elements.append(element_type)
	if secondary_type in COLORS and secondary_type != element_type: effect.elements.append(secondary_type)
	_spawn(target, effect, 0.9)

static func hit_fighter(target: Control, fighter: Dictionary) -> void:
	var types: Array = fighter.get("expedition_types", [])
	var primary := str(types[0]) if not types.is_empty() else str(fighter.get("element_type", fighter.get("type", "")))
	var secondary := str(types[1]) if types.size() > 1 else ""
	hit(target, primary, secondary)

static func passive(hom: Control, owner: Control) -> void:
	if not is_instance_valid(owner): return
	var effect = new()
	effect.mode = "passive"
	if is_instance_valid(hom) and hom.is_visible_in_tree() and (not hom is TextureRect or hom.texture != null):
		effect.has_origin = true
		effect.origin = hom.get_global_transform() * (hom.size * 0.5) - owner.get_global_transform() * (owner.size * 0.5)
	_spawn(owner, effect, 1.3)

static func clear(target: Control) -> void:
	if not is_instance_valid(target): return
	for child in target.get_children():
		if child.has_meta("combat_vfx"): child.queue_free()

static func _spawn(target: Control, effect: Control, duration: float) -> void:
	var count := 0
	for child in target.get_children():
		if child.has_meta("combat_vfx"): count += 1
	if count >= MAX_EFFECTS:
		effect.free()
		return
	effect.set_meta("combat_vfx", true)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.top_level = true
	target.add_child(effect)
	effect.position = target.get_global_transform() * (target.size * 0.5)
	var displayed := target.size * target.get_global_transform().get_scale().abs()
	effect.radius = clampf(maxf(displayed.x, displayed.y) * 0.52, 55.0, 165.0)
	var tween := effect.create_tween()
	tween.tween_method(Callable(effect, "_advance"), 0.0, 1.0, duration)
	tween.tween_callback(Callable(effect, "queue_free"))

func _advance(value: float) -> void:
	progress = value
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 if progress < 0.7 else (1.0 - progress) / 0.3
	if mode == "passive":
		var green := Color(0.35, 1.0, 0.52, alpha)
		if has_origin:
			if progress < 0.35:
				draw_circle(origin, 35.0 + progress * 30.0, Color(0.25, 1.0, 0.4, alpha * 0.18))
				draw_arc(origin, 32.0 + progress * 35.0, 0.0, TAU, 40, green, 3.0, true)
			var travel := clampf((progress - 0.12) / 0.65, 0.0, 1.0)
			for i in 12:
				var angle := float(i) * TAU / 12.0
				var offset := Vector2.from_angle(angle) * (18.0 + 12.0 * sin(travel * PI))
				draw_circle(origin.lerp(Vector2.ZERO, travel) + offset, 5.0 + float(i % 3), green)
		if not has_origin or progress > 0.62:
			var pulse := clampf((progress - 0.62) / 0.38, 0.0, 1.0) if has_origin else progress
			draw_arc(Vector2.ZERO, 40.0 + 12.0 * pulse, 0.0, TAU, 48, green, 4.0, true)
		return
	var expansion := 0.35 + 0.65 * (1.0 - pow(1.0 - minf(progress / 0.7, 1.0), 2.0))
	for i in 14:
		var angle := float(i) * TAU / 14.0 + 0.12
		var point := Vector2.from_angle(angle) * radius * expansion
		var color: Color = COLORS[elements[i % elements.size()]]
		color.a = alpha
		draw_circle(point, 5.0 + float(i % 3), color)
		draw_line(point * 0.87, point, color, 3.0, true)
	for i in elements.size():
		var color: Color = COLORS[elements[i]]
		color.a = alpha
		var glyph_size := clampf(radius * 0.43, 35.0, 52.0) if elements.size() == 1 else clampf(radius * 0.34, 30.0, 42.0)
		var offset := Vector2.ZERO if elements.size() == 1 else Vector2((-0.5 if i == 0 else 0.5) * glyph_size * 0.85, 0)
		draw_set_transform(offset - Vector2.ONE * glyph_size * 0.5, 0.0, Vector2.ONE * glyph_size / 24.0)
		TypeIcon.draw_symbol(self, elements[i], color)
		draw_set_transform(Vector2.ZERO)
