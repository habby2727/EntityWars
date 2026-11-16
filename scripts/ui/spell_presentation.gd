extends RefCounted

const Stats := preload("res://scripts/ui/stat_presentation.gd")
const Localization := preload("res://scripts/ui/game_localization.gd")

static func group(spell: Dictionary) -> String:
	var kind := str(spell.get("type", ""))
	return kind.capitalize() if kind in ["hybrid", "universal"] else "Initial"

static func affinity(spell: Dictionary) -> String:
	if spell.get("type") == "hybrid":
		return "%s / %s" % [_type_label(str(spell.get("primary_type", ""))), _type_label(str(spell.get("secondary_type", "")))]
	return _type_label(str(spell.get("type", "")))

static func _type_label(value: String) -> String:
	return Localization.catalog("type", value, "name", value.capitalize())

static func state_label(value: String) -> String:
	return Localization.catalog("spell_state", value, "name", value)

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
	var power: String = TranslationServer.translate("SPELL_SUPPORT") if float(spell.get("power_mult", 0)) == 0 else Stats.percent(float(spell.power_mult))
	var description := Localization.catalog("spell", str(spell.get("id", "")), "desc", str(spell.get("desc", "")))
	var category := str(spell.get("category", ""))
	var text := str(TranslationServer.translate("SPELL_DETAIL_HEADER")).replace("\\n", "\n") % [affinity(spell), Localization.catalog("spell_category", category, "name", category.capitalize()), state_label(state), power, int(round(float(spell.get("accuracy", 0)) * 100)), int(spell.get("cooldown_turns", 0)), description]
	var effects: Array[String] = []
	for effect in spell.get("effects", []):
		if effect.get("kind") == "physical_anomaly":
			if TranslationServer.get_locale() == "es":
				effects.append("Anomalía física — %s\n%s +15%% | %s -15%% de daño directo de hechizos\nDura 3 intercambios y afecta a ambos combatientes.\nUn nuevo lanzamiento sustituye la anomalía. No afecta al veneno ni al daño de homúnculos.\nPrecisión 100%% | Espera 4" % [Localization.catalog("spell", str(spell.get("id", "")), "name", str(spell.get("name", ""))), _type_label(str(effect.get("favored_type", ""))), _type_label(str(effect.get("weakened_type", "")))])
			else:
				effects.append(anomaly_detail(spell, effect))
			continue
		var strategic := strategic_detail(effect)
		if not strategic.is_empty():
			var kind := str(effect.get("kind", ""))
			var key := "SPELL_STRATEGIC_%s" % kind.to_upper()
			var translated := str(TranslationServer.translate(key))
			if translated != key:
				strategic = translated % roundi(float(effect.get("value", 0)) * 100) if kind in ["delayed_damage", "counter_trap", "ward_convert"] else translated
			effects.append(strategic)
			continue
		var kind := str(effect.get("kind", ""))
		var target := str(effect.get("target", ""))
		var part := "%s: %s (%s)" % [Localization.catalog("effect_kind", kind, "name", kind.replace("_", " ").capitalize()), Stats.effect_value(kind, effect.get("value", 0)), Localization.catalog("effect_target", target, "name", target)]
		if effect.has("second_value"):
			part += str(TranslationServer.translate("SPELL_ALTERNATE")) % Stats.effect_value(kind, effect.second_value, "second_value")
		effects.append(part)
	if not effects.is_empty():
		text += "\n\n" + str(TranslationServer.translate("SPELL_EFFECTS")) + " " + "; ".join(effects)
	if spell.has("tower_level_required"):
		var costs: Array[String] = []
		for key in spell.get("research_cost", {}):
			costs.append("%s: %s" % [Localization.catalog("resource", str(key), "name", str(key).replace("_", " ").capitalize()), spell.research_cost[key]])
		text += "\n\n" + str(TranslationServer.translate("SPELL_RESEARCH_DETAIL")).replace("\\n", "\n") % [int(spell.tower_level_required), ", ".join(costs), int(spell.get("research_time_sec", 0))]
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

static func localized_strategic_detail(effect: Dictionary) -> String:
	var original := strategic_detail(effect)
	if original.is_empty():
		return original
	var kind := str(effect.get("kind", ""))
	var key := "SPELL_STRATEGIC_%s" % kind.to_upper()
	var translated := str(TranslationServer.translate(key))
	if translated == key:
		return original
	return translated % roundi(float(effect.get("value", 0)) * 100) if kind in ["delayed_damage", "counter_trap", "ward_convert"] else translated

static func anomaly_detail(spell: Dictionary, effect: Dictionary) -> String:
	if TranslationServer.get_locale() == "es":
		return "Anomalía física — %s\n%s +15%% | %s -15%% de daño directo de hechizos\nDura 3 intercambios y afecta a ambos combatientes.\nUn nuevo lanzamiento sustituye la anomalía. No afecta al veneno ni al daño de homúnculos.\nPrecisión 100%% | Espera 4" % [Localization.catalog("spell", str(spell.get("id", "")), "name", str(spell.get("name", ""))), _type_label(str(effect.get("favored_type", ""))), _type_label(str(effect.get("weakened_type", "")))]
	return "Physical Anomaly — %s\n%s +15%% | %s -15%% direct spell damage\n3 exchanges after cast; affects both fighters.\nNew casts replace the current anomaly. Poison and homunculus damage are unaffected.\nAccuracy 100%% | CD 4" % [str(spell.get("name", "")), str(effect.get("favored_type", "")).capitalize(), str(effect.get("weakened_type", "")).capitalize()]
