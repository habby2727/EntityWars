extends SceneTree

const HomProgress := preload("res://scripts/domain/homunculus_progress.gd")

func _initialize() -> void:
	var hom := {"id": "cinder", "buff_atk": 2, "buff_def": 0, "buff_hp": 1}
	var original := hom.duplicate(true)
	var progress := {"cinder": {"level": 6, "mutation_id": "vitality"}}
	var effective := HomProgress.effective_bonuses(hom, progress)
	assert(effective.hp_flat == 12 and effective.power_flat == 3 and effective.guard_flat == 2)
	progress.cinder.mutation_id = "resonance"
	assert(is_equal_approx(HomProgress.effective_bonuses(hom, progress).favorable_type_bonus, 0.03))
	progress.cinder.mutation_id = "catalyst"
	assert(HomProgress.effective_bonuses(hom, progress).power_flat == 4 and hom == original)
	print("HOMUNCULUS_PROGRESS_PASS")
	quit()
