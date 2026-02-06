extends Node
class_name EconomyStub

# Deprecated for Lab economy; kept for legacy combat/offline systems.
# Offline-only economy and ranking stubs.
# Resources: player_xp, silver, gold, copper, diamonds (diamonds not used in offline beta)
# Bags ("Sacks") are just bundles of resources.

var resources := {
	"player_xp": 0,
	"silver": 100,
	"gold": 50,
	"copper": 80,
	"diamonds": 0,
}

var season_points := 0        # Batalla
var prestige_points := 0      # Competitivo

var daily_first_win_claimed := false

func reset_daily() -> void:
	daily_first_win_claimed = false

func can_pay(cost: Dictionary) -> bool:
	for k in cost.keys():
		if int(resources.get(k, 0)) < int(cost[k]):
			return false
	return true

func pay(cost: Dictionary) -> void:
	for k in cost.keys():
		resources[k] = int(resources.get(k, 0)) - int(cost[k])

func grant(grant_dict: Dictionary) -> void:
	for k in grant_dict.keys():
		resources[k] = int(resources.get(k, 0)) + int(grant_dict[k])

func make_sack(kind: String, base_amount: int, player_level: int, division_mult: float) -> Dictionary:
	# Scales with player_level and division
	var amount = int(round(base_amount * division_mult * (1.0 + player_level * 0.02)))
	match kind:
		"xp":
			return {"player_xp": amount}
		"silver":
			return {"silver": amount}
		"gold":
			return {"gold": max(1, int(amount * 0.6))}
		"copper":
			return {"copper": amount}
		_:
			return {}
