extends Control

func _draw() -> void:
	var color := Color(0.94, 0.78, 0.38)
	draw_arc(Vector2(10, 8), 5, PI, TAU, 16, color, 2.0, true)
	draw_rect(Rect2(3, 8, 14, 11), color, false, 2.0)
	draw_circle(Vector2(10, 13), 1.5, color)
