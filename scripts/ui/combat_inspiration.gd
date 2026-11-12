extends Control

var _points := 0
var _used := false

func _ready() -> void:
	custom_minimum_size = Vector2(200, 26)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_fighter(fighter: Dictionary) -> void:
	var points := int(fighter.get("inspiration", 0))
	_used = bool(fighter.get("inspiration_used_this_battle", false))
	if points > _points and is_inside_tree():
		var tween := create_tween()
		modulate = Color(1.5, 1.3, 2.0)
		tween.tween_property(self, "modulate", Color.WHITE, 0.35)
	_points = points
	tooltip_text = "Inspiration used for this battle." if _used else "Inspiration: %d/3.\nEarn +1 whenever your spell successfully applies\na negative status to the opponent. Repeated types count.\nAt 3, choose one of three temporary spells.\nIt replaces a random equipped spell until this battle ends." % _points
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(-5, 0, 200, 22), Color(0.025, 0.02, 0.05, 0.94))
	draw_string(font, Vector2(0, 16), "USED" if _used else "INSPIRATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d4af37"))
	for i in 3:
		var rect := Rect2(108 + i * 27, 3, 23, 13)
		draw_rect(rect, Color("9d76eb") if i < _points else Color("171323"))
		draw_rect(rect, Color("d4af37"), false, 1.0)
