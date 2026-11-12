extends Control

var element := ""
var accent := Color.WHITE

func configure(type_id: String) -> void:
	element = type_id
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/types.json"))
	if data is Dictionary:
		for entry in data.get("types", []):
			if str(entry.get("id", "")) == element:
				accent = Color.from_string(str(entry.get("color", "")), Color.WHITE)
				break
	custom_minimum_size = Vector2(24, 24)
	size = Vector2(24, 24)
	tooltip_text = element.capitalize()
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2(12, 12), 10, 0, TAU, 24, accent, 1.5, true)
	match element:
		"sulfur":
			draw_colored_polygon(PackedVector2Array([Vector2(12, 3), Vector2(5, 19), Vector2(19, 19)]), accent)
		"mercury":
			draw_arc(Vector2(12, 9), 5, 0, TAU, 16, accent, 2, true)
			draw_line(Vector2(12, 14), Vector2(12, 21), accent, 2, true)
			draw_line(Vector2(8, 18), Vector2(16, 18), accent, 2, true)
		"sodium":
			draw_colored_polygon(PackedVector2Array([Vector2(12, 3), Vector2(19, 12), Vector2(12, 21), Vector2(5, 12)]), accent)
		"aether":
			draw_line(Vector2(5, 5), Vector2(19, 19), accent, 3, true)
			draw_line(Vector2(19, 5), Vector2(5, 19), accent, 3, true)
		"vitriol":
			draw_colored_polygon(PackedVector2Array([Vector2(12, 3), Vector2(6, 12), Vector2(6, 17), Vector2(12, 21), Vector2(18, 17), Vector2(18, 12)]), accent)
		"gold":
			draw_arc(Vector2(12, 12), 5, 0, TAU, 20, accent, 3, true)
