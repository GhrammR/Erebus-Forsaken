class_name BogCaller extends WildernessEnemy
## Ranged caster. Holds pressure at range, baits melee approaches, then
## dodges after the player commits to an attack before re-casting.

const _PROJECTILE_SCENE := preload("res://scenes/vfx/enemy_projectile.tscn")

@export var projectile_damage: int = 10
@export var projectile_speed: float = 280.0
@export var projectile_range: float = 480.0
@export var projectile_color: Color = Color(0.55, 0.85, 0.55, 1)
@export var ideal_range: float = 245.0
@export var danger_range: float = 128.0
@export var panic_range: float = 72.0
@export var dodge_duration: float = 0.58
@export var post_dodge_cast_delay: float = 0.18

var _dodge_remaining: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _bait_clock: float = 0.0

func _ready() -> void:
	super._ready()
	if elite_damage_mult != 1.0:
		projectile_damage = int(round(float(projectile_damage) * elite_damage_mult))

func _physics_process(delta: float) -> void:
	if _health == null or _health.is_dead():
		velocity = Vector2.ZERO
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	var player := _get_target()
	if player == null:
		_bait_clock = 0.0
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
		_bait_clock = 0.0
		_set_idle()
		move_and_slide()
		return
	var dir := to_player.normalized() if dist > 0.01 else Vector2.RIGHT
	var separation := _compute_separation()
	if _dodge_remaining > 0.0:
		_dodge_remaining = maxf(_dodge_remaining - delta, 0.0)
		velocity = (_dodge_dir + separation * SEPARATION_WEIGHT).normalized() * move_speed * 1.18
		_play_anim_if_changed(&"walk")
		move_and_slide()
		return
	if dist > attack_range:
		_bait_clock = 0.0
		_state = AiState.CHASE
		velocity = (dir + separation * SEPARATION_WEIGHT).normalized() * move_speed
		_play_anim_if_changed(&"walk")
	elif dist < panic_range or (dist < danger_range and _target_is_attacking(player)):
		_start_dodge(dir, separation)
	elif dist < danger_range:
		_bait_clock += delta
		_state = AiState.IDLE
		velocity = separation * move_speed * 0.25
		if _bait_clock >= 0.35 and _attack_cd <= 0.0:
			_cast_at(player)
		elif not _attack_anim_playing():
			_play_anim_if_changed(&"idle")
	else:
		_bait_clock = 0.0
		_state = AiState.WINDUP if _attack_cd <= 0.0 else AiState.IDLE
		var range_bias := -dir if dist < ideal_range else dir
		velocity = (range_bias * 0.22 + separation * SEPARATION_WEIGHT) * move_speed
		if _attack_cd <= 0.0:
			_cast_at(player)
		elif not _attack_anim_playing():
			_play_anim_if_changed(&"idle")
	move_and_slide()

func _start_dodge(dir_to_player: Vector2, separation: Vector2) -> void:
	_bait_clock = 0.0
	_state = AiState.KITE
	var lateral := Vector2(-dir_to_player.y, dir_to_player.x)
	if int(Time.get_ticks_msec() / 200) % 2 == 0:
		lateral = -lateral
	_dodge_dir = (-dir_to_player * 0.82 + lateral * 0.46 + separation * 0.35).normalized()
	_dodge_remaining = dodge_duration
	_attack_cd = minf(_attack_cd, post_dodge_cast_delay)
	velocity = _dodge_dir * move_speed * 1.18
	_play_anim_if_changed(&"walk")

func _cast_at(target: Node2D) -> void:
	var dir := _aim_at(target)
	_attack_cd = attack_interval
	_play_anim_if_changed(&"attack")
	_perform_attack(dir)

func _aim_at(target: Node2D) -> Vector2:
	if target == null:
		return Vector2.RIGHT
	var d: Vector2 = target.global_position - global_position
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT

func _target_is_attacking(target: Node2D) -> bool:
	if target != null and target.has_method(&"is_attacking"):
		return bool(target.call(&"is_attacking"))
	return false

func _attack_anim_playing() -> bool:
	return _sprite_anim != null \
			and _sprite_anim.is_playing() \
			and (_sprite_anim.current_animation == &"attack" \
					or _sprite_anim.current_animation == &"cast")

func _perform_attack(dir: Vector2) -> void:
	# Defer the actual spawn to next idle so a Bog-Caller standing in
	# a tight cluster never schedules an Area2D add during a physics
	# flush from a sibling's attack. See failure-modes #17.
	_spawn_orb.call_deferred(dir)

func _spawn_orb(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var orb: Projectile = _PROJECTILE_SCENE.instantiate() as Projectile
	if orb == null:
		return
	var spawn_pos := global_position + Vector2(0, -18) + dir * 18.0
	orb.configure(dir, projectile_damage, self,
			projectile_speed, projectile_range, projectile_color)
	parent.add_child(orb)
	orb.global_position = spawn_pos
