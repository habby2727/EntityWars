extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var avatar := Node2D.new()
	root.add_child(avatar)
	var nameplate := Label.new()
	nameplate.name = "Nameplate"
	nameplate.position.y = -160
	avatar.add_child(nameplate)
	var bubble = load("res://scripts/forest/forest_speech_bubble.gd").new()
	avatar.add_child(bubble)
	bubble.show_message(1, "[b]plain[/b]", 1000, 11000, 2000)
	await process_frame
	await process_frame
	assert(bubble.visible and bubble._label.text == "[b]plain[/b]" and bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(bubble.size.x == 300 and bubble.size.y >= 30 and bubble._label.size.y >= bubble._label.get_theme_font("font").get_height(22), "Bubble must give the text visible height")
	var original_y: float = bubble.position.y
	var single_line_height: float = bubble.size.y
	var action := Button.new()
	action.name = "DuelAction"
	action.position.y = -240
	avatar.add_child(action)
	bubble._process(0.0)
	assert(bubble.position.y < original_y)
	var original_deadline: int = bubble._deadline_ticks
	bubble.show_message(1, "duplicate", 1000, 11000, 3000)
	assert(bubble._label.text == "[b]plain[/b]" and bubble._deadline_ticks == original_deadline)
	var long_text := "Hola, esto es un mensaje largo con acentos y varias palabras que debe ocupar varias líneas visibles sobre el jugador."
	bubble.show_message(2, long_text, 2000, 12000, 4000)
	await process_frame
	await process_frame
	assert(bubble._label.text == long_text and bubble.size.y > single_line_height and bubble._label.get_line_count() > 1, "Long messages must wrap and expand the bubble")
	assert(bubble.position.y + bubble.size.y < action.position.y, "Bubble must remain above player actions")
	bubble.show_message(3, "W".repeat(120), 3000, 13000, 4000)
	await process_frame
	await process_frame
	assert(bubble._label.get_line_count() > 1 and bubble._label.size.y >= mini(bubble._label.get_line_count(), 8) * bubble._label.get_theme_font("font").get_height(22), "Long words must also fit the wrapped lines")
	bubble.show_message(4, "new", 4000, 14000, 5000)
	await process_frame
	await process_frame
	assert(bubble._label.text == "new" and bubble.size.y == single_line_height, "Bubble must shrink for a shorter message")
	bubble.show_message(5, "expired", 5000, 15000, 15000)
	assert(bubble._label.text == "new")
	bubble._deadline_ticks = Time.get_ticks_msec()
	bubble._process(0.0)
	assert(not bubble.visible)
	print("FOREST_BUBBLE_SMOKE_PASS")
	avatar.queue_free()
	quit(0)
