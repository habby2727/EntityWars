extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := Color("e5c76d")
	var s := minf(size.x, size.y)
	for direction in [-1.0, 1.0]:
		var start := Vector2(s * (0.5 - direction * 0.27), s * 0.2)
		var end := Vector2(s * (0.5 + direction * 0.27), s * 0.8)
		draw_line(start, end, c, maxf(2.0, s * 0.10), true)
		var guard := start.lerp(end, 0.75)
		draw_line(guard + Vector2(-s * 0.13, 0), guard + Vector2(s * 0.13, 0), c, maxf(2.0, s * 0.07), true)
