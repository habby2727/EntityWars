extends SceneTree

const SpellLoadout = preload("res://scripts/domain/spell_loadout.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry := DataRegistry.new()
	var ids := ["septic_echo", "void_purge", "paradox_ledger", "sovereign_hack", "signal_jam", "echo_ambush", "crystal_dividend", "null_quarantine", "gilded_lien", "auric_retort", "caustic_quarantine", "osmotic_rebound", "catalytic_mirror", "toxic_extraction", "pyrolytic_fuse", "scorched_antidote", "overclock_drain", "reactor_feedback", "ashen_patent", "debt_bomb"]
	if registry.spells.size() != 94:
		_fail("Registry did not load 94 spells")
		return
	var debug := FileAccess.open("user://debug.json", FileAccess.WRITE)
	debug.store_string(JSON.stringify({"unlock_all_buildings": true}))
	debug.close()
	var scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var base_player: Dictionary = scene.player.duplicate(true)
	var base_enemy: Dictionary = scene.enemy.duplicate(true)
	for id in ids:
		var spell: Dictionary = registry.get_spell_by_id(id)
		if spell.is_empty() or spell.type != "hybrid":
			_fail("Missing spell " + id)
			return
		for element in spell.eligible_types:
			var entity_id := ""
			for entity in registry.entities.values():
				if entity.type == element:
					entity_id = str(entity.id)
					break
			var learned := {"learned_by_entity": {entity_id: [id]}}
			var initial := SpellLoadout.initial_ids(registry, entity_id)
			if initial.size() != 4 or not SpellLoadout.valid(registry, entity_id, learned, [id, initial[0], initial[1], initial[2]]):
				_fail("Unavailable loadout for " + id + ": " + element)
				return
		var detail: String = preload("res://scripts/ui/spell_presentation.gd").detail(spell, "Learned")
		if detail.length() < 80:
			_fail("Missing detail for " + id)
			return
		var hit := false
		for attempt in 30:
			scene._step_queue.clear()
			scene._strategic_delays.clear()
			scene.player.hp = 1000
			scene.player.max_hp = 1000
			scene.enemy.hp = 1000
			scene.enemy.max_hp = 1000
			scene.player.type = spell.primary_type
			scene.player.spell_cooldowns = {}
			scene.player.status.stun = 0
			scene.player.status.poison = 2
			scene.player.status.shield_pct = 0.3
			scene.player.spell_ward = 0.3
			scene.player.spell_ward_baseline = 0.0
			scene.player.hom_id = "cinder"
			scene.player.hom_spent = false
			scene.player.hom_energy = 0
			scene.enemy.hom_id = "cinder"
			scene.enemy.hom_spent = false
			scene.enemy.hom_energy = 4
			scene.enemy.status.poison = 2
			scene.enemy.status.shield_pct = 0.0
			scene.enemy.status.atk_boost = 0.4
			seed(attempt + 1)
			scene._execute_spell(scene.player, scene.enemy, spell)
			hit = spell.category == "support"
			for step in scene._step_queue:
				if step.event.has("damage"):
					hit = true
			if not hit:
				continue
			for step in scene._step_queue:
				var action: Callable = step.action
				if action.is_valid():
					action.call()
			break
		if not hit:
			_fail("No successful cast: " + id)
			return
		for effect in spell.effects:
			match str(effect.kind):
				"delayed_damage":
					if scene._strategic_delays.is_empty():
						_fail("No delayed damage: " + id)
						return
				"counter_trap":
					if not scene.player.has("strategic_trap"):
						_fail("No trap: " + id)
						return
				"heal_suppression":
					if not scene.enemy.has("strategic_heal_suppression"):
						_fail("No heal suppression: " + id)
						return
				"hom_energy_siphon":
					if scene.player.hom_energy != 2:
						_fail("No energy siphon: " + id)
						return
				"debuff_transfer":
					if scene.player.status.poison != 0:
						_fail("No debuff transfer: " + id)
						return
				"buff_steal":
					if scene.enemy.status.atk_boost != 0:
						_fail("No buff steal: " + id)
						return
				"ward_convert":
					if (id == "gilded_lien" and not is_equal_approx(float(scene.player.get("spell_ward", 0)), 0.08)) or (id != "gilded_lien" and scene.player.has("spell_ward")):
						_fail("Ward not consumed: " + id)
						return
				"cooldown_jam":
					if scene._strategic_jams.is_empty():
						_fail("No cooldown jam: " + id)
						return
	scene.player = base_player
	scene.enemy = base_enemy
	scene.player.type = "sulfur"
	scene.player.atk = 100
	scene.enemy.def = 0
	scene.enemy.hp = 1000
	scene.enemy.max_hp = 1000
	var fuse: Dictionary = registry.get_spell_by_id("pyrolytic_fuse")
	var plain := _strike_damage(scene, fuse, false, false)
	var poisoned := _strike_damage(scene, fuse, true, false)
	var favored := _strike_damage(scene, fuse, false, true)
	if plain <= 0 or poisoned <= plain or favored <= plain or scene._strategic_delays.is_empty():
		_fail("Poison/anomaly combo damage mismatch: %s" % str([plain, poisoned, favored]))
		return
	var delayed := int(scene._strategic_delays[0].amount)
	var hp := int(scene.enemy.hp)
	scene._turn += 1
	scene._end_spell_exchange()
	if int(scene.enemy.hp) != hp - delayed or not scene._strategic_delays.is_empty():
		_fail("Delayed damage did not resolve once")
		return
	scene.player.strategic_trap = {"value": 0.3, "activated_turn": 3, "expires_turn": 5}
	scene._turn = 4
	scene.enemy.hp = 1000
	scene.enemy.max_hp = 1000
	scene._strategic_counter(scene.player, scene.enemy, 100)
	if scene.enemy.hp != 970 or scene.player.has("strategic_trap"):
		_fail("Counter trap did not trigger once")
		return
	scene._strategic_counter(scene.player, scene.enemy, 100)
	if scene.enemy.hp != 970:
		_fail("Counter trap triggered twice")
		return
	scene.player.strategic_heal_suppression = {"expires_turn": 5}
	if scene._strategic_heal(scene.player, 11) != 5:
		_fail("Healing suppression is incorrect")
		return
	scene.player.spell_ward = 0.2
	scene._reset_fighter(scene.player)
	if scene.player.has("strategic_heal_suppression") or scene.player.has("spell_ward"):
		_fail("Strategic effects leaked into a new fight")
		return
	print("PASS: 94 spells; 20 strategic casts; poison/anomaly damage %s" % str([plain, poisoned, favored]))
	scene.queue_free()
	registry.free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _strike_damage(scene, spell: Dictionary, poisoned: bool, favored: bool) -> int:
	scene._step_queue.clear()
	scene._strategic_delays.clear()
	scene.player.spell_cooldowns = {}
	scene.player.status.stun = 0
	scene.enemy.hp = scene.enemy.max_hp
	scene.enemy.status.poison = 2 if poisoned else 0
	scene.enemy.status.vuln_pct = 0
	scene.enemy.status.shield_pct = 0
	scene._physical_anomaly = {"id": "nuclear_fallout", "favored_type": "sulfur", "weakened_type": "gold", "remaining_exchanges": 3, "activated_exchange": scene._turn} if favored else {}
	var damage := 0
	for attempt in 30:
		scene._step_queue.clear()
		scene.player.spell_cooldowns = {}
		seed(attempt + 1)
		scene._execute_spell(scene.player, scene.enemy, spell)
		if scene._step_queue.any(func(step): return step.event.has("damage")):
			break
	for step in scene._step_queue:
		if step.event.has("damage"):
			damage = int(step.event.damage)
		var action: Callable = step.action
		if action.is_valid():
			action.call()
	return damage
