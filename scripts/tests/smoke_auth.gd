extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in load("res://scripts/ui/auth_screen.gd").BACKGROUNDS:
		if load(path) == null:
			push_error("Missing auth background: " + path)
			quit(1)
			return
	var auth := (load("res://scenes/ui/Auth.tscn") as PackedScene).instantiate()
	root.add_child(auth)
	current_scene = auth
	await process_frame
	for field in auth.username:
		field.text = "ab \tc\u00a0d"
		field.caret_column = 5
		field.text_changed.emit(field.text)
		if field.text != "abcd" or field.caret_column != 3:
			push_error("Username whitespace or caret not sanitized")
			quit(1)
			return
	for field in [auth.password[0], auth.password[1], auth.confirm]:
		field.text = "ab \tc\u00a0d"
		field.caret_column = 5
		field.text_changed.emit(field.text)
		if field.text != "abcd" or field.caret_column != 3:
			push_error("Password whitespace or caret not sanitized")
			quit(1)
			return
	if auth.verifying or auth.get_node_or_null("ProgressFill") != null:
		push_error("Unauthenticated startup did not show the form")
		quit(1)
		return
	auth.endpoint_safe = true
	auth.preflight_ok = true
	auth.username[1].text = "test_user"
	auth.password[1].text = "short"
	auth.confirm.text = "short"
	auth._submit(1)
	if auth.message.text != tr("AUTH_SHORT_PASSWORD") or auth.busy:
		push_error("Short password accepted")
		quit(1)
		return
	auth.password[1].text = "longer"
	auth._submit(1)
	if auth.message.text != tr("AUTH_PASSWORD_MISMATCH") or auth.busy:
		push_error("Password mismatch accepted")
		quit(1)
		return
	print("PASS: auth form validation and three backgrounds")
	quit(0)
