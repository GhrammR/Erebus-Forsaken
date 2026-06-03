class_name Corpse extends Node2D
## In-world remains of a previous death. Walk-over reclaim: transfer
## the corpse's gold into the player's Wallet, push the gear item
## back into Inventory (or drop it as a WorldItem if the backpack
## is full), then remove this corpse from CorpseSystem and free.
##
## A Corpse carries its own `corpse_data` Dictionary — the snapshot
## from CorpseSystem at instantiation — so each instance reads and
## writes the entry that belongs to it. This is what lets multiple
## corpses co-exist (Stage 7 Phase 5 multi-corpse design).

const FULL_FALLBACK_ITEM_SCENE := preload("res://scenes/items/world_item.tscn")

@onready var _pickup: Area2D = $PickupArea
@onready var _gold_label: Label = $GoldLabel
@onready var _item_label: Label = $ItemLabel

var corpse_data: Dictionary = {}
var _reclaimed: bool = false

func _ready() -> void:
	_pickup.input_pickable = false
	_pickup.body_entered.connect(_on_body_entered)
	_refresh_labels()

func set_corpse_data(data: Dictionary) -> void:
	corpse_data = data
	if is_inside_tree():
		_refresh_labels()

func _refresh_labels() -> void:
	var gold := int(corpse_data.get("gold", 0))
	_gold_label.text = "%d g" % gold if gold > 0 else ""
	var item_id := StringName(corpse_data.get("item_id", ""))
	if item_id == &"":
		_item_label.text = ""
		return
	var item: ItemData = Database.get_item(item_id) as ItemData
	_item_label.text = item.display_name if item != null else String(item_id)

func _on_body_entered(body: Node) -> void:
	if _reclaimed:
		return
	if not (body is Player):
		return
	_reclaim()

func _reclaim() -> void:
	_reclaimed = true
	var player := GameState.player as Player
	if player == null:
		push_warning("Corpse: GameState.player is null at reclaim")
		queue_free()
		return
	var gold := int(corpse_data.get("gold", 0))
	if gold > 0:
		var wallet := player.get_wallet()
		if wallet != null:
			wallet.add_gold(gold)
		else:
			push_warning("Corpse: player wallet is null at reclaim — %d gold lost" % gold)
	var item_id := StringName(corpse_data.get("item_id", ""))
	if item_id != &"":
		var inv := player.get_inventory()
		if inv != null and inv.add_item(item_id):
			pass
		else:
			_drop_overflow(item_id)
	CorpseSystem.remove_corpse(int(corpse_data.get("id", -1)))
	EventBus.item_picked_up.emit(&"_corpse")
	queue_free()

func _drop_overflow(item_id: StringName) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var w := FULL_FALLBACK_ITEM_SCENE.instantiate()
	w.item_id = item_id
	parent.add_child(w)
	w.global_position = global_position + Vector2(randf_range(-12, 12), -8)
