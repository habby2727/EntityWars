extends RefCounted

# Mutable state is owned by one fighter and discarded at the start of a battle.
static func create(hom: Dictionary, level: int) -> Dictionary:
	return {"id": str(hom.get("id", "")), "passive": hom.get("passive", {}).duplicate(true), "level": level, "exchange": 0, "markers": [], "modifiers": [], "attacks_made": 0, "consecutive_spell_hits": 0}

static func begin_exchange(state: Dictionary) -> void:
	state.exchange += 1
	state.markers = []
	state.modifiers = state.modifiers.filter(func(m): return int(m.exchange) >= int(state.exchange))

static func finish_exchange(state: Dictionary) -> void:
	state.modifiers = state.modifiers.filter(func(m): return int(m.exchange) > int(state.exchange))

static func finish_attack(state: Dictionary, hit: bool) -> void:
	state.attacks_made += 1
	state.consecutive_spell_hits = int(state.consecutive_spell_hits) + 1 if hit else 0
	state.modifiers = state.modifiers.filter(func(m): return int(m.exchange) != int(state.exchange) or m.duration != "current_attack")

static func modifiers(state: Dictionary) -> Dictionary:
	var result := {}
	for modifier in state.get("modifiers", []):
		if int(modifier.exchange) == int(state.exchange):
			result[modifier.kind] = float(result.get(modifier.kind, 0)) + float(modifier.amount)
	return result

static func trigger(state: Dictionary, event: String, context: Dictionary) -> Array:
	var passive: Dictionary = state.get("passive", {})
	if state.get("exchange", 0) < 1 or passive.get("event", "") != event or not state.markers.is_empty() or int(context.get("hp", 0)) <= 0:
		return []
	var condition := str(passive.get("condition", ""))
	var matches := false
	match condition:
		"always": matches = true
		"advantage": matches = float(context.get("relation", 1.0)) > 1.0
		"disadvantage": matches = float(context.get("relation", 1.0)) < 1.0
		"below_half_hp": matches = float(context.hp) < float(context.get("max_hp", 1)) / 2.0
		"two_consecutive_spell_hits": matches = int(state.consecutive_spell_hits) >= 2
		"target_debuffed": matches = bool(context.get("target_debuffed", false))
		"shielded": matches = bool(context.get("shielded", false))
		"opening_attack": matches = int(state.attacks_made) == 0
		"positive_damage": matches = int(context.get("poison_damage", 0)) > 0 and int(context.hp) < int(context.get("max_hp", 0))
		"third_exchange": matches = int(state.exchange) % 3 == 0
	if not matches:
		return []
	state.markers.append(str(state.id))
	var instant := []
	for effect in passive.get("effects", []):
		var amount := _scaled(effect.values, int(state.level), effect.kind not in ["accuracy_pct", "evasion_pct"])
		if effect.kind == "heal":
			amount = minf(amount, minf(float(context.poison_damage), float(context.max_hp) - float(context.hp)))
		if effect.duration == "instant":
			instant.append({"kind":effect.kind, "amount":amount})
		else:
			var exchange: int = state.exchange + (1 if effect.duration == "next_exchange" else 0)
			state.modifiers = state.modifiers.filter(func(m): return m.kind != effect.kind or int(m.exchange) != exchange)
			state.modifiers.append({"kind":effect.kind, "amount":amount, "duration":effect.duration, "exchange":exchange})
	return instant

static func _scaled(values: Array, level: int, integer: bool) -> float:
	var levels := [0, 3, 6, 10]
	var upper := 0
	while upper < 3 and level > levels[upper]:
		upper += 1
	if upper == 0:
		return float(values[0])
	var lower := upper - 1
	var value := float(values[lower]) + (float(values[upper]) - float(values[lower])) * float(level - levels[lower]) / float(levels[upper] - levels[lower])
	return floor(value + 0.000000001) if integer else snappedf(value, 0.0001)
