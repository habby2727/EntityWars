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
	resumed._auth_changed("")
	assert(resumed.session.is_empty() and resumed.account_id.is_empty())
	resumed.queue_free()
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
