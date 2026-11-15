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
	assert(button.get_theme_font("font") == typography._title_font)
	assert(rich.get_theme_font("normal_font") == typography._body_font)
	assert(typography._body_font.resource_path == "res://assets/fonts/old-newspaper-types-font/Oldnewspapertypes-449D.ttf")
	for character in "0123456789":
		assert(typography._body_font.has_char(character.unicode_at(0)))
	for character in "áéíóúñÑ¿¡":
		assert(typography._title_font.has_char(character.unicode_at(0)) and typography._body_font.has_char(character.unicode_at(0)))
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
