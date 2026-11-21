extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var combat = load("res://scenes/Combat.tscn").instantiate()
	combat._load_registry_safe()
	var backend := BackendClient.new()
	combat._combat_backend = backend
	backend.token = "test"
	backend._verified_player_id = "account-a"
	combat._combat_identity = "account-a"
	combat._combat_spell_state = {"player_id":"account-a", "homunculus_progress":{"astralotl":{"owned":true, "level":0, "xp":0}}}
	var build := {"entity_id":"sulfur_01", "homunculus_id":"astralotl", "equip_1":"", "equip_2":""}
	var fighter: Dictionary = combat._build_fighter(build, true)
	assert(fighter.hom_id == "astralotl" and fighter.hom_data.buff_hp == 1 and fighter.hom_data.buff_atk == 1 and fighter.hom_data.buff_def == 1)
	assert(combat._build_fighter(build, false).hom_id == "")
	var target := {"type":"sulfur", "hom_spent":true}
	assert(is_equal_approx(combat._expedition_hom_multiplier(fighter, target), 1.18))
	target.type = "gold"
	assert(is_equal_approx(combat._expedition_hom_multiplier(fighter, target), 0.84))
	target.type = "aether"
	assert(is_equal_approx(combat._expedition_hom_multiplier(fighter, target), 1.0))
	target.type = "sulfur"
	target.spell_neutralize_active = 0.5
	assert(is_equal_approx(combat._expedition_hom_multiplier(fighter, target), 1.09))
	combat.player = fighter
	combat.enemy = combat._build_fighter({"entity_id":"sodium_01", "homunculus_id":"cinder"}, false)
	combat._begin_spell_exchange()
	combat._fire_expedition_passive(combat.player, combat.enemy, "before_attack", {"type":"vitriol"})
	assert(int(combat._passive_modifiers(combat.player).get("power_flat", 0)) == 1)
	combat._end_spell_exchange()
	assert(combat._passive_modifiers(combat.player).is_empty())
	combat._combat_spell_state.homunculus_progress["luny"] = {"owned":true, "level":0, "xp":0}
	build.homunculus_id = "luny"
	combat.player = combat._build_fighter(build, true)
	combat._begin_spell_exchange()
	combat.player.expedition_passive.consecutive_spell_hits = 2
	var tempo_before: float = combat._initiative(combat.player)
	combat._preinitiative_passive(combat.player, combat.enemy, {"kind":"spell", "spell":{"id":"test", "category":"attack", "type":"aether"}})
	assert(is_equal_approx(combat._initiative(combat.player), tempo_before + 1.0))
	combat._end_spell_exchange()
	backend._verified_player_id = "account-b"
	assert(combat._build_fighter(build, true).hom_id == "")
	backend.free()
	combat._reg.free()
	combat.free()
	print("EXPEDITION_COMBAT_CATALOG_PASS")
	quit(0)
