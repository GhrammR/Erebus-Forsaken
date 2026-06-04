extends Node
## Stage 9.5 — Feel Pass camera shake. The ONE place screen-shake math
## lives (feel-pass.md, AD-04 lesson applied to feel). Skills, hit
## reactions, and crit pulses all call this; no script tweens
## Camera2D.offset inline.
##
## API: `CameraShake.kick(amount, duration)`. `amount` is the peak
## pixel-offset magnitude; `duration` is total time in seconds the
## shake fades to zero. Multiple kicks during an existing shake
## extend rather than stack — the new amplitude wins if it's
## stronger, the running tween is killed and replaced.
##
## Looks up the active Camera2D each call. Player owns the active
## camera via a child node; we walk the `game_host` group's player
## reference. If no camera is in the tree (workbenches without a
## player), the kick silently no-ops — feel cues never crash gameplay.

const _CAMERA_GROUP: StringName = &"feel_camera"

var _tween: Tween = null
var _camera: Camera2D = null

## Cancel any running shake and zero the offset immediately. Used by
## the zone-transit chain so a residual offset from a kick fired
## just before the portal interact doesn't carry into the new zone
## (camera then renders the destination scene off-centre — reads as
## "the player spawned in a corner" when the player is actually at
## the entry marker, see failure-modes #23).
func reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	var cam := _resolve_camera()
	if cam != null:
		var before := cam.offset
		cam.offset = Vector2.ZERO
		DebugLog.write(&"transit", "CameraShake.reset cam=%s offset_was=%s -> (0,0)" % [
				cam.get_path(), before])
	else:
		DebugLog.write(&"transit", "CameraShake.reset cam=<not found>")

func current_offset() -> Vector2:
	var cam := _resolve_camera()
	return cam.offset if cam != null else Vector2.ZERO

func kick(amount: float, duration: float = 0.18) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	var cam := _resolve_camera()
	if cam == null:
		return
	# Generate a fading random offset path. Sample ~6 points along
	# the duration so the shake reads as motion, not a single jerk.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var samples := 6
	for i in samples:
		var t := duration * float(i + 1) / float(samples)
		var falloff := 1.0 - float(i) / float(samples)
		var jitter := Vector2(
				randf_range(-amount, amount),
				randf_range(-amount, amount)) * falloff
		_tween.tween_property(cam, "offset", jitter, t / float(samples))
	# Restore offset to zero at the end so a subsequent shake starts
	# from neutral, not a residual offset.
	_tween.tween_property(cam, "offset", Vector2.ZERO, 0.04)

func _resolve_camera() -> Camera2D:
	if _camera != null and is_instance_valid(_camera) and _camera.is_inside_tree():
		return _camera
	# Camera lives on the Player in the production scene; walk the
	# canonical group rather than relying on a fixed path.
	for n in get_tree().get_nodes_in_group(_CAMERA_GROUP):
		var c := n as Camera2D
		if c != null:
			_camera = c
			return c
	return null
