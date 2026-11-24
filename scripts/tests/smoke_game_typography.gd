extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var typography := root.get_node("GameTypography")
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	var menu_button: Button = menu.find_children("*", "Button", true, false)[0]
	var original_menu_font := menu_button.get_theme_font("font")
	root.add_child(menu)
	var loadout: Node = load("res://scenes/LoadoutGrid.tscn").instantiate()
	var loadout_button: Button = loadout.find_children("*", "Button", true, false)[0]
	var loadout_had_override := loadout_button.has_theme_font_override("font")
	root.add_child(loadout)
	var screen := Control.new()
	root.add_child(screen)
	var heading := Label.new()
	heading.name = "Title"
	screen.add_child(heading)
	var body := Label.new()
	body.name = "Description"
	body.add_theme_font_size_override("font_size", 15)
	screen.add_child(body)
	var button := Button.new()
	screen.add_child(button)
	var rich := RichTextLabel.new()
	screen.add_child(rich)
	await process_frame
	await process_frame
	assert(menu_button.get_theme_font("font") == original_menu_font)
	assert(loadout_button.has_theme_font_override("font") == loadout_had_override)
	assert(heading.get_theme_font("font") == typography._title_font)
	assert(body.get_theme_font("font") == typography._body_font)
	assert(body.get_theme_font_size("font_size") == 30)
	typography._apply_font(body)
	assert(body.get_theme_font_size("font_size") == 30)
	body.text = "25%"
	typography._process(0.1)
	assert(body.get_theme_font("font") == typography._sharp_font)
	assert(body.get_theme_font_size("font_size") == 15)
	body.text = "Explanation"
	typography._process(0.1)
	assert(body.get_theme_font_size("font_size") == 30)
	assert(button.get_theme_font("font") == typography._title_font)
	assert(rich.get_theme_font("normal_font") == typography._body_font)
	assert(typography._body_font.resource_path == "res://assets/fonts/MedievalFont/JimNightshade-Regular.ttf")
	for character in "0123456789":
		assert(typography._body_font.has_char(character.unicode_at(0)))
	for character in "áéíóúñÑ¿¡":
		assert(typography._title_font.has_char(character.unicode_at(0)) and typography._body_font.has_char(character.unicode_at(0)))
	var number := Label.new()
	number.text = "25%"
	screen.add_child(number)
	var chat := Control.new()
	chat.set_meta("global_chat_font", true)
	screen.add_child(chat)
	var chat_text := Label.new()
	chat.add_child(chat_text)
	var translated := Button.new()
	translated.text = "Más tarde"
	screen.add_child(translated)
	TranslationServer.set_locale("es")
	await process_frame
	await process_frame
	assert(number.get_theme_font("font") == typography._sharp_font)
	assert(chat_text.get_theme_font("font") == typography._chat_font)
	assert(translated.get_theme_font("font") == typography._sharp_font)
	translated.text = "Aceptar"
	typography._process(0.1)
	assert(translated.get_theme_font("font") == typography._title_font)
	TranslationServer.set_locale("en")
	var dynamic := Button.new()
	screen.add_child(dynamic)
	await process_frame
	await process_frame
	assert(dynamic.get_theme_font("font") == typography._title_font)
	print("PASS game typography and excluded scenes")
	menu.queue_free()
	loadout.queue_free()
	screen.queue_free()
	await process_frame
	if is_instance_valid(UIThemeFactory._catalog):
		UIThemeFactory._catalog.free()
		UIThemeFactory._catalog = null
	quit()
