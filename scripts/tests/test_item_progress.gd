extends SceneTree

const ItemProgress := preload("res://scripts/domain/item_progress.gd")

func _initialize() -> void:
	var base := {"id": "test_item", "effects": {"ward_pct": [0.2], "power_flat": [2,3,4,5,6,7,8,9,10,12], "poison": [2]}}
	var initial := ItemProgress.effective_item(base, {})
	var upgraded := ItemProgress.effective_item(base, {"test_item": {"level": 10}})
	assert(is_equal_approx(initial.effects.ward_pct[0], 0.2))
	assert(is_equal_approx(upgraded.effects.ward_pct[0], 0.2))
	assert(initial.effects.power_flat[0] == 2 and upgraded.effects.power_flat[0] == 12)
	assert(base.effects.power_flat.size() == 10)
	assert(upgraded.effects.poison[0] == 2 and base.effects.ward_pct[0] == 0.2)
	assert(ItemProgress.level_for("test_item", {"test_item": {"level": 99}}) == 10)
	print("ITEM_PROGRESS_PASS")
	quit()
