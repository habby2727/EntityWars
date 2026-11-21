extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# This test writes a fake auth file; run only with an isolated user-data root.
	var isolated := OS.get_environment("ENTITYWARS_TEST_USER_ROOT").replace("\\", "/").to_lower()
	assert(not isolated.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(isolated + "/"))
	var auth := FileAccess.open("user://auth.json", FileAccess.WRITE)
	assert(auth != null)
	auth.store_string(JSON.stringify({"token":"practice-smoke-token"}))
	auth.close()
	var account := "practice-smoke-account"
	var state := {"player_id":account, "homunculus_progress":{"astralotl":{"owned":true, "level":0, "xp":0}}, "spell_progress":{}, "item_progress":{}}
	var screen = load("res://scenes/LoadoutGrid.tscn").instantiate()
	root.add_child(screen)
	current_scene = screen
	await process_frame
	await process_frame
	var backend: BackendClient = screen._spell_backend
	assert(backend != null and not backend.token.is_empty())
	backend._verified_player_id = account
	screen._update_hom_ownership({"player_id":account, "homunculus_progress":{}}, backend)
	screen._current_homunculus_id = "astralotl"
	screen._on_play_pressed()
	assert(screen.lbl_build_error.text == screen.tr("LOADOUT_HOM_PENDING"))
	screen._update_hom_ownership(state, backend)
	screen._on_card_picked("homunculus", "astralotl")
	assert(screen._is_combat_hom("astralotl"))
	screen._spell_state = state.duplicate(true)
	screen._spell_synced = true
	screen._set_button_selection(screen.dd_item1, screen._items, "bismuth_talisman")
	screen._set_button_selection(screen.dd_item2, screen._items, "wind_amulet")
	screen._on_play_pressed()
	await process_frame
	await process_frame
	var combat = current_scene
	assert(combat != null and combat.scene_file_path == "res://scenes/Combat.tscn")
	assert(combat._combat_backend != null and not combat._combat_backend.token.is_empty())
	combat._combat_backend._verified_player_id = account
	combat._on_combat_state_updated(state)
	assert(combat._combat_started and combat.player.hom_id == "astralotl")
	assert(combat.player_hom.texture.resource_path == "res://assets/entities/gameplay/homunculus/ingame/1024/astralotl.png")
	assert(not combat.player_entity.flip_h and not combat.player_hom.flip_h and combat.enemy_entity.flip_h and combat.enemy_hom.flip_h)
	var original := [combat.player.atk, combat.player.def, combat.player.max_hp]
	combat._set_active_weapon(combat.player, 2)
	combat._set_active_weapon(combat.player, 1)
	assert([combat.player.atk, combat.player.def, combat.player.max_hp] == original)
	combat.player.type = "aether"
	combat.player.item_fx = {}
	combat.enemy.type = "sodium"
	combat.enemy.hom_spent = true
	combat.enemy.item_fx = {}
	combat.enemy.status.shield_pct = 0.0
	var spell := {"id":"smoke_attack", "name":"Smoke attack", "type":"vitriol", "category":"attack", "accuracy":1.0, "power_mult":2.0, "effects":[]}
	combat._begin_spell_exchange()
	var multiplier: float = combat._spell_multiplier(combat.player, combat.enemy, spell)
	var expected := maxi(1, roundi((int(combat.player.atk) + 1 - int(combat.enemy.def * 0.5)) * multiplier * 2.0))
	var hp_before: int = combat.enemy.hp
	Engine.time_scale = 10.0
	await combat._resolve_spell_action(combat.player, combat.enemy, spell)
	print("SMOKE_ATTACK before=", hp_before, " after=", combat.enemy.hp, " expected_damage=", expected)
	assert(combat.enemy.hp == maxi(0, hp_before - expected))
	assert(combat.player.expedition_passive.attacks_made == 1)
	assert(combat._passive_modifiers(combat.player).is_empty())
	combat._end_spell_exchange()
	combat._combat_spell_state.homunculus_progress["venam"] = {"owned":true, "level":0, "xp":0}
	combat.player = combat._build_fighter({"entity_id":"sulfur_01", "homunculus_id":"venam"}, true)
	combat.player.hp = combat.player.max_hp - 5
	combat.enemy.hp = 2
	combat.enemy.status.poison = 1
	combat.enemy.poison_source = "enemy"
	combat._begin_spell_exchange()
	var venam_hp: int = combat.player.hp
	combat._apply_spell_poison(combat.enemy)
	await combat._flush_steps()
	assert(combat.player.hp == venam_hp)
	combat.enemy.hp = 2
	combat.enemy.status.poison = 1
	combat.enemy.poison_source = "player"
	combat._apply_spell_poison(combat.enemy)
	await combat._flush_steps()
	assert(combat.player.hp == venam_hp + 1)
	combat._end_spell_exchange()
	combat._combat_spell_state.homunculus_progress["nebulynx"] = {"owned":true, "level":0, "xp":0}
	combat.player = combat._build_fighter({"entity_id":"sulfur_01", "homunculus_id":"nebulynx"}, true)
	combat.enemy.hp = combat.enemy.max_hp
	combat._begin_spell_exchange()
	combat._end_spell_exchange()
	combat.player.inspiration_pending = true
	var choice: Dictionary = combat._reg.get_spell_by_id(combat.player.spell_ids[0])
	combat._replace_inspiration_spell(combat.player, choice)
	assert(combat._passive_modifiers(combat.player).is_empty())
	combat._begin_spell_exchange()
	assert(int(combat._passive_modifiers(combat.player).get("power_flat", 0)) == 1)
	assert(int(combat._passive_modifiers(combat.player).get("tempo_flat", 0)) == 1)
	combat._end_spell_exchange()
	Engine.time_scale = 1.0
	print("PRACTICE_EXPEDITION_PASS")
	quit(0)
