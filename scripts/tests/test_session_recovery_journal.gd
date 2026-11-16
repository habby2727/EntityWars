extends SceneTree

const Journal := preload("res://scripts/net/session_recovery_journal.gd")

func _initialize() -> void:
	var root := OS.get_environment("JOURNAL_TEST_ROOT").replace("\\", "/").to_lower()
	if root.is_empty() or not OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(root + "/"):
		_fail("isolated user directory required")
		return
	var journal := Journal.new()
	assert(journal.set_identity("owner"))
	assert(journal.remove())
	assert(journal.load_entry().is_empty())
	var entry := {"version": 1, "mode": "hunt", "player_id": "owner", "session_id": "session", "context": {"hunt_id": "hunt"}, "pending_kind": "turn", "payload": {"session_id": "session", "client_action_id": "action", "expected_revision": 1, "decision": {"turn": 1, "spell_id": "spell"}}}
	assert(journal.save_entry(entry))
	var loaded := journal.load_entry()
	if JSON.stringify(loaded) != JSON.stringify(JSON.parse_string(JSON.stringify(entry))):
		_fail("round trip differs: %s" % JSON.stringify(loaded))
		return
	var wrong := entry.duplicate(true)
	wrong.player_id = "other"
	assert(not journal.save_entry(wrong))
	assert(journal.set_identity("other"))
	assert(journal.load_entry().get("error") == "journal_owner_mismatch")
	assert(journal.set_identity("owner"))
	wrong = entry.duplicate(true)
	wrong.payload["token"] = "secret"
	assert(not journal.save_entry(wrong))
	wrong = entry.duplicate(true)
	wrong.player_id = "other"
	var file := FileAccess.open("user://session_recovery_%s.json" % "owner".sha256_text(), FileAccess.WRITE)
	file.store_string(JSON.stringify(wrong))
	file.close()
	assert(journal.load_entry().has("error"))
	file = FileAccess.open("user://session_recovery_%s.json" % "owner".sha256_text(), FileAccess.WRITE)
	file.store_string("{invalid")
	file.close()
	assert(journal.load_entry().has("error"))
	assert(journal.remove())
	print("PASS recovery journal persistence, ownership and malformed data")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
