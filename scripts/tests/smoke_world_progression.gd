extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		for world in ["Chaos", "Corrupted", "Crystal"]:
			var zone = load("res://scenes/ui/WorldZone%s.tscn" % world).instantiate()
			zone.get_node("BackendClient").auto_dev_login = false
			zone.get_node("BackendClient").base_url = "http://127.0.0.1:1"
			root.add_child(zone)
			await process_frame
			var entries: Array = zone.WORLD_ART["zone_" + world.to_lower()]
			assert(zone._world_stage.visible)
			assert(zone._actor_roster.get_child_count() == entries.size())
			var gate = root.get_node("ConnectionGate")
			gate._timer.stop()
			gate.state = gate.State.CONNECTED
			gate._layer.hide()
			await process_frame
			var actors: Array = zone._actor_roster.get_children()
			for actor in actors:
				for other in actors:
					if actor != other:
						assert(not actor.get_global_rect().intersects(other.get_global_rect()))
				var point: Vector2 = root.get_canvas_transform() * actor.get_global_rect().get_center()
				var motion := InputEventMouseMotion.new()
				motion.position = point
				motion.global_position = point
				root.push_input(motion, true)
				var press := InputEventMouseButton.new()
				press.position = point
				press.global_position = point
				press.button_index = MOUSE_BUTTON_LEFT
				press.pressed = true
				root.push_input(press, true)
				var release := InputEventMouseButton.new()
				release.position = point
				release.global_position = point
				release.button_index = MOUSE_BUTTON_LEFT
				root.push_input(release, true)
				await process_frame
				assert(zone._world_modal.visible and zone._hunt_selected.get("appearance_id") == actor.get_meta("appearance_id"), "actor=%s hovered=%s point=%s" % [actor.name, root.gui_get_hovered_control(), point])
				zone._world_modal.visible = false
			for i in entries.size():
				zone._select_common_roster(i + 1)
				assert(zone._hunt_selected.appearance_id == entries[i])
				assert(zone._boss_portrait.texture != null)
				zone._world_modal.visible = false
			zone._apply_appearance_seed(17)
			assert(zone._world_stage.visible)
			assert(zone._actor_roster.get_child_count() == entries.size())
			zone._backend.token = "fixture"
			zone._backend._verified_player_id = "player"
			var special := {"id": "hunt_epic", "tier": "epic", "name": "Temporal Warden", "texture_id": "boss_temporal", "available": false}
			zone._hunt_schedule = [special]
			zone._return_encounter = {"zone_id": zone._get_zone_id(), "player_id": "player", "category": "special", "hunt_id": "hunt_epic"}
			zone._restore_encounter_view()
			assert(zone._map_displayed_boss.id == "hunt_epic")
			assert(not zone._world_stage.visible and zone._preview_stage.get_node_or_null("NearbyHunt") == null)
			zone._hunt_progress_key = zone._guardian_key()
			zone._hunt_progress_owner = "player"
			zone._hunt_progress = {"boss_unlocked": false, "guardians": [{"guardian_id": "defeated", "name": "Defeated", "tier": "common", "texture_id": "res://assets/lab/bosses/%s_zone_common/%s.png" % [world.to_lower(), entries[0]], "defeated": true}, {"guardian_id": "remaining", "name": "Remaining", "tier": "common", "texture_id": "res://assets/lab/bosses/%s_zone_common/%s.png" % [world.to_lower(), entries[1]], "defeated": false}]}
			zone._show_map_hunt(special)
			assert(zone._preview_stage.get_node_or_null("Actor_defeated") == null)
			assert(zone._preview_stage.get_node_or_null("Actor_remaining") != null)
			zone._apply_appearance_seed(88)
			assert(zone._map_displayed_boss.id == "hunt_epic" and not zone._world_stage.visible)
			assert(zone._preview_stage.get_node_or_null("Actor_remaining") != null)
			zone._return_encounter = {"zone_id": zone._get_zone_id(), "player_id": "other", "category": "special", "hunt_id": "hunt_rare"}
			zone._restore_encounter_view()
			assert(zone._return_encounter.is_empty() and zone._map_displayed_boss.id == "hunt_epic")
			zone.queue_free()
			await process_frame
	print("PASS world progression navigation")
	quit(0)
