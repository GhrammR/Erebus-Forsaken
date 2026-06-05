class_name WalkGate extends Area2D
## Stage 12 — walkable zone transition. The player walks into the
## trigger area at the edge of one zone and arrives at the matching
## marker in the next zone. No `E` press, no Portal interactable.
##
## Compared to Portal: Portal is "explicit doorway" semantics
## (Crypt entrance, future Maw entrance — a discrete interactable
## that says "press E to enter"). WalkGate is "edge of the world
## rolls into the next zone" semantics — used for the camp ↔
## wilderness seam and (Stage 13+) wilderness ↔ wilderness seams.
##
## Re-entry guards:
##   1. `_armed` is false for the first `ARMING_DELAY` seconds after
##      _ready, so the initial physics flush after instantiation
##      can't double-fire if the player happens to overlap the
##      trigger on arrival.
##   2. `_consumed` is a one-shot flag — a single transit fires at
##      most one go_to_zone call even if multiple bodies briefly
##      overlap the trigger in one frame.
##   3. The destination zone's arrival marker should be positioned
##      outside the destination's reverse gate so the player isn't
##      standing inside the trigger when the scene loads. (This is
##      caller responsibility — verifier checks it.)

const ARMING_DELAY: float = 0.25

@export var target_zone: StringName = &""
@export var arrival_marker: StringName = &""
## Optional — surfaced in DebugLog so the trail reads as
## "[transit] walkgate_entered TownSouthGate -> blighted_reach".
@export var display_name: String = "Walk Gate"

var _armed: bool = false
var _consumed: bool = false

func _ready() -> void:
	# Detect the player CharacterBody2D (layer 2 on player.tscn).
	# WalkGate doesn't need to be hit by anything itself, so leave
	# collision_layer at 0 — scene tscn sets layer/mask explicitly.
	body_entered.connect(_on_body_entered)
	# Arm after the next frame + the grace delay so initial overlap
	# from arrival placement can't trigger.
	var timer := get_tree().create_timer(ARMING_DELAY)
	timer.timeout.connect(_arm)

func _arm() -> void:
	_armed = true

func _on_body_entered(body: Node) -> void:
	if _consumed or not _armed:
		return
	if target_zone == &"":
		push_warning("WalkGate '%s' has no target_zone set." % display_name)
		return
	if not (body is Player):
		return
	_consumed = true
	DebugLog.write(&"transit", "walkgate_entered %s -> %s (arrival=%s)" % [
			display_name, String(target_zone), String(arrival_marker)])
	SceneRouter.go_to_zone(target_zone, arrival_marker)
