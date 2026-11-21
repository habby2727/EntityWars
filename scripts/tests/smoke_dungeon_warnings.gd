extends SceneTree

var confirmed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var gate := root.get_node("ConnectionGate")
	var messages := {
		"en": ["Dungeon runs cannot be resumed.", "Leaving Dungeon will permanently end this run as a defeat.", "ENTER DUNGEON", "CANCEL", "EXIT DUNGEON", "STAY"],
		"es": ["Las partidas de Dungeon no pueden reanudarse.", "Salir de Dungeon finalizará definitivamente esta partida como una derrota.", "ENTRAR", "CANCELAR", "SALIR", "QUEDARSE"]
	}
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		for locale in ["en", "es"]:
			TranslationServer.set_locale(locale)
			for entering in [true, false]:
				gate.dungeon_warning("DUNGEON_ENTRY_WARNING" if entering else "DUNGEON_EXIT_WARNING", "DUNGEON_ENTRY_CONFIRM" if entering else "DUNGEON_EXIT_CONFIRM", "DUNGEON_CANCEL" if entering else "DUNGEON_STAY", func(): confirmed += 1)
				await process_frame
				var layer := gate.get_node_or_null("DungeonWarning")
				assert(layer != null)
				var shade: ColorRect = layer.get_child(0)
				assert(shade.color.a > 0.0 and shade.color.a < 1.0)
				var panel: PanelContainer = layer.get_child(1).get_child(0)
				assert(panel.get_theme_stylebox("panel") is StyleBoxTexture)
				var box: VBoxContainer = panel.get_child(0)
				var label: Label = box.get_node("WarningText")
				assert(label.text.begins_with(messages[locale][0 if entering else 1]))
				assert(label.size.x >= label.get_minimum_size().x and label.size.y >= label.get_minimum_size().y)
				var buttons: HBoxContainer = box.get_child(1)
				assert(buttons.get_child(0).text == messages[locale][2 if entering else 4])
				assert(buttons.get_child(1).text == messages[locale][3 if entering else 5])
				for button in buttons.get_children():
					assert(button.get_theme_stylebox("normal") is StyleBoxTexture)
				buttons.get_child(1).pressed.emit()
				await process_frame
				assert(confirmed == 0 and gate.get_node_or_null("DungeonWarning") == null)
	gate.dungeon_warning("DUNGEON_ENTRY_WARNING", "DUNGEON_ENTRY_CONFIRM", "DUNGEON_CANCEL", func(): confirmed += 1)
	await process_frame
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(0).pressed.emit()
	await process_frame
	assert(confirmed == 1)
	SceneRouter._dungeon_context = {"run_id": "exit-test", "player_id": "fixture"}
	gate.dungeon_exit_warning()
	await process_frame
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(1).pressed.emit()
	await process_frame
	assert(SceneRouter._dungeon_context.get("run_id") == "exit-test")
	gate.dungeon_exit_warning()
	await process_frame
	gate.get_node("DungeonWarning").get_child(1).get_child(0).get_child(0).get_child(1).get_child(0).pressed.emit()
	await process_frame
	assert(SceneRouter._dungeon_context.is_empty())
	SceneRouter._dungeon_context = {"run_id": "disconnect-test", "player_id": "fixture"}
	gate.state = gate.State.CONNECTED
	gate._identity_mismatch = false
	gate._fail(gate.State.RECONNECTING, "fixture disconnect")
	assert(SceneRouter._dungeon_context.is_empty())
	assert(gate._dungeon_return_after_disconnect and gate._recovery_owner_id == 0)
	gate._player_verified = true
	gate._unlock()
	assert(not gate.blocked() and not gate._dungeon_return_after_disconnect)
	assert(SceneRouter._dungeon_context.is_empty() and SceneRouter._solo_hunt_context.is_empty())
	gate._timer.stop()
	print("PASS Dungeon warnings, translations, cancellation, exit and disconnect at 720p and 1080p")
	quit(0)
