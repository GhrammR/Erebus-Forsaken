class_name Player extends CharacterBody2D
## AD-02 — one Player scene. Class identity comes from a ClassData
## resource assigned at runtime via assign_class(). Sprite, stats, and
## class metadata all flow from that one call.

const WALK_SPEED: float = 140.0
const FACE_FLIP_DEADZONE: float = 0.1

# Combat
const ATTACK_BASE_DAMAGE: int = 8
const ATTACK_COOLDOWN: float = 0.4
const ATTACK_SWING_LEAD: float = 0.10
const ATTACK_SWING_END: float = 0.25
const DEATH_DURATION: float = 1.5

enum LifeState { ALIVE, DEAD }
enum CombatState { READY, ATTACKING }

var class_data: ClassData = null
var current_stats: Stats = null
var respawn_position: Vector2 = Vector2.ZERO

## Stage 5: directional facing for skills. `_facing_right` stays for
## the L/R sprite flip (visual). `facing_dir` is the unit Vector2 that
## skills aim along. Updated from movement intent; preserved when idle
## so a stationary skill cast still aims sensibly.
## See failure-modes #12 and gap-log Stage 4 -> Stage 5 carry-over.
var facing_dir: Vector2 = Vector2.RIGHT

var _intent: Vector2 = Vector2.ZERO
var _facing_right: bool = true
var _life: LifeState = LifeState.ALIVE
var _combat: CombatState = CombatState.READY
var _attack_cd_remaining: float = 0.0

## Stage 5: primary skill slot. Swapped in assign_class.
var _skill_1: Skill = null

const _SKILL_BY_CLASS: Dictionary = {
	&"myrmidon":       preload("res://scripts/skills/spear_lunge.gd"),
	&"pythia":         preload("res://scripts/skills/oracle_bolt.gd"),
	&"shade_hunter":   preload("res://scripts/skills/volley.gd"),
	&"ossuary_priest": preload("res://scripts/skills/bone_servant.gd"),
}

@onready var _sprite_anchor: Node2D = $SpriteAnchor
@onready var _input: PlayerInput = $PlayerInput
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: Area2D = $HurtboxComponent
@onready var _hitbox: HitboxComponent = $SpriteAnchor/HitboxComponent
@onready var _inventory: Inventory = $Inventory

var _sprite_anim: AnimationPlayer = null
var _sprite_root: Node = null

func _ready() -> void:
	# CharacterBody2D inherits input_pickable=true from CollisionObject2D
	# and would silently consume mouse clicks landing on the player's
	# collider — visible as a moving click-to-move dead zone. See
	# failure-modes.md #13.
	input_pickable = false
	_input.owner_body = self
	_input.move_intent_changed.connect(_on_move_intent_changed)
	_input.attack_pressed.connect(_on_attack_pressed)
	_input.skill_1_pressed.connect(_on_skill_1_pressed)
	_input.debug_kill_self_pressed.connect(_on_debug_kill_self)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_hitbox.base_damage = ATTACK_BASE_DAMAGE
	_hitbox.owner_body = self

func assign_class(cd: ClassData) -> void:
	assert(cd != null, "Player.assign_class: ClassData is null")
	class_data = cd

	# Stage 5: any class change is also a fresh start for skills. Sweep
	# persistent skill entities — currently just BoneServantMinion via
	# its group. Also handles the save-load path (SaveSystem calls
	# assign_class), satisfying the gap-log "minions don't persist
	# across saves" invariant.
	for m in get_tree().get_nodes_in_group(&"bone_servant_minions"):
		if is_instance_valid(m):
			m.queue_free()

	if current_stats != null and current_stats.recomputed.is_connected(_on_stats_recomputed):
		current_stats.recomputed.disconnect(_on_stats_recomputed)
	current_stats = Stats.from_class_data(cd, 1)
	current_stats.recomputed.connect(_on_stats_recomputed)
	_health.set_stats(current_stats)
	# Re-bind inventory to the new Stats (Stage 4)
	_inventory.stats = current_stats
	_inventory.class_id = cd.id
	_inventory._recompute_totals()

	# Stage 5 — swap the primary skill slot for the new class.
	if _skill_1 != null:
		_skill_1.queue_free()
		_skill_1 = null
	var skill_script: Script = _SKILL_BY_CLASS.get(cd.id, null)
	if skill_script != null:
		_skill_1 = skill_script.new()
		_skill_1.name = "Skill1"
		add_child(_skill_1)

	for child in _sprite_anchor.get_children():
		# Preserve the HitboxComponent — only swap visual children.
		if child == _hitbox:
			continue
		child.queue_free()
	_sprite_anim = null
	_sprite_root = null
	if cd.sprite_scene != null:
		var inst := cd.sprite_scene.instantiate()
		_sprite_anchor.add_child(inst)
		_sprite_root = inst
		_sprite_anim = inst.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if _sprite_anim == null:
			push_warning("Player.assign_class: sprite_scene has no AnimationPlayer for class %s" % cd.id)
	EventBus.stats_changed.emit(self)

func _physics_process(delta: float) -> void:
	if _life == LifeState.DEAD:
		velocity = Vector2.ZERO
		return
	_attack_cd_remaining = maxf(_attack_cd_remaining - delta, 0.0)
	if _combat == CombatState.ATTACKING:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	velocity = _intent * WALK_SPEED
	move_and_slide()
	_update_anim()
	_update_facing()

## Canonical AD-11 one-shot anim names that `_update_anim` will not
## interrupt while they are still playing. Once is_playing() goes
## false the player resumes idle/walk normally. This is what lets a
## skill's `play_sprite_anim("cast")` actually be visible — without
## this guard the per-frame _update_anim overwrites it instantly.
const _ONESHOT_ANIMS: Array[StringName] = [&"attack", &"cast", &"hit", &"die"]

func _update_anim() -> void:
	if _sprite_anim == null:
		return
	# Let any in-progress one-shot finish on its own.
	if _sprite_anim.current_animation in _ONESHOT_ANIMS and _sprite_anim.is_playing():
		return
	var anim_name := &"walk" if _intent != Vector2.ZERO else &"idle"
	if _sprite_anim.current_animation != anim_name:
		_sprite_anim.play(anim_name)

func _update_facing() -> void:
	if absf(_intent.x) < FACE_FLIP_DEADZONE:
		return
	var should_face_right := _intent.x > 0.0
	if should_face_right != _facing_right:
		_facing_right = should_face_right
		_sprite_anchor.scale.x = 1.0 if should_face_right else -1.0

func _on_move_intent_changed(direction: Vector2) -> void:
	_intent = direction
	# Update directional facing; preserve last-known when intent is zero.
	if direction != Vector2.ZERO:
		facing_dir = direction

func _on_skill_1_pressed() -> void:
	if _life != LifeState.ALIVE or _skill_1 == null:
		return
	_skill_1.try_activate(self, facing_dir)

func _on_stats_recomputed() -> void:
	EventBus.stats_changed.emit(self)

# ---- Combat ----------------------------------------------------------------

func _on_attack_pressed() -> void:
	attack()

func attack() -> void:
	if _life != LifeState.ALIVE:
		return
	if _combat != CombatState.READY:
		return
	if _attack_cd_remaining > 0.0:
		return
	_combat = CombatState.ATTACKING
	_attack_cd_remaining = ATTACK_COOLDOWN
	if _sprite_anim != null:
		_sprite_anim.play(&"attack")
	get_tree().create_timer(ATTACK_SWING_LEAD).timeout.connect(_arm_hitbox)
	get_tree().create_timer(ATTACK_SWING_END).timeout.connect(_disarm_hitbox)
	get_tree().create_timer(ATTACK_COOLDOWN).timeout.connect(_end_attack_state)

func _arm_hitbox() -> void:
	if _life == LifeState.ALIVE:
		_hitbox.arm()

func _disarm_hitbox() -> void:
	_hitbox.disarm()

func _end_attack_state() -> void:
	if _combat == CombatState.ATTACKING:
		_combat = CombatState.READY

func _on_damaged(_amount: int, _source: Node) -> void:
	if _amount > 0 and _sprite_anim != null and _life == LifeState.ALIVE \
			and _combat == CombatState.READY:
		_sprite_anim.play(&"hit")

func _on_died(_killer: Node) -> void:
	if _life == LifeState.DEAD:
		return
	_life = LifeState.DEAD
	_intent = Vector2.ZERO
	velocity = Vector2.ZERO
	_hurtbox.set_deferred(&"monitoring", false)
	_hitbox.disarm()
	_input.set_process_unhandled_input(false)
	_input.set_physics_process(false)
	if _sprite_anim != null:
		_sprite_anim.play(&"die")
	EventBus.player_died.emit()
	await get_tree().create_timer(DEATH_DURATION).timeout
	_respawn()

func _respawn() -> void:
	global_position = respawn_position
	current_stats.restore_hp(current_stats.max_hp)
	current_stats.restore_mp(current_stats.max_mp)
	_life = LifeState.ALIVE
	_combat = CombatState.READY
	_attack_cd_remaining = 0.0
	_hurtbox.set_deferred(&"monitoring", true)
	_input.set_process_unhandled_input(true)
	_input.set_physics_process(true)
	# Reset the sprite root's transform: the `die` animation leaves
	# rotation=PI/2 and modulate.a=0.3, and `idle` doesn't animate
	# those properties so they'd persist into the new life.
	if _sprite_root != null and _sprite_root is Node2D:
		var sr := _sprite_root as Node2D
		sr.rotation = 0.0
		sr.modulate = Color(1, 1, 1, 1)
	if _sprite_anim != null:
		_sprite_anim.stop()
		_sprite_anim.play(&"idle")

func _on_debug_kill_self() -> void:
	if _life != LifeState.ALIVE:
		return
	_health.kill(self)

# ---- Helpers ---------------------------------------------------------------

func get_input() -> PlayerInput:
	return _input

func get_facing_right() -> bool:
	return _facing_right

func get_health_component() -> HealthComponent:
	return _health

func get_inventory() -> Inventory:
	return _inventory

func get_skill_1() -> Skill:
	return _skill_1

## Public API for skills — lets a Skill subclass play one of the
## canonical AD-11 sprite animation names without reaching into Player
## internals. No-op if no sprite is bound.
func play_sprite_anim(anim_name: StringName) -> void:
	if _sprite_anim != null:
		_sprite_anim.play(anim_name)

func is_alive() -> bool:
	return _life == LifeState.ALIVE
