extends RefCounted

const COLORS := {"damage": "ff7777", "heal": "78de9f", "shield": "73bfff", "buff": "86dca8", "debuff": "e4b85a", "miss": "a3aab5", "advantage": "ebc768", "combo": "d9a4f5", "system": "cdd3d9", "homunculus": "c6a5f5"}
const PATHS := {"damage": "M4 19 L17 4 M12 4 L20 4 L20 12 M3 14 L10 21", "heal": "M12 4 V20 M4 12 H20", "shield": "M12 3 L20 6 L18 15 L12 21 L6 15 L4 6 Z", "debuff": "M12 3 L5 12 Q3 20 12 21 Q21 20 19 12 Z", "buff": "M12 20 V4 M6 10 L12 4 L18 10", "miss": "M5 5 L19 19 M19 5 L5 19", "advantage": "M12 3 L15 9 L21 12 L15 15 L12 21 L9 15 L3 12 L9 9 Z", "combo": "M3 14 L9 7 L13 12 L20 4 M15 4 H20 V9", "homunculus": "M5 19 V10 L8 5 L12 9 L16 5 L19 10 V19 Z", "system": "M12 4 V12 L17 15 M20 12 A8 8 0 1 1 4 12 A8 8 0 1 1 20 12"}
var _icons := {}

func append(label: RichTextLabel, turn: int, message: String, event: Dictionary = {}) -> void:
	var category := str(event.get("category", "system"))
	var color := Color("d9a4f5") if category == "inspiration" else Color("73d9d4") if category == "switch" else Color.from_string(COLORS.get(category, COLORS.system), Color.WHITE)
	label.push_bold()
	label.push_color(Color("e6d4a2"))
	label.add_text("T%d  " % turn)
	label.pop()
	label.pop()
	label.add_image(_icon(category), 18, 18)
	label.add_text("  ")
	var actor := str(event.get("actor", ""))
	if not actor.is_empty():
		label.push_color(Color.from_string(str(event.get("actor_color", "cdd3d9")), Color.WHITE))
		label.add_text(actor)
		label.pop()
		if event.has("parent"):
			label.add_text(" (homunculus of ")
			label.push_color(Color.from_string(str(event.get("parent_color", "cdd3d9")), Color.WHITE))
			label.add_text(str(event.parent))
			label.pop()
			label.add_text(")")
		label.push_color(color)
		label.add_text(str(event.get("verb", " ")))
		label.pop()
		if event.has("target"):
			label.push_color(Color.from_string(str(event.get("target_color", "cdd3d9")), Color.WHITE))
			label.add_text(str(event.target))
			label.pop()
		if event.has("spell_id") and bool(event.get("show_spell_link", true)) and not str(event.spell_id).is_empty():
			label.push_meta(event.get("spell_meta", str(event.spell_id)))
			label.push_color(Color("e8c875"))
			label.add_text(str(event.get("spell_name", event.spell_id)))
			label.pop()
			label.pop()
		label.push_color(color)
		label.add_text(str(event.get("suffix", "")))
		label.pop()
		var effectiveness := float(event.get("effectiveness", 1.0))
		if event.has("effectiveness"):
			label.add_text("  ")
			label.add_image(_icon("advantage"), 18, 18)
			label.push_color(Color("cdd3d9") if is_equal_approx(effectiveness, 1.0) else Color("ebc768"))
			var matchup := "Neutral" if is_equal_approx(effectiveness, 1.0) else "Effective" if effectiveness > 1.0 else "Ineffective"
			label.add_text(" %s x%.2f" % [matchup, effectiveness])
			label.pop()
	else:
		label.push_color(color)
		if event.has("ability_id"):
			label.push_meta({"ability": str(event.ability_id)})
		label.add_text(message)
		if event.has("ability_id"):
			label.pop()
		label.pop()
	label.add_text("\n")

func _icon(category: String) -> Texture2D:
	if not _icons.has(category):
		var path: String = "M12 2 L14 9 L21 12 L14 15 L12 22 L10 15 L3 12 L10 9 Z" if category == "inspiration" else "M4 8 H19 M15 4 L19 8 L15 12 M20 16 H5 M9 12 L5 16 L9 20" if category == "switch" else PATHS.get(category, PATHS.system)
		var color: String = "d9a4f5" if category == "inspiration" else "73d9d4" if category == "switch" else COLORS.get(category, COLORS.system)
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#%s" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>' % [path, color]
		var image := Image.new()
		image.load_svg_from_buffer(svg.to_utf8_buffer())
		_icons[category] = ImageTexture.create_from_image(image)
	return _icons[category]
