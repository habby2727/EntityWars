extends SceneTree

const FOREST := "res://scenes/forest/ForestWorld.tscn"
const PREGAME := "res://scenes/ui/WOEPregame.tscn"
const ARENA := "res://scenes/ui/WOEArena.tscn"
var role := 0
var sync_dir := ""
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, what: String) -> bool:
	if not value:
		push_error("WOE_FOREST_E2E role=%d: %s" % [role,what])
		failed = true
	return value

func wait_for(test: Callable, seconds: float = 12.0) -> bool:
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
	return await wait_for(func(): return FileAccess.file_exists(sync_dir.path_join(name)), 30.0)

func scene_is(path: String) -> bool:
	return is_instance_valid(current_scene) and current_scene.scene_file_path == path

func walk(world: Node, target: Vector2) -> bool:
	while world._player.position.distance_to(target) > 1.0:
		await create_timer(0.36).timeout
		var point: Vector2 = world._player.position.move_toward(target, 65.0)
		world._player.position = point
		if not world._presence.move(point, 0, true): return false
	return true

func portal(world: Node, direction: String, crossing: Vector2, next: String) -> bool:
	await create_timer(0.36).timeout
	if not world._presence.portal(direction, crossing, world._player.position, 0): return false
	return await wait_for(func(): return world._presence.zone_id == next, 5.0)

func open_woe(world: Node) -> bool:
	if not await wait_for(func(): return not world._player.transition_locked, 5.0): return false
	world._interact_nearest()
	if not world._dialogue.visible:
		print("NPC_DIAGNOSTIC zone=", world._presence.zone_id, " position=", world._player.position, " locked=", world._player.transition_locked, " nearest=", world._nearest_npc())
	if not check(world._dialogue.visible and str(world._talking_to.npc_id) == "war_of_entities", "NPC dialogue"): return false
	world._open_npc_action("woe")
	return await wait_for(func(): return is_instance_valid(world._canvas.get_node_or_null("WOEBrowser")), 5.0)

func confirm_dialog(node: Node) -> bool:
	for child in node.get_children():
		if child is ConfirmationDialog:
			child.confirmed.emit()
			return true
	return false

func play_bot_game(mode: String) -> bool:
	var world = current_scene
	if not check(await open_woe(world), "bot game NPC"): return false
	var browser = world._canvas.get_node("WOEBrowser")
	if not check(await wait_for(func(): return not browser._busy), "bot game browser"): return false
	browser._mutate("create", {"mode":mode})
	if not check(await wait_for(func(): return scene_is(PREGAME)), "bot game admission"): return false
	var pregame = current_scene
	if not check(await wait_for(func(): return not pregame._room.is_empty() and not pregame._requesting), "bot pregame"): return false
	pregame._seat("blue:left")
	if not check(await wait_for(func(): return not pregame._changing and pregame._room.members.any(func(m): return str(m.get("seat", "")) == "blue:left")), "bot game seat"): return false
	pregame._start_match()
	if not check(await wait_for(func(): return scene_is(ARENA)), "bot game arena"): return false
	var arena = current_scene
	if not check(await wait_for(func(): return not arena._snapshot.is_empty()), "bot game state"): return false
	var bots := 0
	for player in arena._snapshot.players:
		if str(player.id).begins_with("woe-bot:"): bots += 1
	if not check(bots == (1 if mode == "1v1" else 3), "bot fill count"): return false
	if not check(await wait_for(func(): return not arena._snapshot.units.is_empty()), "bot deployment"): return false
	arena._confirm_forfeit()
	await process_frame
	if not check(confirm_dialog(arena), "bot game confirmation"): return false
	if not check(await wait_for(func(): return arena._finished), "bot game result"): return false
	if OS.get_environment("FOREST_WOE_CYCLES") == "1":
		# Deliberately close a finished arena while its state request is in flight.
		arena._poll_state()
		if not check(arena._requesting, "state request in flight at return"): return false
	arena._confirm_return()
	return check(await wait_for(func(): return scene_is(FOREST) and is_instance_valid(current_scene._presence) and current_scene._presence.entered), "bot game return")

func _run() -> void:
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
	if not check(await wait_for(func(): return scene_is(FOREST) and is_instance_valid(current_scene._presence) and current_scene._presence.entered), "real Forest presence"): quit(1); return
	var world = current_scene
	if not check(await walk(world,Vector2(960,540)) and await walk(world,Vector2(70,540)), "central walk"): quit(1); return
	if not check(await portal(world,"west",Vector2(0,540),"alchemical_ruins"), "west portal"): quit(1); return
	if not check(await walk(world,Vector2(960,540)) and await walk(world,Vector2(960,70)), "ruins walk"): quit(1); return
	if not check(await portal(world,"north",Vector2(960,0),"duel_clearing"), "north portal"): quit(1); return
	if not check(await walk(world,Vector2(1050,550)), "NPC walk"): quit(1); return
	var invite_test := OS.get_environment("FOREST_WOE_INVITE_TEST") == "1"
	if invite_test:
		var online: Dictionary = await root.get_node("WoeClient").request("/chat/state")
		if not check(online.code == 200, "online presence"): quit(1); return
		signal_file("woe_online_%d" % role)
		if not check(await wait_file("woe_online_%d" % (1-role)), "friend online"): quit(1); return
	if not check(await open_woe(world), "browser opening"): quit(1); return
	var browser = world._canvas.get_node("WOEBrowser")
	if not check(await wait_for(func(): return not browser._busy), "browser ready"): quit(1); return
	if role == 0:
		browser._mutate("create", {"mode":"2v2" if OS.get_environment("FOREST_WOE_INVITE_MODE") == "2v2" else "1v1"})
	else:
		if not check(await wait_file("room"), "room sharing"): quit(1); return
		var room_id := FileAccess.get_file_as_string(sync_dir.path_join("room"))
		if invite_test:
			if not check(await wait_file("woe_invited"), "invitation sent"): quit(1); return
			var invites = browser.find_child("Invitations", true, false)
			if invites == null:
				for node in browser.find_children("*", "VBoxContainer", true, false):
					if node.get_script() == load("res://scripts/ui/minigame_invitations.gd"): invites = node; break
			var response: Dictionary = await root.get_node("WoeClient").request("/forest/minigames/invitations")
			if not check(invites != null and response.code == 200 and response.data.get("incoming", []).size() == 1, "incoming WOE invitation"): quit(1); return
			var invite: Dictionary = response.data.incoming[0]
			var cache = root.get_node("MinigameInvitationCache")
			if not check(await wait_for(func(): return not cache.stale and cache.data.get("incoming", []).any(func(item): return str(item.get("invite_id", "")) == str(invite.invite_id)), 15.0), "verified WOE invitation cache"): quit(1); return
			var original_position: Vector2 = world._player.position
			world._player.position = Vector2(600, 550)
			var notice = cache._overlay.get_node("MinigameInvitationNotices")
			var feedback := Label.new()
			root.add_child(feedback)
			await notice._respond("woe", str(invite.invite_id), true, room_id, feedback)
			if not check(feedback.text == notice.tr("INVITE_CLEARING_GUIDANCE") and current_scene == world and invites._saved().is_empty(), "outside NPC guidance preserves invitation"): quit(1); return
			feedback.queue_free()
			world._player.position = original_position
			var client = root.get_node("WoeClient")
			if OS.get_environment("FOREST_WOE_LOST_ACCEPT") == "1": client.set_script(load("res://scripts/tests/woe_invitation_fault_client.gd"))
			invites._respond(str(invite.invite_id), true, room_id)
			if OS.get_environment("FOREST_WOE_LOST_ACCEPT") == "1":
				if not check(await wait_for(func(): return not invites._busy and not invites._saved().is_empty()), "lost committed response journal"): quit(1); return
				invites._retry()
				if not check(await wait_for(func(): return client.accept_bodies.size() == 2), "accept retry"): quit(1); return
				if not check(client.accept_bodies[0] == client.accept_bodies[1], "exact acceptance replay"): quit(1); return
		else:
			browser._mutate("join", {"room_id_or_code":room_id})
	if not check(await wait_for(func(): return scene_is(PREGAME)), "browser admission and handoff"): quit(1); return
	var pregame = current_scene
	if not check(await wait_for(func(): return not pregame._room.is_empty() and not pregame._requesting), "pregame state"): quit(1); return
	if role == 0:
		signal_file("room", str(pregame._room.room_id))
		if invite_test:
			pregame._open_invites()
			if not check(await wait_for(func(): return is_instance_valid(pregame._invites) and pregame._invites._server_time > 0 and not pregame._invites._busy), "invitation picker ready"): quit(1); return
			pregame._invites._send(OS.get_environment("FOREST_TWO_OTHER"))
			if not check(await wait_for(func(): return not pregame._invites._busy and pregame._invites._saved().is_empty()), "WOE invite submitted"): quit(1); return
			signal_file("woe_invited")
	else:
		if not check(await wait_file("host_seated"), "host seat"): quit(1); return
		pregame._refresh()
		await create_timer(0.6).timeout
	pregame._seat("blue:left" if role == 0 else "red:left")
	if not check(await wait_for(func(): return not pregame._changing and pregame._room.members.any(func(m): return str(m.player_id) == str(gate.player_id) and not str(m.get("seat", "")).is_empty())), "seat accepted"): quit(1); return
	signal_file("host_seated" if role == 0 else "guest_seated")
	if role == 0:
		if not check(await wait_file("guest_seated"), "guest seat"): quit(1); return
		pregame._refresh()
		await create_timer(0.6).timeout
		if OS.get_environment("FOREST_WOE_LOST_START") == "1": root.get_node("WoeClient").set_script(load("res://scripts/tests/woe_invitation_fault_client.gd"))
		pregame._start_match()
	if not check(await wait_for(func(): return scene_is(ARENA), 15.0), "automatic arena transition"): quit(1); return
	var arena = current_scene
	if not check(await wait_for(func(): return not arena._own.is_empty() and not arena._snapshot.is_empty()), "arena state"): quit(1); return
	if role == 0 and OS.get_environment("FOREST_WOE_LOST_START") == "1":
		var client = root.get_node("WoeClient")
		if not check(await wait_for(func(): return client.saved_pending().is_empty(), 10.0), "committed start journal reconciled"): quit(1); return
		if not check(client.start_bodies.size() == 1, "start was not replayed"): quit(1); return
		print("WOE_LOST_COMMITTED_START_PASS")
	var match_id: String = arena._match_id
	if invite_test:
		var bots := 0
		for player in arena._snapshot.players:
			if str(player.id).begins_with("woe-bot:"): bots += 1
		if not check(bots == (2 if OS.get_environment("FOREST_WOE_INVITE_MODE") == "2v2" else 0), "invited match bot fill"): quit(1); return
		if role == 1 and OS.get_environment("FOREST_WOE_LOST_ACCEPT") == "1": print("WOE_INVITATION_EXACT_REPLAY_PASS")
		print("WOE_INVITATION_SCENE_PASS ", OS.get_environment("FOREST_WOE_INVITE_MODE") if OS.get_environment("FOREST_WOE_INVITE_MODE") == "2v2" else "1v1")
		if OS.get_environment("FOREST_WOE_INVITE_MODE") == "2v2":
			if not check(arena._own.get("allowedDeploymentLanes", []) == ["left"], "selected seat owns left lane"): quit(1); return
			var denied: Dictionary = await root.get_node("WoeClient").request("/forest/woe/match/deploy", {"match_id":match_id,"client_action_id":"fixture-denied-lane","slot":0,"card_id":arena._own.slots[0],"lane":"right"})
			if not check(denied.code == 409 and denied.error == "LANE_NOT_OWNED", "server rejects teammate lane"): quit(1); return
			print("WOE_INVITED_LANE_AUTHORITY_PASS")
	for p in arena._snapshot.players:
		if not check(p.has("slots") == (str(p.id) == str(gate.player_id)) and p.has("zeal") == (str(p.id) == str(gate.player_id)), "hand privacy"): quit(1); return
	signal_file("arena_%d" % role, match_id)
	if not check(await wait_file("arena_%d" % (1-role)), "other arena"): quit(1); return
	if OS.get_environment("FOREST_WOE_LAB_TEST") == "1":
		if not check(await wait_for(func(): return scene_is(ARENA) and current_scene._finished, 15.0), "laboratory result"): quit(1); return
		arena = current_scene
		if not check(int(arena._snapshot.tick) < 1800 and str(arena._snapshot.result.reason) == "laboratories" and str(arena._snapshot.result.winner) == "blue", "shared early laboratory result"): quit(1); return
		arena._confirm_return()
		if not check(await wait_for(func(): return scene_is(FOREST) and is_instance_valid(current_scene._presence) and current_scene._presence.entered), "laboratory return"): quit(1); return
		print("WOE_LAB_E2E_PASS")
		print("WOE_FOREST_E2E_PASS ",match_id)
		quit(0)
		return
	if OS.get_environment("FOREST_WOE_TIMEOUT_TEST") == "1":
		if not check(await wait_for(func(): return scene_is(ARENA) and current_scene._finished, 240.0), "180-second timeout"): quit(1); return
		arena = current_scene
		if not check(int(arena._snapshot.tick) == 1800 and str(arena._snapshot.result.reason) == "timeout" and arena._snapshot.result.winner == null, "shared timeout result"): quit(1); return
		arena._confirm_return()
		if not check(await wait_for(func(): return scene_is(FOREST) and is_instance_valid(current_scene._presence) and current_scene._presence.entered), "timeout return"): quit(1); return
		print("WOE_TIMEOUT_E2E_PASS tick=1800")
		print("WOE_FOREST_E2E_PASS ",match_id)
		quit(0)
		return
	if role == 0:
		var slot := 3
		if not check(await wait_for(func(): return not arena._buttons[3].disabled, 15.0), "fourth card affordable"): quit(1); return
		if not check(slot >= 0, "affordable card"): quit(1); return
		arena._select(slot)
		if not check(arena._selected == slot and arena._lane_buttons["blue:left"].visible and arena._lane_buttons["blue:left"].size == Vector2(140,140), "selection and deployment target"): quit(1); return
		arena._deploy("left")
		if not check(await wait_for(func(): return not arena._acting and not arena._snapshot.units.is_empty()), "deploy in arena"): quit(1); return
		var deployed: Dictionary = arena._snapshot.units[0]
		signal_file("deployed", JSON.stringify({"id":deployed.id,"cardId":deployed.cardId,"team":deployed.team}))
	else:
		if not check(await wait_file("deployed"), "deployment signal"): quit(1); return
		var deployed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sync_dir.path_join("deployed")))
		var id := int(deployed.id)
		if not check(await wait_for(func(): return arena._units.has(id)), "opponent sees authoritative unit"): quit(1); return
		if not check(arena._units[id].card_id == deployed.cardId and arena._units[id].team == deployed.team, "shared unit identity"): quit(1); return
		signal_file("seen")
	if role == 0:
		if not check(await wait_file("seen"), "guest sees unit"): quit(1); return
		arena._confirm_return()
		await process_frame
		if not check(confirm_dialog(arena), "return confirmation"): quit(1); return
		if not check(await wait_for(func(): return scene_is(FOREST) and is_instance_valid(current_scene._presence) and current_scene._presence.entered), "Forest return"): quit(1); return
		world = current_scene
		world._presence._drop()
		if not check(await wait_for(func(): return world._presence.entered, 8.0), "Forest socket reconnect"): quit(1); return
		# Exercise match/current when the saved lobby ID is no longer available.
		root.get_node("WoeClient").save_room("")
		if not check(await open_woe(world), "reopen NPC"): quit(1); return
		if not check(await wait_for(func(): return scene_is(ARENA)), "match-current recovery"): quit(1); return
		arena = current_scene
		signal_file("recovered")
	else:
		if not check(await wait_file("recovered"), "host recovery"): quit(1); return
		if not check(not arena._finished, "return did not forfeit"): quit(1); return
		arena._confirm_forfeit()
		await process_frame
		if not check(confirm_dialog(arena), "forfeit confirmation"): quit(1); return
	if not check(await wait_for(func(): return scene_is(ARENA) and current_scene._finished), "shared terminal result"): quit(1); return
	arena = current_scene
	if not check(str(arena._snapshot.result.reason) == "forfeit" and str(arena._snapshot.result.winner) == "blue", "shared forfeit result"): quit(1); return
	arena._confirm_return()
	if not check(await wait_for(func(): return scene_is(FOREST) and is_instance_valid(current_scene._presence) and current_scene._presence.entered), "terminal Forest return"): quit(1); return
	if role == 0:
		print("WOE_CYCLE_COUNTS before_bots nodes=", get_node_count(), " objects=", Performance.get_monitor(Performance.OBJECT_COUNT))
		var cycles := 10 if OS.get_environment("FOREST_WOE_CYCLES") == "1" else 2
		for i in range(cycles):
			if not await play_bot_game("1v1" if i % 2 == 0 else "2v2"): quit(1); return
			await create_timer(1.0).timeout
			var requests := 0
			for node in root.find_children("*", "HTTPRequest", true, false):
				if node.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: requests += 1
			print("WOE_CYCLE_COUNTS cycle=", i+1, " nodes=", get_node_count(), " objects=", Performance.get_monitor(Performance.OBJECT_COUNT), " orphans=", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), " active_http=", requests)
		print("WOE_BOT_SCENES_PASS 1v1 2v2")
	print("WOE_FOREST_E2E_PASS ",match_id)
	quit(0 if not failed else 1)
