class_name Wallet extends Node
## Player's gold purse. Owned by Player as a sibling of Inventory.
## SaveSystem round-trips the integer; Vendor UI spends/credits here.
## Per AD-08 EventBus whitelist, gold_changed is local — UI listeners
## connect to this node directly rather than going through EventBus.

signal gold_changed(new_total: int)

var gold: int = 0

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func set_gold(amount: int) -> void:
	gold = max(amount, 0)
	gold_changed.emit(gold)
