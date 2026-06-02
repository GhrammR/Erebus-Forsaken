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

@onready var _sprite_anchor: Node2D = $SpriteAnchor
@onready var _health: HealthComponent = $HealthComponent

var _sprite_anim: AnimationPlayer = null
var current_stats: Stats = null     # public so DamageResolver finds it via duck-type

func _ready() -> void:
	# Enemy body is a CharacterBody2D; disable mouse picking so it
	# doesn't eat click-to-move events (failure-modes.md #13).
	input_pickable = false
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
	await get_tree().create_timer(corpse_linger).timeout
	queue_free()

func _try_drop() -> void:
	if drop_table == null:
		return
	var id: StringName = drop_table.roll()
	if id == &"":
		return
	var item := _WORLD_ITEM_SCENE.instantiate()
	item.item_id = id
	# Small random offset so multi-drop doesn't perfectly stack.
	var jitter := Vector2(randf_range(-12, 12), randf_range(-6, 6))
	get_parent().add_child(item)
	item.global_position = global_position + jitter
	EventBus.item_dropped.emit(id, item.global_position)
