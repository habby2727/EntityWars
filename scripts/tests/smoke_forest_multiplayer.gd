extends SceneTree
const ClientBuild := preload("res://scripts/net/client_build.gd")
var failed := false
func _initialize() -> void:
	call_deferred("_run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
func _run() -> void:
	var zones_script = load("res://scripts/forest/forest_zones.gd")
	var world_script = load("res://scripts/forest/forest_world.gd")
	var client_script = load("res://scripts/forest/forest_presence_client.gd")
	var remote_script = load("res://scripts/forest/forest_remote_summoner.gd")
	if zones_script == null or world_script == null or client_script == null or remote_script == null or not world_script.can_instantiate() or not client_script.can_instantiate() or not remote_script.can_instantiate():
		push_error("Forest scripts failed to compile")
		quit(1)
		return
	var zones: Array = zones_script.runtime_zones()
	check(zones.size() == 6, "Catalog must load in an export-like environment")
	var total := 0
	for i in zones.size():
		var zone: Dictionary = zones[i]
		var legacy: Dictionary = zones_script.ZONES[i]
		check(zone.id == legacy.id and zone.image == legacy.image and zone.spawn == legacy.spawn and zone.polygon == PackedVector2Array(legacy.polygon), "Catalog differs from existing forest")
		check(zone.portals.size() == legacy.portals.size(), "Portal count differs")
		for j in zone.portals.size():
			var actual: Dictionary = zone.portals[j]
			var old: Dictionary = legacy.portals[j]
			check(actual.id == old.id and actual.direction == old.direction and actual.destination == old.destination and actual.arrival == old.arrival, "Portal link differs")
			for k in 4: check(float(actual.corridor[k]) == float(old.corridor[k]), "Portal corridor differs")
		total += zone.portals.size()
	check(total == 10, "Expected ten portals")
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/forest_zones.json"))
	var bad = raw.duplicate(true)
	bad.zones[1].id = bad.zones[0].id
	check(zones_script._catalog_from_data(bad).is_empty(), "Duplicate zones accepted")
	bad = raw.duplicate(true)
	bad.zones[0].portals[0].arrival = [-1, -1]
	check(zones_script._catalog_from_data(bad).is_empty(), "Invalid portal arrival accepted")
	bad = raw.duplicate(true)
	bad.zones[0].polygon = [[0,0], [100,100], [0,100], [100,0]]
	check(zones_script._catalog_from_data(bad).is_empty(), "Malformed polygon accepted")
	var gate = root.get_node("ConnectionGate")
	var router = load("res://scripts/scene_router.gd")
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = "self"
	gate.token = "test-token"
	gate.base_url = "http://127.0.0.1:1"
	router._forest_owner = "self"
	router._forest_summoner = "wizard"
	var client = client_script.new()
	root.add_child(client)
	client.set_process(false)
	client.zones = zones
	client._summoner = "wizard"
	client._owner = "self"
	client._token = "test-token"
	client._generation = gate._generation
	var snapshots: Array = []
	var joins: Array = []
	var moves: Array = []
	var chats: Array = []
	client.peer_chat.connect(func(id, message_id, text, created, expires, server_now): chats.append([id, message_id, text, created, expires, server_now]))
	client.snapshot.connect(func(state, peers): snapshots.append([state, peers]))
	client.peer_joined.connect(func(player): joins.append(player))
	client.peer_moved.connect(func(id, seq, point, face): moves.append([id, seq, point, face]))
	var self_state := {"player_id":"self", "display_name":"Server Self", "zone_id":"central_clearing", "x":960, "y":760, "facing":0, "summoner_id":"wizard"}
	var peer := {"player_id":"peer", "display_name":"Server Peer", "zone_id":"central_clearing", "x":950, "y":760, "facing":3, "summoner_id":"witch"}
	client._receive({"v":1,"type":"welcome","self":self_state,"peers":[peer],"server_time":100000})
	check(client.entered and snapshots.size() == 1, "Valid welcome rejected")
	client._receive({"v":1,"type":"peer_chat","player_id":"peer","message_id":1,"text":"hello","created_at":100000,"expires_at":110000,"server_time":100000})
	client._receive({"v":1,"type":"peer_chat","player_id":"unknown","message_id":2,"text":"no","created_at":100000,"expires_at":110000,"server_time":100000})
	client._receive({"v":1,"type":"peer_chat","player_id":"peer","message_id":3,"text":"old","created_at":80000,"expires_at":90000,"server_time":100000})
	check(chats.size() == 1 and chats[0][0] == "peer", "Invalid or expired chat event accepted")
	client._receive({"v":1,"type":"peer_move","player_id":"unknown","seq":1,"x":951,"y":760,"facing":1})
	client._receive({"v":1,"type":"peer_move","player_id":"peer","seq":2,"x":951,"y":760,"facing":3})
	client._receive({"v":1,"type":"peer_move","player_id":"peer","seq":1,"x":952,"y":760,"facing":1})
	client._receive({"v":1,"type":"peer_join","player":peer})
	check(moves.size() == 1 and joins.is_empty(), "Stale, unknown or duplicate peer accepted")
	gate._generation += 1
	client._receive({"v":1,"type":"peer_move","player_id":"peer","seq":3,"x":952,"y":760,"facing":1})
	check(moves.size() == 1, "Old authentication generation accepted")
	gate._generation -= 1
	client._receive({"v":2,"type":"peer_leave","player_id":"peer"})
	client._receive({"v":1,"type":"peer_move","player_id":"peer","seq":3,"x":"bad","y":760,"facing":1})
	check(client._peers.has("peer") and moves.size() == 1, "Malformed packet changed presence")
	client._receive({"v":1,"type":"zone","zone_id":"arcane_sanctuary","x":960,"y":880,"facing":0,"peers":[]})
	check(client.zone_id == "central_clearing", "Unsolicited zone accepted")
	client._portal_seq = 3
	client.seq = 3
	client._receive({"v":1,"type":"zone","zone_id":"arcane_sanctuary","x":960,"y":880,"facing":0,"peers":[]})
	client._receive({"v":1,"type":"peer_move","player_id":"peer","seq":3,"x":960,"y":880,"facing":0})
	check(client.zone_id == "arcane_sanctuary" and moves.size() == 1, "Old room leaked into new zone")
	var avatar = remote_script.new()
	root.add_child(avatar)
	avatar.setup(peer)
	check(avatar.facing == 3 and avatar._label.text == "Server Peer", "Remote identity or facing incorrect")
	var first_texture = avatar._textures[0]
	avatar.set_cosmetic("wizard")
	avatar.set_cosmetic("witch")
	check(avatar._textures[0] == first_texture and avatar.get_child_count() == 1, "Cosmetic cache or nameplate leaked")
	avatar.move_to(2, Vector2(960,760), 1)
	avatar.move_to(1, Vector2(1000,760), 0)
	avatar._process(0.1)
	check(avatar.position.x > 950 and avatar.position.x < 960 and avatar.facing == 1, "Remote interpolation or sequence invalid")
	avatar.queue_free()
	client.queue_free()
	gate.debug_offline_enabled = true
	router._forest_owner = ""
	router._forest_summoner = "wizard"
	var scene = load("res://scenes/forest/ForestWorld.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene._catalog_valid and scene._presence == null, "Editor debug must remain offline")
	if OS.has_feature("editor"):
		var f9 := InputEventKey.new()
		f9.pressed = true
		f9.keycode = KEY_F9
		var before: int = scene._zone_index
		scene._unhandled_key_input(f9)
		check(scene._zone_index == (before + 1) % zones.size(), "Offline F9 did not cycle zone")
		gate.debug_offline_enabled = false
		before = scene._zone_index
		scene._unhandled_key_input(f9)
		check(scene._zone_index == before, "Online F9 changed authoritative zone")
		gate.debug_offline_enabled = true
	check(scene._set_zone(0, Vector2(960,760)), "Forest failed to load shared geometry")
	scene._player.position = Vector2(800, 760)
	scene._on_presence_snapshot(self_state, [peer])
	check(scene._player.position == Vector2(960,760) and scene._remotes.size() == 1, "Server welcome failed to replace local state")
	scene._on_presence_correction({"zone_id":"central_clearing", "x":970, "y":750, "facing":1})
	check(scene._player.position == Vector2(970,750) and scene._player.facing == 1 and not scene._player.exit_pending, "Correction failed to reconcile player")
	scene._clear_remotes()
	check(scene._remotes.is_empty(), "Remote avatars not cleared")
	scene._canvas.size = Vector2(1280,720)
	scene._resize_world()
	check(scene._world.scale.is_equal_approx(Vector2(2.0/3.0,2.0/3.0)), "720p forest scale incorrect")
	scene._canvas.size = Vector2(1920,1080)
	scene._resize_world()
	check(scene._world.scale.is_equal_approx(Vector2.ONE), "1080p forest scale incorrect")
	for direction in ["north","south","west","north","south","east","east","west","south","north"]:
		var current: Dictionary = scene._zones[scene._zone_index]
		var portal := {}
		for candidate in current.portals:
			if candidate.direction == direction: portal = candidate
		check(not portal.is_empty(), "Missing portal")
		if portal.is_empty(): break
		var rect: Array = portal.corridor
		var midpoint := Vector2((rect[0]+rect[2])/2.0, (rect[1]+rect[3])/2.0)
		var foot := midpoint
		var next := midpoint
		match direction:
			"north": foot.y = 1; next = foot + Vector2(0.5, -2)
			"south": foot.y = 1079; next = foot + Vector2(0.5, 2)
			"west": foot.x = 1; next = foot + Vector2(-2, 0.5)
			"east": foot.x = 1919; next = foot + Vector2(2, 0.5)
		scene._player.position = foot
		scene._player.exit_pending = false
		scene._player.transition_locked = false
		scene._on_exit_attempt(direction, foot, next)
		await process_frame
		check(scene._zones[scene._zone_index].id == portal.destination, "Offline diagonal portal failed: " + direction)
	current_scene = scene
	scene._set_zone(0, Vector2(960,760))
	scene._player.transition_locked = false
	scene._player.exit_pending = false
	scene._change_summoner()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/SummonerSelection.tscn", "Summoner selector did not open")
	if current_scene != null and current_scene.scene_file_path == "res://scenes/ui/SummonerSelection.tscn":
		current_scene._cancel_selection()
		await process_frame
		await process_frame
		check(current_scene != null and current_scene.scene_file_path == "res://scenes/forest/ForestWorld.tscn" and router.forest_selected_summoner() == "wizard", "Cancel did not restore forest choice")
		if current_scene != null and current_scene.scene_file_path == "res://scenes/forest/ForestWorld.tscn":
			current_scene._player.transition_locked = false
			current_scene._change_summoner()
			await process_frame
			await process_frame
			if current_scene != null and current_scene.scene_file_path == "res://scenes/ui/SummonerSelection.tscn":
				current_scene._select("witch")
				current_scene._confirm_selection()
				await process_frame
				await process_frame
				check(current_scene != null and current_scene.scene_file_path == "res://scenes/forest/ForestWorld.tscn" and router.forest_selected_summoner() == "witch", "Confirm did not restore selected summoner")
				if current_scene != null and current_scene.scene_file_path == "res://scenes/forest/ForestWorld.tscn":
					current_scene._player.transition_locked = false
					var guide = current_scene._npcs[0]
					current_scene._player.position = guide.position
					current_scene._open_dialogue(guide)
					current_scene._open_npc_action("guide_inventory")
					await process_frame
					await process_frame
					check(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/Inventory.tscn" and router.forest_return_available(), "NPC menu did not retain safe return")
					if current_scene != null and current_scene.scene_file_path == "res://scenes/ui/Inventory.tscn":
						router.return_to_forest()
						await process_frame
						await process_frame
						check(current_scene != null and current_scene.scene_file_path == "res://scenes/forest/ForestWorld.tscn", "NPC return failed")
			else:
				check(false, "Summoner selector did not reopen")
	if current_scene != null: current_scene.queue_free()
	await process_frame
	if not OS.get_environment("FOREST_SMOKE_URL").is_empty():
		await _live_test(zones, client_script, gate, router)
	if not OS.get_environment("FOREST_FAULT_URL").is_empty():
		await _handoff_fault_test(zones, client_script, gate, router)
	if not OS.get_environment("FOREST_TWO_URL").is_empty():
		await _two_client_test(zones, client_script, gate, router)
	print("Forest multiplayer smoke: ", "FAILED" if failed else "passed")
	quit(1 if failed else 0)

func _live_test(zones: Array, script, gate: Node, router) -> void:
	var token := OS.get_environment("FOREST_SMOKE_TOKEN")
	var identity := OS.get_environment("FOREST_SMOKE_PLAYER_ID")
	var peer_token := OS.get_environment("FOREST_SMOKE_PEER_TOKEN")
	gate.debug_offline_enabled = false
	gate.state = 0
	gate.player_id = identity
	gate.token = token
	gate.base_url = OS.get_environment("FOREST_SMOKE_URL")
	router._forest_owner = identity
	router._forest_summoner = "wizard"
	var client = script.new()
	root.add_child(client)
	var joins: Array = []
	var moves: Array = []
	client.peer_joined.connect(func(player): joins.append(player))
	client.peer_moved.connect(func(id, seq, point, face): moves.append([id, seq, point, face]))
	client.configure(zones, "wizard")
	var deadline := Time.get_ticks_msec() + 7000
	while not client.entered and Time.get_ticks_msec() < deadline:
		await process_frame
	check(client.entered, "Godot client did not enter real backend")
	var peer := WebSocketPeer.new()
	peer.handshake_headers = PackedStringArray(["Authorization: Bearer " + peer_token, ClientBuild.header()])
	var url: String = gate.base_url.trim_suffix("/").replace("https://", "wss://").replace("http://", "ws://") + "/forest/ws"
	check(peer.connect_to_url(url) == OK, "Peer could not connect")
	while peer.get_ready_state() == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() < deadline:
		peer.poll()
		await process_frame
	if peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		peer.send_text(JSON.stringify({"v":1,"type":"enter","summoner_id":"witch"}))
	while joins.is_empty() and Time.get_ticks_msec() < deadline:
		peer.poll()
		await process_frame
	check(joins.size() == 1 and joins[0].display_name == "ForestPeer", "Real peer name or join missing")
	var peer_saw_self := false
	while not peer_saw_self and Time.get_ticks_msec() < deadline:
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var incoming = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			if incoming is Dictionary and incoming.get("type") == "welcome":
				for other in incoming.get("peers", []):
					if other.get("display_name") == "ForestSelf": peer_saw_self = true
		await process_frame
	check(peer_saw_self, "Peer did not receive self's server-owned name")
	peer.send_text(JSON.stringify({"v":1,"type":"move","seq":1,"x":970,"y":760,"facing":3}))
	while moves.is_empty() and Time.get_ticks_msec() < deadline:
		peer.poll()
		await process_frame
	check(moves.size() == 1 and moves[0][3] == 3, "Real peer movement missing")
	for y in range(720, 0, -40):
		await create_timer(0.22).timeout
		check(client.move(Vector2(960, y), 2), "Failed to send authoritative walk")
	await create_timer(0.22).timeout
	check(client.portal("north", Vector2(960,0), Vector2(960,10), 2), "Portal request failed")
	deadline = Time.get_ticks_msec() + 3000
	while client.zone_id != "arcane_sanctuary" and Time.get_ticks_msec() < deadline:
		peer.poll()
		await process_frame
	check(client.zone_id == "arcane_sanctuary", "Server did not confirm portal transition")
	var previous_moves := moves.size()
	var previous_joins := joins.size()
	var third_token := OS.get_environment("FOREST_SMOKE_THIRD_TOKEN")
	var third: WebSocketPeer
	if not third_token.is_empty():
		third = WebSocketPeer.new()
		third.handshake_headers = PackedStringArray(["Authorization: Bearer " + third_token, ClientBuild.header()])
		check(third.connect_to_url(url) == OK, "Third client could not connect")
		deadline = Time.get_ticks_msec() + 3000
		while third.get_ready_state() == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() < deadline:
			third.poll()
			await process_frame
		if third.get_ready_state() == WebSocketPeer.STATE_OPEN:
			third.send_text(JSON.stringify({"v":1,"type":"enter","summoner_id":"cyberghost"}))
			var third_saw_peer := false
			while not third_saw_peer and Time.get_ticks_msec() < deadline:
				third.poll()
				while third.get_available_packet_count() > 0:
					var incoming = JSON.parse_string(third.get_packet().get_string_from_utf8())
					if incoming is Dictionary and incoming.get("type") == "welcome":
						for other in incoming.get("peers", []):
							if other.get("display_name") == "ForestPeer": third_saw_peer = true
				await process_frame
			check(third_saw_peer, "Third client did not join the peer's room")
			third.send_text(JSON.stringify({"v":1,"type":"move","seq":1,"x":970,"y":760,"facing":1}))
	peer.send_text(JSON.stringify({"v":1,"type":"move","seq":2,"x":980,"y":760,"facing":1}))
	deadline = Time.get_ticks_msec() + 400
	var peer_saw_third_move := false
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		while peer.get_available_packet_count() > 0:
			var incoming = JSON.parse_string(peer.get_packet().get_string_from_utf8())
			if incoming is Dictionary and incoming.get("type") == "peer_move" and incoming.get("seq") == 1: peer_saw_third_move = true
		if third != null: third.poll()
		await process_frame
	if third != null: check(peer_saw_third_move, "Same-room peer did not receive third player's movement")
	check(moves.size() == previous_moves and joins.size() == previous_joins, "Presence or movement leaked across zones")
	if third != null: third.close()
	peer.close()
	var acknowledged: bool = await client.handoff("suspend")
	check(acknowledged and client.socket == null and not client.entered, "Live suspend handoff was not acknowledged and closed")
	client.queue_free()
	var resumed = script.new()
	root.add_child(resumed)
	resumed.configure(zones, "wizard")
	deadline = Time.get_ticks_msec() + 7000
	while not resumed.entered and Time.get_ticks_msec() < deadline:
		await process_frame
	check(resumed.entered and resumed.zone_id == "arcane_sanctuary", "Live resume did not restore authoritative zone")
	var left: bool = await resumed.handoff("leave")
	check(left and resumed.socket == null and not resumed.entered, "Live leave handoff was not acknowledged and closed")
	resumed.queue_free()

# Isolated controllable transport fixture; not an authenticated server test.
func _collect_handoff(client, results: Array) -> void:
	results.append(await client.handoff("suspend"))

func _handoff_fault_test(zones: Array, script, gate: Node, router) -> void:
	gate.debug_offline_enabled = false
	gate.state = 0
	gate.player_id = "fault-test"
	gate.token = "fixture-only"
	router._forest_owner = "fault-test"
	router._forest_summoner = "wizard"
	for mode in ["ack", "delayed", "closed", "withheld", "generation"]:
		gate.base_url = OS.get_environment("FOREST_FAULT_URL") + "/" + mode
		var client = script.new()
		root.add_child(client)
		client.configure(zones, "wizard")
		var deadline := Time.get_ticks_msec() + 3000
		while not client.entered and Time.get_ticks_msec() < deadline:
			await process_frame
		check(client.entered, "Fault fixture failed to welcome: " + mode)
		var late_joins: Array = []
		client.peer_joined.connect(func(player): late_joins.append(player))
		var started := Time.get_ticks_msec()
		var results: Array = []
		_collect_handoff(client, results)
		await process_frame
		check(not await client.handoff("suspend"), "Duplicate handoff accepted: " + mode)
		if mode == "generation": gate._generation += 1
		deadline = started + 1400
		while results.is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		check(not results.is_empty(), "Handoff exceeded deadline: " + mode)
		if not results.is_empty():
			check(results[0] == (mode in ["ack", "delayed"]), "Unexpected handoff result: " + mode)
			if mode == "withheld": check(Time.get_ticks_msec() - started >= 850, "Withheld ACK did not await deadline")
		check(client.socket == null and not client.entered and client._peers.is_empty() and late_joins.is_empty(), "Handoff retained socket or peers: " + mode)
		client.queue_free()
		await process_frame

# Runs in its own Godot process with a distinct account and ConnectionGate.
func _two_client_test(zones: Array, script, gate: Node, router) -> void:
	var identity := OS.get_environment("FOREST_TWO_ID")
	var other := OS.get_environment("FOREST_TWO_OTHER")
	var third := OS.get_environment("FOREST_TWO_THIRD")
	gate.state = 0
	gate.debug_offline_enabled = false
	gate.player_id = identity
	gate.token = OS.get_environment("FOREST_TWO_TOKEN")
	gate.base_url = OS.get_environment("FOREST_TWO_URL")
	router._forest_owner = identity
	router._forest_summoner = "wizard"
	var client = script.new()
	root.add_child(client)
	var peers := {}
	var movement: Array = []
	var cosmetics: Array = []
	client.snapshot.connect(func(_state, entries):
		peers.clear()
		for entry in entries: peers[entry.player_id] = entry.display_name)
	client.peer_joined.connect(func(entry): peers[entry.player_id] = entry.display_name)
	client.peer_left.connect(func(id): peers.erase(id))
	client.peer_moved.connect(func(id, _seq, _point, _facing): movement.append(id))
	client.peer_cosmetic.connect(func(id, cosmetic): cosmetics.append([id, cosmetic]))
	client.configure(zones, "wizard")
	var deadline := Time.get_ticks_msec() + 12000
	while (not client.entered or not peers.has(other) or not peers.has(third)) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(client.entered and peers.has(other) and peers.has(third), "Two Godot clients and third peer did not join")
	check(str(peers.get(other, "")).begins_with("TwoGodot"), "Other Godot client name is not server identity")
	if client.entered:
		check(client.move(Vector2(970, 760), 1), "Two-client movement send failed")
		check(client._send({"type":"cosmetic", "summoner_id":"witch"}), "Two-client cosmetic send failed")
	deadline = Time.get_ticks_msec() + 5000
	while (not movement.has(other) or not cosmetics.has([other, "witch"])) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(movement.has(other) and cosmetics.has([other, "witch"]), "Two Godot clients did not receive reciprocal movement and cosmetic")
	await create_timer(1.0).timeout
	client.shutdown()
	client.queue_free()
