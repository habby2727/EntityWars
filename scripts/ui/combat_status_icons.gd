extends Control

signal effect_clicked(description: String)

const SLOT := 24.0
const BOSS_ROW_HEIGHT := 36.0
const DEFINITIONS := [
	["poison", "poison", "Veneno: daño periódico", "turns"],
	["shield_pct", "shield", "Escudo: reduce el próximo impacto", "percent"],
	["reflect_pct", "reflect", "Reflejo: devuelve daño en el próximo impacto", "percent"],
	["atk_boost", "atk_up", "Ataque aumentado en el próximo golpe", "plus"],
	["atk_down", "atk_down", "Ataque reducido en el próximo golpe", "minus"],
	["vuln_pct", "vuln", "Vulnerabilidad: aumenta el daño recibido en el próximo impacto", "percent"],
	["stun", "stun", "Aturdimiento: pierde acciones", "turns"],
	["hom_stun", "chain", "Homúnculo bloqueado", "turns"],
	["tempo_bonus", "tempo", "Cambio de tempo hasta la próxima iniciativa", "number"],
	["focus_next", "type", "Precisión aumentada en la próxima acción ofensiva", "plus"],
	["misalign_next", "stun", "Precisión reducida en la próxima acción ofensiva", "minus"],
	["poison_on_reflect", "poison", "Veneno al activar el próximo reflejo", "turns"],
]

var _wins := 0
var _effects: Array = []
var _boss_mode := false
var _extra_effects: Array = []

func set_boss_effects(enabled: bool, effects: Array) -> void:
	_boss_mode = enabled
	_extra_effects = effects.duplicate(true)
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_update_boss_height()
	queue_redraw()

func _visible_effects() -> Array:
	return _extra_effects + _effects

func _boss_slots() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var cursor := Vector2.ZERO
	var available := maxf(SLOT + 8.0, size.x)
	for effect in _visible_effects():
		var text_width := ThemeDB.fallback_font.get_string_size(str(effect.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var width := maxf(SLOT, text_width) + 8.0
		if cursor.x > 0.0 and cursor.x + width > available:
			cursor.x = 0.0
			cursor.y += BOSS_ROW_HEIGHT
		result.append(Rect2(cursor, Vector2(width, BOSS_ROW_HEIGHT)))
		cursor.x += width
	return result

func _update_boss_height() -> void:
	if _boss_mode:
		var slots := _boss_slots()
		size.y = BOSS_ROW_HEIGHT if slots.is_empty() else slots.back().end.y

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
				_queue_feedback("%s %s" % [key.replace("_pct", "").replace("_", " ").capitalize(), "ended" if current == 0.0 else value_text], str(definition[1]))
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
		_effects.append({"icon": definition[1], "label": label, "tooltip": "%s (%s)" % [definition[2], label]})
	var mark: Dictionary = status.get("hybrid_mark", {})
	if int(mark.get("remaining", 0)) > 0:
		_effects.append({"icon": "chain", "label": "%dT" % int(mark.remaining), "tooltip": "Marca híbrida: %d acciones del lanzador" % int(mark.remaining)})
	var active := float(fighter.get("spell_neutralize_active", 0.0))
	var pending := float(fighter.get("spell_neutralize_pending", 0.0))
	var neutralization := maxf(active, pending)
	var mark_turns := int(mark.get("remaining", 0))
	if _status_initialized and not is_equal_approx(neutralization, _previous_neutralization):
		_queue_feedback("Type alteration %s" % ("ended" if neutralization == 0 else "%d%%" % roundi(neutralization * 100.0)))
	if _status_initialized and mark_turns != _previous_mark_turns:
		_queue_feedback("Hybrid mark %s" % ("ended" if mark_turns == 0 else "%dT" % mark_turns))
	_previous_neutralization = neutralization
	_previous_mark_turns = mark_turns
	if active > 0.0 or pending > 0.0:
		var value := maxf(active, pending)
		var phase := "intercambio actual" if active > 0.0 else "próximo intercambio"
		_effects.append({"icon": "type", "label": "%d%%" % int(round(value * 100)), "tooltip": "Alteración de tipo: %d%% (%s)" % [int(round(value * 100)), phase]})
	_update_boss_height()
	queue_redraw()

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _feedback_until:
		_show_next_feedback()

func _show_next_feedback() -> void:
	if _feedback_queue.is_empty():
		_feedback = ""
		set_process(false)
	else:
		var next: Dictionary = _feedback_queue.pop_front()
		_feedback = str(next.text)
		_feedback_icon = str(next.icon)
		_feedback_until = Time.get_ticks_msec() + 1800
		set_process(true)
	queue_redraw()

func _queue_feedback(message: String, icon: String = "type") -> void:
	_feedback_queue.append({"text": message, "icon": icon})
	if _feedback.is_empty():
		_show_next_feedback()

func _get_tooltip(at_position: Vector2) -> String:
	if _boss_mode:
		var slots := _boss_slots()
		var boss_effects := _visible_effects()
		for i in slots.size():
			if slots[i].has_point(at_position):
				return str(boss_effects[i].tooltip)
		return ""
	var slot := int(at_position.x / SLOT)
	var offset := 0 if _boss_mode else 2
	if not _boss_mode and slot < 2:
		return "Victoria %d: %s" % [slot + 1, "conseguida" if slot < _wins else "pendiente"]
	var effects := _visible_effects()
	var index := slot - offset
	if index >= 0 and index < effects.size() and (_boss_mode or index < 5):
		return effects[index].tooltip
	if not _boss_mode and index == 5 and effects.size() > 5:
		var extra: Array[String] = []
		for effect in effects.slice(5):
			extra.append(effect.tooltip)
		return "\n".join(extra)
	return ""

func _draw() -> void:
	if _boss_mode:
		var slots := _boss_slots()
		var boss_effects := _visible_effects()
		for i in slots.size():
			var rect := slots[i]
			_draw_icon(boss_effects[i].icon, rect.position + Vector2((rect.size.x - SLOT) * 0.5, 0), true)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0, 32), str(boss_effects[i].label), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, Color.WHITE)
		return
	if not _boss_mode:
		for i in 2:
			_draw_icon("crown", Vector2(i * SLOT, 0), i < _wins)
	var effects := _visible_effects()
	var offset := 0 if _boss_mode else 2
	for i in (effects.size() if _boss_mode else mini(effects.size(), 5)):
		_draw_icon(effects[i].icon, Vector2((i + offset) * SLOT, 0), true)
		_draw_label(effects[i].label, (i + offset) * SLOT)
	if not _boss_mode and effects.size() > 5:
		_draw_label("+%d" % (effects.size() - 5), 7 * SLOT, 15)
	if not _boss_mode and not _feedback.is_empty():
		_draw_icon(_feedback_icon, Vector2(200, 0), true)
		draw_string(ThemeDB.fallback_font, Vector2(226, 14), _feedback, HORIZONTAL_ALIGNMENT_LEFT, 150, 13, Color("e4d39b"))

func _draw_label(label: String, x: float, baseline: int = 28) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline), label, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 9, Color(1, 1, 1))

func _draw_icon(kind: String, offset: Vector2, enabled: bool) -> void:
	draw_set_transform(offset)
	var c := Color.WHITE
	match kind:
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
