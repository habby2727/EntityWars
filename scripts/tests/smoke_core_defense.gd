extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var client = root.get_node("CoreDefenseClient")
	var woe = root.get_node("WoeClient")
	var match_data := {"match_id":"m","status":"RUNNING","snapshot":{"kind":"core_defense","mode":"coop","players":[{"id":"a","team":"blue","slots":["neon"],"zeal":5},{"id":"b","team":"blue"}]}}
	assert(client.valid_match(match_data,"a") and not woe.valid_match(match_data,"a"))
	match_data.snapshot.kind = "woe"
	assert(not client.valid_match(match_data,"a") and woe.valid_match(match_data,"a"))
	assert(client.recovery_file() != woe.recovery_file())
	var renderer = load("res://scripts/ui/woe_unit.gd")
	assert(renderer != null)
	for id in renderer.IDS + renderer.ENEMY_IDS:
		var common := Rect2()
		var dirs := ["front"] if id in renderer.ENEMY_IDS else ["front", "back"]
		for direction in dirs:
			for i in range(1,4):
				var texture: AtlasTexture = renderer.frame(id, direction, i)
				assert(texture != null)
				if common.size == Vector2.ZERO: common = texture.region
				assert(texture.region == common)
		var node = renderer.new()
		root.add_child(node)
		var kind := "enemy" if id in renderer.ENEMY_IDS else "homunculus"
		node.setup({"id":7,"cardId":id,"assetId":id,"kind":kind,"team":"red" if kind == "enemy" else "blue","x":0,"y":0,"hp":10,"maxHp":10})
		var facing := "front" if kind == "enemy" else "back"
		assert(node.sprite.texture == renderer.frame(id,facing,1))
		node.attack()
		node._process(0.01)
		assert(node.sprite.texture == renderer.frame(id,facing,2))
		node.die()
		node._process(0.01)
		assert(node.sprite.texture == renderer.frame(id,facing,3))
		node.queue_free()
	var catalog = load("res://scripts/forest/forest_npcs.gd")
	var found := {}
	for npc in catalog.NPCS:
		if npc.id == "core_defense": found = npc
	assert(found.get("stationary", false) and found.get("position") == Vector2(800,450) and found.get("zone") == "duel_clearing")
	var zones: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/static/forest_zones.json"))
	for zone in zones.get("zones", []):
		if zone.id != "duel_clearing": continue
		var polygon := PackedVector2Array()
		for point in zone.polygon: polygon.append(Vector2(point[0],point[1]))
		assert(Geometry2D.is_point_in_polygon(found.position, polygon))
	assert(load("res://scripts/tests/smoke_core_defense_forest_e2e.gd") != null)
	assert(load("res://scripts/ui/core_defense_browser.gd") != null)
	assert(load("res://scripts/ui/minigame_invitations.gd") != null)
	assert(load("res://scenes/ui/CoreDefensePregame.tscn") != null)
	assert(load("res://scripts/ui/woe_arena.gd") != null)
	print("CORE_DEFENSE_SMOKE_PASS")
	quit(0)
