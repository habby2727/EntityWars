extends SceneTree

class FakeBackend extends BackendClient:
	var replays: Array[bool] = []
	func request_api(_method: String, _path: String, _body: Variant, _expect_state: bool = false, _recovery: bool = false, replay: bool = false) -> String:
		replays.append(replay)
		return "request-%d" % replays.size()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ranked: Node = (load("res://scripts/ui/ranked_combat.gd") as Script).new()
	var client := FakeBackend.new()
	client.token = "token"
	client._verified_player_id = "owner"
	ranked.backend = client
	ranked.chat_send = Button.new()
	ranked.chat_pending = {"client_message_id": "new-chat", "text": "hello"}
	ranked.next_poll = 100.0
	ranked._process(0.0)
	if client.replays != [false]:
		_fail("deferred new chat was marked as replay")
		return
	ranked.request_id = ""
	ranked._process(0.0)
	if client.replays != [false, true]:
		_fail("retransmitted chat was not marked as replay")
		return
	ranked.chat_send.free()
	ranked.free()
	client._debug_flags.free()
	client.free()
	print("PASS PvP new chat and retransmission flags")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
