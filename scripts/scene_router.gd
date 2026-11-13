extends Node
class_name SceneRouter

const SCENE_MAIN_MENU := "res://scenes/MainMenu.tscn"
const SCENE_SETTINGS := "res://scenes/ui/Settings.tscn"
const SCENE_LAB_HUB := "res://scenes/ui/LabHub.tscn"
const SCENE_LAB_STRUCTURES := "res://scenes/ui/LabStructures.tscn"
const SCENE_INVENTORY := "res://scenes/ui/Inventory.tscn"
const SCENE_TRADE_HALL := "res://scenes/ui/TradeHall.tscn"
const SCENE_WORLD_GATE := "res://scenes/ui/WorldGate.tscn"
const SCENE_WORLD_ZONE := "res://scenes/ui/WorldZone.tscn"
const SCENE_WORLD_ZONE_CORRUPTED := "res://scenes/ui/WorldZoneCorrupted.tscn"
const SCENE_WORLD_ZONE_CRYSTAL := "res://scenes/ui/WorldZoneCrystal.tscn"
const SCENE_WORLD_ZONE_CHAOS := "res://scenes/ui/WorldZoneChaos.tscn"
const SCENE_COMBAT := "res://scenes/Combat.tscn"
const SCENE_LOADOUT := "res://scenes/LoadoutGrid.tscn"

static var _next_lab_focus_id: String = ""
static var _next_inventory_tab: String = ""
static var _inventory_return_to_lab := false
static var _next_world_zone_id: String = ""
static var _next_world_boss_id: String = ""
static var _combat_seal_mode := "attack"
static var _solo_hunt_context := {}

static func go_to_solo_hunt(hunt_id: String, rotation_key: int, display_texture_id: String = "") -> void:
	_solo_hunt_context = {"hunt_id": hunt_id, "rotation_key": rotation_key, "display_texture_id": display_texture_id}
	_go_to(SCENE_COMBAT, "Combat")

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
	_go_to(SCENE_MAIN_MENU, "MainMenu")

static func go_to_settings() -> void:
	_go_to(SCENE_SETTINGS, "Settings")

static func go_to_lab() -> void:
	go_to_lab_hub()

static func go_to_lab_hub() -> void:
	_go_to(SCENE_LAB_HUB, "LabHub")

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

static func _go_to(scene_path: String, label: String) -> void:
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
