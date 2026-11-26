extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var catalog = load("res://scripts/forest/forest_npcs.gd")
	var found := {}
	for npc in catalog.NPCS:
		if npc.id == "war_of_entities": found = npc
	assert(not found.is_empty() and found.stationary and found.zone == "duel_clearing" and found.action_id == "woe")
	var npc = load("res://scripts/forest/forest_npc.gd").new()
	root.add_child(npc)
	var area := PackedVector2Array([Vector2(0,0),Vector2(1920,0),Vector2(1920,1080),Vector2(0,1080)])
	var protected: Array[Vector2] = []
	npc.setup(found, area, [], protected)
	assert(npc.get_node("Nameplate").text == "War of Elements")
	npc._process(100.0)
	assert(npc.position == found.position and not npc.moving)
	var browser = load("res://scripts/ui/woe_browser.gd").new()
	browser._status = Label.new()
	var emitted := [false]
	browser.admitted.connect(func(_room): emitted[0] = true)
	browser._complete({"code":200, "data":{"room_id":"forged", "members":[]}})
	assert(not emitted[0])
	browser._status.free()
	browser.free()
	assert(load("res://scripts/net/woe_client.gd") != null)
	assert(load("res://scripts/ui/woe_pregame.gd") != null)
	var scene := load("res://scenes/ui/WOEPregame.tscn") as PackedScene
	assert(scene != null)
	var arena: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/woe_arena.json"))
	assert(arena.laboratories.blue.left.x == 410 and arena.laboratories.blue.left.y == 860)
	assert(arena.laboratories.red.right.x == 1510 and arena.laboratories.red.right.y == 220)
	var client = root.get_node("WoeClient")
	var room := {"room_id":"room","mode":"1v1","status":"WAITING","members":[{"player_id":"a","seat":"blue:left"}]}
	assert(client.valid_room(room, "a") and not client.valid_room(room, "b"))
	room.mode = "2v2"
	assert(client.valid_room(room, "a"))
	room.members = []
	assert(not client.valid_room(room, "a"))
	assert(not SceneRouter.woe_context_valid())
	var pregame = load("res://scripts/ui/woe_pregame.gd").new()
	pregame._build()
	pregame._room = {"room_id":"room", "mode":"1v1", "status":"WAITING", "host_id":"a", "revision":2, "join_code":"CODE", "members":[{"player_id":"tester-abc", "display_name":"Test Player", "seat":"blue:left"}]}
	pregame._render()
	assert(pregame._seat_buttons.size() == 4)
	assert(pregame._seat_buttons["blue:left"].get_theme_stylebox("normal") is StyleBoxFlat)
	assert(pregame._start.get_theme_stylebox("normal") is StyleBoxFlat)
	for viewport_size in [Vector2(1920,1080), Vector2(1280,720), Vector2(960,540)]:
		pregame._canvas.size = viewport_size
		pregame._resize()
		var factor: Vector2 = viewport_size / Vector2(1920,1080)
		assert(pregame._seat_buttons["blue:left"].position.is_equal_approx(Vector2(260,785) * factor))
		assert(pregame._seat_buttons["red:right"].position.is_equal_approx(Vector2(1360,145) * factor))
	assert(pregame._copy_button.code == "CODE")
	pregame._copy_button._copy()
	assert(pregame._copy_button.copied_for > 0.0)
	pregame._copy_button._process(2.1)
	assert(pregame._copy_button.copied_for == 0.0)
	assert(pregame._seat_buttons["blue:right"].text.contains("Test Player"))
	pregame._room.mode = "2v2"
	pregame._render()
	assert(not pregame._seat_buttons["blue:right"].text.contains("Test Player"))
	assert(pregame._seat_buttons["blue:left"].text.contains("Test Player"))
	pregame._room.members.append({"player_id":"other", "display_name":null, "seat":null})
	pregame._room.join_code = null
	pregame._render()
	assert(not pregame._info.text.to_lower().contains("null") and not pregame._code_label.text.to_lower().contains("null"))
	assert(pregame._copy_button.disabled)
	pregame._room.members[0].display_name = "<null>"
	assert(pregame._display_name("tester-abc") == pregame.tr("INVITE_UNKNOWN_PLAYER"))
	pregame.free()
	npc.queue_free()
	print("WOE_SMOKE_PASS")
	quit(0)
