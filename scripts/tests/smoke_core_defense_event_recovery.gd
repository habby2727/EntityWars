extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.player_id = "event-test"
	gate.token = "test"
	gate.base_url = "https://example.invalid"
	var arena = load("res://scripts/ui/woe_arena.gd").new()
	root.add_child(arena)
	arena._is_cd = true
	arena._client = root.get_node("CoreDefenseClient")
	arena._build()
	arena._match_id = "event-match"
	arena._cards = {"neon":{"cost":2,"element":"mercury"}}
	var snapshot := {"kind":"core_defense","mode":"solo","tick":100,"wave":1,"players":[{"id":"event-test","team":"blue","slots":["neon"],"zeal":5}],"units":[{"id":1,"cardId":"neon","team":"blue","x":100,"y":100,"hp":10,"maxHp":10}],"laboratories":[],"result":null}
	arena._accept_state({"match_id":"event-match","revision":1,"snapshot":snapshot,"latest_event_seq":0,"events":[]}, true)
	var attack := {"seq":1,"tick":91,"type":"attack","attacker":1,"target":2,"cardId":"neon","team":"blue","position":{"x":100,"y":100},"targetPosition":{"x":150,"y":100},"damage":4}
	var later := attack.duplicate(true)
	later.seq = 2
	later.tick = 99
	arena._accept_state({"match_id":"event-match","revision":2,"snapshot":snapshot,"events":[attack,later]}, true)
	assert(arena._cursor == 2 and arena._effects.effects.size() == 6)
	arena._accept_state({"match_id":"event-match","revision":2,"snapshot":snapshot,"events":[attack,later]}, true)
	assert(arena._effects.effects.size() == 6)
	arena._units[1].strike_time = 0.0
	var unrelated := attack.duplicate(true)
	unrelated.seq = 3
	unrelated.cardId = "luny"
	arena._accept_state({"match_id":"event-match","revision":3,"snapshot":snapshot,"events":[unrelated]}, true)
	assert(arena._units[1].strike_time == 0.0)
	arena._playback_ready = false
	var backlog := attack.duplicate(true)
	backlog.seq = 4
	var before: int = arena._effects.effects.size()
	arena._accept_state({"match_id":"event-match","revision":3,"snapshot":snapshot,"latest_event_seq":4,"events":[backlog]}, true)
	assert(arena._cursor == 4 and arena._effects.effects.size() == before)
	var death := {"seq":5,"tick":91,"type":"death","target":99,"targetKind":"unit","victimAssetId":"noxiris","victimKind":"enemy","victimTeam":"red","victimPosition":{"x":160,"y":100},"victimElement":"mercury"}
	arena._accept_state({"match_id":"event-match","revision":4,"snapshot":snapshot,"events":[death]}, true)
	assert(arena._cursor == 5 and arena._corpses.size() == 1)
	arena._action_kind = "match/deploy"
	arena._finish_action({"code":200,"data":{"accepted":true,"match_id":"event-match","revision":10}})
	assert(arena._awaiting_deploy_state and arena._deploy_receipt_revision == 10 and arena._buttons[0].disabled)
	# A concurrent poll can already contain the committed action before its receipt arrives.
	arena._revision = 12
	arena._poll = 0.25
	arena._action_kind = "match/deploy"
	arena._finish_action({"code":200,"data":{"accepted":true,"match_id":"event-match","revision":10}})
	assert(not arena._awaiting_deploy_state and arena._deploy_receipt_revision == -1 and is_equal_approx(arena._poll, 0.25))
	print("CORE_DEFENSE_EVENT_RECOVERY_PASS")
	quit(0)
