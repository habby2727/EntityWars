extends SceneTree

var output := ""
var viewport: SubViewport
var scene: Control

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("COMBAT_EVO_DIR").replace("\\", "/")
	var user_path := OS.get_user_data_dir().replace("\\", "/").to_lower()
	var dimensions := OS.get_environment("COMBAT_EVO_SIZE").split("x")
	if output.is_empty() or not user_path.begins_with(output.to_lower() + "/") or dimensions.size() != 2:
		_fail("Isolation or size missing")
		return
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	viewport = SubViewport.new()
	viewport.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.timeout.connect(func(): _fail("Test timed out"))
	root.add_child(timeout)
	timeout.start(45.0)
	scene = load("res://scenes/Combat.tscn").instantiate()
	viewport.add_child(scene)
	await process_frame
	await process_frame
	if scene.get_script() == null or not scene._combat_started:
		_fail("Combat did not start")
		return
	var data := {"entity_id": "sulfur_01", "homunculus_id": scene.player.hom_id, "equip_1": "bismuth_talisman", "equip_2": "mirror_sigel"}
	scene.player = scene._build_fighter(data, true)
	scene.enemy = scene._build_fighter({"entity_id": "vitriol_01", "homunculus_id": scene.enemy.hom_id, "equip_1": "wind_amulet"}, false)
	scene._update_ui()
	scene._refresh_spell_buttons()
	if scene._actor_color(scene.player) != "69d7e8" or scene._actor_color(scene.player, true) != "85dca2" or scene._actor_color(scene.enemy) != "f2a078" or scene._actor_color(scene.enemy, true) != "c6a5f5":
		_fail("Actor colors do not match the combatant")
		return
	if scene.player_item1.get_parent().custom_minimum_size != Vector2(144, 144) or scene.player_item1.mouse_entered.get_connections().is_empty():
		_fail("Item frame or tooltip binding missing")
		return
	await _capture("initial")
	var buff: Dictionary = scene._reg.get_spell_by_id("ash_temper")
	scene._execute_spell(scene.player, scene.enemy, buff)
	await scene._flush_steps()
	if float(scene.player.status.atk_boost) <= 0 or scene.player_indicators._feedback.is_empty():
		_fail("Status or transient feedback missing")
		return
	await _capture("status")
	seed(1)
	var attack: Dictionary = scene._reg.get_spell_by_id("cinder_fist")
	var hp_before: int = scene.enemy.hp
	scene._execute_spell(scene.player, scene.enemy, attack)
	var spell_meta := {}
	for step in scene._step_queue:
		var event: Dictionary = step.get("event", {})
		if event.get("spell_id") == "cinder_fist" and event.has("spell_meta"):
			spell_meta = event.get("spell_meta", {})
	await scene._flush_steps()
	if int(scene._highlights.damage) <= 0 or hp_before - int(scene.enemy.hp) != int(scene._highlights.damage) + 1 or not scene.log_box.get_parsed_text().contains("COMBO"):
		_fail("Damage or combo event missing")
		return
	scene._attack_homunculus(scene.player, scene.enemy)
	await scene._flush_steps()
	if not scene.log_box.get_parsed_text().contains("%s (homunculus of %s)" % [scene.player.hom_name, scene.player.name]):
		_fail("Homunculus actor or parent name missing")
		return
	await _capture("exchange")
	scene.log_box.meta_hover_started.emit(spell_meta)
	if not scene.log_box.tooltip_text.contains("Cinder Fist"):
		_fail("Spell hover details missing")
		return
	scene.log_box.meta_clicked.emit(spell_meta)
	if not scene._spell_detail.visible or not scene._spell_detail.dialog_text.contains("Accuracy") or not scene._spell_detail.dialog_text.contains("Recorded damage"):
		_fail("Spell details did not open")
		return
	await _capture("details")
	scene._spell_detail.hide()
	scene._player_wins = 1
	scene.enemy.hp = 0
	scene._handle_battle_end()
	if not scene._battle_over or not scene.next_turn_btn.visible:
		_fail("Match did not finish")
		return
	if not scene._reward_request_id.is_empty() or not scene._verified_combat_match_id.is_empty() or not str(scene._highlights.get("reward_status", "")).contains("verification required"):
		_fail("Offline combat must not claim unverified rewards")
		return
	await _capture("highlights")
	if viewport.size == Vector2i(1280, 720):
		var ordered: Array[int] = []
		var enemy_hp: int = scene.enemy.hp
		scene._log_step("First", func(): ordered.append(1))
		scene._log_step("Second", func(): ordered.append(2))
		await scene._flush_steps()
		if ordered != [1, 2] or scene.enemy.hp != enemy_hp:
			_fail("Log step ordering or state changed")
			return
		for i in 25:
			scene._append_combat_log("Scroll test %d" % i)
		await process_frame
		var scroll: VScrollBar = scene.log_box.get_v_scroll_bar()
		scroll.value = 0
		scene._append_combat_log("Keep manual position")
		await process_frame
		if scroll.value > 1:
			_fail("Manual log scroll was lost")
			return
		var text := RichTextLabel.new()
		scene._log_presenter.append(text, 1, "", {"actor": "[color=red]literal", "verb": " acts.", "actor_color": "69d7e8"})
		if not text.get_parsed_text().contains("[color=red]literal"):
			_fail("Dynamic text was interpreted as markup")
			text.free()
			return
		text.free()
	print("PASS combat event presentation, status, slots, spell details and highlights ", viewport.size)
	scene.queue_free()
	viewport.queue_free()
	timeout.queue_free()
	await process_frame
	quit(0)

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	var path := "%s/%s_%dx%d.png" % [output, name, viewport.size.x, viewport.size.y]
	if image.is_empty() or image.save_png(path) != OK:
		_fail("Capture failed: " + name)

func _fail(message: String) -> void:
	push_error("COMBAT_EVO_FAIL: " + message)
	quit(1)
