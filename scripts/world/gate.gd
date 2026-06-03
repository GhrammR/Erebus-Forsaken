class_name Gate extends Node2D
## Stage 8 — kill-gated barrier between dungeon rooms. Starts locked
## (slab visible + collision active). When the owning room reports
## clear, the rune flares briefly and the slab fades out as the
## collider disables. Once unlocked, stays unlocked for the zone
## lifetime — the dungeon doesn't reset mid-run.
##
## The slab/rune/collider live in the .tscn as Polygon2D / CollisionShape2D
## children; this script just owns the state transition and tween.

@onready var _slab: Node2D = $Slab
@onready var _rune: Node2D = $Rune
@onready var _body: StaticBody2D = $StaticBody2D
@onready var _shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

var _unlocked: bool = false

func _ready() -> void:
	# Defer in case the gate's parent zone is being added mid-physics-flush
	# (Stage 7 transit path goes through call_deferred — failure-modes #17).
	_shape.set_deferred(&"disabled", false)
	_slab.modulate.a = 1.0
	_rune.modulate = Color(0.4, 0.85, 1.0, 1.0)

func is_unlocked() -> bool:
	return _unlocked

func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	# Pulse the rune brighter for a beat, then dissolve the slab and
	# kill the collider. Tween is parented to self so freeing the gate
	# mid-tween cleans up automatically.
	var t := create_tween()
	t.tween_property(_rune, "modulate", Color(1.6, 1.2, 1.8, 1.0), 0.18)
	t.parallel().tween_property(_slab, "modulate:a", 0.0, 0.4)
	t.tween_property(_rune, "modulate:a", 0.0, 0.3)
	t.tween_callback(func(): _shape.set_deferred(&"disabled", true))
