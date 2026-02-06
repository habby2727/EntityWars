extends RefCounted
class_name ExperimentCatalog

const EXPERIMENTS := [
	{
		"id": "refine_core",
		"name": "Refine Core",
		"desc": "Essence -> Core (safe)",
		"kind": "convert",
		"cost": {"essence": 50},
		"grants": {"core": 1},
		"success_chance": 1.0,
		"cooldown_s": 60
	},
	{
		"id": "arcane_distill",
		"name": "Arcane Distill",
		"desc": "Core -> Arcane Shard (medium risk)",
		"kind": "convert",
		"cost": {"core": 2},
		"grants": {"arcane_shard": 1},
		"success_chance": 0.7,
		"cooldown_s": 90
	},
	{
		"id": "catalyst_brew",
		"name": "Catalyst Brew",
		"desc": "Essence + Arcane Shard -> Living Catalyst (medium)",
		"kind": "convert",
		"cost": {"essence": 60, "arcane_shard": 1},
		"grants": {"living_catalyst": 1},
		"success_chance": 0.7,
		"cooldown_s": 120
	},
	{
		"id": "temporal_crystallize",
		"name": "Temporal Crystallize",
		"desc": "Essence -> Time Crystal (risky low yield)",
		"kind": "convert",
		"cost": {"essence": 120},
		"grants": {"time_crystal": 1},
		"success_chance": 0.4,
		"cooldown_s": 180
	},
	{
		"id": "volatile_overclock",
		"name": "Volatile Overclock",
		"desc": "10 min reactor output boost; increases volatile loss chance",
		"kind": "boost",
		"cost": {"essence": 80, "chaos_cell": 1},
		"cooldown_s": 600,
		"boost_id": "volatile_overclock",
		"boost_duration_s": 600
	},
	{
		"id": "mutagen_surge",
		"name": "Mutagen Surge",
		"desc": "10 min rare chance boost; increases failure chance",
		"kind": "boost",
		"cost": {"essence": 80, "arcane_shard": 1, "chaos_cell": 1},
		"cooldown_s": 600,
		"boost_id": "mutagen_surge",
		"boost_duration_s": 600
	}
]

static func get_all() -> Array:
	return EXPERIMENTS.duplicate(true)

static func get_by_id(experiment_id: String) -> Dictionary:
	for entry in EXPERIMENTS:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("id", "")) == experiment_id:
			return entry
	return {}
