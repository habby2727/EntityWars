extends Control

const SLOT := 24.0
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

func set_fighter(wins: int, fighter: Dictionary) -> void:
	_wins = wins
	_effects.clear()
	var status: Dictionary = fighter.get("status", {})
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
	if active > 0.0 or pending > 0.0:
		var value := maxf(active, pending)
		var phase := "intercambio actual" if active > 0.0 else "próximo intercambio"
		_effects.append({"icon": "type", "label": "%d%%" % int(round(value * 100)), "tooltip": "Alteración de tipo: %d%% (%s)" % [int(round(value * 100)), phase]})
	queue_redraw()

func _get_tooltip(at_position: Vector2) -> String:
	var slot := int(at_position.x / SLOT)
	if slot < 2:
		return "Victoria %d: %s" % [slot + 1, "conseguida" if slot < _wins else "pendiente"]
	var index := slot - 2
	if index < mini(_effects.size(), 5):
		return _effects[index].tooltip
	if index == 5 and _effects.size() > 5:
		var extra: Array[String] = []
		for effect in _effects.slice(5):
			extra.append(effect.tooltip)
		return "\n".join(extra)
	return ""

func _draw() -> void:
	for i in 2:
		_draw_icon("crown", Vector2(i * SLOT, 0), i < _wins)
	for i in mini(_effects.size(), 5):
		_draw_icon(_effects[i].icon, Vector2((i + 2) * SLOT, 0), true)
		_draw_label(_effects[i].label, (i + 2) * SLOT)
	if _effects.size() > 5:
		_draw_label("+%d" % (_effects.size() - 5), 7 * SLOT, 15)

func _draw_label(label: String, x: float, baseline: int = 28) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, baseline), label, HORIZONTAL_ALIGNMENT_CENTER, SLOT, 9, Color(1, 1, 1))

func _draw_icon(kind: String, offset: Vector2, enabled: bool) -> void:
	draw_set_transform(offset)
	var c := Color.WHITE
	match kind:
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
