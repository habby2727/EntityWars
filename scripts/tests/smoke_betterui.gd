extends SceneTree

const MenuArt = preload("res://scripts/ui/menu_art.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var button := Button.new()
	button.text = "SETTINGS_BACK"
	root.add_child(button)
	for locale in ["en", "es"]:
		TranslationServer.set_locale(locale)
		MenuArt.button(button)
		assert(button.get_meta("betterui_button") == "boton_corto.png")
		var short_style := button.get_theme_stylebox("normal") as StyleBoxTexture
		assert(short_style != null and short_style.texture != null)
		button.text = "LAB_OPEN_INVENTORY"
		MenuArt.refresh_button(button)
		assert(button.get_meta("betterui_button") == "boton_largo.png")
		var long_style := button.get_theme_stylebox("normal") as StyleBoxTexture
		assert(long_style.texture.get_width() > short_style.texture.get_width())
		assert(button.get_theme_stylebox("disabled") is StyleBoxTexture)
		button.text = "SETTINGS_BACK"
		MenuArt.refresh_button(button)
	for name in ["panel_vertical.png", "panel_horizontal.png"]:
		var style := MenuArt.frame(name, Vector4(10, 12, 10, 12))
		assert(style.texture.resource_path.ends_with("betterui/" + name))
	button.queue_free()
	print("PASS betterui styles")
	quit()
