extends RefCounted
class_name Wallet

var balance: int = 0

func _init(start_balance: int = 0) -> void:
	balance = max(0, int(start_balance))

func can_afford(cost: int) -> bool:
	if cost < 0:
		return false
	return balance >= cost

func add(amount: int) -> int:
	if amount < 0:
		return balance
	balance = max(0, balance + int(amount))
	return balance

func subtract(amount: int) -> bool:
	if amount < 0:
		return false
	if balance - int(amount) < 0:
		return false
	balance -= int(amount)
	return true

func serialize() -> Dictionary:
	return {"balance": balance}
