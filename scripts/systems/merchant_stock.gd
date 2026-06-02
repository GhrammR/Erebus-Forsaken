class_name MerchantStock extends Resource
## A vendor's offered wares. Each entry is the item id and a
## price override (or 0 to use the ItemData.base_price).

## Array of { "item_id": StringName, "price": int } dictionaries.
@export var entries: Array[Dictionary] = []

## Sell-back multiplier — what fraction of an item's base_price the
## vendor pays to buy from the player. 0.5 = vendor pays half.
@export var sell_back_ratio: float = 0.5

func buy_price(item_id: StringName) -> int:
	for e in entries:
		if StringName(e.get("item_id", &"")) == item_id:
			var override := int(e.get("price", 0))
			if override > 0:
				return override
			var item: ItemData = Database.get_item(item_id) as ItemData
			return item.base_price if item != null else 0
	return 0

func sell_price(item_id: StringName) -> int:
	var item: ItemData = Database.get_item(item_id) as ItemData
	if item == null or item.base_price <= 0:
		return 0
	return max(int(round(item.base_price * sell_back_ratio)), 1)

func has(item_id: StringName) -> bool:
	for e in entries:
		if StringName(e.get("item_id", &"")) == item_id:
			return true
	return false

func item_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in entries:
		out.append(StringName(e.get("item_id", &"")))
	return out
