extends Node
class_name AssetCatalog

const ROOT_DIR := "res://assets/lab"
const VALID_EXTS := ["png", "webp", "jpg", "jpeg"]
const ALIAS_IDS := {
	"lab_th": "lab",
	"ui_panel": "lab_panel",
	"rune_offensive": "offensive_rune",
	"rune_defense": "defense_rune",
	"rune_chaos": "chaos_rune",
	"loadbar_0": "loadbar0",
	"loadbar_25": "loadbar25",
	"loadbar_50": "loadbar50",
	"loadbar_75": "loadbar75",
	"loadbar_90": "loadbar90",
	"loadbar_100": "loadbar100",
	"boss_common": "common_boss",
	"boss_colossus": "giant_arcane_colossus",
	"boss_leviathan": "corrupted_energy_leviathan",
	"boss_temporal": "temporal_warden_titan",
	"zone_corrupted": "corrupted_zone",
	"zone_crystal": "crystal_zone",
	"zone_chaos": "chaos_zone",
	"zone_corrupted_load_bg": "corrupted_zone_load_bg",
	"zone_crystal_load_bg": "crystal_zone_load_bg",
	"zone_chaos_load_bg": "chaos_zone_load_bg"
}
const REQUIRED_IDS := [
	"lab_th",
	"essence_reactor",
	"storage_vault",
	"build_forge",
	"homunculus_vat",
	"ultrahit_tower",
	"experiment_chamber",
	"arcane_archives",
	"sync_nexus",
	"anomaly_containment",
	"trade_hall",
	"world_gate",
	"essence",
	"core",
	"arcane_shard",
	"time_crystal",
	"ui_panel",
	"button_base",
	"button_hover",
	"icon_slot_frame"
]
const SEARCH_HINTS := {
	"lab_th": ["lab"],
	"ui_panel": ["lab_panel", "panel"],
	"icon_slot_frame": ["icon_slot", "slot_frame"],
	"button_base": ["button_base", "button"],
	"button_hover": ["button_hover", "button"],
	"essence_reactor": ["essence_reactor", "reactor"],
	"storage_vault": ["storage_vault", "storage"],
	"build_forge": ["build_forge", "forge"],
	"homunculus_vat": ["homunculus_vat", "vat"],
	"ultrahit_tower": ["ultrahit_tower", "ultrahit"],
	"experiment_chamber": ["experiment_chamber", "experiment"],
	"arcane_archives": ["arcane_archives", "archives"],
	"sync_nexus": ["sync_nexus", "nexus"],
	"anomaly_containment": ["anomaly_containment", "anomaly"],
	"trade_hall": ["trade_hall", "trade"],
	"world_gate": ["world_gate", "gate"]
}
const FALLBACK_PATHS := {
	"lab_th": "res://assets/lab/lab_structures/lab.png",
	"essence_reactor": "res://assets/lab/lab_structures/essence_reactor.png",
	"storage_vault": "res://assets/lab/lab_structures/storage_vault.png",
	"build_forge": "res://assets/lab/lab_structures/build_forge.png",
	"homunculus_vat": "res://assets/lab/lab_structures/homunculus_vat.png",
	"ultrahit_tower": "res://assets/lab/lab_structures/ultrahit_tower.png",
	"experiment_chamber": "res://assets/lab/lab_structures/experiment_chamber.png",
	"arcane_archives": "res://assets/lab/lab_structures/arcane_archives.png",
	"sync_nexus": "res://assets/lab/lab_structures/sync_nexus.png",
	"anomaly_containment": "res://assets/lab/lab_structures/anomaly_containment.png",
	"trade_hall": "res://assets/lab/lab_structures/trade_hall.png",
	"world_gate": "res://assets/lab/lab_structures/world_gate.png",
	"essence": "res://assets/lab/resources/essence.png",
	"core": "res://assets/lab/resources/core.png",
	"arcane_shard": "res://assets/lab/resources/arcane_shard.png",
	"time_crystal": "res://assets/lab/resources/time_crystal.png",
	"ui_panel": "res://assets/lab/more_ui/lab_panel.png",
	"button_base": "res://assets/lab/more_ui/button_base.png",
	"button_hover": "res://assets/lab/more_ui/button_hover.png",
	"icon_slot_frame": "res://assets/lab/more_ui/icon_slot_frame.png"
}

var _paths: Dictionary = {}
var _cache: Dictionary = {}
var _scanned := false

func has(id: String) -> bool:
	_ensure_scan()
	return _paths.has(id)

func get_asset_path(id: String) -> String:
	_ensure_scan()
	return _paths.get(id, "")

func clear_cache() -> void:
	_cache.clear()

func rescan() -> void:
	_scanned = false
	_paths.clear()
	_cache.clear()
	_ensure_scan()

func get_tex(id: String) -> Texture2D:
	_ensure_scan()
	if not _paths.has(id):
		push_error("AssetCatalog: Missing texture id: %s" % id)
		return null
	if _cache.has(id):
		var cached = _cache[id]
		if cached is WeakRef:
			var ref = cached.get_ref()
			if ref is Texture2D:
				return ref
			_cache.erase(id)
		elif cached is Texture2D:
			return cached
	var path: String = _paths[id]
	var res = ResourceLoader.load(path)
	if res == null:
		push_error("AssetCatalog: Failed to load texture id '%s' at %s" % [id, path])
		return null
	if res is Texture2D:
		_cache[id] = weakref(res)
		return res
	push_error("AssetCatalog: Resource for id '%s' is not a Texture2D (%s)" % [id, path])
	return null

func find_id_contains(fragment: String) -> String:
	_ensure_scan()
	if fragment == "":
		return ""
	var needle := fragment.to_lower()
	var ids: Array = _paths.keys()
	ids.sort()
	for id in ids:
		var id_str := str(id).to_lower()
		if id_str.find(needle) != -1:
			return str(id)
	return ""

func get_tex_by_contains(fragment: String) -> Texture2D:
	var id := find_id_contains(fragment)
	if id == "":
		push_error("AssetCatalog: No texture id contains '%s'." % fragment)
		return null
	return get_tex(id)

func _ensure_scan() -> void:
	if _scanned:
		return
	_scanned = true
	_paths.clear()
	_scan_dir(ROOT_DIR)
	_apply_aliases()
	_resolve_required_ids()

func _scan_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("AssetCatalog: Failed to open dir %s" % path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var full_path = path + "/" + file_name
		if dir.current_is_dir():
			_scan_dir(full_path)
			file_name = dir.get_next()
			continue
		if file_name.ends_with(".import"):
			file_name = dir.get_next()
			continue
		var ext = file_name.get_extension().to_lower()
		if not VALID_EXTS.has(ext):
			file_name = dir.get_next()
			continue
		var id = file_name.get_basename()
		if not _paths.has(id):
			_paths[id] = full_path
		file_name = dir.get_next()
	dir.list_dir_end()

func _apply_aliases() -> void:
	for alias in ALIAS_IDS.keys():
		if _paths.has(alias):
			continue
		var target_id = ALIAS_IDS[alias]
		if _paths.has(target_id):
			_paths[alias] = _paths[target_id]
		else:
			push_error("AssetCatalog: Alias target missing for %s -> %s" % [alias, target_id])

func _resolve_required_ids() -> void:
	for id in REQUIRED_IDS:
		if _paths.has(id):
			continue
		var found = _find_by_hints(SEARCH_HINTS.get(id, [id]))
		if found != "":
			_paths[id] = _paths[found]
			continue
		var fallback = str(FALLBACK_PATHS.get(id, ""))
		if fallback != "" and ResourceLoader.exists(fallback):
			_paths[id] = fallback
			continue
		push_error("AssetCatalog: Missing required texture id: %s" % id)

func _find_by_hints(hints: Array) -> String:
	if hints.is_empty():
		return ""
	var ids: Array = _paths.keys()
	for hint in hints:
		var needle = str(hint).to_lower()
		for id in ids:
			var id_str := str(id).to_lower()
			if id_str.find(needle) != -1:
				return str(id)
		for id in ids:
			var path_str := str(_paths[id]).to_lower()
			if path_str.find(needle) != -1:
				return str(id)
	return ""

func apply_icon(texture_rect: TextureRect, tex_id: String, target_px: Vector2i) -> void:
	if texture_rect == null:
		return
	texture_rect.texture = get_tex(tex_id)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.custom_minimum_size = target_px

func apply_panel(panel: CanvasItem, tex_id: String, target_min_px: Vector2i = Vector2i(0, 0), margins_px: int = 0) -> void:
	if panel == null:
		return
	if panel is NinePatchRect:
		apply_ninepatch(panel, tex_id, target_min_px, margins_px)
		return
	if panel is Panel:
		var tex = get_tex(tex_id)
		if tex == null:
			return
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.draw_center = true
		if sb.has_method("set_axis_stretch_horizontal"):
			sb.set_axis_stretch_horizontal(StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
			sb.set_axis_stretch_vertical(StyleBoxTexture.AXIS_STRETCH_MODE_TILE)
		else:
			sb.set("axis_stretch_horizontal", 1)
			sb.set("axis_stretch_vertical", 1)
		panel.add_theme_stylebox_override("panel", sb)
		if target_min_px != Vector2i(0, 0):
			panel.custom_minimum_size = target_min_px

func apply_ninepatch(panel: NinePatchRect, tex_id: String, target_min_px: Vector2i, margins_px: int) -> void:
	if panel == null:
		return
	panel.texture = get_tex(tex_id)
	panel.custom_minimum_size = target_min_px
	panel.patch_margin_left = margins_px
	panel.patch_margin_right = margins_px
	panel.patch_margin_top = margins_px
	panel.patch_margin_bottom = margins_px
