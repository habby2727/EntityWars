extends Node
class_name CombatSim

func simulate(_attacker: Dictionary, _defender: Dictionary) -> Dictionary:
	var result := {
		"winner": "attacker",
		"score": 1
	}
	return result
