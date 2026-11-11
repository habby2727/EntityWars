extends RefCounted

static func group(spell: Dictionary) -> String:
	var kind := str(spell.get("type", ""))
	return kind.capitalize() if kind in ["hybrid", "universal"] else "Initial"

static func affinity(spell: Dictionary) -> String:
	if spell.get("type") == "hybrid":
		return "%s / %s" % [str(spell.get("primary_type", "")).capitalize(), str(spell.get("secondary_type", "")).capitalize()]
	return str(spell.get("type", "")).capitalize()

static func status(spell: Dictionary, entity_id: String, entity_type: String, progress: Dictionary, known: bool) -> String:
	var kind := str(spell.get("type", ""))
	if kind not in ["hybrid", "universal"]:
		return "Initial" if kind == entity_type else "Incompatible"
	if entity_type not in spell.get("eligible_types", []):
		return "Incompatible"
	if not known:
		return "Unknown"
	return "Learned" if str(spell.get("id", "")) in progress.get("learned_by_entity", {}).get(entity_id, []) else "Locked"

static func detail(spell: Dictionary, state: String) -> String:
	var power := "Support" if float(spell.get("power_mult", 0)) == 0 else "x%.2f" % float(spell.power_mult)
	var text := "%s | %s | %s\nPower: %s   Accuracy: %d%%   Cooldown: %d\n\n%s" % [affinity(spell), str(spell.get("category", "")).capitalize(), state, power, int(round(float(spell.get("accuracy", 0)) * 100)), int(spell.get("cooldown_turns", 0)), str(spell.get("desc", ""))]
	var effects: Array[String] = []
	for effect in spell.get("effects", []):
		var part := "%s: %s (%s)" % [str(effect.get("kind", "")).replace("_", " ").capitalize(), effect.get("value", 0), str(effect.get("target", ""))]
		if effect.has("second_value"):
			part += ", alternate: %s" % str(effect.second_value)
		effects.append(part)
	if not effects.is_empty():
		text += "\n\nEffects: " + "; ".join(effects)
	if spell.has("tower_level_required"):
		var costs: Array[String] = []
		for key in spell.get("research_cost", {}):
			costs.append("%s: %s" % [str(key).replace("_", " ").capitalize(), spell.research_cost[key]])
		text += "\n\nResearch: Spell Tower level %d\n%s\nTime: %d s" % [int(spell.tower_level_required), ", ".join(costs), int(spell.get("research_time_sec", 0))]
	return text
