extends SceneTree

const Passive := preload("res://scripts/domain/expedition_passive.gd")

func _initialize() -> void:
	var file := FileAccess.open("res://data/static/expedition_homunculi.json", FileAccess.READ)
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	assert(catalog.homunculi.size() == 14)
	for hom in catalog.homunculi:
		for level in [0, 3, 6, 10]:
			var state: Dictionary = Passive.create(hom, level)
			Passive.begin_exchange(state)
			Passive.begin_exchange(state)
			Passive.begin_exchange(state)
			state.consecutive_spell_hits = 2
			var context := {"hp":4, "max_hp":10, "relation":0.5 if hom.id == "honin" else 2.0, "target_debuffed":true, "shielded":true, "poison_damage":3}
			var instant: Array = Passive.trigger(state, hom.passive.event, context)
			assert(state.markers.size() == 1)
			assert(instant.size() + state.modifiers.size() == hom.passive.effects.size())
			Passive.trigger(state, hom.passive.event, context)
			assert(state.markers.size() == 1)
			Passive.finish_exchange(state)
			for modifier in state.modifiers:
				assert(modifier.duration == "next_exchange")
			Passive.begin_exchange(state)
			for modifier in state.modifiers:
				assert(int(modifier.exchange) == int(state.exchange))
			Passive.finish_exchange(state)
			assert(state.modifiers.is_empty())
	print("EXPEDITION_PASSIVE_PASS")
	quit(0)
