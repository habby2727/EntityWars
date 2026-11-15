extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := DataRegistry.new()
	if registry.spells.size() != 94:
		push_error("Expected 94 validated spells; got %d" % registry.spells.size())
		quit(1)
		return
	var debug := FileAccess.open("user://debug.json", FileAccess.WRITE)
	debug.store_string(JSON.stringify({"unlock_all_buildings": true}))
	debug.close()
	var scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var ids := ["toxic_smog", "nuclear_fallout", "quicksilver_tempest", "cryosalt_squall", "vacuum_shear", "aureate_eclipse", "corrosive_rain", "plasma_tide", "quantum_static", "crystalline_dawn"]
	for id in ids:
		var spell: Dictionary = registry.spells.get(id, {})
		if spell.is_empty() or not scene._execute_spell(scene.player, scene.enemy, spell):
			push_error("Unable to cast " + id)
			quit(1)
			return
		for step in scene._step_queue:
			var action: Callable = step.action
			if action.is_valid():
				action.call()
		scene._step_queue.clear()
		if scene._physical_anomaly.get("id") != id:
			push_error("Anomaly did not activate: " + id)
			quit(1)
			return
		scene._end_spell_exchange()
		if scene._physical_anomaly.get("remaining_exchanges") != 3:
			push_error("Anomaly expired during casting exchange")
			quit(1)
			return
		for remaining in [2, 1, 0]:
			scene._turn += 1
			scene._end_spell_exchange()
			if remaining > 0 and scene._physical_anomaly.get("remaining_exchanges") != remaining:
				push_error("Incorrect anomaly duration")
				quit(1)
				return
		if not scene._physical_anomaly.is_empty():
			push_error("Anomaly did not expire")
			quit(1)
			return
	var kind := str(scene.player.type)
	var baseline := _damage(scene, {}, true)
	var favored := _damage(scene, {"favored_type": kind, "weakened_type": "other"}, true)
	var weakened := _damage(scene, {"favored_type": "other", "weakened_type": kind}, true)
	var indirect := _damage(scene, {"favored_type": kind, "weakened_type": "other"}, false)
	var indirect_base := _damage(scene, {}, false)
	if baseline <= 0 or favored <= baseline or weakened >= baseline or indirect != indirect_base:
		push_error("Wrong direct or indirect damage: %s" % str([baseline, favored, weakened, indirect_base, indirect]))
		quit(1)
		return
	print("PASS: 94 spells; 10 anomaly casts and expiration; damage %s" % str([baseline, favored, weakened]))
	scene.queue_free()
	registry.free()
	await process_frame
	quit(0)

func _damage(scene, anomaly: Dictionary, spell_attack: bool) -> int:
	scene._step_queue.clear()
	scene._physical_anomaly = anomaly
	seed(12345)
	var context := {"spell": scene._reg.spells.get("cinder_fist", {}), "actual_damage": 0} if spell_attack else {}
	scene._attack_entity(scene.player, scene.enemy, 1.0, 1.0, spell_attack, context)
	for step in scene._step_queue:
		if step.event.has("damage"):
			return int(step.event.damage)
	return 0
