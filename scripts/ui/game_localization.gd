extends Node

const SETTINGS_PATH := "user://settings.cfg"

func _enter_tree() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	var language := str(config.get_value("interface", "language", "en"))
	TranslationServer.set_locale(language if language in ["en", "es"] else "en")

func set_language(language: String) -> void:
	if language not in ["en", "es"]:
		return
	TranslationServer.set_locale(language)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("interface", "language", language)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Could not save language preference.")

static func catalog(kind: String, id: String, field: String, fallback: String) -> String:
	var key := "%s_%s_%s" % [kind.to_upper(), id.to_upper(), field.to_upper()]
	var translated := TranslationServer.translate(key)
	return fallback if translated == key else translated
