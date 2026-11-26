extends Control
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var c := Color("e5c76d")
	var w := size.x
	var h := size.y
	var points := PackedVector2Array([Vector2(w * 0.08, h * 0.5), Vector2(w * 0.28, h * 0.24), Vector2(w * 0.5, h * 0.15), Vector2(w * 0.72, h * 0.24), Vector2(w * 0.92, h * 0.5), Vector2(w * 0.72, h * 0.76), Vector2(w * 0.5, h * 0.85), Vector2(w * 0.28, h * 0.76), Vector2(w * 0.08, h * 0.5)])
	draw_polyline(points, c, 2.0, true)
	draw_circle(size * 0.5, minf(w, h) * 0.15, c)
