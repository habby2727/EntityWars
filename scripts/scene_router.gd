extends Node
class_name SceneRouter

const SCENE_MAIN_MENU := "res://scenes/MainMenu.tscn"
const SCENE_SETTINGS := "res://scenes/ui/Settings.tscn"
const SCENE_SUMMONER_SELECTION := "res://scenes/ui/SummonerSelection.tscn"
const SCENE_WOE_PREGAME := "res://scenes/ui/WOEPregame.tscn"
const SCENE_WOE_ARENA := "res://scenes/ui/WOEArena.tscn"
const SCENE_FOREST_WORLD := "res://scenes/forest/ForestWorld.tscn"
const FOREST_SUMMONERS := ["wizard", "witch", "cyberghost"]
const FOREST_PREFERENCES := "user://forest_summoners.cfg"
const SCENE_LAB_HUB := "res://scenes/ui/LabHub.tscn"
const SCENE_LAB_STRUCTURES := "res://scenes/ui/LabStructures.tscn"
const SCENE_INVENTORY := "res://scenes/ui/Inventory.tscn"
const SCENE_TRADE_HALL := "res://scenes/ui/TradeHall.tscn"
const SCENE_EXPEDITIONS := "res://scenes/ui/Expeditions.tscn"
const SCENE_WORLD_GATE := "res://scenes/ui/WorldGate.tscn"
const SCENE_WORLD_ZONE := "res://scenes/ui/WorldZone.tscn"
const SCENE_WORLD_ZONE_CORRUPTED := "res://scenes/ui/WorldZoneCorrupted.tscn"
const SCENE_WORLD_ZONE_CRYSTAL := "res://scenes/ui/WorldZoneCrystal.tscn"
const SCENE_WORLD_ZONE_CHAOS := "res://scenes/ui/WorldZoneChaos.tscn"
const SCENE_COMBAT := "res://scenes/Combat.tscn"
const SCENE_LOADOUT := "res://scenes/LoadoutGrid.tscn"
const SCENE_TOP_PLAYERS := "res://scenes/ui/TopPlayers.tscn"

static var _woe_context := {}
static var _forest_summoner := ""
static var _forest_owner := ""
static var _forest_return := {}
static var _forest_restore := {}
static var _forest_change := {}
const FOREST_ZONES := preload("res://scripts/forest/forest_zones.gd")
const FOREST_ACTIONS := ["forge", "lab", "expeditions", "world_gate", "ranked", "guide_inventory", "guide_trade"]

static var _next_lab_focus_id: String = ""
static var _next_inventory_tab: String = ""
static var _inventory_return_to_lab := false
static var _next_world_zone_id: String = ""
static var _next_world_boss_id: String = ""
static var _combat_seal_mode := "attack"
static var _solo_hunt_context := {}
static var _world_encounter_return := {}
static var _hunt_loadout_active := false
static var _hunt_loadout := {}
static var _debug_guardian_wins := {}
static var _dungeon_context := {}
static var _ranked_context := {}
static var _spectator_context := {}
static var _friendly_context := {}
static var _expedition_context := {}
static var _expedition_forfeit_notice := false
static var logout_notice := ""

static func clear_account_context() -> void:
	_clear_forest_return()
	_woe_context.clear()
	_forest_summoner = ""
	_forest_owner = ""
	_next_lab_focus_id = ""
	_next_inventory_tab = ""
	_inventory_return_to_lab = false
	_next_world_zone_id = ""
	_next_world_boss_id = ""
	_combat_seal_mode = "attack"
	_world_encounter_return.clear()
	_solo_hunt_context.clear()
	_hunt_loadout_active = false
	_hunt_loadout.clear()
	_debug_guardian_wins.clear()
	_dungeon_context.clear()
	_ranked_context.clear()
	_spectator_context.clear()
	_friendly_context.clear()
	_expedition_context.clear()
	_expedition_forfeit_notice = false

# Called only after authenticated room admission and the Forest handoff.
static func begin_woe(room: Dictionary, zone_id: String, foot: Vector2, facing: int) -> void:
	var tree := _get_tree()
	var owner := _forest_verified_owner()
	if tree == null or not is_instance_valid(tree.current_scene) or tree.current_scene.scene_file_path != SCENE_FOREST_WORLD or not _forest_modes_safe(): return
	var client := tree.root.get_node("WoeClient")
	var is_match: bool = client.valid_match(room, owner)
	if not is_match and not client.valid_room(room, owner): return
	if not tree.current_scene.forest_action_allowed("woe", zone_id, foot, facing): return
	var context := {"verified_owner":owner, "summoner_id":forest_selected_summoner(), "zone_id":zone_id, "foot_position":foot, "facing":facing, "debug":false, "identity_generation":_connection_gate()._generation}
	if not _valid_forest_context(context): return
	_forest_return = context
	_forest_restore.clear()
	_woe_context = {"room_id":str(room.get("room_id", "")), "player_id":owner, "generation":_connection_gate()._generation, "base_url":str(_connection_gate().base_url)}
	if is_match:
		_woe_context.match_id = str(room.match_id)
		client.save_match(str(room.match_id))
		_go_to(SCENE_WOE_ARENA, "WOEArena")
	else:
		_go_to(SCENE_WOE_PREGAME, "WOEPregame")

static func woe_context_valid() -> bool:
	return not _woe_context.is_empty() and str(_woe_context.get("player_id", "")) == _forest_verified_owner() and int(_woe_context.get("generation", -1)) == int(_connection_gate()._generation) and str(_woe_context.get("base_url", "")) == str(_connection_gate().base_url) and (bool(_woe_context.get("startup", false)) or forest_return_available())

# Called after a server-confirmed STARTED room response for this member.
static func enter_woe_match(room: Dictionary) -> void:
	if not woe_context_valid() or str(room.get("status", "")) != "STARTED": return
	var tree := _get_tree()
	if tree == null or not is_instance_valid(tree.current_scene) or tree.current_scene.scene_file_path != SCENE_WOE_PREGAME: return
	var client := tree.root.get_node("WoeClient")
	if not client.valid_room(room, str(_woe_context.player_id)) or str(room.get("room_id", "")) != str(_woe_context.room_id): return
	var match_id := str(room.get("match_id", ""))
	if match_id.is_empty() or _woe_context.has("match_id"): return
	_woe_context.match_id = match_id
	client.save_match(match_id)
	_go_to(SCENE_WOE_ARENA, "WOEArena")

# Startup recovery has no Forest position to restore; membership is checked by the server.
static func recover_woe_after_startup(match: Dictionary) -> bool:
	var tree := _get_tree()
	if tree == null or not is_instance_valid(tree.current_scene) or tree.current_scene.scene_file_path != SCENE_MAIN_MENU or not _forest_modes_safe(): return false
	var owner := _forest_verified_owner()
	var client := tree.root.get_node("WoeClient")
	if owner.is_empty() or not _woe_context.is_empty() or not client.valid_match(match, owner): return false
	if str(match.match_id) != client.saved_match(): return false
	_woe_context = {"room_id":"", "match_id":str(match.match_id), "player_id":owner, "generation":_connection_gate()._generation, "base_url":str(_connection_gate().base_url), "startup":true}
	_go_to(SCENE_WOE_ARENA, "WOEArena")
	return true

static func finish_woe_safely() -> void:
	if woe_context_valid() and forest_return_available():
		finish_woe()
	else:
		_woe_context.clear()
		_clear_forest_return()
		go_to_lab_hub()

static func finish_woe() -> void:
	if not woe_context_valid(): return
	_woe_context.clear()
	_forest_restore = _forest_return.duplicate(true)
	_forest_return.clear()
	_go_to(SCENE_FOREST_WORLD, "ForestWorld")

static func begin_friendly_preparation(invite: Dictionary, zone_id: String, foot: Vector2, facing: int, recovery_match: String = "") -> void:
	var gate := _connection_gate()
	var tree := _get_tree()
	if tree == null or not is_instance_valid(tree.current_scene) or tree.current_scene.scene_file_path != SCENE_FOREST_WORLD or not _forest_modes_safe():
		return
	var owner := _forest_verified_owner()
	var id := str(invite.get("invite_id", ""))
	if owner.is_empty() or id.is_empty() or str(invite.get("status", "")) != "ACCEPTED" or owner not in [str(invite.get("challenger_id", "")), str(invite.get("recipient_id", ""))]:
		return
	var context := {"verified_owner":owner, "summoner_id":forest_selected_summoner(), "zone_id":zone_id, "foot_position":foot, "facing":facing, "debug":false, "identity_generation":gate._generation}
	if not _valid_forest_context(context): return
	_forest_return = context
	_forest_restore.clear()
	_friendly_context = {"player_id":owner, "generation":gate._generation, "invite_id":id, "opponent":str(invite.get("recipient_name", "")) if owner == str(invite.get("challenger_id", "")) else str(invite.get("challenger_name", "")), "expires_at":int(invite.get("expires_at", 0))}
	if recovery_match.is_empty():
		_go_to(SCENE_LOADOUT, "FriendlyLoadout")
	else:
		go_to_friendly_combat(id, recovery_match)

# Only a server-confirmed invitation or active match may enter here. The caller
# has already bound the invitation to this account and backend URL.
static func recover_friendly_after_startup(invite: Dictionary, match_id: String = "") -> bool:
	var tree := _get_tree()
	if tree == null or not is_instance_valid(tree.current_scene) or tree.current_scene.scene_file_path != SCENE_MAIN_MENU or not _forest_modes_safe(): return false
	var owner := _forest_verified_owner()
	var id := str(invite.get("invite_id", ""))
	if owner.is_empty() or id.is_empty() or not _friendly_context.is_empty(): return false
	if match_id.is_empty() and (str(invite.get("status", "")) != "ACCEPTED" or owner not in [str(invite.get("challenger_id", "")), str(invite.get("recipient_id", ""))]): return false
	_friendly_context = {"player_id":owner, "generation":_connection_gate()._generation, "invite_id":id, "opponent":str(invite.get("recipient_name", "")) if owner == str(invite.get("challenger_id", "")) else str(invite.get("challenger_name", "")), "expires_at":int(invite.get("expires_at", 0))}
	if match_id.is_empty():
		_go_to(SCENE_LOADOUT, "FriendlyLoadoutRecovery")
	else:
		go_to_friendly_combat(id, match_id)
	return true

static func go_to_friendly_combat(invite_id: String, match_id: String) -> void:
	if _connection_gate().blocked() or str(_friendly_context.get("invite_id", "")) != invite_id or str(_friendly_context.get("player_id", "")) != _forest_verified_owner() or int(_friendly_context.get("generation", -1)) != _connection_gate()._generation or match_id.is_empty(): return
	_ranked_context = {"match_id":match_id, "kind":"friendly", "player_id":_forest_verified_owner()}
	_go_to(SCENE_COMBAT, "FriendlyCombat")

static func finish_friendly() -> void:
	var duel := _get_tree().root.get_node_or_null("DuelClient")
	if duel != null: duel.clear_recovery()
	_ranked_context.clear()
	_friendly_context.clear()
	if forest_return_available():
		_forest_restore = _forest_return.duplicate(true)
		_forest_return.clear()
		_go_to(SCENE_FOREST_WORLD, "ForestWorld")
	else:
		go_to_lab_hub()

static func go_to_expedition_loadout(player_id: String) -> void:
	_expedition_context = {"player_id": player_id, "loadout": true}
	_go_to(SCENE_LOADOUT, "LoadoutGrid")

static func begin_spectating(context: Dictionary) -> void:
	var gate := _connection_gate()
	if gate.blocked() or str(context.get("player_id", "")) != str(gate.player_id) or int(context.get("generation", -1)) != int(gate._generation) or not _forest_modes_safe(): return
	_spectator_context = context.duplicate(true)
	_go_to(SCENE_EXPEDITIONS if context.get("mode") == "expedition" else SCENE_COMBAT, "Spectator")

static func finish_spectating() -> void:
	var tree := _get_tree()
	var spectator = tree.root.get_node_or_null("SpectatorClient") if tree != null and tree.root != null else null
	if _spectator_context.is_empty():
		if spectator != null: spectator.leave()
		go_to_lab_hub()
		return
	var origin := str(_spectator_context.get("origin", ""))
	if spectator != null: spectator.leave()
	_spectator_context.clear()
	if forest_return_available():
		_forest_restore = _forest_return.duplicate(true)
		_forest_return.clear()
		_go_to(SCENE_FOREST_WORLD, "ForestWorld")
	elif not origin.is_empty() and ResourceLoader.exists(origin):
		_go_to(origin, "SpectatorReturn")
	else: go_to_lab_hub()

static func go_to_ranked_combat(match_id: String) -> void:
	if _connection_gate().blocked():
		return
	_ranked_context = {"match_id": match_id}
	_go_to(SCENE_COMBAT, "Combat")

static func go_to_practice_combat(match_id: String, owner: String) -> void:
	if _connection_gate().blocked() or owner.is_empty() or owner != str(_connection_gate().player_id):
		return
	_ranked_context = {"match_id": match_id, "kind": "practice", "player_id": owner, "base_url": str(_connection_gate().base_url)}
	_go_to(SCENE_COMBAT, "Combat")

static func go_to_debug_ranked_combat() -> void:
	if not _connection_gate().debug_lab_navigation_allowed():
		return
	_ranked_context = {"debug_visual": true}
	_go_to(SCENE_COMBAT, "Combat")

static func go_to_dungeon_loadout(run_id: String, player_id: String) -> void:
	_dungeon_context["run_id"] = run_id
	_dungeon_context["player_id"] = player_id
	_go_to(SCENE_LOADOUT, "LoadoutGrid")

static func go_to_dungeon_combat() -> void:
	_go_to(SCENE_COMBAT, "Combat")

static func return_from_dungeon() -> void:
	if _connection_gate().blocked():
		return
	_dungeon_context.clear()
	go_to_lab_structures("sync_nexus")

static func debug_guardian_key(zone: String, tier_index: int, encounter_id: String) -> String:
	return "%s:%d:%s" % [zone, tier_index, encounter_id]

static func go_to_solo_hunt(hunt_id: String, rotation_key: int, display_texture_id: String = "", session_id: String = "", visual_zone_id: String = "", debug_visual: Dictionary = {}, replaced_session_id: String = "", return_view: Dictionary = {}) -> void:
	if _connection_gate().blocked():
		return
	_solo_hunt_context = {"hunt_id": hunt_id, "rotation_key": rotation_key, "display_texture_id": display_texture_id, "session_id": session_id, "visual_zone_id": visual_zone_id if visual_zone_id in ["zone_chaos", "zone_corrupted", "zone_crystal"] else ""}
	_solo_hunt_context["return_view"] = return_view.duplicate(true)
	if not replaced_session_id.is_empty():
		_solo_hunt_context["replaced_session_id"] = replaced_session_id
	if session_id.is_empty() and not debug_visual.is_empty():
		_solo_hunt_context["debug_visual"] = debug_visual.duplicate(true)
	_hunt_loadout_active = true
	_hunt_loadout.clear()
	_go_to(SCENE_LOADOUT, "LoadoutGrid")

static func cancel_hunt_loadout() -> void:
	if _connection_gate().blocked():
		return
	var zone_id := str(_solo_hunt_context.get("visual_zone_id", ""))
	_world_encounter_return = _solo_hunt_context.get("return_view", {}).duplicate(true)
	_hunt_loadout_active = false
	_hunt_loadout.clear()
	_solo_hunt_context.clear()
	if zone_id.is_empty():
		go_to_world_gate()
	else:
		go_to_world_zone(zone_id)

static func consume_solo_hunt_context() -> Dictionary:
	var context := _solo_hunt_context.duplicate(true)
	_solo_hunt_context.clear()
	return context

static func set_combat_seal_mode(mode: String) -> void:
	_combat_seal_mode = "defense" if mode == "defense" else "attack"

static func consume_combat_seal_mode() -> String:
	var mode := _combat_seal_mode
	_combat_seal_mode = "attack"
	return mode

static func go_to_main_menu() -> void:
	_clear_forest_return()
	_go_to(SCENE_MAIN_MENU, "MainMenu")

static func go_to_settings() -> void:
	_go_to(SCENE_SETTINGS, "Settings")

static func go_to_lab() -> void:
	go_to_lab_hub()

static func go_to_lab_hub() -> void:
	_go_to(SCENE_LAB_HUB, "LabHub")

# ConnectionGate registers its identity only after BackendClient verifies server state.
static func _forest_verified_owner() -> String:
	var gate := _connection_gate()
	if gate.blocked() or gate.debug_lab_navigation_allowed():
		return ""
	if str(gate.player_id).strip_edges().is_empty() or str(gate.token).strip_edges().is_empty():
		return ""
	return str(gate.player_id)

static func _forest_access_allowed() -> bool:
	return not _forest_verified_owner().is_empty() or _connection_gate().debug_lab_navigation_allowed()

static func go_to_summoner_selection() -> void:
	_clear_forest_return()
	if not _forest_access_allowed():
		return
	_forest_summoner = ""
	_forest_owner = _forest_verified_owner()
	if not _forest_owner.is_empty():
		var config := ConfigFile.new()
		if config.load(FOREST_PREFERENCES) == OK:
			var remembered := str(config.get_value("players", _forest_owner.sha256_text(), ""))
			if remembered in FOREST_SUMMONERS:
				_forest_summoner = remembered
	_go_to(SCENE_SUMMONER_SELECTION, "SummonerSelection")

static func forest_selected_summoner() -> String:
	if not _forest_access_allowed() or _forest_owner != _forest_verified_owner():
		return ""
	return _forest_summoner if _forest_summoner in FOREST_SUMMONERS else ""

static func enter_forest(summoner_id: String) -> void:
	if summoner_id not in FOREST_SUMMONERS or not _forest_access_allowed():
		return
	var owner := _forest_verified_owner()
	if owner != _forest_owner:
		return
	_forest_summoner = summoner_id
	if not owner.is_empty():
		var config := ConfigFile.new()
		config.load(FOREST_PREFERENCES)
		config.set_value("players", owner.sha256_text(), summoner_id)
		if config.save(FOREST_PREFERENCES) != OK:
			push_warning("Could not save forest summoner preference.")
	_go_to(SCENE_FOREST_WORLD, "ForestWorld")

static func leave_forest() -> void:
	_clear_forest_return()
	_forest_summoner = ""
	_forest_owner = ""
	go_to_lab_hub()

static func _clear_forest_return() -> void:
	_forest_return.clear()
	_forest_restore.clear()
	_forest_change.clear()

static func _valid_forest_context(context: Dictionary) -> bool:
	if context.is_empty() or str(context.get("summoner_id", "")) not in FOREST_SUMMONERS:
		return false
	var position = context.get("foot_position")
	var facing = context.get("facing")
	if not position is Vector2 or not position.is_finite() or not facing is int or facing not in [0, 1, 2, 3]:
		return false
	var zone_id := str(context.get("zone_id", ""))
	var count := 0
	var inside := false
	for zone in FOREST_ZONES.runtime_zones():
		if zone.id == zone_id:
			count += 1
			inside = FOREST_ZONES.contains_point(PackedVector2Array(zone.polygon), position)
	return count == 1 and inside

static func forest_return_available() -> bool:
	if _forest_return.is_empty():
		return false
	var gate := _connection_gate()
	var debug_mode: bool = gate.debug_lab_navigation_allowed()
	var owner := str(_forest_return.get("verified_owner", ""))
	if not _valid_forest_context(_forest_return) or str(_forest_return.get("summoner_id", "")) != _forest_summoner or owner != _forest_owner or _forest_return.get("identity_generation", -1) != gate._generation:
		_clear_forest_return()
		return false
	if bool(_forest_return.get("debug", false)):
		if not debug_mode:
			_clear_forest_return()
			return false
	elif str(gate.player_id) != owner or str(gate.token).strip_edges().is_empty():
		_clear_forest_return()
		return false
	if not _forest_access_allowed() or _forest_verified_owner() != owner:
		return false
	return true

static func _forest_modes_safe() -> bool:
	if not _spectator_context.is_empty() or _hunt_loadout_active or not _solo_hunt_context.is_empty() or not _dungeon_context.is_empty() or not _ranked_context.is_empty() or _expedition_forfeit_notice:
		return false
	# Returning from an unstarted loadout can leave only its owner in this context.
	for key in _expedition_context:
		if key != "player_id":
			return false
	if not _expedition_context.is_empty() and not _connection_gate().debug_lab_navigation_allowed() and str(_expedition_context.get("player_id", "")) != _forest_verified_owner():
		return false
	var gate := _connection_gate()
	if int(gate._recovery_owner_id) != 0:
		return false
	if not _forest_verified_owner().is_empty():
		var journal := preload("res://scripts/net/session_recovery_journal.gd").new()
		if not journal.set_identity(_forest_verified_owner()) or not journal.load_entry().is_empty():
			return false
	return true

static func forest_return_safe() -> bool:
	if not forest_return_available() or not _forest_modes_safe():
		return false
	var tree := _get_tree()
	var scene := tree.current_scene if tree != null else null
	if not is_instance_valid(scene) or scene.scene_file_path not in [SCENE_LAB_STRUCTURES, SCENE_WORLD_GATE, SCENE_TRADE_HALL, SCENE_INVENTORY, SCENE_EXPEDITIONS, SCENE_LOADOUT]:
		return false
	return scene.has_method("forest_return_safe") and bool(scene.forest_return_safe())

static func open_from_forest(action_id: String, zone_id: String, foot: Vector2, facing: int) -> void:
	if action_id not in FOREST_ACTIONS or not _forest_access_allowed() or not _forest_modes_safe():
		return
	var tree := _get_tree()
	var scene := tree.current_scene if tree != null else null
	if not is_instance_valid(scene) or scene.scene_file_path != SCENE_FOREST_WORLD or not scene.forest_action_allowed(action_id, zone_id, foot, facing):
		return
	var summoner := forest_selected_summoner()
	var owner := _forest_verified_owner()
	var context := {"verified_owner": owner, "summoner_id": summoner, "zone_id": zone_id, "foot_position": foot, "facing": facing, "debug": _connection_gate().debug_lab_navigation_allowed(), "identity_generation": _connection_gate()._generation}
	if summoner.is_empty() or not _valid_forest_context(context):
		return
	_forest_restore.clear()
	_forest_return = context
	match action_id:
		"forge": go_to_lab_structures("build_forge")
		"lab": go_to_lab_structures("arcane_archives")
		"expeditions": go_to_expeditions()
		"world_gate": go_to_world_gate()
		"ranked": go_to_loadout()
		"guide_inventory": go_to_inventory("", true)
		"guide_trade": go_to_trade_hall()

static func return_to_forest() -> void:
	if not forest_return_safe():
		return
	_forest_restore = _forest_return.duplicate(true)
	_forest_return.clear()
	_go_to(SCENE_FOREST_WORLD, "ForestWorld")

static func consume_forest_restore() -> Dictionary:
	var result := _forest_restore.duplicate(true)
	_forest_restore.clear()
	if not _valid_forest_context(result) or not _forest_access_allowed() or _forest_verified_owner() != str(result.get("verified_owner", "")) or forest_selected_summoner() != str(result.get("summoner_id", "")) or bool(result.get("debug", false)) != _connection_gate().debug_lab_navigation_allowed() or result.get("identity_generation", -1) != _connection_gate()._generation:
		return {}
	return result

static func forest_change_available() -> bool:
	if _forest_change.is_empty():
		return false
	var gate := _connection_gate()
	var owner := str(_forest_change.get("verified_owner", ""))
	if not _valid_forest_context(_forest_change) or str(_forest_change.get("summoner_id", "")) != _forest_summoner or owner != _forest_owner or _forest_change.get("identity_generation", -1) != gate._generation or bool(_forest_change.get("debug", false)) != gate.debug_lab_navigation_allowed():
		_forest_change.clear()
		return false
	if not gate.debug_lab_navigation_allowed() and (str(gate.player_id) != owner or str(gate.token).strip_edges().is_empty()):
		_forest_change.clear()
		return false
	return _forest_access_allowed() and _forest_verified_owner() == owner and _forest_modes_safe()

static func change_summoner_from_forest(zone_id: String, foot: Vector2, facing: int) -> void:
	if not _forest_access_allowed() or not _forest_modes_safe() or not _forest_change.is_empty():
		return
	var tree := _get_tree()
	var scene := tree.current_scene if tree != null else null
	if not is_instance_valid(scene) or scene.scene_file_path != SCENE_FOREST_WORLD or not scene.forest_change_allowed(zone_id, foot, facing):
		return
	var context := {"verified_owner": _forest_verified_owner(), "summoner_id": forest_selected_summoner(), "zone_id": zone_id, "foot_position": foot, "facing": facing, "debug": _connection_gate().debug_lab_navigation_allowed(), "identity_generation": _connection_gate()._generation}
	if not _valid_forest_context(context):
		return
	_forest_change = context
	_go_to(SCENE_SUMMONER_SELECTION, "SummonerSelection")

static func finish_forest_change(summoner_id: String, confirmed: bool) -> void:
	if not forest_change_available():
		return
	var tree := _get_tree()
	if tree == null or not is_instance_valid(tree.current_scene) or tree.current_scene.scene_file_path != SCENE_SUMMONER_SELECTION:
		return
	var selected := summoner_id if confirmed else str(_forest_change.summoner_id)
	if selected not in FOREST_SUMMONERS:
		return
	var owner := _forest_verified_owner()
	if confirmed and not owner.is_empty():
		var config := ConfigFile.new()
		var err := config.load(FOREST_PREFERENCES)
		if err != OK and err != ERR_FILE_NOT_FOUND:
			push_warning("Could not read forest summoner preference.")
			return
		config.set_value("players", owner.sha256_text(), selected)
		if config.save(FOREST_PREFERENCES) != OK:
			push_warning("Could not save forest summoner preference.")
			return
	var restore := _forest_change.duplicate(true)
	restore.summoner_id = selected
	_forest_summoner = selected
	_forest_change.clear()
	_forest_restore = restore
	_go_to(SCENE_FOREST_WORLD, "ForestWorld")

static func go_to_lab_structures(building_id: String = "") -> void:
	_next_lab_focus_id = building_id
	_go_to(SCENE_LAB_STRUCTURES, "LabStructures")

static func consume_lab_focus_id() -> String:
	var focus_id := _next_lab_focus_id
	_next_lab_focus_id = ""
	return focus_id

static func go_to_inventory(tab: String = "", return_to_lab: bool = false) -> void:
	_next_inventory_tab = tab
	_inventory_return_to_lab = return_to_lab
	_go_to(SCENE_INVENTORY, "Inventory")

static func consume_inventory_return_to_lab() -> bool:
	var result := _inventory_return_to_lab
	_inventory_return_to_lab = false
	return result

static func consume_inventory_tab() -> String:
	var tab := _next_inventory_tab
	_next_inventory_tab = ""
	return tab

static func go_to_trade_hall() -> void:
	_go_to(SCENE_TRADE_HALL, "TradeHall")

static func go_to_expeditions() -> void:
	if not _connection_gate().debug_lab_navigation_allowed():
		_expedition_context.erase("loadout")
	_go_to(SCENE_EXPEDITIONS, "Expeditions")

static func go_to_world_gate() -> void:
	_go_to(SCENE_WORLD_GATE, "WorldGate")

static func go_to_world_gate_boss(boss_id: String) -> void:
	_next_world_boss_id = boss_id
	go_to_world_gate()

static func consume_world_boss_id() -> String:
	var boss_id := _next_world_boss_id
	_next_world_boss_id = ""
	return boss_id

static func go_to_world_zone(zone_id: String = "") -> void:
	_next_world_zone_id = zone_id
	match zone_id:
		"zone_corrupted":
			_go_to(SCENE_WORLD_ZONE_CORRUPTED, "WorldZoneCorrupted")
		"zone_crystal":
			_go_to(SCENE_WORLD_ZONE_CRYSTAL, "WorldZoneCrystal")
		"zone_chaos":
			_go_to(SCENE_WORLD_ZONE_CHAOS, "WorldZoneChaos")
		_:
			_go_to(SCENE_WORLD_ZONE, "WorldZone")

static func consume_world_zone_id() -> String:
	var zone_id := _next_world_zone_id
	_next_world_zone_id = ""
	return zone_id

static func go_to_combat() -> void:
	_go_to(SCENE_COMBAT, "Combat")

static func go_to_loadout() -> void:
	_go_to(SCENE_LOADOUT, "LoadoutGrid")

static func go_to_top_players() -> void:
	_go_to(SCENE_TOP_PLAYERS, "TopPlayers")

static func _go_to(scene_path: String, label: String) -> void:
	var local_debug_scenes := [SCENE_MAIN_MENU, SCENE_SETTINGS, SCENE_LAB_HUB, SCENE_LAB_STRUCTURES, SCENE_INVENTORY, SCENE_TRADE_HALL, SCENE_EXPEDITIONS, SCENE_WORLD_GATE, SCENE_WORLD_ZONE, SCENE_WORLD_ZONE_CHAOS, SCENE_WORLD_ZONE_CORRUPTED, SCENE_WORLD_ZONE_CRYSTAL, SCENE_SUMMONER_SELECTION, SCENE_FOREST_WORLD]
	if _connection_gate().debug_lab_navigation_allowed():
		local_debug_scenes.append(SCENE_LOADOUT)
		if bool(_ranked_context.get("debug_visual", false)):
			local_debug_scenes.append(SCENE_COMBAT)
	if _connection_gate().blocked() and not (_connection_gate().debug_lab_navigation_allowed() and scene_path in local_debug_scenes):
		return
	if scene_path == "":
		push_error("SceneRouter: Missing scene path for %s." % label)
		return
	var tree := _get_tree()
	if tree == null:
		push_error("SceneRouter: No SceneTree available for %s." % label)
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: Scene path not found for %s -> %s." % [label, scene_path])
		return
	var err := tree.change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: Failed to change scene to %s (err %s)." % [label, err])

static func _get_tree() -> SceneTree:
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		return loop
	return null

static func _connection_gate() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("ConnectionGate")
