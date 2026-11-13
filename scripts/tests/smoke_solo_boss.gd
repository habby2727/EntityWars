extends SceneTree

var scene: Control

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)
	print("PASS: " + message)

func _run() -> void:
	var isolation := OS.get_environment("WG_QA_ROOT").replace("\\", "/").to_lower()
	_check(not isolation.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(isolation + "/"), "isolated user directory")
	var flags := FileAccess.open("user://debug.json", FileAccess.WRITE)
	flags.store_string(JSON.stringify({"unlock_all_buildings": true}))
	flags.close()
	Engine.time_scale = 100.0
	scene = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene._combat_started and not scene._solo_boss_mode, "normal combat initializes without boss state")
	var assets := AssetCatalog.new()
	for texture_id in ["boss_common", "boss_colossus", "boss_leviathan", "tier3boss", "boss_temporal", "ghost_boss", "summoned-boss"]:
		_check(assets.has(texture_id) and assets.get_tex(texture_id) != null, "texture resolves: " + texture_id)
	assets.free()
	for tier in ["common", "mythic", "rare", "epic", "legendary"]:
		scene._solo_boss_mode = false
		scene._solo_def = {}
		scene._solo_context = {"hunt_id": "hunt_" + tier, "rotation_key": 1}
		scene._setup_enemy()
		_check(scene._setup_solo_boss(), tier + " loads")
		if tier == "legendary":
			_check(scene._solo_texture.resource_path.ends_with("ghost_boss.png"), "legendary uses ghost boss")
		if tier == "rare":
			var variants: Array = scene._solo_def.texture_variants
			var selected: String = variants[int(scene._solo_context.rotation_key) % variants.size()]
			scene._solo_context.display_texture_id = selected
			_check(scene._setup_solo_boss() and scene._solo_texture.resource_path.ends_with("tier3boss.png"), "rare rotation appearance reaches combat")
			scene._solo_context.display_texture_id = "ghost_boss"
			_check(scene._setup_solo_boss() and scene._solo_texture.resource_path.ends_with("corrupted_energy_leviathan.png"), "invalid appearance falls back")
		if tier != "common":
			_check(scene._solo_minion_texture != null and scene._solo_minion_texture.resource_path.ends_with("summoned-boss.png"), tier + " minion portrait")
		var max_hp: int = scene.enemy.max_hp
		var atk: int = scene.enemy.atk
		scene._apply_mods(scene.enemy)
		_check(scene.enemy.max_hp == max_hp and scene.enemy.atk == atk, tier + " retains scaling")
		scene._solo_minions.clear()
		scene._solo_summoned = false
		scene._solo_actions = 2
		scene._prepare_solo_intent()
		_check(scene._solo_intent == ("Strike" if tier == "common" else "Summon"), tier + " summon intent")
		if tier != "common":
			scene._solo_summon()
			_check(scene._solo_minions.size() == (1 if tier == "mythic" else 2), tier + " minion count")
			var hp: int = scene.enemy.hp
			_check(not scene._attack_entity(scene.player, scene.enemy) and scene.enemy.hp == hp, tier + " boss protected")
			scene._prepare_solo_intent()
			_check(scene._solo_intent == "Strike", tier + " no repeated summon")
	var spell: Dictionary = scene._reg.get_spell_by_id("ash_temper")
	for tier in ["common", "legendary"]:
		for boss_first in [false, true]:
			scene._solo_boss_mode = false
			scene._solo_def = {}
			scene._solo_context = {"hunt_id": "hunt_" + tier, "rotation_key": 1}
			scene._setup_enemy()
			_check(scene._setup_solo_boss(), tier + " shield fixture")
			scene._solo_minions.clear()
			scene._solo_shield_turns = 0
			scene._solo_shield_cooldown = 0
			scene._solo_intent = "Shield"
			scene.player.hp = scene.player.max_hp
			scene.player.status.tempo_bonus = -100.0 if boss_first else 100.0
			scene.enemy.hp = scene.enemy.max_hp - 1
			await scene._resolve_solo_exchange({"kind": "spell", "spell": spell, "hom": "hold"})
			_check(scene._solo_shield_turns == int(scene._solo_def.shield_turns), tier + " shield survives activation exchange, boss first=" + str(boss_first))
			scene._solo_intent = "Strike"
			scene.player.hp = scene.player.max_hp
			await scene._resolve_solo_exchange({"kind": "switch", "slot": 1, "hom": "hold"})
			_check(scene._solo_shield_turns == int(scene._solo_def.shield_turns) - 1, tier + " shield expires after full exchange")
	# A killed target must not redirect a homunculus strike to another minion.
	scene._solo_minions.clear()
	scene._solo_summon()
	scene._solo_minions[0].hp = 1
	scene._solo_target_index = 0
	scene.player.hom_spent = false
	scene.player.hom_energy = 6
	scene.player.atk = 100
	var second_hp: int = scene._solo_minions[1].hp
	var attack: Dictionary = scene._reg.get_spell_by_id("cinder_fist").duplicate(true)
	attack.accuracy = 1.0
	seed(1)
	await scene._solo_player_action({"kind": "spell", "spell": attack, "hom": "attack"})
	_check(scene._solo_minions[0].hp == 0 and scene._solo_minions[1].hp == second_hp and scene.player.hom_energy == 6, "homunculus does not retarget after kill")
	scene._solo_minions.clear()
	scene._solo_summoned = false
	scene._solo_intent = "Summon"
	scene.enemy.status.stun = 0
	scene.player.hp = 10000
	scene.player.max_hp = 10000
	scene.player.status.tempo_bonus = -100.0
	var log_before: String = scene.log_box.get_parsed_text()
	await scene._resolve_solo_exchange({"kind": "switch", "slot": 1, "hom": "hold"})
	var log_after: String = scene.log_box.get_parsed_text().substr(log_before.length())
	_check(scene._solo_minions.size() == 2 and not log_after.contains("Minion 1") and not log_after.contains("Minion 2"), "summoned minions wait until next exchange")
	scene._solo_intent = "Strike"
	log_before = scene.log_box.get_parsed_text()
	await scene._resolve_solo_exchange({"kind": "switch", "slot": 1, "hom": "hold"})
	log_after = scene.log_box.get_parsed_text().substr(log_before.length())
	_check(log_after.count("Minion 1") == 1 and log_after.count("Minion 2") == 1, "living minions act once each")
	scene._solo_minions.clear()
	scene._solo_intent = "Special"
	scene.enemy.spell_cooldowns.clear()
	scene.enemy.status.stun = 0
	await scene._solo_boss_action()
	_check(int(scene.enemy.spell_cooldowns.get(scene._solo_signature.id, -1)) == int(scene._solo_signature.cooldown_turns), "signature uses spell cooldown")
	scene._solo_intent = "Shield"
	scene._update_ui()
	_check(scene._solo_intent == "Shield", "UI refresh does not change boss intent")
	scene._solo_summon()
	scene.enemy.hp = 0
	scene._battle_over = false
	scene._check_end()
	_check(not scene._battle_over, "no victory while minions survive")
	scene._solo_minions.clear()
	scene._check_end()
	var events_after_win: int = scene._solo_events.size()
	scene._check_end()
	_check(scene._battle_over and scene._solo_events.size() == events_after_win and scene._reward_request_id.is_empty() and scene._verified_combat_match_id.is_empty(), "victory ends once without verified rewards")
	print("PASS: solo boss focused smoke")
	quit(0)
