extends Node

signal snapshot(state: Dictionary, peers: Array)
signal correction(state: Dictionary)
signal peer_joined(player: Dictionary)
signal peer_moved(player_id: String, seq: int, point: Vector2, facing: int)
signal peer_cosmetic(player_id: String, summoner_id: String)
signal peer_left(player_id: String)
signal disconnected

const ClientBuild := preload("res://scripts/net/client_build.gd")
const Player := preload("res://scripts/forest/forest_player.gd")
var zones: Array = []
var socket: WebSocketPeer
var entered := false
var zone_id := ""
var seq := 0
var _owner := ""
var _token := ""
var _generation := -1
var _summoner := ""
var _peers := {}
var _retry_at := 0
var _attempt := 0
var _connect_at := 0
var _ping_at := 0
var _pong_deadline := 0
var _closing := false
var _last_point := Vector2.INF
var _last_facing := -1
var _last_sent := 0
var _welcome_deadline := 0
var _portal_seq := 0
var _last_correction := -1

func configure(catalog: Array, selected: String) -> void:
	zones = catalog
	_summoner = selected
	if _eligible():
		_connect_socket()

func _eligible() -> bool:
	return not zones.is_empty() and _summoner in Player.FILES and not ConnectionGate.debug_lab_navigation_allowed() and ConnectionGate.state == ConnectionGate.State.CONNECTED and not str(ConnectionGate.player_id).is_empty() and not str(ConnectionGate.token).is_empty() and SceneRouter.forest_selected_summoner() == _summoner

func _matches() -> bool:
	return _eligible() and ConnectionGate.player_id == _owner and ConnectionGate.token == _token and ConnectionGate._generation == _generation

func _connect_socket() -> void:
	if not _eligible() or _closing:
		return
	var base := str(ConnectionGate.base_url).strip_edges().trim_suffix("/")
	if base.is_empty():
		_retry_at = Time.get_ticks_msec() + 30000
		return
	if base.contains("?") or base.contains("#"):
		_retry_at = Time.get_ticks_msec() + 30000
		return
	if base.begins_with("https://"):
		base = "wss://" + base.substr(8)
	elif base.begins_with("http://"):
		base = "ws://" + base.substr(7)
	else:
		_retry_at = Time.get_ticks_msec() + 30000
		return
	_owner = ConnectionGate.player_id
	_token = ConnectionGate.token
	_generation = ConnectionGate._generation
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 262144
	socket.outbound_buffer_size = 65536
	socket.handshake_headers = PackedStringArray(["Authorization: Bearer " + _token, ClientBuild.header()])
	seq = 0
	entered = false
	_last_point = Vector2.INF
	_last_facing = -1
	_connect_at = Time.get_ticks_msec()
	if not base.ends_with("/forest/ws"):
		base += "/forest/ws"
	_welcome_deadline = Time.get_ticks_msec() + 12000
	_pong_deadline = 0
	_portal_seq = 0
	_last_correction = -1
	if socket.connect_to_url(base) != OK:
		_drop()

func _process(_delta: float) -> void:
	if _closing:
		return
	if socket != null and not _matches():
		_drop(false)
	if socket == null:
		if _eligible() and Time.get_ticks_msec() >= _retry_at:
			_connect_socket()
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED or (state == WebSocketPeer.STATE_CONNECTING and Time.get_ticks_msec() - _connect_at > 8000):
		_drop()
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	if not entered and Time.get_ticks_msec() >= _welcome_deadline:
		_drop()
		return
	if not entered and _connect_at > 0:
		_send({"type":"enter", "summoner_id":_summoner})
		_connect_at = 0
		_ping_at = Time.get_ticks_msec()
	if socket.get_available_packet_count() > 128:
		_drop()
		return
	for i in mini(socket.get_available_packet_count(), 32):
		var packet := socket.get_packet()
		if not socket.was_string_packet() or packet.size() > 65536:
			_drop()
			return
		var parsed = JSON.parse_string(packet.get_string_from_utf8())
		if parsed is Dictionary:
			_receive(parsed)
			if socket == null:
				return
	if _pong_deadline > 0 and Time.get_ticks_msec() >= _pong_deadline:
		_drop()
		return
	if _pong_deadline == 0 and Time.get_ticks_msec() - _ping_at >= 20000:
		if _send({"type":"ping"}): _pong_deadline = Time.get_ticks_msec() + 10000
		_ping_at = Time.get_ticks_msec()

func _send(message: Dictionary) -> bool:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN or not _matches() or socket.get_current_outbound_buffered_amount() > 32768:
		return false
	message["v"] = 1
	return socket.send_text(JSON.stringify(message)) == OK

func move(point: Vector2, facing: int, force: bool = false) -> bool:
	if _closing or not entered or not point.is_finite() or facing not in [0, 1, 2, 3]:
		return false
	if point.distance_to(_last_point) < 0.1 and facing == _last_facing:
		return true
	var now := Time.get_ticks_msec()
	if not force and now - _last_sent < 200:
		return false
	if seq >= 2147483647:
		_drop()
		return false
	seq += 1
	if not _send({"type":"move", "seq":seq, "x":point.x, "y":point.y, "facing":facing}):
		return false
	_last_point = point
	_last_facing = facing
	_last_sent = now
	return true

func portal(direction: String, point: Vector2, foot: Vector2, facing: int) -> bool:
	if _closing or not entered or direction not in ["north", "south", "east", "west"] or not point.is_finite():
		return false
	if not move(foot, facing, true) or seq >= 2147483647:
		return false
	seq += 1
	if not _send({"type":"portal", "seq":seq, "direction":direction, "crossing_x":point.x, "crossing_y":point.y}):
		return false
	_portal_seq = seq
	return true

func handoff(kind: String) -> bool:
	if _closing:
		return false
	var sent := kind in ["leave", "suspend"] and entered and _send({"type":kind})
	_closing = true
	entered = false
	_peers.clear()
	disconnected.emit()
	var acknowledged := false
	var deadline := Time.get_ticks_msec() + 1000
	while sent and socket != null and _matches() and Time.get_ticks_msec() < deadline:
		socket.poll()
		if socket.get_available_packet_count() > 128:
			break
		for i in mini(socket.get_available_packet_count(), 32):
			var packet := socket.get_packet()
			if socket.was_string_packet() and packet.size() <= 65536:
				var message = JSON.parse_string(packet.get_string_from_utf8())
				if message is Dictionary and message.get("v") == 1 and message.get("type") == "handoff_ack" and message.get("kind") == kind:
					acknowledged = true
					break
		if acknowledged or socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			break
		await get_tree().process_frame
	shutdown()
	return acknowledged

func shutdown() -> void:
	_closing = true
	if socket != null:
		socket.close(1000, "forest exit")
		socket.poll()
		socket = null
	entered = false
	_peers.clear()

func _drop(retry: bool = true) -> void:
	if socket != null:
		socket.close()
		socket = null
	entered = false
	zone_id = ""
	_portal_seq = 0
	_peers.clear()
	disconnected.emit()
	_attempt = mini(_attempt + 1, 6) if retry else 0
	_retry_at = Time.get_ticks_msec() + mini(30000, 1000 * (1 << _attempt))

func _integer(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

func _valid_position(id: String, x, y) -> bool:
	if not (x is int or x is float) or not (y is int or y is float) or not is_finite(float(x)) or not is_finite(float(y)):
		return false
	var point := Vector2(float(x), float(y))
	for zone in zones:
		if zone.id == id:
			if Geometry2D.is_point_in_polygon(point, zone.polygon):
				return true
			for i in zone.polygon.size():
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point, zone.polygon[i], zone.polygon[(i + 1) % zone.polygon.size()])) < 0.01:
					return true
	return false

func _player(value, expected_zone: String) -> bool:
	return value is Dictionary and value.get("player_id") is String and value.player_id.length() > 0 and value.player_id.length() <= 128 and value.get("display_name") is String and value.display_name.length() > 0 and value.display_name.length() <= 128 and value.get("zone_id") == expected_zone and value.get("summoner_id") in Player.FILES and _integer(value.get("facing"), 0, 3) and _valid_position(expected_zone, value.get("x"), value.get("y"))

func _snapshot_peers(value, zone: String) -> bool:
	if not value is Array or value.size() > 128:
		return false
	var found := {}
	for peer in value:
		if not _player(peer, zone) or peer.player_id == _owner or found.has(peer.player_id):
			return false
		found[peer.player_id] = -1
	_peers = found
	return true

func _receive(m: Dictionary) -> void:
	if not _matches() or m.get("v") != 1 or not m.get("type") is String:
		return
	match m.type:
		"pong":
			_pong_deadline = 0
		"welcome":
			var self_state = m.get("self")
			if entered or not self_state is Dictionary or not self_state.get("zone_id") is String or not _player(self_state, self_state.zone_id) or self_state.player_id != _owner or self_state.summoner_id != _summoner or not _snapshot_peers(m.get("peers"), self_state.zone_id):
				return
			zone_id = self_state.zone_id
			entered = true
			_attempt = 0
			_last_point = Vector2(self_state.x, self_state.y)
			_last_facing = int(self_state.facing)
			snapshot.emit(self_state, m.peers)
		"zone":
			if not entered or _portal_seq == 0 or not m.get("zone_id") is String or not _integer(m.get("facing"), 0, 3) or not _valid_position(m.zone_id, m.get("x"), m.get("y")) or not _snapshot_peers(m.get("peers"), m.zone_id):
				return
			_portal_seq = 0
			zone_id = m.zone_id
			_last_point = Vector2(m.x, m.y)
			_last_facing = int(m.facing)
			snapshot.emit(m, m.peers)
		"correction":
			if not entered or not m.get("zone_id") is String or m.zone_id != zone_id or not _integer(m.get("seq"), 0, 2147483647) or int(m.seq) <= _last_correction or int(m.seq) > seq or (_portal_seq > 0 and int(m.seq) < _portal_seq) or not _integer(m.get("facing"), 0, 3) or not _valid_position(zone_id, m.get("x"), m.get("y")):
				return
			_last_correction = int(m.seq)
			_portal_seq = 0
			_last_point = Vector2(m.x, m.y)
			_last_facing = int(m.facing)
			correction.emit(m)
		"peer_join":
			var player = m.get("player")
			if entered and _player(player, zone_id) and player.player_id != _owner and not _peers.has(player.player_id) and _peers.size() < 128:
				_peers[player.player_id] = -1
				peer_joined.emit(player)
		"peer_move":
			var id = m.get("player_id")
			if entered and id is String and _peers.has(id) and _integer(m.get("seq"), 0, 2147483647) and int(m.seq) > _peers[id] and _integer(m.get("facing"), 0, 3) and _valid_position(zone_id, m.get("x"), m.get("y")):
				_peers[id] = int(m.seq)
				peer_moved.emit(id, int(m.seq), Vector2(m.x, m.y), int(m.facing))
		"peer_cosmetic":
			var id = m.get("player_id")
			if entered and id is String and _peers.has(id) and m.get("summoner_id") in Player.FILES:
				peer_cosmetic.emit(id, m.summoner_id)
		"peer_leave":
			var id = m.get("player_id")
			if entered and id is String and _peers.erase(id):
				peer_left.emit(id)
