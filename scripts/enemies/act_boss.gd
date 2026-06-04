class_name ActBoss extends Enemy
## Stage 9 — Act 1 boss. Three HP-threshold phases, guaranteed
## class-aware unique on first kill, sets GameState.act_1_complete on
## death. Does not extend WildernessEnemy because the chase/kite ladder
## doesn't match a phase-driven encounter — boss owns its own AI.
##
## Phase ladder (re-evaluated after every damage event):
##   P1 100→66% HP — Stalk:   slow melee chase, telegraphed swings.
##   P2  66→33% HP — Channel: stops, fires 3-orb fan every 1.6s.
##   P3  33→ 0% HP — Frenzy:  speed +60%, cadence ×0.5, melee
##                            alternating with 6-orb radial burst
##                            every 4s; summons 1 wretch on entry.
##
## Transitions trigger a 0.3s invuln window + sprite-tint shift +
## skill_cast sfx + a `cast` anim telegraph. Each transition is
## one-shot (a phase can never go backwards even if the player heals
## the boss — academic since no heals exist in Act 1).
##
## Damage path remains AD-04 — the hitbox + projectiles route through
## DamageResolver.resolve via HealthComponent.take_damage.

const _PROJECTILE_SCENE := preload("res://scenes/vfx/enemy_projectile.tscn")
const _WRETCH_SCENE := preload("res://scenes/enemies/shade_wretch.tscn")

# Class-id → unique-item-id map. First-kill drop picks based on the
# player's class at the moment the boss dies. Single source of truth
# for the unique table; the verifier walks this to assert Database
# has all four entries.
const UNIQUE_BY_CLASS: Dictionary = {
	&"myrmidon":       &"forsaken_myrmidon_sigil",
	&"pythia":         &"forsaken_pythia_sigil",
	&"shade_hunter":   &"forsaken_shade_hunter_sigil",
	&"ossuary_priest": &"forsaken_ossuary_priest_sigil",
}

const PHASE_2_THRESHOLD: float = 0.66
const PHASE_3_THRESHOLD: float = 0.33

const P1_MOVE_SPEED: float = 75.0
const P1_ATTACK_INTERVAL: float = 1.6
const P2_ATTACK_INTERVAL: float = 1.6   ## cast cadence in channel phase
const P3_MOVE_SPEED_MULT: float = 1.6
const P3_ATTACK_INTERVAL_MULT: float = 0.5
const P3_BURST_INTERVAL: float = 4.0

const AGGRO_RANGE: float = 480.0
const MELEE_RANGE: float = 56.0
const P2_PROJECTILE_DAMAGE: int = 10
const P3_PROJECTILE_DAMAGE: int = 12
const TRANSITION_INVULN: float = 0.3
## P2 will close to within this distance before standing still to cast.
## Computed from projectile_range at runtime; keep a small margin so
## the orb's max-distance doesn't fizzle right at the target.
const P2_CAST_RANGE_MARGIN: float = 60.0
## Walls live on physics layer 1. LOS raycasts against this mask only
## — enemy/player layers ignored so the player's own body doesn't
## block the boss's sight of themselves.
const _WALL_MASK: int = 1

enum Phase { P1_STALK, P2_CHANNEL, P3_FRENZY }

@export var melee_damage: int = 14
@export var projectile_speed: float = 280.0
@export var projectile_range: float = 520.0
@export var projectile_color: Color = Color(0.55, 0.85, 1.0, 1)

var _phase: Phase = Phase.P1_STALK
var _move_speed: float = P1_MOVE_SPEED
var _attack_interval: float = P1_ATTACK_INTERVAL
var _attack_cd: float = 0.0
var _burst_cd: float = P3_BURST_INTERVAL
var _aggroed: bool = false

func _ready() -> void:
	super._ready()
	# The boss arms its own swing hitbox dynamically rather than using a
	# permanent HitboxComponent like the wretches — phase transitions
	# need to retune base_damage cleanly. Disable the always-on Hitbox
	# child so it never double-counts swings.
	var hb := get_node_or_null(^"HitboxComponent") as Node
	if hb != null and "monitoring" in hb:
		hb.set_deferred(&"monitoring", false)

func _physics_process(delta: float) -> void:
	if _health == null or _health.is_dead():
		velocity = Vector2.ZERO
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_burst_cd = maxf(_burst_cd - delta, 0.0)
	var player := _get_target()
	if player == null:
		velocity = Vector2.ZERO
		_play_anim_if_changed(&"idle")
		move_and_slide()
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	# Aggro requires both range and line-of-sight. A sealed gate
	# between boss and player keeps the boss patient — no sniping
	# through walls, no pre-fight projectile lock-in.
	var has_los := _has_line_of_sight(player)
	if not _aggroed:
		if dist <= AGGRO_RANGE and has_los:
			_aggroed = true
		else:
			velocity = Vector2.ZERO
			_play_anim_if_changed(&"idle")
			move_and_slide()
			return
	elif not has_los:
		# Lost sight (player slipped behind a wall or the gate closed):
		# stop attacking but stay aggro'd so they re-engage on contact.
		velocity = Vector2.ZERO
		_play_anim_if_changed(&"idle")
		move_and_slide()
		return
	var dir := to_player.normalized() if dist > 0.01 else Vector2.RIGHT
	match _phase:
		Phase.P1_STALK:
			_tick_stalk(dir, dist)
		Phase.P2_CHANNEL:
			_tick_channel(dir)
		Phase.P3_FRENZY:
			_tick_frenzy(dir, dist)
	move_and_slide()

func _tick_stalk(dir: Vector2, dist: float) -> void:
	if dist > MELEE_RANGE:
		velocity = dir * _move_speed
		_play_anim_if_changed(&"walk")
	else:
		velocity = Vector2.ZERO
		if _attack_cd <= 0.0:
			_attack_cd = _attack_interval
			_swing_melee(dir, melee_damage)
		elif not _attack_anim_playing():
			_play_anim_if_changed(&"idle")

func _tick_channel(dir: Vector2) -> void:
	# P2 used to root in place; if the player walked out the boss
	# would keep firing into empty floor. Now: if outside cast range,
	# walk closer at stalk speed; otherwise stop and cast.
	var p := _get_target()
	var dist := INF
	if p != null:
		dist = (p.global_position - global_position).length()
	var cast_range := projectile_range - P2_CAST_RANGE_MARGIN
	if dist > cast_range:
		velocity = dir * _move_speed
		_play_anim_if_changed(&"walk")
		return
	velocity = Vector2.ZERO
	if _attack_cd <= 0.0:
		_attack_cd = P2_ATTACK_INTERVAL
		# Recompute aim at the moment of firing; the cached `dir` from
		# the start of the physics step may be stale by 1.6s.
		var aim := _aim_at(p)
		_fire_fan(aim, 3, 0.26, P2_PROJECTILE_DAMAGE)
	elif not _attack_anim_playing():
		_play_anim_if_changed(&"idle")

func _aim_at(target: Node2D) -> Vector2:
	if target == null:
		return Vector2.RIGHT
	var d: Vector2 = target.global_position - global_position
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT

func _tick_frenzy(dir: Vector2, dist: float) -> void:
	if _burst_cd <= 0.0:
		_burst_cd = P3_BURST_INTERVAL
		_fire_radial_burst(6, P3_PROJECTILE_DAMAGE)
		return
	if dist > MELEE_RANGE:
		velocity = dir * _move_speed
		_play_anim_if_changed(&"walk")
	else:
		velocity = Vector2.ZERO
		if _attack_cd <= 0.0:
			_attack_cd = _attack_interval
			_swing_melee(dir, melee_damage)
		elif not _attack_anim_playing():
			_play_anim_if_changed(&"idle")

# ---- combat helpers ------------------------------------------------------

func _swing_melee(dir: Vector2, dmg: int) -> void:
	# Defer the hitbox spawn so we never schedule an Area2D add during a
	# physics flush (failure-modes #17). Same pattern bog_caller uses.
	_play_anim_if_changed(&"attack")
	_spawn_swing_hitbox.call_deferred(dir, dmg)

func _spawn_swing_hitbox(dir: Vector2, dmg: int) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	# Reuse the skill hitbox scene — it carries a HitboxComponent +
	# CollisionShape2D + the arm/disarm interface SpearLunge uses.
	var hb_scene := load("res://scenes/vfx/skill_hitbox.tscn") as PackedScene
	if hb_scene == null:
		return
	var hb := hb_scene.instantiate() as HitboxComponent
	if hb == null:
		return
	hb.owner_body = self
	hb.base_damage = dmg
	parent.add_child(hb)
	hb.global_position = global_position + dir * 44.0
	hb.rotation = dir.angle()
	get_tree().create_timer(0.10).timeout.connect(hb.arm)
	get_tree().create_timer(0.28).timeout.connect(hb.disarm)
	get_tree().create_timer(0.34).timeout.connect(hb.queue_free)

func _fire_fan(dir: Vector2, count: int, spread_rad: float, dmg: int) -> void:
	_play_anim_if_changed(&"cast")
	AudioBank.play_sfx(&"skill_cast")
	var step := 0.0
	if count > 1:
		step = (2.0 * spread_rad) / float(count - 1)
	for i in count:
		var angle := -spread_rad + step * float(i)
		_spawn_orb.call_deferred(dir.rotated(angle), dmg)

func _fire_radial_burst(count: int, dmg: int) -> void:
	_play_anim_if_changed(&"cast")
	AudioBank.play_sfx(&"skill_cast")
	for i in count:
		var angle := TAU * float(i) / float(count)
		_spawn_orb.call_deferred(Vector2.RIGHT.rotated(angle), dmg)

func _spawn_orb(dir: Vector2, dmg: int) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var orb := _PROJECTILE_SCENE.instantiate() as Projectile
	if orb == null:
		return
	orb.configure(dir, dmg, self, projectile_speed, projectile_range, projectile_color)
	parent.add_child(orb)
	orb.global_position = global_position + Vector2(0, -28) + dir * 18.0

# ---- phase transitions ---------------------------------------------------

func _on_damaged(amount: int, source: Node) -> void:
	super._on_damaged(amount, source)
	_check_phase_transition()

func _check_phase_transition() -> void:
	if current_stats == null or _health == null or _health.is_dead():
		return
	var frac := float(current_stats.current_hp) / float(maxi(current_stats.max_hp, 1))
	if _phase == Phase.P1_STALK and frac <= PHASE_2_THRESHOLD:
		_enter_phase_2()
	elif _phase == Phase.P2_CHANNEL and frac <= PHASE_3_THRESHOLD:
		_enter_phase_3()

func _enter_phase_2() -> void:
	_phase = Phase.P2_CHANNEL
	_attack_cd = P2_ATTACK_INTERVAL    ## breathing room before first fan
	_telegraph_transition(Color(1.1, 0.95, 1.4, 1))

func _enter_phase_3() -> void:
	_phase = Phase.P3_FRENZY
	_move_speed = P1_MOVE_SPEED * P3_MOVE_SPEED_MULT
	_attack_interval = P1_ATTACK_INTERVAL * P3_ATTACK_INTERVAL_MULT
	_attack_cd = 0.4
	_burst_cd = P3_BURST_INTERVAL
	_telegraph_transition(Color(1.4, 0.9, 1.0, 1))
	# Phase 3 adds: one shade_wretch reinforcement.
	_spawn_phase3_add.call_deferred()

func _telegraph_transition(tint: Color) -> void:
	_play_anim_if_changed(&"cast")
	AudioBank.play_sfx(&"skill_cast")
	if _sprite_anchor != null:
		_sprite_anchor.modulate = tint
	var hurtbox := get_node_or_null(^"HurtboxComponent") as Node
	if hurtbox != null and "monitoring" in hurtbox:
		hurtbox.set_deferred(&"monitoring", false)
		get_tree().create_timer(TRANSITION_INVULN).timeout.connect(
				func(): if is_instance_valid(hurtbox): hurtbox.monitoring = true)

func _spawn_phase3_add() -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var inst := _WRETCH_SCENE.instantiate() as Enemy
	if inst == null:
		return
	parent.add_child(inst)
	inst.global_position = global_position + Vector2(randf_range(-60, 60), randf_range(40, 80))

# ---- death / drop --------------------------------------------------------

func _on_died(killer: Node) -> void:
	# Set Act 1 completion BEFORE the deferred queue_free so the flag is
	# observable from the save snapshot if the player F5's on the spot.
	GameState.act_1_complete = true
	var first_kill := not GameState.boss_first_kill
	GameState.boss_first_kill = true
	if _sprite_anim != null:
		_sprite_anim.play(&"die")
	$HurtboxComponent.set_deferred(&"monitoring", false)
	$CollisionShape2D.set_deferred(&"disabled", true)
	EventBus.enemy_died.emit(self, killer)
	# First kill: guaranteed class-matched unique. Subsequent kills fall
	# back to the normal drop_table roll (which may also be null — fine).
	if first_kill:
		_drop_first_kill_unique()
	else:
		_try_drop()
	_try_drop_gold()
	await get_tree().create_timer(corpse_linger).timeout
	queue_free()

func _drop_first_kill_unique() -> void:
	var pid: StringName = _player_class_id()
	var uid: StringName = UNIQUE_BY_CLASS.get(pid, &"")
	if uid == &"":
		# No class on player (shouldn't happen — fall back to table).
		_try_drop()
		return
	AudioBank.play_sfx(&"drop_rare")
	var drop_pos := global_position + Vector2(randf_range(-14, 14), randf_range(-18, -6))
	_spawn_world_item.call_deferred(uid, drop_pos)

static func _player_class_id() -> StringName:
	var p: Node = GameState.player
	if p == null or not is_instance_valid(p):
		return &""
	if "class_data" in p and p.class_data != null:
		return p.class_data.id
	return &""

# ---- anim helpers --------------------------------------------------------

## True when there's a clear line of sight from the boss to the
## target with no wall body in between. A closed gate (StaticBody2D
## on the wall layer) breaks the line and disables aggro.
func _has_line_of_sight(target: Node2D) -> bool:
	if target == null:
		return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	# Raycast from the boss's chest height rather than feet so a low
	# debris collider doesn't false-positive block. Same on the target.
	var from := global_position + Vector2(0, -32)
	var to := target.global_position + Vector2(0, -24)
	var params := PhysicsRayQueryParameters2D.create(from, to, _WALL_MASK)
	params.exclude = [self]
	# When the boss stands close to a wall its chest-y offset can
	# fall *inside* the wall collider; without hit_from_inside the
	# ray reports zero hits and would falsely declare LOS through
	# the wall.
	params.hit_from_inside = true
	var result := space.intersect_ray(params)
	return result.is_empty()

func _get_player() -> Node2D:
	var p: Node = GameState.player
	if p == null or not is_instance_valid(p):
		return null
	if "get_health_component" in p:
		var ph = p.get_health_component()
		if ph != null and ph.is_dead():
			return null
	return p as Node2D

## Boss-side variant of WildernessEnemy._get_target. Picks the closer
## of player + bone-servant minion. Mild bias toward the player so the
## boss prefers the real threat in a tie.
const _BOSS_MINION_BIAS: float = 0.85
const _BOSS_MINION_GROUP: StringName = &"bone_servant_minions"

func _get_target() -> Node2D:
	var player := _get_player()
	var best: Node2D = player
	var best_d := INF
	if player != null:
		best_d = (player.global_position - global_position).length()
	for m in get_tree().get_nodes_in_group(_BOSS_MINION_GROUP):
		if not is_instance_valid(m):
			continue
		var n := m as Node2D
		if n == null:
			continue
		if "current_stats" in n and n.current_stats != null \
				and n.current_stats.is_dead():
			continue
		var d := (n.global_position - global_position).length() / _BOSS_MINION_BIAS
		if d < best_d:
			best_d = d
			best = n
	return best

func _attack_anim_playing() -> bool:
	return _sprite_anim != null \
			and _sprite_anim.is_playing() \
			and (_sprite_anim.current_animation == &"attack"
					or _sprite_anim.current_animation == &"cast")

func _play_anim_if_changed(anim_name: StringName) -> void:
	if _sprite_anim != null and _sprite_anim.current_animation != anim_name:
		_sprite_anim.play(anim_name)

# ---- verifier hooks ------------------------------------------------------

func get_phase() -> int:
	return int(_phase)

func force_check_phase() -> void:
	_check_phase_transition()
