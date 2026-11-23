extends RefCounted

# GameTypography applies fonts deferred. Its existing metadata selects Old Newspaper
# only for these social controls, and restores the normal choice when English returns.
static func apply(control: Control, text: String) -> void:
	var needs_font := false
	if TranslationServer.get_locale().begins_with("es"):
		for character in text:
			if "áéíóúüñÁÉÍÓÚÜÑ".contains(character):
				needs_font = true
				break
	if needs_font == control.has_meta("localization_body_font"):
		return
	if needs_font:
		control.set_meta("localization_body_font", true)
	else:
		control.remove_meta("localization_body_font")
	GameTypography._apply_font_if_alive.call_deferred(control.get_instance_id())
