extends Button

var code := ""
var copied_for := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(52, 44)
	tooltip_text = tr("WOE_COPY_CODE")
	pressed.connect(_copy)

func _copy() -> void:
	if code.is_empty(): return
	DisplayServer.clipboard_set(code)
	copied_for = 2.0
	queue_redraw()

func _process(delta: float) -> void:
	if copied_for <= 0.0: return
	copied_for = maxf(0.0, copied_for - delta)
	if copied_for == 0.0: queue_redraw()

func _draw() -> void:
	var center := size / 2.0
	var ink := Color("a9f3b7") if copied_for > 0.0 else Color("f5e4ad")
	if copied_for > 0.0:
		draw_polyline(PackedVector2Array([center + Vector2(-9, 0), center + Vector2(-2, 7), center + Vector2(10, -8)]), ink, 3.0, true)
	else:
		draw_rect(Rect2(center + Vector2(-8, -10), Vector2(13, 15)), ink, false, 2.0)
		draw_rect(Rect2(center + Vector2(-3, -5), Vector2(13, 15)), ink, false, 2.0)
