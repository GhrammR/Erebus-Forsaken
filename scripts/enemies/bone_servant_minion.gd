class_name BoneServantMinion extends CharacterBody2D
## Persistent allied minion summoned by the Ossuary Priest's Bone
## Servant skill. Walks toward the nearest "enemies"-group node,
## auto-attacks in melee range. Dies when its HP hits 0.
##
## Save exclusion: minions live only in the active scene tree. They
## are not snapshotted by SaveSystem; on load, any pre-load minion
## is left orphaned until the next Bone Servant re-cast (which finds
## and frees existing minions via the bone_servant_minions group).
##
## Per gap-log Stage 4 -> Stage 5.

const SPEED: float = 110.0
const ATTACK_RANGE: float = 36.0
const ATTACK_INTERVAL: float = 0.8
const ATTACK_DAMAGE: int = 8
const SWING_LEAD: float = 0.08
const SWING_WINDOW: float = 0.16

const GROUP: StringName = &"bone_servant_minions"
const ENEMY_GROUP: StringName = &"enemies"

@onready var _health: HealthComponent = $HealthComponent
@onready var _hitbox: HitboxComponent = $HitboxComponent
@onready var _hurtbox: Area2D = $HurtboxComponent
@onready var _sprite_anchor: Node2D = $SpriteAnchor

var current_stats: Stats = null
var owner_caster: Node = null
var _attack_cd_remaining: float = 0.0
var _target: Node2D = null
var _sprite_anim: AnimationPlayer = null
var _sprite_root: Node = null

func _ready() -> void:
	input_pickable = false
	add_to_group(GROUP)
	current_stats = Stats.new_basic(60, 0, 0)
	_health.set_stats(current_stats)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_hitbox.base_damage = ATTACK_DAMAGE
	_hitbox.owner_body = self
	_install_sprite()

func _install_sprite() -> void:
	var scene: PackedScene = load("res://art/procedural/enemies/bone_servant_sprite.tscn")
	if scene == null:
		return
	var inst := scene.instantiate()
	_sprite_anchor.add_child(inst)
	_sprite_root = inst
	_sprite_anim = inst.get_node_or_null(^"AnimationPlayer") as AnimationPlayer

func _physics_process(delta: float) -> void:
	if _health.is_dead():
		velocity = Vector2.ZERO
		return
	_attack_cd_remaining = maxf(_attack_cd_remaining - delta, 0.0)
	_target = _find_nearest_enemy()
	if _target == null:
		velocity = Vector2.ZERO
		_play_anim_if_changed(&"idle")
		move_and_slide()
		return
	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	if dist > ATTACK_RANGE:
		velocity = to_target.normalized() * SPEED
		_play_anim_if_changed(&"walk")
	else:
		velocity = Vector2.ZERO
		if _attack_cd_remaining <= 0.0:
			_do_attack(to_target.normalized())
	move_and_slide()

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group(ENEMY_GROUP)
	var best: Node2D = null
	var best_d := INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var en := e as Node2D
		if en == null:
			continue
		var d := (en.global_position - global_position).length()
		if d < best_d:
			best_d = d
			best = en
	return best

func _do_attack(dir: Vector2) -> void:
	_attack_cd_remaining = ATTACK_INTERVAL
	if _sprite_anim != null:
		_sprite_anim.play(&"attack")
	# Position the hitbox in front of the minion, aligned with attack dir.
	_hitbox.position = dir * 18.0
	_hitbox.rotation = dir.angle()
	get_tree().create_timer(SWING_LEAD).timeout.connect(_hitbox.arm)
	get_tree().create_timer(SWING_LEAD + SWING_WINDOW).timeout.connect(_hitbox.disarm)

func _on_damaged(_amount: int, _source: Node) -> void:
	if _sprite_anim != null and not _health.is_dead():
		_sprite_anim.play(&"hit")

func _on_died(_killer: Node) -> void:
	if _sprite_anim != null:
		_sprite_anim.play(&"die")
	_hurtbox.set_deferred(&"monitoring", false)
	_hitbox.disarm()
	await get_tree().create_timer(0.7).timeout
	queue_free()

func _play_anim_if_changed(anim_name: StringName) -> void:
	if _sprite_anim != null and _sprite_anim.current_animation != anim_name:
		_sprite_anim.play(anim_name)
