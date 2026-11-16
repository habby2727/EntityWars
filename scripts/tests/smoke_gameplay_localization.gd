extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	TranslationServer.set_locale("en")
	var icons = load("res://scripts/ui/combat_status_icons.gd").new()
	root.add_child(icons)
	icons.set_fighter(1, {"status": {"poison": 2}})
	if not icons._get_tooltip(Vector2(49, 2)).contains("Poison: periodic damage") or not icons._get_tooltip(Vector2(1, 2)).contains("Victory 1: earned"):
		_fail("English combat status tooltips")
		return
	var previous_status: Dictionary = icons._previous_status.duplicate(true)
	var queued: int = icons._feedback_queue.size()
	TranslationServer.set_locale("es")
	if not icons._get_tooltip(Vector2(49, 2)).contains("Veneno: daño periódico") or not icons._get_tooltip(Vector2(1, 2)).contains("Victoria 1: conseguida"):
		_fail("Spanish combat status tooltips")
		return
	if icons._previous_status != previous_status or icons._feedback_queue.size() != queued:
		_fail("Changing language must not reapply statuses")
		return
	icons.set_fighter(1, {"status": {"poison": 0}})
	var feedback_deadline: int = icons._feedback_until
	var feedback_count: int = icons._feedback_queue.size()
	TranslationServer.set_locale("en")
	if not icons._feedback.contains("Poison ended"):
		_fail("English status feedback")
		return
	TranslationServer.set_locale("es")
	if not icons._feedback.contains("Veneno terminado") or icons._feedback_until != feedback_deadline or icons._feedback_queue.size() != feedback_count:
		_fail("Changing language must not replay status feedback")
		return
	icons.queue_free()
	var hom = load("res://scripts/ui/combat_hom_status.gd").new()
	root.add_child(hom)
	hom.set_fighter({"hom_name": "Cinder", "hom_energy": 3, "hom_spent": false})
	var inspiration = load("res://scripts/ui/combat_inspiration.gd").new()
	root.add_child(inspiration)
	inspiration.set_fighter({"inspiration": 0})
	TranslationServer.set_locale("en")
	if not hom.tooltip_text.contains("30 HP") or not inspiration.tooltip_text.contains("Repeated types"):
		_fail("English homunculus and inspiration tooltips")
		return
	TranslationServer.set_locale("es")
	if not hom.tooltip_text.contains("30 PV") or not inspiration.tooltip_text.contains("tipos repetidos"):
		_fail("Spanish homunculus and inspiration tooltips")
		return
	hom.queue_free()
	inspiration.queue_free()
	node_added.connect(func(node):
		if node is BackendClient:
			node.base_url = "http://127.0.0.1:1"
			node.auto_dev_login = false)
	change_scene_to_file("res://scenes/ui/TradeHall.tscn")
	await process_frame
	await process_frame
	var trade = current_scene
	var offer := {"id": "fixture", "period": "daily", "pay": {"essence": 5}, "receive": {"core": 1}, "remaining": 1, "max": 2}
	trade._npc_offers = [offer]
	trade._npc_preview = false
	trade._render_npc_offers()
	var offer_label: Label = trade._npc_list.find_child("NPCOfferText", true, false)
	var buy_button: Button = trade._npc_buttons[0]
	var was_disabled := buy_button.disabled
	var was_fetching: bool = trade._npc_fetch_pending
	TranslationServer.set_locale("en")
	if not offer_label.text.contains("5 Essence"):
		_fail("English trade offer")
		return
	TranslationServer.set_locale("es")
	if not offer_label.text.contains("5 Esencia") or buy_button.disabled != was_disabled or trade._npc_fetch_pending != was_fetching or buy_button.get_meta("offer") != offer:
		_fail("Changing language must preserve trade offer and actions")
		return
	change_scene_to_file("res://scenes/Combat.tscn")
	await process_frame
	await process_frame
	var combat = current_scene
	var before: Dictionary = combat._dungeon_session.duplicate(true)
	for action in ["retry", "next_floor", "return"]:
		combat._set_next_turn_action(action)
		TranslationServer.set_locale("en")
		var en_text: String = combat.next_turn_btn.text
		TranslationServer.set_locale("es")
		if combat._next_turn_action != action or combat.next_turn_btn.text == en_text or combat._dungeon_session != before:
			_fail("Changing language must preserve combat button action and session")
			return
	print("PASS gameplay localization status and combat actions")
	quit(0)

func _fail(message: String) -> void:
	push_error("GAMEPLAY_LOCALIZATION_FAIL: " + message)
	quit(1)
