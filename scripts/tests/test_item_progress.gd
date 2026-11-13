extends SceneTree

const ItemProgress := preload("res://scripts/domain/item_progress.gd")

func _initialize() -> void:
	var base := {"id": "test_item", "base_effects": {"power_flat": 1}, "effects": {"ward_pct": [0.2], "power_flat": [2,3,4,5,6,7,8,9,10,12], "poison": [2]}}
	var initial := ItemProgress.effective_item(base, {})
	var upgraded := ItemProgress.effective_item(base, {"test_item": {"level": 10}})
	assert(is_equal_approx(initial.effects.ward_pct[0], 0.2))
	assert(is_equal_approx(upgraded.effects.ward_pct[0], 0.2))
	assert(initial.effects.power_flat[0] == 1 and upgraded.effects.power_flat[0] == 12)
	assert(base.effects.power_flat.size() == 10)
	assert(upgraded.effects.poison[0] == 2 and base.effects.ward_pct[0] == 0.2)
	assert(ItemProgress.level_for("test_item", {"test_item": {"level": 99}}) == 10)
	var original := base.duplicate(true)
	var traits := {"test_item": {"level": 3, "specialization": "aggressive", "traits": [{"id": "power_flat", "points": 2}, {"id": "true_on_hit", "points": 1}, {"id": "dot_true", "points": 0}]}}
	var trait_item := ItemProgress.effective_item(base, traits)
	assert(trait_item.effects.power_flat[0] == 6 and trait_item.effects.true_on_hit[0] == 1)
	assert(not trait_item.effects.has("dot_true") and base == original)
	traits.test_item.traits[0].points = 0
	traits.test_item.traits[1].points = 0
	assert(ItemProgress.effective_item(base, traits) == ItemProgress.effective_item(base, {"test_item": {"level": 3}}))
	assert(ItemProgress.effective_item(base, {}) == initial)
	traits.test_item.traits[0].points = 2
	traits.test_item.traits[1].points = 1
	traits.test_item.fusion = {"donor_id": "bismuth_talisman"}
	var fused := ItemProgress.effective_item(base, traits)
	assert(fused.effects.power_flat[0] == 6 and fused.effects.true_on_hit[0] == 2)
	assert(ItemProgress.effective_item(base, traits).effects.true_on_hit[0] == 2 and base == original)
	traits.test_item.erase("specialization")
	assert(ItemProgress.effective_item(base, traits).effects.true_on_hit[0] == 1)
	var file := FileAccess.open("res://data/items.json", FileAccess.READ)
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	assert(catalog.items.size() == 8)
	for item in catalog.items:
		var baseline: Dictionary = ItemProgress.effective_item(item, {})
		var first: Dictionary = ItemProgress.effective_item(item, {item.id: {"level": 1}})
		var improved := false
		for key in item.effects:
			var values: Array = item.effects[key]
			if values.size() == 10:
				assert(item.base_effects.has(key) and float(baseline.effects[key][0]) >= 0)
				if float(first.effects[key][0]) > float(baseline.effects[key][0]):
					improved = true
				for level in range(1, 11):
					var effective: Dictionary = ItemProgress.effective_item(item, {item.id: {"level": level}})
					assert(effective.effects[key][0] == values[level - 1])
			else:
				assert(baseline.effects[key][0] == values[0] and first.effects[key][0] == values[0])
		assert(improved)
	print("ITEM_PROGRESS_PASS")
	quit()
