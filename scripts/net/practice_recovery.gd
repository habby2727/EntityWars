extends RefCounted
const FILE := "user://practice_recovery.cfg"

static func key() -> String:
	return JSON.stringify([str(ConnectionGate.base_url).strip_edges().trim_suffix("/"), str(ConnectionGate.player_id)]).sha256_text()

static func read() -> Dictionary:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(FILE): return {}
	if cfg.load(FILE) != OK: return {"error": "unreadable"}
	var value: Variant = cfg.get_value("players", key(), {})
	return value if value is Dictionary else {"error": "invalid"}

static func write(value: Dictionary) -> bool:
	if str(ConnectionGate.player_id).is_empty() or str(ConnectionGate.base_url).strip_edges().is_empty(): return false
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(FILE) and cfg.load(FILE) != OK: return false
	if value.is_empty(): cfg.erase_section_key("players", key())
	else: cfg.set_value("players", key(), value)
	return cfg.save(FILE) == OK
