extends SceneTree

class FakeBackend extends BackendClient:
	var sent: Array = []
	func _ready() -> void:
		pass
	func request_api(_method: String, path: String, body: Variant, _expect_state: bool = false, _recovery: bool = false, _replay: bool = false, _lease: String = "") -> String:
		if path == "/world/boss-hunts/start":
			sent.append(body.duplicate(true))
			return "start-%d" % sent.size()
		return ""
	func get_server_time_unix_ms() -> int:
		return 1000

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var zone = load("res://scenes/ui/WorldZoneChaos.tscn").instantiate()
	zone.get_node("BackendClient").auto_dev_login = false
	root.add_child(zone)
	await process_frame
	var fake := FakeBackend.new()
	fake.token = "fixture-token"
	fake._verified_player_id = "player-a"
	zone.add_child(fake)
	zone._backend = fake
	zone._hunt_selected = {"id":"hunt_mythic", "available":true}
	zone._hunt_rotation = 100
	zone._hunt_boundary = 2000
	zone._hunt_progress_key = zone._guardian_key()
	zone._hunt_progress_owner = "player-a"
	zone._hunt_progress = {"boss_unlocked":true, "personal_boss_available":true}
	zone._start_map_hunt()
	assert(fake.sent.size() == 1)
	var original: Dictionary = fake.sent[0].duplicate(true)
	# The server committed the request, but its response was lost.
	zone._on_api_completed("start-1", false, {"error":"network_error"})
	zone._hunt_rotation = 101
	zone._hunt_selected.available = false
	zone._hunt_boundary = 1
	zone._hunt_progress.personal_boss_available = false
	assert(zone._has_pending_hunt_start())
	# A token change keeps A's unresolved request without exposing it to B.
	zone._on_auth_changed("")
	zone._hunt_selected = {"id":"hunt_mythic", "available":false}
	fake._verified_player_id = "player-b"
	assert(not zone._has_pending_hunt_start())
	fake._verified_player_id = "player-a"
	assert(zone._has_pending_hunt_start())
	zone._start_map_hunt()
	assert(fake.sent.size() == 2 and fake.sent[1] == original)
	assert(zone._hunt_action_id == original.client_action_id)
	# A duplicate server response confirms the original session.
	zone._on_api_completed("start-2", true, {"session_id":"committed", "status":"EXPIRED", "duplicate":true})
	assert(zone._hunt_pending_start_payload.is_empty() and zone._hunt_action_id.is_empty())
	print("PASS hunt start replay preserves payload across rotation")
	quit(0)
