extends SceneTree

func _initialize() -> void:
	var root_dir := OS.get_environment("REVISION_TEST_ROOT").replace("\\", "/").to_lower()
	assert(not root_dir.is_empty() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(root_dir + "/"))
	var reconcile := Reconcile.new()
	assert(reconcile.apply_server_state({"player_id": "a", "state_revision": 3, "wallet": {"essence": 30}}))
	assert(not reconcile.apply_server_state({"player_id": "a", "state_revision": 2, "wallet": {"essence": 20}}))
	assert(not reconcile.apply_server_state({"player_id": "a", "wallet": {"essence": 0}}))
	assert(reconcile.apply_server_state({"player_id": "a", "state_revision": 3, "wallet": {"essence": 0}}))
	assert(reconcile.get_state().wallet.essence == 30)
	assert(reconcile.apply_server_state({"player_id": "a", "state_revision": 4, "wallet": {"essence": 40}}))
	assert(reconcile.get_state().wallet.essence == 40)
	print("RECONCILE_REVISION_PASS")
	quit()
