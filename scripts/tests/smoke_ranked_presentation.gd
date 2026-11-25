extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	SceneRouter._ranked_context = {"match_id": "smoke"}
	var combat = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(combat)
	await process_frame
	var ranked = combat._ranked_controller
	ranked.set_process(false)
	var fighter := {"entity_id":"", "name":"Fighter", "display_name":"Fighter", "hp":100, "max_hp":100, "status":{}, "weapon_ids":[], "spell_ids":[]}
	var snapshot := {"match_id":"smoke", "status":"ACTIVE", "combat_revision":0, "turn":0, "battle_index":1, "player":fighter.duplicate(true), "enemy":fighter.duplicate(true), "ready":{}, "score":{}, "events":[], "chat":[]}
	ranked.state = snapshot.duplicate(true)
	ranked._render()
	if not (combat.player_hp.value == 100 and combat.enemy_hp.value == 100):
		push_error("Ranked presentation assertion failed at original line 17")
		quit(1)
		return
	var events := [
		{"id":1,"turn":1,"kind":"damage","category":"damage","actor":"player","target":"enemy","verb":" FIRST", "damage":30,"hp":70},
		{"id":2,"turn":1,"kind":"reflect","category":"damage","actor":"enemy","target":"player","verb":" REFLECT", "damage":10,"hp":90},
		{"id":3,"turn":1,"kind":"status_applied","category":"debuff","actor":"player","target":"enemy", "verb":" STATUS"},
		{"id":4,"turn":2,"kind":"damage","category":"damage","actor":"player","target":"enemy","verb":" SECOND", "damage":20,"hp":50}]
	snapshot.player.hp = 90
	snapshot.enemy.hp = 50
	snapshot.turn = 2
	snapshot.events = events
	ranked.state = snapshot.duplicate(true)
	ranked._render()
	ranked._render()
	if not (ranked.event_queue.size() == 4):
		push_error("Ranked presentation assertion failed at original line 30")
		quit(1)
		return
	ranked.next_poll = 1000
	ranked._process(0.01)
	if not (combat.enemy_hp.value == 100 and ranked.event_queue.size() == 3):
		push_error("Ranked presentation assertion failed at original line 33")
		quit(1)
		return
	ranked._process(0.3)
	if not (combat.enemy_hp.value > 70 and combat.enemy_hp.value < 100):
		push_error("Ranked presentation assertion failed at original line 35")
		quit(1)
		return
	var midpoint: float = combat.enemy_hp.value
	ranked._render()
	if not (is_equal_approx(combat.enemy_hp.value, midpoint)):
		push_error("Ranked presentation assertion failed at original line 38")
		quit(1)
		return
	ranked._on_auth_changed("")
	if not (ranked.event_queue.size() == 3 and ranked.event_presenting):
		push_error("Ranked presentation assertion failed at original line 40")
		quit(1)
		return
	ranked.state = snapshot.duplicate(true)
	ranked._render()
	if not (ranked.event_queue.size() == 3):
		push_error("Ranked presentation assertion failed at original line 43")
		quit(1)
		return
	ranked._process(0.31)
	if not (combat.enemy_hp.value == 70 and combat.player_hp.value == 100):
		push_error("Ranked presentation assertion failed at original line 45")
		quit(1)
		return
	ranked._process(0.4)
	if not (ranked.event_queue.size() == 2 and combat.player_hp.value == 100):
		push_error("Ranked presentation assertion failed at original line 47")
		quit(1)
		return
	ranked._process(0.6)
	if not (combat.player_hp.value == 90):
		push_error("Ranked presentation assertion failed at original line 49")
		quit(1)
		return
	ranked._process(0.4)
	if not (ranked.event_queue.size() == 1):
		push_error("Ranked presentation assertion failed at original line 51")
		quit(1)
		return
	if not (combat.log_box.get_parsed_text().find("STATUS") >= 0):
		push_error("Ranked presentation assertion failed at original line 52")
		quit(1)
		return
	snapshot.status = "FINISHED"
	snapshot.result = {"result":"win", "mp_delta":1}
	snapshot.enemy.hp = 0
	snapshot.events = events + [{"id":5,"turn":2,"kind":"damage","category":"damage","actor":"player","target":"enemy","verb":" FINAL", "hp":0,"damage":50}, {"id":6,"turn":2,"kind":"battle_result"}, {"id":7,"turn":2,"kind":"match_result"}]
	ranked.state = snapshot.duplicate(true)
	ranked._render()
	if not (not ranked.result_popup_shown and combat.enemy_hp.value == 70):
		push_error("Ranked presentation assertion failed at original line 59")
		quit(1)
		return
	ranked._process(1.25)
	if not (combat.enemy_hp.value == 70 and ranked.event_queue.size() == 3):
		push_error("Ranked presentation assertion failed at original line 61")
		quit(1)
		return
	ranked._process(0.6)
	if not (combat.enemy_hp.value == 50 and not ranked.result_popup_shown):
		push_error("Ranked presentation assertion failed at original line 63")
		quit(1)
		return
	ranked._process(0.4)
	ranked._process(0.3)
	if not (combat.enemy_hp.value > 0 and combat.enemy_hp.value < 50 and not ranked.result_popup_shown):
		push_error("Ranked presentation assertion failed at original line 66")
		quit(1)
		return
	ranked._process(0.3)
	ranked._process(0.4)
	ranked._process(1.0)
	if not (not ranked.result_popup_shown):
		push_error("Ranked presentation assertion failed at original line 70")
		quit(1)
		return
	ranked._process(1.0)
	if not (ranked.result_popup_shown and combat.enemy_hp.value == 0):
		push_error("Ranked presentation assertion failed at original line 72")
		quit(1)
		return
	var log_text: String = combat.log_box.get_parsed_text()
	if not (log_text.find("FIRST") < log_text.find("REFLECT") and log_text.find("REFLECT") < log_text.find("STATUS") and log_text.find("STATUS") < log_text.find("SECOND") and log_text.find("SECOND") < log_text.find("FINAL")):
		push_error("Ranked presentation assertion failed at original line 74")
		quit(1)
		return
	combat.queue_free()
	await process_frame
	var restored = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(restored)
	await process_frame
	var restored_ranked = restored._ranked_controller
	restored_ranked.set_process(false)
	restored_ranked.next_poll = 1000
	restored_ranked.state = snapshot.duplicate(true)
	restored_ranked._render()
	if not (restored.enemy_hp.value == 0 and not restored.next_turn_btn.visible and not restored_ranked.result_popup_shown):
		push_error("Ranked presentation assertion failed at original line 85")
		quit(1)
		return
	restored_ranked._process(0.1)
	restored_ranked._process(0.6)
	if not (restored.enemy_hp.value == 0 and not restored_ranked.result_popup_shown):
		push_error("Ranked presentation assertion failed at original line 88")
		quit(1)
		return
	restored.queue_free()
	await process_frame
	var round_combat = load("res://scenes/Combat.tscn").instantiate()
	root.add_child(round_combat)
	await process_frame
	var round_ranked = round_combat._ranked_controller
	round_ranked.set_process(false)
	round_ranked.next_poll = 1000
	var round_state := snapshot.duplicate(true)
	round_state.status = "ACTIVE"
	round_state.player.hp = 100
	round_state.enemy.hp = 100
	round_state.events = []
	round_ranked.state = round_state.duplicate(true)
	round_ranked._render()
	round_state.enemy.hp = 80
	round_state.events = [{"id":1,"kind":"damage","actor":"player","target":"enemy","hp":0,"damage":100}, {"id":2,"kind":"battle_result"}, {"id":3,"kind":"damage","actor":"player","target":"enemy","hp":80,"damage":20}]
	round_ranked.state = round_state
	round_ranked._render()
	round_ranked._process(0.01)
	round_ranked._process(0.6)
	round_ranked._process(0.4)
	if not (round_combat.enemy_hp.value == 0):
		push_error("Ranked presentation assertion failed at original line 111")
		quit(1)
		return
	round_ranked._process(1.0)
	if not (round_combat.enemy_hp.value == 100):
		push_error("Ranked presentation assertion failed at original line 113")
		quit(1)
		return
	round_ranked._process(0.6)
	if not (round_combat.enemy_hp.value == 80):
		push_error("Ranked presentation assertion failed at original line 115")
		quit(1)
		return
	print("PASS ranked serial playback, polling, reconnect, initial snapshot and terminal result")
	round_combat.queue_free()
	quit(0)

