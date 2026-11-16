extends SceneTree

const Stats := preload("res://scripts/ui/stat_presentation.gd")
const SpellView := preload("res://scripts/ui/spell_presentation.gd")

func _initialize() -> void:
	TranslationServer.set_locale("en")
	assert(Stats.percent(0.9) == "90%")
	assert(Stats.effect_value("shield", 0.5) == "50%")
	assert(Stats.effect_value("poison", 2) == "2")
	assert(Stats.effect_value("shield_by_order", 0.075, "second_value") == "7.5%")
	assert(Stats.effect_value("bonus_if_low_hp", 0.4, "threshold") == "40%")
	assert(Stats.stat_value("incoming_mult", 0.96) == "96%")
	assert(Stats.stat_value("ward_pct", [0.075, 0.1]) == "7.5%, 10%")
	var detail := SpellView.detail({"name": "Test", "type": "sulfur", "category": "attack", "power_mult": 0.9, "accuracy": 1.0, "effects": [{"kind": "shield", "value": 0.5, "target": "self"}, {"kind": "poison", "value": 2, "target": "enemy"}]}, "Initial")
	assert(detail.contains("Power: 90%") and detail.contains("Shield: 50%") and detail.contains("Poison: 2"))
	print("PASS readable stat presentation")
	quit()
