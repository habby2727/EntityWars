extends SceneTree

# Invoked by the existing authenticated Forest HTTP fixture after both sockets
# have reached the clearing. Tokens are ephemeral test accounts supplied by it.
var accounts: Array
var base := ""
var client: Node
var gate: Node
var sync_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func use_account(index: int) -> void:
	gate.player_id = str(accounts[index].id)
	gate.token = str(accounts[index].token)
	gate.base_url = base
	gate._generation += 1

func require(condition: bool, message: String) -> bool:
	if condition: return true
	push_error("WOE live: " + message)
	quit(1)
	return false

func checkpoint(name: String) -> bool:
	var file := FileAccess.open(sync_dir.path_join(name), FileAccess.WRITE)
	file.store_string("ready")
	file.close()
	var deadline := Time.get_ticks_msec() + 10000
	while not FileAccess.file_exists(sync_dir.path_join(name + ".ack")) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	return require(FileAccess.file_exists(sync_dir.path_join(name + ".ack")), "handoff " + name)

func _run() -> void:
	for singleton in ["GlobalChatClient", "SocialClient", "DuelClient", "SpectatorClient"]:
		root.get_node(singleton).set_process(false)
	sync_dir = OS.get_environment("WOE_TEST_SYNC")
	accounts = JSON.parse_string(OS.get_environment("WOE_TEST_ACCOUNTS"))
	base = OS.get_environment("WOE_TEST_BASE")
	client = root.get_node("WoeClient")
	gate = root.get_node("ConnectionGate")
	use_account(0)
	var result: Dictionary = await client.request("/forest/woe/match/current")
	if not require(result.code == 200 and client.valid_match(result.data, str(accounts[0].id)), "recover fixture match"): return
	result = await client.mutate("match/forfeit", {"match_id":result.data.match_id})
	if not require(result.code == 200, "forfeit fixture match"): return
	client.save_room("")
	result = await client.mutate("create", {"mode":"1v1"})
	if not require(result.code == 200 and client.valid_room(result.data, accounts[0].id), "create 1v1"): return
	var room: Dictionary = result.data
	if not await checkpoint("suspend_a"): return
	var room_id: String = room.room_id
	if not require(client.saved_room() == room_id, "save host recovery"): return
	use_account(1)
	if not require(client.saved_room().is_empty(), "isolate accounts"): return
	result = await client.mutate("join", {"room_id_or_code":room.join_code})
	if not require(result.code == 200 and result.data.room_id == room_id, "join same room"): return
	room = result.data
	if not await checkpoint("suspend_b"): return
	use_account(0)
	result = await client.mutate("seat", {"room_id":room_id,"seat":"blue:left","expected_revision":room.revision})
	if not require(result.code == 200, "seat host"): return
	room = result.data
	use_account(1)
	result = await client.mutate("seat", {"room_id":room_id,"seat":"red:right","expected_revision":int(room.revision)-1})
	if not require(result.code == 409 and result.error == "REVISION_CONFLICT", "stale revision"): return
	result = await client.mutate("seat", {"room_id":room_id,"seat":"red:right","expected_revision":room.revision})
	if not require(result.code == 200, "seat guest"): return
	room = result.data
	use_account(0)
	result = await client.mutate("start", {"room_id":room_id,"fill_bots":false,"expected_revision":room.revision})
	if not require(result.code == 200, "start without bots"): return
	var host_state: Dictionary = result.data
	use_account(1)
	result = await client.request("/forest/woe/state?room_id=" + room_id.uri_encode())
	if not require(result.code == 200 and client.saved_room() == room_id, "recover guest room"): return
	var guest_state: Dictionary = result.data
	for player in host_state.snapshot.players:
		if not require(player.has("slots") == (str(player.id) == str(accounts[0].id)), "host privacy"): return
	for player in guest_state.snapshot.players:
		if not require(player.has("slots") == (str(player.id) == str(accounts[1].id)), "guest privacy"): return
	use_account(0)
	result = await client.request("/forest/woe/match/current")
	if not require(result.code == 200 and client.valid_match(result.data, str(accounts[0].id)), "recover started match"): return
	var match_id: String = result.data.match_id
	var own := {}
	for player in result.data.snapshot.players:
		if str(player.id) == str(accounts[0].id): own = player
	result = await client.mutate("match/deploy", {"match_id":match_id,"slot":0,"card_id":own.slots[0],"lane":"left"})
	if not require(result.code == 200, "authoritative deployment"): return
	result = await client.request("/forest/woe/match/state?match_id=" + match_id.uri_encode() + "&after=0")
	if not require(result.code == 200 and not result.data.events.is_empty(), "event journal"): return
	result = await client.mutate("match/forfeit", {"match_id":match_id})
	if not require(result.code == 200, "forfeit initialized room"): return
	client.save_room("")
	if not await checkpoint("restore"): return
	gate.base_url = OS.get_environment("WOE_TEST_PROXY")
	gate._generation += 1
	result = await client.mutate("create", {"mode":"2v2"})
	if not require(result.code == 503, "simulated lost response"): return
	var uncertain_id := str(client.saved_pending().get("body", {}).get("client_action_id", ""))
	if not require(not uncertain_id.is_empty(), "persist uncertain create"): return
	result = await client.retry_pending()
	if not require(result.code == 200 and client.saved_pending().is_empty(), "retry same committed create"): return
	if not await checkpoint("suspend_a2"): return
	room = result.data
	result = await client.mutate("seat", {"room_id":room.room_id,"seat":"blue:right","expected_revision":room.revision})
	if not require(result.code == 200, "seat host for bots"): return
	room = result.data
	result = await client.mutate("start", {"room_id":room.room_id,"fill_bots":true,"expected_revision":room.revision})
	if not require(result.code == 200, "start with bots"): return
	var bots := 0
	for controller in result.data.controllers:
		if controller.bot: bots += 1
	if not require(bots == 3, "three bot controllers"): return
	var bot_match_id: String = result.data.match_id
	var bot_hand := []
	for player in result.data.snapshot.players:
		if str(player.id) == str(accounts[0].id): bot_hand = player.slots
	var card_catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/woe_cards.json"))
	var affordable := -1
	for i in range(bot_hand.size()):
		for card in card_catalog.cards:
			if card.id == bot_hand[i] and card.cost <= 5 and affordable < 0: affordable = i
	if not require(affordable >= 0, "affordable bot match card"): return
	result = await client.mutate("match/deploy", {"match_id":bot_match_id,"slot":affordable,"card_id":bot_hand[affordable],"lane":"right"})
	if not require(result.code == 503, "lost deploy response"): return
	var deploy_id := str(client.saved_pending().get("body", {}).get("client_action_id", ""))
	result = await client.retry_pending()
	if not require(result.code == 200 and not deploy_id.is_empty() and client.saved_pending().is_empty(), "retry deployment"): return
	result = await client.mutate("match/forfeit", {"match_id":bot_match_id})
	if not require(result.code == 200, "forfeit bot room"): return
	client.save_room("")
	if not await checkpoint("restore2"): return
	use_account(1)
	client.save_room("")
	gate.base_url = OS.get_environment("WOE_TEST_DISABLED_BASE")
	gate._generation += 1
	result = await client.request("/forest/woe/rooms")
	if not require(result.code == 503 and result.error == "FOREST_WOE_UNAVAILABLE", "disabled endpoint"): return
	gate.base_url = "http://127.0.0.1:1"
	gate._generation += 1
	result = await client.mutate("create", {"mode":"1v1"})
	if not require(result.code == 0, "unreachable server"): return
	var pending: Dictionary = client.saved_pending()
	var action_id := str(pending.get("body", {}).get("client_action_id", ""))
	if not require(not action_id.is_empty(), "save uncertain action"): return
	gate._generation += 1
	if not require(str(client.saved_pending().get("body", {}).get("client_action_id", "")) == action_id, "generation change retains pending action"): return
	gate.player_id = str(accounts[0].id)
	if not require(client.saved_pending().is_empty(), "pending action belongs to original account"): return
	gate.player_id = str(accounts[1].id)
	result = await client.retry_pending()
	if not require(result.code == 0 and str(client.saved_pending().get("body", {}).get("client_action_id", "")) == action_id, "reuse uncertain action id"): return
	client._save_pending({})
	print("WOE_LIVE_CLIENT_PASS")
	quit(0)
