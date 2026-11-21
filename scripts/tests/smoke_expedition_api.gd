extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var token := OS.get_environment("EXPEDITION_TEST_TOKEN")
	var player_id := OS.get_environment("EXPEDITION_TEST_PLAYER")
	var base_url := OS.get_environment("EXPEDITION_TEST_URL")
	assert(not token.is_empty() and not player_id.is_empty() and not base_url.is_empty())
	var gate := root.get_node("ConnectionGate")
	gate.player_id = player_id
	gate.token = token
	gate.base_url = base_url
	gate.state = gate.State.CONNECTED
	SceneRouter._expedition_context = {"player_id": player_id, "loadout": true}
	var loadout = load("res://scenes/LoadoutGrid.tscn").instantiate()
	root.add_child(loadout)
	current_scene = loadout
	await process_frame
	loadout._spell_backend.base_url = base_url
	loadout._spell_backend.token = token
	assert(loadout._spell_backend._verify_identity({"player_id": player_id}))
	loadout._spell_backend.refresh_state()
	for i in 200:
		if loadout._hom_identity == player_id and loadout._spell_synced: break
		await create_timer(0.05).timeout
	assert(loadout._hom_identity == player_id and loadout._spell_synced)
	loadout._current_entity_id = "sulfur_01"
	loadout._current_homunculus_id = "cinder"
	loadout._set_button_selection(loadout.dd_item1, loadout._items, "bismuth_talisman")
	loadout._set_button_selection(loadout.dd_item2, loadout._items, "wind_amulet")
	loadout._on_play_pressed()
	for i in 100:
		await process_frame
		if current_scene != loadout and current_scene != null: break
	var screen = current_scene
	assert(screen != loadout and screen.has_method("_reconcile_pending"))
	screen.backend.base_url = base_url
	screen.backend.token = token
	screen.backend._verified_player_id = player_id
	screen._identity_changed({"player_id": player_id})
	assert(await _wait_for(screen, "explore"))
	var run_id: String = screen.session.run_id
	var selected: Dictionary = screen.session.choices[0]
	var key: String = screen.session.background_key
	screen._select(0)
	var interrupted: Dictionary = screen.pending.duplicate(true)
	assert(await _wait_for(screen, "combat"))
	assert(screen.session.run_id == run_id and int(screen.session.revision) == 2)
	assert(screen.session.combat_state.npc.id == selected.id and screen.session.background_key == key)
	assert(screen.pending.is_empty())
	# A persisted action whose response was lost is reconciled against the
	# advanced server revision without issuing a second selection.
	assert(preload("res://scripts/net/expedition_recovery.gd").save_pending(player_id, "select", interrupted.payload))
	screen.pending = preload("res://scripts/net/expedition_recovery.gd").load_pending(player_id)
	screen._refresh()
	assert(await _wait_for(screen, "combat"))
	assert(int(screen.session.revision) == 2 and screen.pending.is_empty())
	assert(screen.combat_view.weapon_buttons.size() == 2)
	screen.combat_view._switch(2)
	assert(await _wait_revision(screen, 3))
	assert(int(screen.session.combat_state.active_weapon_slot) == 2)
	assert(screen.combat_view.weapon_buttons[1].disabled)
	var cast_id: String = str(screen.session.combat_state.player.spell_ids[0])
	screen.combat_view._cast(cast_id)
	var turn_pending: Dictionary = screen.pending.duplicate(true)
	assert(await _wait_revision(screen, 4))
	assert(int(screen.session.combat_state.turn) == 2)
	assert(not screen.session.get("battle_log", []).is_empty())
	assert(preload("res://scripts/net/expedition_recovery.gd").save_pending(player_id, "turn", turn_pending.payload))
	screen.pending = preload("res://scripts/net/expedition_recovery.gd").load_pending(player_id)
	screen._refresh()
	assert(await _wait_revision(screen, 4))
	assert(screen.pending.is_empty() and int(screen.session.revision) == 4)
	var unsent := {"run_id":run_id, "expected_revision":4, "client_action_id":screen.backend._make_uuid(), "decision":{"turn":3, "switch_slot":1}}
	assert(preload("res://scripts/net/expedition_recovery.gd").save_pending(player_id, "turn", unsent))
	assert(preload("res://scripts/net/expedition_recovery.gd").load_pending(player_id + "-other").is_empty())
	screen.pending = preload("res://scripts/net/expedition_recovery.gd").load_pending(player_id)
	assert(screen.pending.payload.client_action_id == unsent.client_action_id)
	screen._refresh()
	assert(await _wait_revision(screen, 5))
	assert(int(screen.session.combat_state.active_weapon_slot) == 1)
	for choice in ["choose", "decline"]:
		assert(await _fixture(screen, "inspiration"))
		screen._refresh()
		assert(await _wait_for(screen, "state"))
		assert(int(screen.session.combat_state.player.hom_energy) == 3)
		screen.combat_view.hom_attack.button_pressed = true
		var player: Dictionary = screen.session.combat_state.player
		var available := ""
		for spell_id in player.spell_ids:
			if int(player.get("cooldowns", {}).get(spell_id, 0)) == 0: available = str(spell_id); break
		assert(not available.is_empty())
		var revision := int(screen.session.revision)
		screen.combat_view._cast(available)
		assert(await _wait_revision(screen, revision + 1))
		assert(screen.session.combat_state.player.inspiration_pending)
		assert(screen.combat_view.inspiration_buttons.size() == 3)
		assert(screen.session.battle_log.any(func(event): return event.kind in ["hom_attack", "hom_miss", "status_consumed"]))
		var offer: String = str(screen.session.combat_state.player.inspiration_offers[0])
		if choice == "choose": screen.combat_view.inspiration_buttons[0].pressed.emit()
		else: screen.combat_view.decline_button.pressed.emit()
		assert(await _wait_revision(screen, revision + 2))
		assert(not screen.session.combat_state.player.inspiration_pending)
		if choice == "choose": assert(offer in screen.session.combat_state.player.spell_ids)
	screen.queue_free()
	await process_frame
	var resumed = load("res://scenes/ui/Expeditions.tscn").instantiate()
	root.add_child(resumed)
	await process_frame
	resumed.backend.base_url = base_url
	resumed.backend.token = token
	resumed.backend._verified_player_id = player_id
	resumed._identity_changed({"player_id": player_id})
	assert(await _wait_for(resumed, "state"))
	assert(not resumed.resumed and resumed.session.run_id == run_id and resumed.session.phase == "COMBAT")
	resumed.resumed = true
	resumed._render()
	assert(await _fixture(resumed, "loss"))
	resumed._refresh()
	assert(await _wait_for(resumed, "state"))
	var terminal_pending := {}
	for attempt in 5:
		var revision := int(resumed.session.revision)
		var slot := 1 if int(resumed.session.combat_state.active_weapon_slot) == 2 else 2
		resumed.combat_view._switch(slot)
		terminal_pending = resumed.pending.duplicate(true)
		var completed := await _wait_revision(resumed, revision + 1)
		if not completed: print("LOSS_TEST_WAIT ", resumed.session.get("revision"), " ", resumed.session.get("phase"), " pending=", resumed.pending, " request=", resumed.request, " error=", resumed.message.text, " gate=", gate.state)
		assert(completed)
		if resumed.session.phase == "LOSS": break
	assert(resumed.session.phase == "LOSS")
	assert(preload("res://scripts/net/expedition_recovery.gd").save_pending(player_id, "turn", terminal_pending.payload))
	resumed.queue_free()
	await process_frame
	var recovered = load("res://scenes/ui/Expeditions.tscn").instantiate()
	root.add_child(recovered)
	await process_frame
	recovered.backend.base_url = base_url
	recovered.backend.token = token
	recovered.backend._verified_player_id = player_id
	recovered._identity_changed({"player_id": player_id})
	for i in 200:
		if recovered.session.get("phase") == "LOSS" and recovered.pending.is_empty(): break
		await create_timer(0.05).timeout
	assert(recovered.session.get("phase") == "LOSS" and recovered.pending.is_empty())
	recovered._auth_changed("")
	assert(recovered.session.is_empty() and recovered.account_id.is_empty())
	recovered.queue_free()
	await process_frame
	print("EXPEDITION_REAL_API_PASS")
	quit()

func _wait_for(screen: Control, target: String) -> bool:
	for i in 200:
		await create_timer(0.05).timeout
		if target == "state" and not screen.state_data.is_empty() and screen.request.is_empty(): return true
		if target == "explore" and str(screen.session.get("phase", "")) == "EXPLORE" and screen.pending.is_empty(): return true
		if target == "combat" and str(screen.session.get("phase", "")) == "COMBAT" and screen.pending.is_empty(): return true
	return false

func _wait_revision(screen: Control, revision: int) -> bool:
	for i in 300:
		await create_timer(0.05).timeout
		if int(screen.session.get("revision", 0)) == revision and screen.pending.is_empty() and not screen.playing_events: return true
	return false

func _fixture(screen: Control, kind: String) -> bool:
	var dir := OS.get_environment("EXPEDITION_FIXTURE_DIR").replace("\\", "/")
	var done := dir.path_join("fixture-done")
	if FileAccess.file_exists(done): DirAccess.remove_absolute(done)
	var file := FileAccess.open(dir.path_join("fixture-request.json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"kind":kind, "run_id":screen.session.run_id}))
	file.close()
	for i in 200:
		await create_timer(0.05).timeout
		if FileAccess.file_exists(done): return true
	return false
