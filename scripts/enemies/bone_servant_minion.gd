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

## Stage 9 polish: radius-bound detection so the minion does not
## chase enemies it shouldn't even know about. Leash keeps it tied
## to the player so it doesn't wander off and refuse to come back.
const DETECTION_RADIUS: float = 220.0
const LEASH_RADIUS: float = 260.0
## Idle patrol: the minion picks a random point inside this radius
## around the player, walks to it, pauses to "look around" for a
## random beat, then picks a new point. Reads as a guard sweeping
## the area rather than a satellite orbiting on rails. The pause
## window is the breathing room — without it the minion would feel
## restless instead of watchful.
const PATROL_RADIUS_MIN: float = 36.0
const PATROL_RADIUS_MAX: float = 90.0
const PATROL_ARRIVE_EPS: float = 6.0
const PATROL_PAUSE_MIN: float = 0.6
const PATROL_PAUSE_MAX: float = 1.6
## If the player drifts far enough that the current patrol point
## would be visibly off-screen of the player, re-pick early.
const PATROL_REPATH_DRIFT: float = 140.0

const GROUP: StringName = &"bone_servant_minions"
const ENEMY_GROUP: StringName = &"enemies"
## Walls live on physics layer 1. The minion drops any target it
## doesn't have line-of-sight to so it stops mashing into walls when
## the enemy is on the other side of a gate. Proper navmesh
## pathfinding around walls is parked — see parking_lot.md::
## monster-pathfinding.
const _WALL_MASK: int = 1

@onready var _health: HealthComponent = $HealthComponent
@onready var _hitbox: HitboxComponent = $HitboxComponent
@onready var _hurtbox: Area2D = $HurtboxComponent
@onready var _sprite_anchor: Node2D = $SpriteAnchor

var current_stats: Stats = null
var owner_caster: Node = null
## Stage 9 — flat bonus added to the minion's base swing damage from
## the Ossuary Priest's unique item (skill_bonus_bone_servant affix).
## Set by BoneServant._execute before add_child.
var bonus_damage: int = 0
var _attack_cd_remaining: float = 0.0
var _patrol_target: Vector2 = Vector2.ZERO
var _patrol_anchor: Vector2 = Vector2.ZERO    ## player position at last pick
var _patrol_pause: float = 0.0
var _patrol_initialized: bool = false
var _hit_tween: Tween = null
## Whether the minion's sprite currently faces right (positive x).
## Flipped via _sprite_anchor.scale.x when horizontal velocity crosses
## the deadzone. Same pattern as Player._update_facing.
var _facing_right: bool = true
const _FACING_DEADZONE: float = 0.05
const _HIT_FLASH_TINT: Color = Color(1.6, 0.6, 0.6, 1)
const _HIT_FLASH_DURATION: float = 0.18
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
	_hitbox.base_damage = ATTACK_DAMAGE + bonus_damage
	_hitbox.owner_body = self
	# Summon-lifecycle: a minion outlives its summoner only as long as
	# the summoner is alive. When the player dies, every active summon
	# despawns. The minion subscribes itself so any future summon class
	# inherits the rule by following the same pattern.
	EventBus.player_died.connect(_on_summoner_died)
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
	# Drop a target that wandered out of leash / detection or died.
	if _target != null and not _target_still_valid(_target):
		_target = null
	if _target == null:
		_target = _find_target_in_radius()
	if _target == null:
		_idle_follow_player()
		_update_facing()
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
		# Face the target while swinging so the attack arm reads as
		# striking forward, not behind.
		_face_toward(to_target.x)
	_update_facing()
	move_and_slide()

## Patrol idle: pick a random point in a ring around the player, walk
## to it, pause to "scan," repeat. The pause is what sells the
## "on watch" read — a minion in motion the whole time looks anxious.
## Re-picks early if the player wanders, so the patrol stays anchored
## to wherever the player is currently standing rather than where they
## stood when the point was chosen.
##
## TODO: when summon AI gets its proper polish pass (see
## parking_lot.md::smart-ai-presence), patrol points should bias
## toward unexplored angles and recently-empty sightlines so the same
## point isn't picked twice in a row.
func _idle_follow_player() -> void:
	var p := _get_player()
	if p == null:
		velocity = Vector2.ZERO
		_play_anim_if_changed(&"idle")
		return
	var delta := get_physics_process_delta_time()
	# Fresh spawn or anchor drifted — pick the first point now so the
	# minion doesn't spend the first cycle stationary.
	if not _patrol_initialized:
		_pick_patrol_point(p)
		_patrol_initialized = true
	# Player drifted from where this point was anchored — repath.
	if (p.global_position - _patrol_anchor).length() > PATROL_REPATH_DRIFT:
		_pick_patrol_point(p)
	if _patrol_pause > 0.0:
		_patrol_pause = maxf(_patrol_pause - delta, 0.0)
		velocity = Vector2.ZERO
		_play_anim_if_changed(&"idle")
		if _patrol_pause <= 0.0:
			_pick_patrol_point(p)
		return
	var to_target := _patrol_target - global_position
	if to_target.length() <= PATROL_ARRIVE_EPS:
		_patrol_pause = randf_range(PATROL_PAUSE_MIN, PATROL_PAUSE_MAX)
		velocity = Vector2.ZERO
		_play_anim_if_changed(&"idle")
		return
	velocity = to_target.normalized() * SPEED
	_play_anim_if_changed(&"walk")

func _pick_patrol_point(p: Node2D) -> void:
	_patrol_anchor = p.global_position
	var angle := randf() * TAU
	var radius := randf_range(PATROL_RADIUS_MIN, PATROL_RADIUS_MAX)
	_patrol_target = p.global_position + Vector2.RIGHT.rotated(angle) * radius

func _find_target_in_radius() -> Node2D:
	var p := _get_player()
	var anchor: Vector2 = p.global_position if p != null else global_position
	var best: Node2D = null
	var best_d := DETECTION_RADIUS
	for e in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if not is_instance_valid(e):
			continue
		var en := e as Node2D
		if en == null:
			continue
		if "current_stats" in en and en.current_stats != null \
				and en.current_stats.is_dead():
			continue
		var d := (en.global_position - global_position).length()
		# Only engage enemies the minion can both see and reach without
		# breaking the leash to the player.
		if d > DETECTION_RADIUS:
			continue
		if (en.global_position - anchor).length() > LEASH_RADIUS:
			continue
		# LOS gate: no point picking a target the minion would just
		# mash into a wall to reach. A future navmesh pass would
		# replace this with proper pathfinding.
		if not _has_line_of_sight(en):
			continue
		if d < best_d:
			best_d = d
			best = en
	return best

func _target_still_valid(t: Node2D) -> bool:
	if not is_instance_valid(t):
		return false
	if "current_stats" in t and t.current_stats != null \
			and t.current_stats.is_dead():
		return false
	if (t.global_position - global_position).length() > DETECTION_RADIUS:
		return false
	var p := _get_player()
	if p != null and (t.global_position - p.global_position).length() > LEASH_RADIUS:
		return false
	# Drop the target the moment a wall slips between us. The minion
	# will fall back to its patrol; if the wall opens again (gate
	# unlocks, player kites the target out), the next radius scan
	# re-acquires.
	if not _has_line_of_sight(t):
		return false
	return true

func _has_line_of_sight(target: Node2D) -> bool:
	if target == null:
		return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	# Cast from the minion's chest to the target's chest so a low
	# debris collider can't false-positive block.
	var from := global_position + Vector2(0, -20)
	var to := target.global_position + Vector2(0, -20)
	var params := PhysicsRayQueryParameters2D.create(from, to, _WALL_MASK)
	params.exclude = [self]
	# When the minion presses against a thick wall, the chest-y
	# offset can fall *inside* the wall's collider. Without
	# hit_from_inside the ray treats the origin as outside the
	# collider and reports zero hits — i.e. "clear LOS" straight
	# through the wall. Flipping this on makes the ray fire an
	# immediate hit when starting inside the wall.
	params.hit_from_inside = true
	return space.intersect_ray(params).is_empty()

func _get_player() -> Node2D:
	var p: Node = GameState.player
	if p == null or not is_instance_valid(p):
		return null
	return p as Node2D

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
	if _health.is_dead():
		return
	_flash_hit()

## The procedural minion sprite's anim_hit writes `.:modulate` on the
## sprite root itself. Tweening the SpriteAnchor (parent) leaves the
## sprite root stuck at whatever red the anim_hit was interrupted at —
## multiply renders as red. Skip playing the per-sprite hit anim
## entirely and tween the sprite root directly so the property the
## anim_hit was racing on always lands at white.
func _flash_hit() -> void:
	if _sprite_root == null or not (_sprite_root is CanvasItem):
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	# Cancel any running per-sprite anim that might be writing modulate.
	if _sprite_anim != null and _sprite_anim.current_animation == &"hit":
		_sprite_anim.stop()
	(_sprite_root as CanvasItem).modulate = _HIT_FLASH_TINT
	_hit_tween = create_tween()
	_hit_tween.tween_property(_sprite_root, "modulate",
			Color(1, 1, 1, 1), _HIT_FLASH_DURATION)

func _on_summoner_died() -> void:
	if _health.is_dead():
		return
	# Route through HealthComponent.kill so the same die-anim and
	# cleanup path runs as a normal lethal hit.
	_health.kill(self)

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

func _update_facing() -> void:
	if absf(velocity.x) < _FACING_DEADZONE:
		return
	_face_toward(velocity.x)

func _face_toward(x: float) -> void:
	if absf(x) < _FACING_DEADZONE:
		return
	var should_face_right := x > 0.0
	if should_face_right == _facing_right:
		return
	_facing_right = should_face_right
	if _sprite_anchor != null:
		_sprite_anchor.scale.x = 1.0 if should_face_right else -1.0
