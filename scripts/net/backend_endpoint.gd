extends RefCounted

const LOCAL_URL := "http://127.0.0.1:8787"
const RELEASE_URL := "https://entitywars.duckdns.org"

static func resolve(current: String = LOCAL_URL) -> String:
	return resolve_for(OS.has_feature("editor"), current, OS.get_environment("ENTITYWARS_BACKEND_URL"))

static func resolve_for(editor: bool, current: String, override: String) -> String:
	if not editor:
		return RELEASE_URL
	var configured := override.strip_edges().trim_suffix("/")
	if current == LOCAL_URL and not configured.is_empty():
		return configured
	return current
