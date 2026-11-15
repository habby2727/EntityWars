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
		if effect.get("kind") == "physical_anomaly":
			effects.append(anomaly_detail(spell, effect))
			continue
		var strategic := strategic_detail(effect)
		if not strategic.is_empty():
			effects.append(strategic)
			continue
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

static func strategic_detail(effect: Dictionary) -> String:
	var amount := roundi(float(effect.get("value", 0)) * 100)
	match str(effect.get("kind", "")):
		"delayed_damage": return "Delayed: %d%% of actual direct HP damage after the next exchange; replaces the caster's prior delay on this target." % amount
		"debuff_transfer": return "Transfers one caster debuff to the enemy: poison, vulnerability, then attack reduction. No debuff means no effect."
		"buff_steal": return "Steals 50% of one enemy buff (attack, shield, then reflect), capped at 20%; no buff means no effect."
		"cooldown_jam": return "Adds 1 cooldown to the strongest eligible enemy spell, up to 4; basic attacks are unaffected."
		"counter_trap": return "Counter Trap: retaliates for %d%% of direct spell HP damage, up to 20%% of attacker HP. Expires after two exchanges or one trigger." % amount
		"ward_convert": return "Consumes a pre-existing spell shield for %d%% of its max-HP value as direct damage, capped at 20%% of target HP. Shields gained by this spell are retained." % amount
		"heal_suppression": return "Reduces enemy healing by 50% for two exchanges after casting."
		"hom_energy_siphon": return "Transfers up to 2 homunculus energy; both combatants need an active homunculus and the recipient cannot exceed its maximum."
	return ""

static func anomaly_detail(spell: Dictionary, effect: Dictionary) -> String:
	return "Phisical Anomaly — %s\n%s +15%% | %s -15%% direct spell damage\n3 exchanges after cast; affects both fighters.\nNew casts replace the current anomaly. Poison and homunculus damage are unaffected.\nAccuracy 100%% | CD 4" % [str(spell.get("name", "")), str(effect.get("favored_type", "")).capitalize(), str(effect.get("weakened_type", "")).capitalize()]
