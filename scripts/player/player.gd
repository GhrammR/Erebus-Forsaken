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
## Stage 9.8 — Hearth Ember channel lock. While true, movement intent
## is zeroed in _physics_process and attack / skill inputs early-return.
## ConsumableUse owns the lifecycle; Player just consults the flag.
var _channeling: bool = false

## Stage 5: primary skill slot. Swapped in assign_class.
var _skill_1: Skill = null

const _SKILL_BY_CLASS: Dictionary = {
	&"myrmidon":       preload("res://scripts/skills/spear_lunge.gd"),
	&"pythia":         preload("res://scripts/skills/oracle_bolt.gd"),
	&"shade_hunter":   preload("res://scripts/skills/volley.gd"),
	&"ossuary_priest": preload("res://scripts/skills/bone_servant.gd"),
}

## Stage 7 Phase 5 — when true, _on_died skips the auto-respawn
## timer. The orchestrating layer (Game.gd in production, the
## death screen flow) calls respawn() explicitly once the player
## has reviewed the scene and chosen to return to town. Default
## false keeps the workbench/headless flow self-contained.
@export var external_respawn_handler: bool = false

@onready var _sprite_anchor: Node2D = $SpriteAnchor
@onready var _input: PlayerInput = $PlayerInput
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: Area2D = $HurtboxComponent
@onready var _hitbox: HitboxComponent = $SpriteAnchor/HitboxComponent
@onready var _inventory: Inventory = $Inventory
@onready var _wallet: Wallet = $Wallet

var _sprite_anim: AnimationPlayer = null
var _sprite_root: Node = null
## Stage 15 — paper-doll component. Created per assign_class so a class
## swap rebinds it to the freshly-instantiated sprite. Listens to
## Inventory.equipment_changed and maintains overlay polygons under
## the sprite's Body node + toggles the class's built-in weapon arm.
var _paperdoll: EquipmentPaperdoll = null
## Tween driving the hit flash. The per-class sprite hit anims also
## carry a modulate track, but the AnimationPlayer doesn't reliably
## land the final keyframe on very short LOOP_NONE clips — leaving
## the sprite stuck at the red mid-flash value. We override with a
## code-driven Tween that always lands cleanly at white. Killed and
## restarted on each new hit so consecutive damage doesn't accumulate
## into a permanent tint.
var _hit_tween: Tween = null

func _ready() -> void:
	# CharacterBody2D inherits input_pickable=true from CollisionObject2D
	# and would silently consume mouse clicks landing on the player's
	# collider — visible as a moving click-to-move dead zone. See
	# failure-modes.md #13.
	input_pickable = false
	if DebugLog.is_enabled(&"class"):
		DebugLog.write(&"class", "Player._ready gp=%s vis=%s mod=%s" % [
				global_position, visible, modulate])
	# Stage 9.5 — register the player's Camera2D so CameraShake.kick()
	# finds it without a hardcoded NodePath. Workbenches without a
	# player wired in just have no camera in the group; kicks no-op.
	var cam := $Camera2D as Camera2D
	if cam != null:
		cam.add_to_group(&"feel_camera")
	_input.owner_body = self
	_input.move_intent_changed.connect(_on_move_intent_changed)
	_input.attack_pressed.connect(_on_attack_pressed)
	_input.skill_1_pressed.connect(_on_skill_1_pressed)
	_input.debug_kill_self_pressed.connect(_on_debug_kill_self)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_hitbox.base_damage = ATTACK_BASE_DAMAGE
	_hitbox.owner_body = self
	# Stage 9.8 — register with ConsumableUse so InventoryPanel and
	# PlayerInput hotkeys can find the active player without traversing
	# the scene tree. Cleared in _exit_tree.
	ConsumableUse.set_active_player(self)

func _exit_tree() -> void:
	if ConsumableUse.get_active_player() == self:
		ConsumableUse.set_active_player(null)

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
	# Re-bind inventory to the new Stats, then swap to this class's
	# per-class loadout (stashes the outgoing class's items so they
	# come back next time we switch to that class).
	_inventory.stats = current_stats
	_inventory.set_active_class(cd.id)

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
		if DebugLog.is_enabled(&"class"):
			DebugLog.write(&"class", "assign_class(%s) -> sprite_root=%s anim=%s mod=%s" % [
					cd.id, _sprite_root.name,
					"yes" if _sprite_anim != null else "NO",
					str((_sprite_root as Node2D).modulate) if _sprite_root is Node2D else "<not Node2D>"])
	else:
		if DebugLog.is_enabled(&"class"):
			DebugLog.write(&"class", "assign_class(%s) -> sprite_scene is NULL" % cd.id)

	# Stage 15 — bind paper-doll to the new sprite + inventory. Deferred
	# one frame so the class sprite's own _ready (which paints the
	# Polygon2D children) runs before we add overlays — otherwise the
	# class's _paint() runs after us and could re-color or reorder
	# children unpredictably.
	if _paperdoll == null:
		_paperdoll = EquipmentPaperdoll.new()
		_paperdoll.name = "EquipmentPaperdoll"
		add_child(_paperdoll)
	if _sprite_root != null:
		_paperdoll.call_deferred(&"bind", _sprite_root, _inventory, cd.id)

	EventBus.stats_changed.emit(self)

var _phys_watch_prev: Vector2 = Vector2.ZERO
var _phys_watch_first: bool = true

func _physics_process(delta: float) -> void:
	# Stage 9.7 polish — watch for unexplained position jumps. Logs
	# the BEFORE/AFTER, intent, life state, and velocity if the
	# player moved more than 50 px in a single physics tick. Walking
	# is bounded at WALK_SPEED * delta ≈ 2.3 px / tick at 60 Hz, so
	# anything past 50 px is a teleport, a depenetration shove, or
	# a respawn. Opt-in via --debug=physics.
	if not _phys_watch_first and DebugLog.is_enabled(&"physics"):
		var jump := global_position - _phys_watch_prev
		# Expected walk this tick = velocity * delta. Anything else is
		# either a teleport, a depenetration shove, or floor() rounding.
		var expected := velocity * delta
		var unexpected := jump - expected
		if jump.length() > 50.0:
			DebugLog.write(&"physics",
					"BIG JUMP from=%s to=%s delta=%s expected=%s unexpected=%s vel=%s intent=%s life=%s combat=%s" % [
							_phys_watch_prev, global_position, jump,
							expected, unexpected,
							velocity, _intent, _life, _combat])
		elif unexpected.length() > 1.0:
			DebugLog.write(&"physics",
					"DRIFT from=%s to=%s delta=%s expected=%s unexpected=%s vel=%s intent=%s" % [
							_phys_watch_prev, global_position, jump,
							expected, unexpected,
							velocity, _intent])
	_phys_watch_first = false
	_phys_watch_prev = global_position
	if _life == LifeState.DEAD:
		velocity = Vector2.ZERO
		return
	_attack_cd_remaining = maxf(_attack_cd_remaining - delta, 0.0)
	if _combat == CombatState.ATTACKING:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _channeling:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_anim()
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
	if _life != LifeState.ALIVE or _skill_1 == null or _channeling:
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
	if _channeling:
		return
	if _combat != CombatState.READY:
		return
	if _attack_cd_remaining > 0.0:
		return
	_combat = CombatState.ATTACKING
	_attack_cd_remaining = ATTACK_COOLDOWN
	AudioBank.play_sfx(&"swing")
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
	if _amount > 0 and _life == LifeState.ALIVE:
		AudioBank.play_sfx(&"player_hurt")
	if _amount <= 0 or _life != LifeState.ALIVE:
		return
	# Stage 9.5 — feel-pass.md "hit taken" contract: red flash + camera
	# shake. Tuned up after first playtest — the 4px kick was too
	# subtle to register as feedback; 9px reads as "ouch" without
	# making the screen unreadable.
	CameraShake.kick(9.0, 0.18)
	# Always run the flash, even mid-attack. Gating on CombatState.READY
	# meant a hit landed during a swing skipped the lerp-back, leaving
	# the sprite stuck on whatever modulate frame the previous flash
	# was on. The anim_hit play is still gated (it would interrupt the
	# swing anim) but the colour reset is universal.
	_flash_hit()
	if _sprite_anim != null and _combat == CombatState.READY:
		_sprite_anim.play(&"hit")

func _flash_hit() -> void:
	if _sprite_root == null or not (_sprite_root is Node2D):
		return
	var sr := _sprite_root as Node2D
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	sr.modulate = Color(1.35, 0.55, 0.55, 1)
	_hit_tween = create_tween()
	_hit_tween.tween_property(sr, "modulate", Color(1, 1, 1, 1), 0.18)

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
	if external_respawn_handler:
		# Caller owns the respawn timing. They'll call respawn()
		# when they're ready (after the death-review screen, etc).
		return
	await get_tree().create_timer(DEATH_DURATION).timeout
	respawn()

func is_dead() -> bool:
	return _life == LifeState.DEAD

## Stage 9.7 polish — full respawn with HP/MP refill + teleport to
## the zone's spawn point. Used by the corpse-run flow where dying
## sends you back to camp.
func respawn() -> void:
	global_position = respawn_position
	revive_in_place()

## Revive without teleporting. Used by the endless rollback chain
## (Maw -> rollback to pre-portal save in the crypt): the player's
## position was already restored by SaveSystem._apply, so re-using
## respawn() would yank them to the zone's south-wall SpawnPoint
## instead of leaving them where they entered The Maw. HP/MP were
## also restored from save, so re-filling here is harmless.
func revive_in_place() -> void:
	current_stats.restore_hp(current_stats.max_hp)
	current_stats.restore_mp(current_stats.max_mp)
	_life = LifeState.ALIVE
	_combat = CombatState.READY
	_attack_cd_remaining = 0.0
	_intent = Vector2.ZERO
	velocity = Vector2.ZERO
	_hurtbox.set_deferred(&"monitoring", true)
	_input.set_process_unhandled_input(true)
	_input.set_physics_process(true)
	# Clear any click-to-move target queued before death so the
	# fresh-respawned player doesn't immediately march toward the
	# spot where they died. See failure-modes #19.
	_input.clear_click_target()
	# Reset the sprite root's transform: the `die` animation leaves
	# rotation=PI/2 and modulate.a=0.3, and `idle` doesn't animate
	# those properties so they'd persist into the new life.
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
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

func get_wallet() -> Wallet:
	return _wallet

## Stage 7 Phase 5 — corpse-run harvest. Snapshots every coin and
## one random equipped slot, then *removes* them from the player.
## The caller (Game) hands the result to CorpseSystem. Returns
## { gold, item_id, slot } where item_id is &"" / slot is -1 when
## the player died wearing nothing.
func harvest_for_corpse() -> Dictionary:
	var gold := 0
	if _wallet != null:
		gold = _wallet.gold
		_wallet.set_gold(0)
	var item_id: StringName = &""
	var slot := -1
	if _inventory != null:
		slot = _inventory.pick_random_equipped_slot()
		if slot != -1:
			item_id = _inventory.discard_equipped(slot)
	return { "gold": gold, "item_id": item_id, "slot": slot }

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

func is_attacking() -> bool:
	return _combat == CombatState.ATTACKING

## Stage 9.8 — Hearth Ember channel lock. ConsumableUse owns the
## lifecycle: it flips this to true when the channel starts and back
## to false on completion / interruption / item-loss. Player just
## reads the flag in _physics_process / attack() / skill_1.
func set_channeling(value: bool) -> void:
	_channeling = value
	if value:
		_intent = Vector2.ZERO

func is_channeling() -> bool:
	return _channeling
