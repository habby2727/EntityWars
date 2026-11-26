extends SceneTree

const FOREST := "res://scenes/forest/ForestWorld.tscn"
const PREGAME := "res://scenes/ui/CoreDefensePregame.tscn"
const ARENA := "res://scenes/ui/WOEArena.tscn"
var role := 0
var sync_dir := ""
var cd: Node

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, what: String) -> bool:
	if not value: push_error("CORE_DEFENSE_E2E role=%d: %s" % [role, what])
	return value

func wait_for(test: Callable, seconds: float = 15.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if test.call(): return true
		await create_timer(0.05).timeout
	return false

func signal_file(name: String, content: String = "ok") -> void:
	var file := FileAccess.open(sync_dir.path_join(name), FileAccess.WRITE)
	file.store_string(content)
	file.close()

func wait_file(name: String) -> bool:
	return await wait_for(func(): return FileAccess.file_exists(sync_dir.path_join(name)), 35.0)

func scene_is(path: String) -> bool:
	return is_instance_valid(current_scene) and current_scene.scene_file_path == path

func walk(world: Node, target: Vector2) -> bool:
	while world._player.position.distance_to(target) > 1.0:
		await create_timer(0.36).timeout
		var point: Vector2 = world._player.position.move_toward(target,65.0)
		world._player.position = point
		if not world._presence.move(point,0,true): return false
	return true

func portal(world: Node, direction: String, crossing: Vector2, next: String) -> bool:
	await create_timer(0.36).timeout
	if not world._presence.portal(direction,crossing,world._player.position,0): return false
	return await wait_for(func(): return world._presence.zone_id == next, 5.0)

func open_browser(world: Node) -> bool:
	if not await wait_for(func(): return not world._player.transition_locked,5.0): return false
	world._interact_nearest()
	if not check(world._dialogue.visible and str(world._talking_to.npc_id) == "core_defense", "Core Defense NPC"): return false
	world._open_npc_action("core_defense")
	return await wait_for(func(): return is_instance_valid(world._canvas.get_node_or_null("CoreDefenseBrowser")),5.0)

func confirm(node: Node) -> bool:
	for child in node.get_children():
		if child is ConfirmationDialog:
			child.confirmed.emit()
			return true
	return false

func movement_during_deploy(arena: Node) -> bool:
	if not await wait_for(func(): return cd.deploy_in_flight, 3.0): return false
	var before_tick := int(arena._snapshot.get("tick", 0))
	var positions := {}
	for id in arena._units:
		if is_instance_valid(arena._units[id]): positions[id] = arena._units[id].position
	var progressed := await wait_for(func(): return cd.deploy_in_flight and int(arena._snapshot.get("tick", 0)) >= before_tick + 8, 2.5)
	if not progressed or not arena._acting or not cd._request_busy: return false
	for id in positions:
		if arena._units.has(id) and is_instance_valid(arena._units[id]) and arena._units[id].position.distance_to(positions[id]) > 0.5:
			return true
	return false

func _run() -> void:
	cd = root.get_node("CoreDefenseClient")
	role = int(OS.get_environment("FOREST_DUEL_ROLE"))
	sync_dir = OS.get_environment("FOREST_WOE_SYNC")
	var gate = root.get_node("ConnectionGate")
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = OS.get_environment("FOREST_TWO_ID")
	gate.token = OS.get_environment("FOREST_TWO_TOKEN")
	gate.base_url = OS.get_environment("FOREST_TWO_URL")
	SceneRouter._forest_owner = gate.player_id
	SceneRouter._forest_summoner = "wizard"
	change_scene_to_file(FOREST)
	if not check(await wait_for(func(): return scene_is(FOREST) and is_instance_valid(current_scene._presence) and current_scene._presence.entered),"Forest entry"): quit(1); return
	var world = current_scene
	if not check(await walk(world,Vector2(960,540)) and await walk(world,Vector2(70,540)),"central walk"): quit(1); return
	if not check(await portal(world,"west",Vector2(0,540),"alchemical_ruins"),"west portal"): quit(1); return
	if not check(await walk(world,Vector2(960,540)) and await walk(world,Vector2(960,70)),"ruins walk"): quit(1); return
	if not check(await portal(world,"north",Vector2(960,0),"duel_clearing"),"north portal"): quit(1); return
	if not check(await walk(world,Vector2(800,550)),"NPC walk"): quit(1); return
	var online: Dictionary = await cd.request("/chat/state")
	if not check(online.code == 200,"online presence"): quit(1); return
	signal_file("cd_online_%d" % role)
	if not check(await wait_file("cd_online_%d" % (1-role)),"friend online"): quit(1); return
	if role == 0:
		if not check(cd._persist_pending({"action":"match/deploy", "values":{"match_id":"expired-fixture-match"}, "body":{"match_id":"expired-fixture-match", "client_action_id":"1700000000000:fixture"}}), "stale match journal setup"): quit(1); return
		cd.save_match("expired-fixture-match")
	if not check(await open_browser(world),"browser"): quit(1); return
	var browser = world._canvas.get_node("CoreDefenseBrowser")
	if not check(await wait_for(func(): return not browser._busy),"browser ready"): quit(1); return
	if role == 0:
		if not check(cd.saved_pending().is_empty() and cd.saved_match().is_empty(), "expired match journal reconciled"): quit(1); return
		browser._create("coop")
		if not check(await wait_for(func(): return scene_is(PREGAME)),"host admission"): quit(1); return
		var pregame = current_scene
		if not check(await wait_for(func(): return not pregame._room.is_empty() and not pregame._invites._busy),"host lobby"): quit(1); return
		signal_file("cd_room", str(pregame._room.room_id))
		pregame._invites._send(OS.get_environment("FOREST_TWO_OTHER"))
		if not check(await wait_for(func(): return not pregame._invites._busy and pregame._invites._saved().is_empty()),"send invitation"): quit(1); return
		signal_file("cd_sent")
		if not check(await wait_for(func(): return pregame._room.get("members", []).size() == 2),"guest joined"): quit(1); return
		pregame._start_match()
	else:
		if not check(await wait_file("cd_sent") and await wait_file("cd_room"),"invitation ready"): quit(1); return
		var invitations = browser.find_child("Invitations",true,false)
		invitations.refresh_invitations()
		if not check(await wait_for(func(): return not invitations._busy and invitations._items.get_child_count() > 0),"incoming invitation"): quit(1); return
		var inbox: Dictionary = await cd.request("/forest/minigames/invitations")
		if not check(inbox.code == 200 and inbox.data.get("incoming", []).size() == 1,"private inbox"): quit(1); return
		var invite: Dictionary = inbox.data.incoming[0]
		invitations._respond(str(invite.invite_id),true,str(invite.room_id))
	if not check(await wait_for(func(): return scene_is(ARENA),20.0),"arena transition"): quit(1); return
	var arena = current_scene
	if not check(await wait_for(func(): return not arena._snapshot.is_empty() and not arena._own.is_empty()),"arena snapshot"): quit(1); return
	if not check(arena._is_cd and arena._lab_bars.size() == 2 and arena._lane_buttons.size() == 2,"blue lanes only"): quit(1); return
	for p in arena._snapshot.players:
		if not check(p.has("slots") == (str(p.id) == str(gate.player_id)),"private hand"): quit(1); return
	var match_id: String = arena._match_id
	signal_file("cd_arena_%d" % role,match_id)
	if not check(await wait_file("cd_arena_%d" % (1-role)),"shared arena"): quit(1); return
	if not check(await wait_for(func(): return arena._snapshot.units.any(func(u): return u.get("kind") == "enemy"),10.0),"enemy snapshot"): quit(1); return
	if role == 0:
		var delay_test := OS.get_environment("FOREST_ACTION_DELAY_TEST") == "1"
		if delay_test:
			if not check(await wait_for(func(): return not arena._requesting and not cd._request_busy), "before delayed actions"): quit(1); return
			cd.set_script(load("res://scripts/tests/core_defense_e2e_fault_client.gd"))
			arena._poll = 0
			if not check(await wait_for(func(): return cd.authoritative_time() > 0 and not arena._requesting), "time after fault injection"): quit(1); return
		if OS.get_environment("FOREST_POTION_TEST") == "1":
			var potion_id := OS.get_environment("FOREST_POTION_ID")
			if potion_id.is_empty(): potion_id = "thunderlock"
			if not check(await wait_file("potion_ready"), "potion fixture ready"): quit(1); return
			if not check(await wait_for(func(): return arena._own.get("slots", []).size() == 4 and arena._own.slots[3] == potion_id and not arena._buttons[3].disabled, 10.0), "potion hand ready"): quit(1); return
			arena._select(3)
			if not check(arena._potion_target.visible and not arena._lane_buttons["blue:left"].visible, "potion targeting"): quit(1); return
			if delay_test: cd.delay_next_deploy = true
			arena._cast_potion(Vector2(960,540))
			if delay_test and not check(await movement_during_deploy(arena), "movement and polling continue during potion request"): quit(1); return
			if not check(await wait_for(func(): return not arena._acting and arena._own.get("slots", []).size() == 4 and arena._own.slots[3] != potion_id, 10.0), "authoritative potion cast"): quit(1); return
			signal_file("potion_cast_0")
		var slot := -1
		if not check(await wait_for(func(): return arena._own.get("slots", []).any(func(id): return arena._cards.get(str(id), {}).get("kind") != "potion" and arena._card_cost(arena._cards.get(str(id), {})) <= float(arena._own.get("zeal", 0))), 15.0), "unit affordable"): quit(1); return
		for i in range(4):
			if not arena._buttons[i].disabled and arena._cards.get(str(arena._own.slots[i]), {}).get("kind") != "potion": slot = i; break
		if not check(slot >= 0,"affordable card"): quit(1); return
		arena._select(slot)
		if not check(arena._lane_buttons["blue:left"].visible and arena._lane_buttons["blue:right"].visible,"both lanes"): quit(1); return
		if delay_test: cd.delay_next_deploy = true
		arena._deploy("left")
		if delay_test and not check(await movement_during_deploy(arena), "movement and polling continue during unit request"): quit(1); return
		if not check(await wait_for(func(): return not arena._acting and arena._snapshot.units.any(func(u): return str(u.get("controllerId", "")) == str(gate.player_id))),"authoritative deployment"): quit(1); return
		# Inject one transport outage, then reconnect to the same live server.
		if not check(await wait_for(func(): return not arena._requesting and not cd._request_busy), "before disconnect"): quit(1); return
		cd.set_script(load("res://scripts/tests/core_defense_e2e_fault_client.gd"))
		cd.simulate_disconnect = true
		arena._poll = 0
		if not check(await wait_for(func(): return not arena._playback_ready, 5.0), "simulated disconnect"): quit(1); return
		cd.simulate_disconnect = false
		arena._poll = 0
		if not check(await wait_for(func(): return arena._playback_ready and not arena._requesting, 5.0), "live reconnect"): quit(1); return
		signal_file("cd_deployed")
	else:
		if not check(await wait_file("cd_deployed"),"deployment signal"): quit(1); return
		var slot := -1
		for i in range(4):
			if not arena._buttons[i].disabled and slot < 0 and arena._cards.get(str(arena._own.slots[i]), {}).get("kind") != "potion": slot = i
		if not check(slot >= 0, "coop guest affordable card"): quit(1); return
		arena._select(slot)
		if not check(arena._lane_buttons["blue:left"].visible and arena._lane_buttons["blue:right"].visible, "guest both lanes"): quit(1); return
		arena._deploy("right")
		if not check(await wait_for(func(): return not arena._acting and arena._snapshot.units.any(func(u): return str(u.get("controllerId", "")) == str(gate.player_id) and u.get("lane") == "right")), "guest right lane deployment"): quit(1); return
		signal_file("cd_both_deployed")
	# Fixture accelerates wave completion in its private database; the scheduler
	# still performs the transition and emits both clients' authoritative states.
	if not check(await wait_for(func(): return arena._snapshot.get("phase") == "intermission" and int(arena._snapshot.get("completedWaves", 0)) >= 1, 15.0),"wave one intermission"): quit(1); return
	if not check(await wait_for(func(): return int(arena._snapshot.get("wave", 0)) >= 2, 15.0),"wave two"): quit(1); return
	signal_file("cd_wave2_%d" % role)
	if not check(await wait_for(func(): return arena._finished,15.0),"shared result"): quit(1); return
	if not check(str(arena._snapshot.result.reason) == "laboratories","shared defeat reason"): quit(1); return
	arena._confirm_return()
	if not check(await wait_for(func(): return scene_is(FOREST) and is_instance_valid(current_scene._presence) and current_scene._presence.entered),"Forest return"): quit(1); return
	if not check(current_scene._player.position.distance_to(Vector2(800,550)) < 1.0 and str(current_scene._zones[current_scene._zone_index].id) == "duel_clearing", "exact Forest return"): quit(1); return
	if role == 0:
		world = current_scene
		if not check(await open_browser(world),"solo browser"): quit(1); return
		browser = world._canvas.get_node("CoreDefenseBrowser")
		if not check(await wait_for(func(): return not browser._busy),"solo browser ready"): quit(1); return
		browser._create("solo")
		if not check(await wait_for(func(): return scene_is(ARENA),15.0),"solo starts immediately"): quit(1); return
		arena = current_scene
		if not check(await wait_for(func(): return not arena._snapshot.is_empty()),"solo state"): quit(1); return
		if not check(str(arena._snapshot.mode) == "solo","solo mode"): quit(1); return
		arena._confirm_forfeit()
		await process_frame
		if not check(confirm(arena),"solo forfeit confirmation"): quit(1); return
		if not check(await wait_for(func(): return arena._finished),"solo result"): quit(1); return
		arena._confirm_return()
		if not check(await wait_for(func(): return scene_is(FOREST) and current_scene._presence.entered),"solo Forest return"): quit(1); return
	print("CORE_DEFENSE_FOREST_E2E_PASS ",match_id)
	quit(0)
