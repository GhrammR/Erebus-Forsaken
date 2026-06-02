class_name Enemy extends CharacterBody2D
## Base for Stage 3 dummies and (later) wilderness enemies. Owns Stats
## via HealthComponent, plays the canonical AD-11 anim names through
## the sprite scene assigned in the subclass's .tscn.

@export var max_hp: int = 100
@export var defense_value: int = 0
@export var attack_rating_value: int = 0
@export var sprite_scene: PackedScene
@export var drop_table: DropTable                ## Stage 4 — rolled on death
@export var corpse_linger: float = 1.0  ## seconds between die anim and queue_free

const _WORLD_ITEM_SCENE := preload("res://scenes/items/world_item.tscn")
const _GOLD_PICKUP_SCENE := preload("res://scenes/items/gold_pickup.tscn")

## Stage 6 — gold economy stub. Each kill rolls for a gold drop with
## a value in [gold_min, gold_max]. gold_drop_chance = 0 disables.
## Stage 7 will tune per enemy type; for now training dummies use
## an aggressive default so the pickup pipeline is easy to validate.
@export_range(0.0, 1.0, 0.05) var gold_drop_chance: float = 0.9
@export var gold_min: int = 1
@export var gold_max: int = 5

@onready var _sprite_anchor: Node2D = $SpriteAnchor
@onready var _health: HealthComponent = $HealthComponent

var _sprite_anim: AnimationPlayer = null
var current_stats: Stats = null     # public so DamageResolver finds it via duck-type

func _ready() -> void:
	# Enemy body is a CharacterBody2D; disable mouse picking so it
	# doesn't eat click-to-move events (failure-modes.md #13).
	input_pickable = false
	# Stage 5: ally minions (BoneServantMinion) look up valid targets
	# via this group. Every Enemy joins it on _ready.
	add_to_group(&"enemies")
	current_stats = Stats.new_basic(max_hp, defense_value, attack_rating_value)
	_health.set_stats(current_stats)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	if sprite_scene != null:
		var inst := sprite_scene.instantiate()
		_sprite_anchor.add_child(inst)
		_sprite_anim = inst.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if _sprite_anim != null:
			_sprite_anim.play(&"idle")

func _on_damaged(amount: int, _source: Node) -> void:
	if amount > 0 and _sprite_anim != null and not _health.is_dead():
		_sprite_anim.play(&"hit")

func _on_died(_killer: Node) -> void:
	if _sprite_anim != null:
		_sprite_anim.play(&"die")
	$HurtboxComponent.set_deferred(&"monitoring", false)
	$CollisionShape2D.set_deferred(&"disabled", true)
	_try_drop()
	_try_drop_gold()
	await get_tree().create_timer(corpse_linger).timeout
	queue_free()

func _try_drop() -> void:
	if drop_table == null:
		return
	var id: StringName = drop_table.roll()
	if id == &"":
		return
	# _on_died runs from inside a physics-flush callback chain
	# (area_entered -> take_damage -> died). Adding a WorldItem
	# synchronously here would attach its PickupArea Area2D mid-flush,
	# triggering "Can't change this state while flushing queries".
	# Defer to the next idle frame. See failure-modes #17.
	# Items drop above the corpse so their name labels don't overlap
	# with the gold "Xg" label (which drops below). See _try_drop_gold.
	var jitter := Vector2(randf_range(-14, 14), randf_range(-18, -6))
	var drop_pos := global_position + jitter
	_spawn_world_item.call_deferred(id, drop_pos)

func _spawn_world_item(id: StringName, at: Vector2) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var item := _WORLD_ITEM_SCENE.instantiate()
	item.item_id = id
	parent.add_child(item)
	item.global_position = at
	EventBus.item_dropped.emit(id, at)

func _try_drop_gold() -> void:
	if gold_drop_chance <= 0.0 or randf() > gold_drop_chance:
		return
	var value := randi_range(gold_min, gold_max)
	# Bias gold below the corpse, items above. Their labels render
	# upward from the pickup position; separating them in y stops the
	# "1g" / item-name labels stacking on top of each other.
	var jitter := Vector2(randf_range(-10, 10), randf_range(22, 32))
	_spawn_gold_pickup.call_deferred(value, global_position + jitter)

func _spawn_gold_pickup(value: int, at: Vector2) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var coin := _GOLD_PICKUP_SCENE.instantiate()
	coin.value = value
	parent.add_child(coin)
	coin.global_position = at
