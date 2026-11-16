extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var presenter = preload("res://scripts/ui/combat_log_presenter.gd").new()
	for locale in ["en", "es"]:
		TranslationServer.set_locale(locale)
		for mode in ["bo3", "hunt", "dungeon"]:
			var label := RichTextLabel.new()
			presenter.append(label, 1, "", {"actor": mode, "parent": "Mage", "verb": " uses ", "spell_id": "cinder_fist", "spell_name": "Cinder Fist", "effectiveness": 1.5})
			var content := label.get_parsed_text()
			if not content.contains("homunculus of" if locale == "en" else "homúnculo de") or not content.contains("Effective" if locale == "en" else "Eficaz"):
				push_error("FAIL %s %s: %s" % [locale, mode, content])
				quit(1)
				return
			label.free()
	print("PASS presenter EN/ES fixtures for Bo3, Hunt and Dungeon")
	quit()
