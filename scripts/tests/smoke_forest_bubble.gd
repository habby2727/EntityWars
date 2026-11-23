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
	assert(bubble.visible and bubble._label.text == "[b]plain[/b]" and bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var original_y: float = bubble.position.y
	var action := Button.new()
	action.name = "DuelAction"
	action.position.y = -240
	avatar.add_child(action)
	bubble._process(0.0)
	assert(bubble.position.y < original_y)
	var original_deadline: int = bubble._deadline_ticks
	bubble.show_message(1, "duplicate", 1000, 11000, 3000)
	assert(bubble._label.text == "[b]plain[/b]" and bubble._deadline_ticks == original_deadline)
	bubble.show_message(2, "new", 2000, 12000, 4000)
	assert(bubble._label.text == "new")
	bubble.show_message(3, "expired", 3000, 13000, 13000)
	assert(bubble._label.text == "new")
	bubble._deadline_ticks = Time.get_ticks_msec()
	bubble._process(0.0)
	assert(not bubble.visible)
	print("FOREST_BUBBLE_SMOKE_PASS")
	avatar.queue_free()
	quit(0)
