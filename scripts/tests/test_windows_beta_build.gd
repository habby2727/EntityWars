extends SceneTree

const Endpoint = preload("res://scripts/net/backend_endpoint.gd")
const ClientBuild = preload("res://scripts/net/client_build.gd")

func _initialize() -> void:
	var local := "http://127.0.0.1:8787"
	var release := "https://entitywars.duckdns.org"
	assert(Endpoint.resolve_for(true, local, "") == local)
	assert(Endpoint.resolve_for(true, local, "http://127.0.0.1:9999/") == "http://127.0.0.1:9999")
	assert(Endpoint.resolve_for(true, "http://localhost:9000", "http://127.0.0.1:9999") == "http://localhost:9000")
	assert(Endpoint.resolve_for(false, local, "http://attacker.invalid") == release)
	assert(Endpoint.resolve_for(false, "http://attacker.invalid", "") == release)
	assert(ClientBuild.header() == "X-EntityWars-Client-Build: 5504")
	for path in ["res://scripts/ui/auth_screen.gd", "res://scripts/net/backend_client.gd", "res://scripts/combat.gd"]:
		assert(FileAccess.get_file_as_string(path).contains('preload("res://scripts/net/backend_endpoint.gd").resolve('))
	var client := FileAccess.get_file_as_string("res://scripts/net/backend_client.gd").replace("\r\n", "\n")
	assert(client.contains('if not OS.has_feature("editor"):\n\t\treturn'))
	var flags := FileAccess.get_file_as_string("res://scripts/debug_flags.gd").replace("\r\n", "\n")
	assert(flags.contains('if not OS.has_feature("editor"):\n\t\treturn'))
	for path in ["res://data/types.json", "res://data/static/balance.json", "res://data/static/buildings.json", "res://data/static/resources.json", "res://data/static/solo_bosses.json", "res://data/static/experiments.json", "res://data/static/mutations.json"]:
		assert(FileAccess.file_exists(path), "Missing runtime data: " + path)
	print("Windows beta configuration tests passed")
	quit(0)
