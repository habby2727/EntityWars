extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("INSPIRATION_FAIL: " + message)
		quit(1)
		assert(false, message)

func _cast(scene: Node, caster: Dictionary, target: Dictionary, effects: Array, accuracy: float = 1.0) -> void:
	var spell := {"id": "test_spell", "name": "Test", "type": caster.type, "category": "support", "power_mult": 0.0, "accuracy": accuracy, "cooldown_turns": 0, "effects": effects}
	scene._execute_spell(caster, target, spell)
	await scene._flush_steps()

func _run() -> void:
	var output := OS.get_environment("INSPIRATION_TEST_DIR").replace("\\", "/")
	if output.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(output.to_lower() + "/"):
		quit(1)
		return
	Engine.time_scale = 20.0
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	var scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var player: Dictionary = scene.player
	var enemy: Dictionary = scene.enemy
	var poison := {"kind": "poison", "value": 2, "target": "enemy"}
	var vuln := {"kind": "vuln", "value": 0.12, "target": "enemy"}
	await _cast(scene, player, enemy, [poison])
	_check(player.inspiration == 1, "first poison")
	await _cast(scene, player, enemy, [poison])
	_check(player.inspiration == 1, "unchanged status")
	enemy.status.poison = 1
	await _cast(scene, player, enemy, [poison])
	enemy.status.poison = 1
	await _cast(scene, player, enemy, [poison])
	_check(player.inspiration == 3 and player.inspiration_pending, "three poison applications")
	await _cast(scene, player, enemy, [vuln])
	_check(player.inspiration == 3, "cap")
	scene._restore_inspiration(player)
	enemy.status.poison = 0
	enemy.status.vuln_pct = 0
	await _cast(scene, player, enemy, [poison])
	enemy.status.poison = 1
	await _cast(scene, player, enemy, [poison, vuln])
	_check(player.inspiration == 3, "repeated poison and multi-status")
	scene._restore_inspiration(player)
	enemy.status.poison = 0
	enemy.status.vuln_pct = 0
	await _cast(scene, player, enemy, [poison, vuln])
	_check(player.inspiration == 2, "two statuses in one spell")
	scene._restore_inspiration(player)
	player.inspiration = 2
	player.hp = player.max_hp
	enemy.hp = enemy.max_hp
	enemy.status.poison = 0
	var turn_before_exchange: int = scene._turn
	var trigger := {"id": "trigger_test", "name": "Trigger", "type": player.type, "category": "support", "power_mult": 0.0, "accuracy": 1.0, "cooldown_turns": 0, "effects": [poison]}
	await scene._start_weapon_exchange({"kind": "spell", "spell": trigger, "hom": "hold"})
	_check(scene._turn == turn_before_exchange + 1 and not scene._processing_steps and not scene._resolving_exchange and scene._inspiration_panel.visible, "selection after completed exchange")
	scene._choose_inspiration(0)
	scene._restore_inspiration(player)
	enemy.status.poison = 0
	await _cast(scene, player, enemy, [poison], 0.0)
	await _cast(scene, player, enemy, [{"kind": "poison", "value": 2, "target": "self"}])
	scene._apply_spell_poison(player)
	await scene._flush_steps()
	_check(player.inspiration == 0, "miss, self or tick awarded inspiration")
	var old_evasion: float = float(enemy.item_fx.evasion_pct)
	enemy.item_fx.evasion_pct = 1.0
	var resisted := {"id": "resisted_test", "name": "Resisted", "type": player.type, "category": "attack", "power_mult": 1.0, "accuracy": 1.0, "cooldown_turns": 0, "effects": [poison]}
	scene._execute_spell(player, enemy, resisted)
	await scene._flush_steps()
	enemy.item_fx.evasion_pct = old_evasion
	scene._attack_homunculus(player, enemy)
	await scene._flush_steps()
	_check(player.inspiration == 0, "evasion or homunculus awarded inspiration")
	player.status.poison = 0
	enemy.status.hom_stun = 0
	enemy.status.tempo_bonus = 0
	await _cast(scene, player, enemy, [{"kind": "hom_stun", "value": 1, "target": "enemy"}, {"kind": "tempo_shift", "value": -2, "target": "enemy"}])
	_check(player.inspiration == 2, "homunculus stun and negative tempo")
	await _cast(scene, player, enemy, [{"kind": "tempo_shift", "value": -1, "target": "enemy"}])
	_check(player.inspiration == 2, "weaker tempo awarded inspiration")
	scene._restore_inspiration(player)
	for element in ["sulfur", "mercury", "sodium", "aether", "vitriol", "gold"]:
		var equipped: Array = []
		for spell in scene._reg.get_spells_for_type(element):
			equipped.append(spell.id)
		var options: Array = scene._inspiration_candidates({"type": element, "spell_ids": equipped})
		_check(options.size() == 3, "candidate count for " + element)
		for option in options:
			_check(option.type == element or (option.type == "hybrid" and option.primary_type == element), "secondary-only hybrid")
	var candidates: Array = scene._inspiration_candidates(player)
	_check(candidates.size() == 3, "candidate count")
	var seen := {}
	for candidate in candidates:
		_check(not seen.has(candidate.id) and candidate.id not in player.spell_ids, "duplicate candidate")
		_check(candidate.type == player.type or (candidate.type == "hybrid" and candidate.primary_type == player.type), "invalid primary type")
		seen[candidate.id] = true
	var original: Array = player.spell_ids.duplicate()
	var progression := JSON.stringify(scene._combat_spell_state)
	player.spell_cooldowns = {"existing": 2}
	player.inspiration = 3
	player.inspiration_pending = true
	var turn: int = scene._turn
	scene._processing_steps = true
	scene._finish_inspiration_exchange()
	_check(not scene._inspiration_panel.visible, "opened during steps")
	scene._processing_steps = false
	scene._finish_inspiration_exchange()
	_check(scene._inspiration_panel.visible and scene._inspiration_options.size() == 3, "selection panel")
	_check(scene._player_inspiration.tooltip_text.contains("Repeated types"), "indicator tooltip")
	var cancel: Button = scene._inspiration_panel.get_node("Content/Cancel")
	_check(cancel.visible and cancel.pressed.is_connected(Callable(scene, "_on_inspiration_cancel")), "cancel button")
	var originals: Array = player.original_spell_ids.duplicate()
	cancel.pressed.emit()
	_check(not scene._inspiration_panel.visible and scene._inspiration_options.is_empty() and player.inspiration == 0 and player.inspiration_used_this_battle and not player.inspiration_pending, "cancel state")
	_check(player.spell_ids == original and player.original_spell_ids == originals and player.temporary_spell_id == "" and player.temporary_replaced_slot == -1, "cancel changed spells")
	_check(player.spell_cooldowns.existing == 2 and scene._turn == turn and JSON.stringify(scene._combat_spell_state) == progression and scene._player_inspiration._used, "cancel changed turn, cooldown or progression")
	scene._award_inspiration(player, enemy, "poison")
	scene._finish_inspiration_exchange()
	_check(player.inspiration == 0 and not scene._inspiration_panel.visible, "cancel reopened in same battle")
	scene._reset_fighter(player)
	_check(not player.inspiration_used_this_battle, "next battle did not reset inspiration")
	player.spell_cooldowns = {"existing": 2}
	player.inspiration = 3
	player.inspiration_pending = true
	scene._finish_inspiration_exchange()
	scene._choose_inspiration(0)
	_check(not scene._inspiration_panel.visible and player.inspiration_used_this_battle and scene._turn == turn, "redemption costs turn")
	_check(player.spell_cooldowns.existing == 2 and JSON.stringify(scene._combat_spell_state) == progression, "cooldowns or progression changed")
	var changed := 0
	for i in 4:
		if player.spell_ids[i] != original[i]:
			changed += 1
	_check(changed == 1 and not str(player.temporary_spell_id).is_empty(), "replacement slots")
	var selected: String = player.temporary_spell_id
	scene._choose_inspiration(1)
	_check(player.temporary_spell_id == selected, "double selection")
	var temporary: Dictionary = scene._reg.get_spell_by_id(selected)
	scene._execute_spell(player, enemy, temporary)
	await scene._flush_steps()
	_check(scene._highlights.has("inspiration_spell"), "temporary spell not used")
	scene._restore_inspiration(player)
	_check(player.spell_ids == original and player.inspiration == 0 and not player.inspiration_used_this_battle, "restoration")
	enemy.status.poison = 0
	player.status.poison = 0
	await _cast(scene, enemy, player, [poison, vuln])
	_check(enemy.inspiration == 2, "npc application")
	enemy.inspiration = 3
	enemy.inspiration_pending = true
	var enemy_original: Array = enemy.spell_ids.duplicate()
	scene._finish_inspiration_exchange()
	_check(enemy.inspiration_used_this_battle and enemy.spell_ids != enemy_original, "npc selection")
	scene._reset_fighter(enemy)
	_check(enemy.spell_ids == enemy_original and not enemy.inspiration_used_this_battle, "npc battle reset")
	player.inspiration = 3
	player.inspiration_pending = true
	scene._replace_inspiration_spell(player, scene._inspiration_candidates(player)[0])
	scene._player_wins = 1
	enemy.hp = 0
	scene._handle_battle_end()
	_check(player.spell_ids == original and player.temporary_spell_id == "" and not scene._inspiration_panel.visible, "match end restoration")
	scene._battle_over = false
	enemy.hp = enemy.max_hp
	player.inspiration = 3
	player.inspiration_pending = true
	scene._replace_inspiration_spell(player, scene._inspiration_candidates(player)[0])
	scene._combat_identity = "test-player"
	scene._on_combat_state_updated({})
	_check(scene._combat_session_invalid and player.spell_ids == original and player.temporary_spell_id == "", "invalid session restoration")
	print("PASS inspiration application, eligibility, selection, restoration and NPC")
	scene.queue_free()
	await process_frame
	quit(0)
