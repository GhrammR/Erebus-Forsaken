class_name Projectile extends Node2D
## Reusable projectile for ranged skills. Moves in `direction` at
## `speed`, despawns on first hit or after `max_distance`. Damage
## routes through the embedded HitboxComponent -> HurtboxComponent ->
## HealthComponent.take_damage -> DamageResolver (AD-04 preserved).

signal hit_target(target: Node)
signal expired

@export var speed: float = 500.0
@export var max_distance: float = 600.0
@export var direction: Vector2 = Vector2.RIGHT
@export var visual_color: Color = Color(0.6, 0.85, 0.85, 1)

@onready var _hitbox: HitboxComponent = $Hitbox
@onready var _visual: Polygon2D = $Visual

var _traveled: float = 0.0

func _ready() -> void:
	rotation = direction.angle()
	_visual.color = visual_color
	_hitbox.arm()
	_hitbox.area_entered.connect(_on_area_entered)
	# Stage 9 polish — projectiles must die on wall contact. Walls are
	# StaticBody2D (bodies, not areas) so area_entered alone won't
	# catch them; the hitbox masks include the wall layer (1) and we
	# despawn on body overlap. No damage delivered: walls have no
	# HurtboxComponent. Later traversal skills (teleport, etc.) can
	# opt out by flagging the projectile.
	_hitbox.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var step := speed * delta
	position += direction * step
	_traveled += step
	if _traveled >= max_distance:
		expired.emit()
		queue_free()

func _on_area_entered(other: Area2D) -> void:
	# Only despawn on a HurtboxComponent overlap (a real target).
	var hurt := other as HurtboxComponent
	if hurt == null:
		return
	hit_target.emit(hurt.get_parent())
	queue_free()

func _on_body_entered(_body: Node) -> void:
	# Walls (any non-hurt body in the hitbox's mask) stop the projectile.
	expired.emit()
	queue_free()

## Configure before adding to the tree; call after instantiate().
func configure(dir: Vector2, damage: int, source: Node,
		spd: float = 500.0, max_dist: float = 600.0,
		color: Color = Color(0.6, 0.85, 0.85, 1)) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	speed = spd
	max_distance = max_dist
	visual_color = color
	# _hitbox is null until _ready, so we use a deferred set path.
	_pending_damage = damage
	_pending_source = source

var _pending_damage: int = 0
var _pending_source: Node = null

func _enter_tree() -> void:
	# Apply pending hitbox config; _ready will run right after and arm.
	if has_node(^"Hitbox"):
		var hb := $Hitbox as HitboxComponent
		hb.base_damage = _pending_damage
		hb.owner_body = _pending_source
