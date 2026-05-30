class_name Player extends CharacterBody2D
## AD-02 — one Player scene. Class identity comes from a ClassData
## resource assigned at runtime via assign_class(). Sprite, stats, and
## class metadata all flow from that one call.

const WALK_SPEED: float = 140.0
const FACE_FLIP_DEADZONE: float = 0.1

var class_data: ClassData = null
var current_stats: Stats = null

var _intent: Vector2 = Vector2.ZERO
var _facing_right: bool = true

@onready var _sprite_anchor: Node2D = $SpriteAnchor
@onready var _input: PlayerInput = $PlayerInput

var _sprite_anim: AnimationPlayer = null
var _sprite_root: Node = null

func _ready() -> void:
	_input.owner_body = self
	_input.move_intent_changed.connect(_on_move_intent_changed)

func assign_class(cd: ClassData) -> void:
	assert(cd != null, "Player.assign_class: ClassData is null")
	class_data = cd

	# Stats — instantiate at level 1 and forward recomputed -> EventBus.
	if current_stats != null and current_stats.recomputed.is_connected(_on_stats_recomputed):
		current_stats.recomputed.disconnect(_on_stats_recomputed)
	current_stats = Stats.from_class_data(cd, 1)
	current_stats.recomputed.connect(_on_stats_recomputed)

	# Sprite — swap subtree under SpriteAnchor.
	for child in _sprite_anchor.get_children():
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
	# Stats emit-once on bind so listeners (HUDs, overlays) refresh.
	EventBus.stats_changed.emit(self)

func _physics_process(_delta: float) -> void:
	velocity = _intent * WALK_SPEED
	move_and_slide()
	_update_anim()
	_update_facing()

func _update_anim() -> void:
	if _sprite_anim == null:
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

func _on_stats_recomputed() -> void:
	EventBus.stats_changed.emit(self)

# ---- helpers exposed for the workbench / future stages
func get_input() -> PlayerInput:
	return _input

func get_facing_right() -> bool:
	return _facing_right
