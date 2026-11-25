extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var cache = root.get_node("MinigameInvitationCache")
	var social = root.get_node("SocialClient")
	social.friends["friend-id"] = "Friend Name"
	var now := 1700000000000
	cache.data = {"incoming":[{"invite_id":"one","room_id":"room","game_kind":"woe","inviter_id":"friend-id","expires_at":now + 90000}],"outgoing":[],"recent":[],"server_time_unix_ms":now}
	var notices = load("res://scripts/ui/minigame_invitation_notices.gd").new()
	root.add_child(notices)
	assert(notices._rows.size() == 1)
	var row: Node = notices._rows["one"]
	assert(row.get_meta("label").text.contains("Friend Name"))
	notices._refresh()
	assert(notices._rows.size() == 1 and notices._rows["one"] == row)
	var feedback := Label.new()
	root.add_child(feedback)
	notices._respond("woe", "one", true, "room", feedback)
	assert(feedback.text == notices.tr("INVITE_CLEARING_GUIDANCE"))
	cache.data.incoming = []
	notices._refresh()
	assert(notices._rows.is_empty())
	feedback.queue_free()
	notices.queue_free()
	print("MINIGAME_INVITATION_NOTICES_PASS")
	quit(0)
