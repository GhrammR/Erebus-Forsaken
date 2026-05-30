class_name DropTable extends Resource
## Weighted item drop table. Stage 4: training dummy uses near-equal
## weights with no_drop_weight=0 to maximize testing variety. Stage 7
## enemies will tune no_drop_weight for proper economy.

## Each entry: { "item_id": StringName, "weight": int }
@export var entries: Array[Dictionary] = []

## Rolls in the pool. If selected, no item drops.
@export var no_drop_weight: int = 0

## Returns the item_id rolled, or &"" if no drop.
func roll() -> StringName:
	var total: int = no_drop_weight
	for e in entries:
		total += int(e.get("weight", 0))
	if total <= 0:
		return &""
	var r: int = randi() % total
	if r < no_drop_weight:
		return &""
	var acc: int = no_drop_weight
	for e in entries:
		acc += int(e.get("weight", 0))
		if r < acc:
			return StringName(e.get("item_id", &""))
	return &""
