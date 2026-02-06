extends Node
class_name NetQueueTests

const TEST_BACKEND_URL := "http://127.0.0.1:8787"

var _client: BackendClient

func _ready() -> void:
	_client = BackendClient.new()
	_client.base_url = TEST_BACKEND_URL
	add_child(_client)
	_client.action_queued.connect(_on_action_queued)
	_client.action_confirmed.connect(_on_action_confirmed)
	_client.state_updated.connect(_on_state_updated)
	_run_manual()

func _run_manual() -> void:
	print("NetQueueTests: With backend OFF, queue should grow.")
	_client.set_token("dev-token-placeholder")
	_client.send_action({"action_type": "UPGRADE_BUILDING", "payload": {"building_id": "lab_th"}})
	await get_tree().create_timer(1.0).timeout
	print("Pending queue size: %s" % _client.get_pending_count())
	print("NetQueueTests: Start backend and call flush_queue() to drain.")
	# Manual: start backend, then call _client.flush_queue() in the debugger.

func _on_action_queued(action_id: String, _key: String, reason: String) -> void:
	print("Queued action %s (reason: %s)" % [action_id, reason])

func _on_action_confirmed(action_id: String) -> void:
	print("Confirmed action %s" % action_id)

func _on_state_updated(_state: Dictionary) -> void:
	print("State updated from server.")
