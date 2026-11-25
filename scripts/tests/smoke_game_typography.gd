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
	var native_panel := PanelContainer.new()
	load("res://scripts/ui/minigame_panel_style.gd").panel(native_panel)
	screen.add_child(native_panel)
	var native_label := Label.new()
	native_label.text = "Sala de duelos"
	native_panel.add_child(native_label)
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
	assert(native_label.get_theme_font("font") is SystemFont)
	native_label.text = "Sala actualizada"
	typography._process(0.1)
	assert(native_label.get_theme_font("font") is SystemFont)
	typography._apply_font(body)
	assert(body.get_theme_font_size("font_size") == 30)
	body.text = "25%"
	typography._process(0.1)
	assert(body.get_theme_font("font") == typography._sharp_font)
	assert(body.get_theme_font_size("font_size") == 15)
	body.text = "Explanation"
	typography._process(0.1)
	assert(body.get_theme_font_size("font_size") == 30)
	body.add_theme_font_size_override("font_size", 19)
	body.text = "Updated explanation"
	typography._process(0.1)
	assert(body.get_theme_font_size("font_size") == 19)
	body.text = "Another explanation"
	typography._process(0.1)
	assert(body.get_theme_font_size("font_size") == 19)
	body.text = "25%"
	typography._process(0.1)
	body.text = "Explanation again"
	typography._process(0.1)
	assert(body.get_theme_font_size("font_size") == 19)
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
	var combat := Control.new()
	combat.set_meta("combat_font", true)
	screen.add_child(combat)
	var fighter_name := Label.new()
	fighter_name.text = "Homúnculo 25"
	fighter_name.add_theme_font_size_override("font_size", 15)
	combat.add_child(fighter_name)
	var spell := Button.new()
	spell.text = "Poción"
	combat.add_child(spell)
	var combat_log := RichTextLabel.new()
	combat_log.set_meta("global_chat_font", true)
	combat.add_child(combat_log)
	await process_frame
	await process_frame
	assert(fighter_name.get_theme_font("font") == typography._title_font)
	assert(fighter_name.get_theme_font_size("font_size") == 15)
	assert(spell.get_theme_font("font") == typography._title_font)
	assert(combat_log.get_theme_font("normal_font") == typography._chat_font)
	var saved_chat: Font = typography._chat_font
	typography._chat_font = null
	typography._apply_font(combat_log)
	assert(combat_log.get_theme_font("normal_font") == saved_chat)
	typography._chat_font = saved_chat
	var popup := PopupMenu.new()
	popup.set_meta("global_chat_font", true)
	screen.add_child(popup)
	await process_frame
	var saved_popup_font := popup.get_theme_font("font")
	typography._chat_font = null
	typography._apply_font(popup)
	assert(popup.get_theme_font("font") == saved_popup_font)
	typography._chat_font = saved_chat
	fighter_name.text = "25%"
	typography._process(0.1)
	assert(fighter_name.get_theme_font("font") == typography._title_font)
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
