extends RefCounted

# Preserve the regular font choice for social text without Spanish accents.
static func apply(control: Control, text: String) -> void:
	if not control is Button:
		return
	var needs_font := false
	if TranslationServer.get_locale().begins_with("es"):
		for character in text:
			if "áéíóúüñÁÉÍÓÚÜÑ".contains(character):
				needs_font = true
				break
	if needs_font == control.has_meta("medieval_sharp_font"):
		return
	if needs_font:
		control.set_meta("medieval_sharp_font", true)
	else:
		control.remove_meta("medieval_sharp_font")
	GameTypography._apply_font_if_alive.call_deferred(control.get_instance_id())
