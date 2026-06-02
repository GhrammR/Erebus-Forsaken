extends Node2D
## Minimal Player-shaped node for stage4_verify.gd. Has the same public
## surface SaveSystem._snapshot/_apply reads: current_stats, class_data,
## get_inventory(), global_position. Avoids spinning up the full
## CharacterBody2D scene (and its physics dependencies) inside a
## headless verifier.

var current_stats: Stats = null
var class_data: ClassData = null

var _inventory: Inventory = null

func setup(class_id: StringName) -> void:
	class_data = Database.get_class_data(class_id) as ClassData
	assert(class_data != null, "test player: class missing")
	current_stats = Stats.from_class_data(class_data, 1)
	_inventory = Inventory.new()
	_inventory.name = "Inventory"        # SaveSystem looks up via get_node_or_null("Inventory")
	_inventory.stats = current_stats
	add_child(_inventory)
	_inventory.set_active_class(class_data.id)

func get_inventory() -> Inventory:
	return _inventory

## Player has assign_class — SaveSystem.load_game calls it. Reuse the
## class_data field; rebuild Stats + rebind inventory.
func assign_class(cd: ClassData) -> void:
	class_data = cd
	current_stats = Stats.from_class_data(cd, 1)
	_inventory.stats = current_stats
	_inventory.set_active_class(cd.id)
