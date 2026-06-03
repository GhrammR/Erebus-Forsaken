class_name Enemy extends CharacterBody2D
## Base for Stage 3 dummies and (later) wilderness enemies. Owns Stats
## via HealthComponent, plays the canonical AD-11 anim names through
## the sprite scene assigned in the subclass's .tscn.

@export var enemy_id: StringName = &""  ## Stage 7 — save persistence key
@export var max_hp: int = 100
@export var defense_value: int = 0
@export var attack_rating_value: int = 0
@export var sprite_scene: PackedScene
@export var drop_table: DropTable                ## Stage 4 — rolled on death
@export var corpse_linger: float = 1.0  ## seconds between die anim and queue_free

## Stage 8 — optional elite suffix. SpawnDirector assigns this before
## add_child so _ready applies the mults to Stats/sprite/damage in one
## pass. Saved per-enemy via EnemyRegistry snapshot so a Tough
## Shade-Wretch round-trips correctly across save/load + zone-cache.
@export var elite_modifier: EliteModifier = null

## Subclasses read this in _ready when computing outgoing damage
## (Hitbox.base_damage, projectile_damage). Defaults to 1.0; an elite
## modifier overrides during _apply_elite_modifier.
var elite_damage_mult: float = 1.0

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

## Stage 9 polish — tween-driven hit flash. The animation-track flash
## on the sprite scenes is fire-and-forget; if a follow-up anim
## interrupts mid-flash the modulate property stays at the red
## mid-frame value, leaving the entity stuck red. The tween restores
## modulate explicitly so a cancelled flash always ends at white.
var _hit_tween: Tween = null
const _HIT_FLASH_TINT: Color = Color(1.6, 0.6, 0.6, 1)
const _HIT_FLASH_DURATION: float = 0.18

func _ready() -> void:
	# Enemy body is a CharacterBody2D; disable mouse picking so it
	# doesn't eat click-to-move events (failure-modes.md #13).
	input_pickable = false
	# Stage 5: ally minions (BoneServantMinion) look up valid targets
	# via this group. Every Enemy joins it on _ready.
	add_to_group(&"enemies")
	# Apply elite mults to max_hp/defense/AR *before* Stats are built so
	# HealthComponent and DamageResolver see the boosted values from
	# tick zero. Tint + scale + spawns-on-death wait until after the
	# sprite subtree is up.
	_apply_elite_pre_stats()
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
	_apply_elite_post_sprite()

func _apply_elite_pre_stats() -> void:
	if elite_modifier == null:
		return
	max_hp = maxi(1, int(round(float(max_hp) * elite_modifier.hp_mult)))
	defense_value = int(round(float(defense_value) * elite_modifier.defense_mult))
	attack_rating_value = int(round(float(attack_rating_value) * elite_modifier.defense_mult))
	elite_damage_mult = elite_modifier.damage_mult

func _apply_elite_post_sprite() -> void:
	if elite_modifier == null:
		return
	_sprite_anchor.modulate = elite_modifier.tint
	_sprite_anchor.scale = Vector2.ONE * elite_modifier.scale_mult

func _on_damaged(amount: int, _source: Node) -> void:
	if amount > 0 and not _health.is_dead():
		AudioBank.play_sfx(&"hit_flesh")
	if amount > 0 and not _health.is_dead():
		_flash_hit()

## Procedural enemy sprites animate hit by tweening `Body:modulate` —
## a child of the sprite root. Tweening the SpriteAnchor (a grand-
## parent) leaves Body stuck at the interrupted red value, which
## multiplies into the rendered colour. Target the same Body node
## the anim_hit writes so a cancelled flash always lands on white.
## Elite tint stays on _sprite_anchor (untouched), so the rest-state
## colour for Body is plain white regardless.
func _flash_hit() -> void:
	var body := _hit_flash_target()
	if body == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	# Cancel any in-progress hit anim so it doesn't keep writing the
	# property while the tween runs.
	if _sprite_anim != null and _sprite_anim.current_animation == &"hit":
		_sprite_anim.stop()
	body.modulate = _HIT_FLASH_TINT
	_hit_tween = create_tween()
	_hit_tween.tween_property(body, "modulate",
			Color(1, 1, 1, 1), _HIT_FLASH_DURATION)

func _hit_flash_target() -> CanvasItem:
	if _sprite_anchor == null or _sprite_anchor.get_child_count() == 0:
		return null
	var sprite_root := _sprite_anchor.get_child(0) as Node
	if sprite_root == null:
		return null
	var body := sprite_root.get_node_or_null(^"Body") as CanvasItem
	if body != null:
		return body
	# Fall back to the sprite root if a future sprite layout doesn't
	# carry a "Body" subnode.
	return sprite_root as CanvasItem

func _on_died(killer: Node) -> void:
	if _sprite_anim != null:
		_sprite_anim.play(&"die")
	$HurtboxComponent.set_deferred(&"monitoring", false)
	$CollisionShape2D.set_deferred(&"disabled", true)
	EventBus.enemy_died.emit(self, killer)
	_try_drop()
	_try_drop_gold()
	_try_elite_spawn_on_death()
	await get_tree().create_timer(corpse_linger).timeout
	queue_free()

func _try_elite_spawn_on_death() -> void:
	if elite_modifier == null:
		return
	if elite_modifier.spawns_on_death == &"" or elite_modifier.spawn_count <= 0:
		return
	var packed := EnemyRegistry.scene_for(elite_modifier.spawns_on_death)
	if packed == null:
		return
	for i in elite_modifier.spawn_count:
		_spawn_elite_minion.call_deferred(packed, global_position
				+ Vector2(randf_range(-24, 24), randf_range(-24, 24)))

func _spawn_elite_minion(packed: PackedScene, at: Vector2) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var inst := packed.instantiate() as Enemy
	if inst == null:
		return
	parent.add_child(inst)
	inst.global_position = at

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
	# Stage 8 — every base drop gets a chance to roll a single prefix
	# tier (Strategic Review D3.A). maybe_roll_prefix either returns
	# the base id unchanged or registers a fresh synthetic instance id;
	# the rest of the pipeline doesn't need to care which.
	var rolled := ItemInstanceRegistry.maybe_roll_prefix(id)
	_spawn_world_item.call_deferred(rolled, drop_pos)

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
