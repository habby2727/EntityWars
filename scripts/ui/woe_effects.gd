extends Node2D

# A single drawing node owns all effects, with fixed memory regardless of match length.
const CAP := 96
const COLORS := {
	"sulfur": [Color("ff9b45"), Color("ffdb85")],
	"mercury": [Color("b5e6fa"), Color("e7f6ff")],
	"sodium": [Color("ffd048"), Color("fff1a5")],
	"vitriol": [Color("b990ed"), Color("a2e88d")],
	"gold": [Color("f4c66a"), Color("fff1b6")],
	"aether": [Color("7ddff1"), Color("c3a1ff")]
}
var effects: Array[Dictionary] = []
var potion_areas: Array[Dictionary] = []
var elapsed := 0.0

func show_potion_area(element: String, point: Vector2, radius: float, duration: float, age: float = 0.0) -> void:
	if element not in ["aether", "vitriol"] or radius <= 0.0 or duration <= age: return
	if potion_areas.size() >= CAP: potion_areas.pop_front()
	potion_areas.append({"element":element, "point":point, "radius":radius, "duration":duration, "age":maxf(0.0, age)})
	queue_redraw()

func emit_effect(kind: String, element: String, source: Vector2, target: Vector2, team: String = "", lab_id: String = "", area_radius: float = 0.0) -> void:
	if not COLORS.has(element): return
	if effects.size() >= CAP: effects.pop_front()
	var life := 0.45
	if kind == "death": life = 0.75
	elif kind == "spawn": life = 0.6
	effects.append({"kind":kind,"element":element,"source":source,"target":target,"team":team,"lab_id":lab_id,"radius":area_radius,"age":0.0,"life":life})
	queue_redraw()

func prune_lab_defense(labs: Dictionary) -> void:
	for i in range(effects.size() - 1, -1, -1):
		if effects[i].kind == "lab_defense" and (not labs.has(effects[i].lab_id) or not labs[effects[i].lab_id].alive): effects.remove_at(i)
	queue_redraw()

func clear() -> void:
	effects.clear()
	potion_areas.clear()
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	for i in range(potion_areas.size() - 1, -1, -1):
		potion_areas[i].age += delta
		if potion_areas[i].age >= potion_areas[i].duration: potion_areas.remove_at(i)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].age += delta
		if effects[i].age >= effects[i].life: effects.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for area in potion_areas:
		var pulse := 0.5 + 0.5 * sin(float(area.age) * TAU / 2.4)
		var end_fade := minf(1.0, (float(area.duration) - float(area.age)) / 0.3)
		var color := Color(1.0, 0.46, 0.06) if area.element == "aether" else Color(0.3, 0.88, 0.23)
		color.a = (0.07 + 0.08 * pulse) * end_fade
		draw_circle(area.point, area.radius, color)
		color.a = (0.22 + 0.2 * pulse) * end_fade
		draw_arc(area.point, area.radius, 0, TAU, 48, color, 2.5)
	# Sparse ambient motes are fixed in place and never allocate nodes.
	for i in range(12):
		var alpha := 0.08 + 0.05 * sin(elapsed * 0.7 + i)
		var x := 120.0 + float((i * 547) % 1680)
		var y := 120.0 + float((i * 313) % 820) + sin(elapsed + i) * 4.0
		draw_circle(Vector2(x,y), 2.0, Color(0.65,0.85,1.0,alpha))
	for effect in effects:
		var t: float = float(effect.age) / float(effect.life)
		var fade := 1.0 - t
		var palette: Array = COLORS[effect.element]
		var c: Color = palette[0]
		var accent: Color = palette[1]
		c.a = fade * 0.7
		accent.a = fade * 0.8
		var point: Vector2 = effect.target
		var radius := 4.0 + 13.0 * t
		if effect.kind == "potion_cast":
			var area := float(effect.radius)
			var splash := Color(0.4,0.75,1.0,fade*0.2) if effect.element == "aether" else Color(0.45,0.9,0.25,fade*0.2)
			accent = Color(1.0,0.9,0.35,fade*0.8) if effect.element == "aether" else Color(0.7,0.4,0.95,fade*0.8)
			draw_circle(point,area * (0.55 + 0.45*t),splash)
			draw_arc(point,area,0,TAU,48,accent,3.0)
			for i in range(8):
				var direction := Vector2.from_angle(float(i)*TAU/8.0+t)
				if effect.element == "aether":
					var perpendicular := direction.orthogonal()
					var bolt := PackedVector2Array([point+direction*area*0.2, point+direction*area*0.4+perpendicular*6.0, point+direction*area*0.55-perpendicular*6.0, point+direction*area*0.8])
					draw_polyline(bolt,accent,2.0)
				else:
					draw_circle(point+direction*area*0.65,4.0+4.0*t,accent)
			continue
		if effect.kind == "tower_strike":
			draw_line(effect.source, effect.target, Color(1.0, 0.15, 0.04, fade * 0.85), 12.0)
			draw_line(effect.source, effect.target, Color(1.0, 0.85, 0.35, fade), 5.0)
			draw_circle(effect.target, 10.0 + 10.0 * t, Color(1.0, 0.65, 0.12, fade * 0.7))
			continue
		if effect.kind == "lab_defense":
			var beam := Color("66c8ff") if effect.team == "blue" else Color("ff735f")
			beam.a = fade * 0.85
			draw_line(effect.source, effect.target, beam, 4.0)
			draw_circle(effect.target, 8.0 + 5.0 * t, beam)
			continue
		if effect.kind in ["strike", "charge"]:
			point = effect.source
			if effect.kind == "strike": draw_line(effect.source, effect.source.lerp(effect.target, 0.35), c, 2.0)
		if effect.kind == "spawn":
			var team_color := Color("78bdff") if effect.team == "blue" else Color("ff9285")
			team_color.a = fade * 0.5
			draw_arc(point, radius + 4.0, 0, TAU, 20, team_color, 1.5)
		if effect.kind == "lab":
			radius *= 1.35
			draw_line(point + Vector2(-radius, 0), point + Vector2(radius, 0), c, 2.0)
			draw_line(point + Vector2(0, -radius), point + Vector2(0, radius), c, 2.0)
		elif effect.kind == "death":
			draw_arc(point, radius + 3.0, 0, TAU, 24, accent, 1.5)
		elif effect.kind == "charge":
			draw_arc(point, maxf(2.0, 12.0 - 7.0*t), 0, TAU, 16, accent, 1.5)
		match str(effect.element):
			"sulfur":
				for i in range(5):
					var direction := Vector2.from_angle(float(i) * TAU / 5.0 + 0.3)
					draw_line(point + direction * radius * 0.4, point + direction * radius + Vector2(0,-6*t), accent, 2.0)
			"mercury":
				draw_arc(point, radius, 0, TAU, 20, c, 2.0)
				draw_circle(point + Vector2(radius * 0.55,-radius * 0.4), 3.0 * fade, accent)
			"sodium":
				var bolt := PackedVector2Array([point + Vector2(-radius, -radius), point + Vector2(0,-radius * 0.3), point + Vector2(-3,radius * 0.1), point + Vector2(radius,radius)])
				draw_polyline(bolt, accent, 2.0)
			"vitriol":
				for i in range(4):
					var direction := Vector2.from_angle(float(i) * TAU / 4.0 + t)
					draw_circle(point + direction * radius * 0.55, 4.0 + 4.0*t, c if i % 2 == 0 else accent)
			"gold":
				var diamond := PackedVector2Array([point + Vector2(0,-radius),point + Vector2(radius,0),point + Vector2(0,radius),point + Vector2(-radius,0),point + Vector2(0,-radius)])
				draw_polyline(diamond, accent, 2.0)
			"aether":
				draw_arc(point, radius, 0, TAU, 24, c, 2.0)
				draw_arc(point, radius * 0.65, 0, TAU, 20, accent, 1.5)
