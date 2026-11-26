extends Control

var vector := Vector2.ZERO
var _finger := -1
const RADIUS := 78.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and _finger == -1:
		_finger = event.index
		_set_vector(event.position)
		accept_event()

func _input(event: InputEvent) -> void:
	if _finger == -1:
		return
	if event is InputEventScreenDrag and event.index == _finger:
		_set_vector(make_input_local(event).position)
	elif event is InputEventScreenTouch and event.index == _finger and not event.pressed:
		_finger = -1
		vector = Vector2.ZERO
		queue_redraw()

func _set_vector(local_position: Vector2) -> void:
	vector = ((local_position - size * 0.5) / RADIUS).limit_length(1.0)
	if vector.length() < 0.12:
		vector = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, RADIUS + 6.0, Color(0.02, 0.05, 0.05, 0.48))
	draw_arc(center, RADIUS + 6.0, 0, TAU, 48, Color(0.75, 0.86, 0.74, 0.65), 3.0)
	draw_circle(center + vector * RADIUS, 32.0, Color(0.72, 0.83, 0.70, 0.65))
