class_name WildernessEnemy extends Enemy
## Base for the first hostile enemies — the Blighted Reach roster.
## Adds simple aggro/chase/attack AI on top of Enemy. Subclasses
## supply attack execution by overriding `_perform_attack(dir)`.
##
## Behaviour ladder, evaluated each physics tick:
##   1. If dead, freeze.
##   2. If player out of `aggro_range`, idle.
##   3. If player further than `attack_range`, chase at `move_speed`.
##   4. If `keep_distance > 0` and player closer than `keep_distance`,
##      kite away (used by ranged casters).
##   5. Else stop and try to attack (cooldown-gated).
##
## The target is always the live Player from GameState; once it dies
## or unregisters, the enemy reverts to idle.

@export var move_speed: float = 90.0
@export var aggro_range: float = 220.0
@export var deaggro_range: float = 360.0
@export var attack_range: float = 36.0     ## within this -> attack
@export var keep_distance: float = 0.0     ## > 0 -> kite when closer
@export var attack_interval: float = 1.0
@export var attack_windup: float = 0.15    ## telegraph before damage

## Soft "personal space" — a fading repel force pushes enemies away
## from siblings whose centers are within this radius. Keeps a
## kited cluster from collapsing into a single indistinguishable
## blob without preventing them from melee-stacking at the player.
const SEPARATION_RADIUS: float = 34.0
const SEPARATION_WEIGHT: float = 0.55

enum AiState { IDLE, CHASE, KITE, WINDUP, RECOVER }

var _attack_cd: float = 0.0
var _state: AiState = AiState.IDLE
var _aggroed: bool = false

func _physics_process(delta: float) -> void:
	if _health == null or _health.is_dead():
		velocity = Vector2.ZERO
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	var player := _get_player()
	if player == null:
		_set_idle()
		move_and_slide()
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	if not _aggroed:
		if dist <= aggro_range:
			_aggroed = true
	else:
		if dist > deaggro_range:
			_aggroed = false
	if not _aggroed:
		_set_idle()
		move_and_slide()
		return
	var dir := to_player.normalized() if dist > 0.01 else Vector2.RIGHT
	var separation := _compute_separation()
	if dist > attack_range:
		_state = AiState.CHASE
		velocity = (dir + separation * SEPARATION_WEIGHT) * move_speed
		_play_anim_if_changed(&"walk")
	elif keep_distance > 0.0 and dist < keep_distance:
		_state = AiState.KITE
		velocity = (-dir + separation * SEPARATION_WEIGHT) * move_speed
		_play_anim_if_changed(&"walk")
	else:
		# In attack range: stop closing on the player but still let
		# separation nudge us off a stack so we don't all overlap
		# the same pixel while swinging.
		velocity = separation * move_speed * SEPARATION_WEIGHT
		if _attack_cd <= 0.0:
			_state = AiState.WINDUP
			_attack_cd = attack_interval
			_play_anim_if_changed(&"attack")
			_perform_attack(dir)
		elif not _attack_anim_playing():
			# Don't snap back to idle while the attack swing/cast
			# animation is still mid-frame — that's what made the
			# wretches look like they froze instead of striking.
			_play_anim_if_changed(&"idle")
	move_and_slide()

func _compute_separation() -> Vector2:
	var force := Vector2.ZERO
	for n in get_tree().get_nodes_in_group(&"enemies"):
		if n == self:
			continue
		var other := n as Node2D
		if other == null:
			continue
		var d := global_position - other.global_position
		var dist := d.length()
		if dist > 0.001 and dist < SEPARATION_RADIUS:
			# Linear falloff so adjacent enemies push hardest and the
			# force fades to zero at the edge of the radius.
			force += d.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return force

func _attack_anim_playing() -> bool:
	return _sprite_anim != null \
			and _sprite_anim.is_playing() \
			and _sprite_anim.current_animation == &"attack"

func _set_idle() -> void:
	velocity = Vector2.ZERO
	_state = AiState.IDLE
	_play_anim_if_changed(&"idle")

func _get_player() -> Node2D:
	var p: Node = GameState.player
	if p == null or not is_instance_valid(p):
		return null
	var pl := p as Player
	if pl == null:
		return null
	var ph := pl.get_health_component()
	if ph != null and ph.is_dead():
		return null
	return p as Node2D

## Subclasses override to swing a hitbox or spawn a projectile. The
## base call enforces the windup delay and animation; the subclass
## owns the actual damage delivery (deferred via timers / call_deferred
## so we never schedule Area2D changes mid-physics-flush).
func _perform_attack(_dir: Vector2) -> void:
	pass

func _play_anim_if_changed(anim_name: StringName) -> void:
	if _sprite_anim != null and _sprite_anim.current_animation != anim_name:
		_sprite_anim.play(anim_name)
