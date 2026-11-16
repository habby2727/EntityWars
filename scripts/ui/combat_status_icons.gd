extends Control

signal effect_clicked(description: String)

const SLOT := 48.0
const ROW_HEIGHT := 64.0
const DEFINITIONS := [
	["poison", "poison", "STATUS_POISON", "turns"],
	["shield_pct", "shield", "STATUS_SHIELD", "percent"],
	["reflect_pct", "reflect", "STATUS_REFLECT", "percent"],
	["atk_boost", "atk_up", "STATUS_ATK_BOOST", "plus"],
	["atk_down", "atk_down", "STATUS_ATK_DOWN", "minus"],
	["vuln_pct", "vuln", "STATUS_VULNERABILITY", "percent"],
	["stun", "stun", "STATUS_STUN", "turns"],
	["hom_stun", "chain", "STATUS_HOM_STUN", "turns"],
	["tempo_bonus", "tempo", "STATUS_TEMPO", "number"],
	["focus_next", "type", "STATUS_FOCUS", "plus"],
	["misalign_next", "stun", "STATUS_MISALIGN", "minus"],
	["poison_on_reflect", "poison", "STATUS_POISON_REFLECT", "turns"],
]

var _wins := 0
var _effects: Array = []
var _boss_mode := false
var _extra_effects: Array = []

func set_boss_effects(enabled: bool, effects: Array) -> void:
	_boss_mode = enabled
	_extra_effects = effects.duplicate(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_boss_height()
	queue_redraw()

func _visible_effects() -> Array:
	return _extra_effects + _effects

func _entries() -> Array:
	var entries: Array = []
	if not _boss_mode:
		entries.append({"icon": "crown", "label": "", "victory": 0})
		entries.append({"icon": "crown", "label": "", "victory": 1})
		if not _feedback.is_empty():
			entries.append({"icon": _feedback_icon, "label": _feedback, "tooltip": _feedback})
	entries.append_array(_visible_effects())
	return entries

func _slots() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var x := 0.0
	for entry in _entries():
		var text_width := ThemeDB.fallback_font.get_string_size(str(entry.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var width := maxf(SLOT, text_width) + 16.0
		result.append(Rect2(x, 0, width, ROW_HEIGHT))
		x += width
	return result

func _update_boss_height() -> void:
	var slots := _slots()
	custom_minimum_size = Vector2(slots.back().end.x if not slots.is_empty() else 1.0, ROW_HEIGHT)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var description := _get_tooltip(event.position)
		if not description.is_empty():
			effect_clicked.emit(description)
var _previous_status := {}
var _status_initialized := false
var _feedback := ""
var _feedback_until := 0
var _feedback_queue: Array[Dictionary] = []
var _current_feedback: Dictionary = {}
var _feedback_icon := "type"
var _previous_neutralization := 0.0
var _previous_mark_turns := 0

func set_fighter(wins: int, fighter: Dictionary) -> void:
	_wins = wins
	_effects.clear()
	var status: Dictionary = fighter.get("status", {})
	if _status_initialized:
		for definition in DEFINITIONS:
			var key: String = definition[0]
			var previous := float(_previous_status.get(key, 0.0))
			var current := float(status.get(key, 0.0))
			if not is_equal_approx(previous, current):
				var value_text := str(current)
				if definition[3] in ["percent", "plus", "minus"]:
					value_text = "%d%%" % roundi(absf(current) * 100.0)
				elif definition[3] == "turns":
					value_text = "%dT" % int(current)
				_queue_feedback(key, value_text, current == 0.0, str(definition[1]))
	_previous_status = status.duplicate(true)
	_status_initialized = true
	for definition in DEFINITIONS:
		var value := float(status.get(definition[0], 0))
		if value == 0.0 or (value < 0.0 and definition[0] != "tempo_bonus"):
			continue
		var label := ""
		match definition[3]:
			"turns": label = "%dT" % int(value)
			"percent": label = "%d%%" % int(round(value * 100))
			"plus": label = "+%d%%" % int(round(value * 100))
			"minus": label = "-%d%%" % int(round(value * 100))
			_: label = ("+" if value > 0 else "") + str(value).trim_suffix(".0")
		_effects.append({"icon": definition[1], "label": label, "tooltip": "%s (%s)" % [tr(definition[2]), label], "tooltip_key": definition[2]})
	var mark: Dictionary = status.get("hybrid_mark", {})
	if int(mark.get("remaining", 0)) > 0:
		_effects.append({"icon": "chain", "label": "%dT" % int(mark.remaining), "tooltip": tr("STATUS_HYBRID_MARK") % int(mark.remaining), "tooltip_key": "STATUS_HYBRID_MARK", "turns": int(mark.remaining)})
	var active := float(fighter.get("spell_neutralize_active", 0.0))
	var pending := float(fighter.get("spell_neutralize_pending", 0.0))
	var neutralization := maxf(active, pending)
	var mark_turns := int(mark.get("remaining", 0))
	if _status_initialized and not is_equal_approx(neutralization, _previous_neutralization):
		_queue_feedback("type_alteration", "%d%%" % roundi(neutralization * 100.0), neutralization == 0.0)
	if _status_initialized and mark_turns != _previous_mark_turns:
		_queue_feedback("hybrid_mark", "%dT" % mark_turns, mark_turns == 0)
	_previous_neutralization = neutralization
	_previous_mark_turns = mark_turns
	if active > 0.0 or pending > 0.0:
		var value := maxf(active, pending)
		var phase := "STATUS_CURRENT_EXCHANGE" if active > 0.0 else "STATUS_NEXT_EXCHANGE"
		_effects.append({"icon": "type", "label": "%d%%" % int(round(value * 100)), "tooltip": tr("STATUS_TYPE_CHANGE") % [int(round(value * 100)), tr(phase)], "tooltip_key": "STATUS_TYPE_CHANGE", "value": int(round(value * 100)), "phase": phase})
	_update_boss_height()
	queue_redraw()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _feedback_until:
		_show_next_feedback()

func _show_next_feedback() -> void:
	if _feedback_queue.is_empty():
		_feedback = ""
		_current_feedback.clear()
		set_process(false)
	else:
		var next: Dictionary = _feedback_queue.pop_front()
		_current_feedback = next
		_feedback = _feedback_text(next)
		_feedback_icon = str(next.icon)
		_feedback_until = Time.get_ticks_msec() + 1800
		set_process(true)
	_update_boss_height()

func _feedback_text(entry: Dictionary) -> String:
	var id := str(entry.name)
	var fallback := id.replace("_pct", "").replace("_", " ").capitalize()
	return "%s %s" % [GameLocalization.catalog("status_name", id, "name", fallback), tr("STATUS_ENDED") if bool(entry.ended) else str(entry.value)]

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and not _current_feedback.is_empty():
		_feedback = _feedback_text(_current_feedback)
		queue_redraw()

func _queue_feedback(name: String, value: String, ended: bool, icon: String = "type") -> void:
	_feedback_queue.append({"name": name, "value": value, "ended": ended, "icon": icon})
	if _feedback.is_empty():
		_show_next_feedback()

func _effect_tooltip(effect: Dictionary) -> String:
	var key := str(effect.get("tooltip_key", ""))
	if key == "STATUS_HYBRID_MARK":
		return tr(key) % int(effect.turns)
	if key == "STATUS_TYPE_CHANGE":
		return tr(key) % [int(effect.value), tr(effect.phase)]
	if not key.is_empty():
		return "%s (%s)" % [tr(key), effect.label]
	return str(effect.get("tooltip", ""))

func _get_tooltip(at_position: Vector2) -> String:
	var slots := _slots()
	var entries := _entries()
	for i in slots.size():
		if slots[i].has_point(at_position):
			var entry: Dictionary = entries[i]
			if entry.has("victory"):
				var victory := int(entry.victory)
				return tr("STATUS_VICTORY") % [victory + 1, tr("STATUS_EARNED") if victory < _wins else tr("STATUS_PENDING")]
			return _effect_tooltip(entry)
	return ""

func _draw() -> void:
	var slots := _slots()
	var entries := _entries()
	for i in slots.size():
		var rect := slots[i]
		var entry: Dictionary = entries[i]
		_draw_icon(entry.icon, rect.position + Vector2((rect.size.x - SLOT) * 0.5, 0), not entry.has("victory") or int(entry.victory) < _wins)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 62), str(entry.label), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color.WHITE)

func _draw_icon(kind: String, offset: Vector2, enabled: bool) -> void:
	draw_set_transform(offset, 0.0, Vector2(2, 2))
	var c := Color.WHITE
	match kind:
		"hourglass":
			c = Color("e9c77e")
			draw_line(Vector2(5, 3), Vector2(19, 3), c, 2, true)
			draw_line(Vector2(5, 19), Vector2(19, 19), c, 2, true)
			draw_polyline(PackedVector2Array([Vector2(7, 4), Vector2(17, 18), Vector2(7, 18), Vector2(17, 4)]), c, 2, true)
		"trap":
			c = Color("e7a868")
			draw_arc(Vector2(12, 11), 8, 0.3, 5.5, 20, c, 2, true)
			draw_line(Vector2(7, 15), Vector2(17, 6), c, 2, true)
		"heal_block":
			c = Color("eb7884")
			draw_line(Vector2(12, 4), Vector2(12, 19), c, 3, true)
			draw_line(Vector2(5, 11), Vector2(19, 11), c, 3, true)
			draw_line(Vector2(5, 19), Vector2(19, 3), c, 2, true)
		"fury":
			c = Color("fa7440")
			draw_colored_polygon(PackedVector2Array([Vector2(12, 2), Vector2(17, 9), Vector2(19, 14), Vector2(16, 20), Vector2(8, 20), Vector2(5, 15), Vector2(9, 8), Vector2(10, 13)]), c)
		"minions":
			c = Color("d5b968")
			draw_circle(Vector2(8, 8), 4, c)
			draw_circle(Vector2(16, 8), 4, c)
			draw_line(Vector2(4, 19), Vector2(6, 14), c, 3, true)
			draw_line(Vector2(20, 19), Vector2(18, 14), c, 3, true)
		"power":
			c = Color("8de8f2")
			draw_colored_polygon(PackedVector2Array([Vector2(13, 1), Vector2(5, 12), Vector2(11, 12), Vector2(9, 22), Vector2(20, 8), Vector2(14, 8)]), c)
		"crown":
			c = Color("e9bb51") if enabled else Color("65645b")
			draw_colored_polygon(PackedVector2Array([Vector2(3, 5), Vector2(6, 17), Vector2(19, 17), Vector2(22, 5), Vector2(16, 10), Vector2(12, 3), Vector2(8, 10)]), c)
		"poison":
			c = Color("65d56e")
			draw_colored_polygon(PackedVector2Array([Vector2(12, 2), Vector2(6, 10), Vector2(5, 14), Vector2(7, 18), Vector2(12, 20), Vector2(17, 18), Vector2(19, 14), Vector2(18, 10)]), c)
		"shield":
			c = Color("69b9f4")
			draw_colored_polygon(PackedVector2Array([Vector2(12, 2), Vector2(20, 5), Vector2(19, 13), Vector2(12, 20), Vector2(5, 13), Vector2(4, 5)]), c)
		"reflect":
			c = Color("f36b6b")
			draw_arc(Vector2(12, 11), 7, -2.3, 0.5, 14, c, 2.0, true)
			draw_arc(Vector2(12, 11), 7, 0.85, 3.65, 14, c, 2.0, true)
			draw_line(Vector2(18, 6), Vector2(20, 10), c, 2, true)
			draw_line(Vector2(6, 16), Vector2(4, 12), c, 2, true)
		"atk_up", "atk_down":
			c = Color("72dc89") if kind == "atk_up" else Color("f36b6b")
			draw_line(Vector2(6, 18), Vector2(17, 5), c, 3, true)
			draw_line(Vector2(5, 12), Vector2(11, 18), c, 2, true)
			if kind == "atk_down":
				draw_line(Vector2(19, 12), Vector2(19, 20), c, 2, true)
				draw_line(Vector2(16, 17), Vector2(19, 20), c, 2, true)
		"vuln":
			c = Color("f0a04e")
			draw_polyline(PackedVector2Array([Vector2(14, 2), Vector2(8, 9), Vector2(13, 11), Vector2(8, 20)]), c, 3, true)
		"stun":
			c = Color("f4dc61")
			draw_colored_polygon(PackedVector2Array([Vector2(13, 2), Vector2(6, 12), Vector2(11, 12), Vector2(9, 20), Vector2(19, 9), Vector2(13, 9)]), c)
		"chain":
			c = Color("b994ee")
			draw_arc(Vector2(9, 14), 5, 0.4, 5.8, 16, c, 2.5, true)
			draw_arc(Vector2(15, 8), 5, 3.5, 8.9, 16, c, 2.5, true)
		"tempo":
			c = Color("83dce8")
			draw_arc(Vector2(12, 11), 8, 0, TAU, 24, c, 2, true)
			draw_line(Vector2(12, 5), Vector2(12, 11), c, 2, true)
			draw_line(Vector2(12, 11), Vector2(16, 14), c, 2, true)
		"type":
			c = Color("d69ff1")
			draw_arc(Vector2(12, 11), 8, 0, TAU, 24, c, 2, true)
			draw_line(Vector2(5, 16), Vector2(19, 6), c, 2, true)
			draw_line(Vector2(7, 4), Vector2(17, 18), c, 2, true)
	draw_set_transform(Vector2.ZERO)
