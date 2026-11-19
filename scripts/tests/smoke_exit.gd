extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var menu := (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var exit_button: Button = menu.get_node("ExitButton")
	if exit_button.size != Vector2(210, 59) or menu.get_node("LowerButtons").get_child_count() != 4:
		_fail("exit dimensions or central buttons: %s / %d" % [exit_button.size, menu.get_node("LowerButtons").get_child_count()])
		return
	for locale in ["en", "es"]:
		TranslationServer.set_locale(locale)
		exit_button.pressed.emit()
		var overlay: CanvasLayer = menu._exit_overlay
		var box: VBoxContainer = overlay.get_child(1).get_child(0).get_child(0)
		if box.get_child(0).text != ("¿Estás seguro?" if locale == "es" else "Are you sure?") or box.get_child(1).get_child(1).text != ("Sí" if locale == "es" else "Yes"):
			_fail("confirmation translation")
			return
		box.get_child(1).get_child(0).pressed.emit()
		if is_instance_valid(menu._exit_overlay):
			_fail("No did not cancel")
			return
		await process_frame
	exit_button.pressed.emit()
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	menu._unhandled_input(event)
	if is_instance_valid(menu._exit_overlay):
		_fail("Escape did not cancel")
		return
	await process_frame
	exit_button.pressed.emit()
	print("PASS exit layout, translations, No, Escape and Yes")
	menu._exit_overlay.get_child(1).get_child(0).get_child(0).get_child(1).get_child(1).pressed.emit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
