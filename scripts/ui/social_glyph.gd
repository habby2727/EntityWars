extends Control

var plus := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)

func _draw() -> void:
	var s := minf(size.x, size.y)
	var origin := (size - Vector2(s, s)) * 0.5
	var color := Color("e5c76d")
	draw_circle(origin + Vector2(s * 0.43, s * 0.30), s * 0.17, color)
	draw_arc(origin + Vector2(s * 0.43, s * 0.91), s * 0.35, PI * 1.12, PI * 1.88, 20, color, maxf(2.0, s * 0.10), true)
	if plus:
		var c := origin + Vector2(s * 0.79, s * 0.65)
		draw_line(c + Vector2(-s * 0.14, 0), c + Vector2(s * 0.14, 0), color, maxf(2.0, s * 0.09), true)
		draw_line(c + Vector2(0, -s * 0.14), c + Vector2(0, s * 0.14), color, maxf(2.0, s * 0.09), true)
