class_name AnatomyValidator extends Object
## Stage 17.8 — anatomy/reach pre-flight validator.
##
## Purpose: catch sprite-rig violations BEFORE render. The previous
## "render and squint" loop let bad poses ship; the validator walks
## every animation keyframe at sprite _ready, simulates where each
## pinned target would land, and reports violations.
##
## Three violation classes:
##   1. MISSING_PIN  — a required pin entry is absent for the weapon
##                     type (e.g. bow_attack requires R→Riser + L→Nock).
##   2. OUT_OF_REACH — target distance from shoulder > l1 + l2.
##                     Arm extends fully but hand never lands.
##   3. COLLAPSE     — target distance from shoulder < MIN_PIN_DIST.
##                     Hand folds onto the elbow; reads as "elbow grips
##                     the weapon" (Stage 17.7 bow incident).
##
## Two severity modes:
##   strict=true  — push_error on any violation; returns false.
##                  Used by sprite_render so CI catches violations.
##   strict=false — push_warning; returns true.
##                  Used by the live game so a single bad keyframe
##                  doesn't crash a session.
##
## Usage from a class sprite at _ready:
##   var ok := AnatomyValidator.validate_sprite(self, _body, PIN_TABLE,
##           _anim, AnatomyValidator.is_strict_env())
##   if not ok and AnatomyValidator.is_strict_env():
##       return  # render harness aborts via OS.exit

const MIN_PIN_DIST: float = 3.0      # below this the hand reads as elbow
const REACH_SLACK: float  = 0.5      # allow ~half-pixel float error
const SCAN_STEPS: int      = 16      # keyframe-time samples per anim

## Test-environment detector. sprite_render sets a feature flag at
## boot; everything else stays in soft mode.
static func is_strict_env() -> bool:
	return OS.has_feature("anatomy_strict") or Engine.has_meta(&"anatomy_strict")

## Validate every (anim, sample_t, pin) combination in a sprite. Returns
## true if no violations (or only soft ones in non-strict mode).
##
## `pins` is the sprite's PIN_TABLE constant. `anim_player` lets the
## validator seek each animation in turn to evaluate marker positions
## under live animation. `body` is the Body Node2D used as the IK
## reference frame.
static func validate_sprite(sprite_root: Node2D, body: Node2D,
		pins: Array, anim_player: AnimationPlayer,
		strict: bool) -> bool:
	if sprite_root == null or body == null or anim_player == null:
		return true
	var l1: float = HumanRig.ELBOW_DROP
	var l2: float = HumanRig.WRIST_DROP + 1.0
	var max_reach: float = l1 + l2
	var clean: bool = true
	var prior_anim: StringName = anim_player.current_animation
	var prior_pos: float = anim_player.current_animation_position
	for anim_name in anim_player.get_animation_list():
		var anim: Animation = anim_player.get_animation(anim_name)
		if anim == null:
			continue
		anim_player.play(anim_name)
		for pin in pins:
			# MISSING_PIN: skip-anims means the pin intentionally
			# doesn't apply, so absence is allowed. Otherwise the
			# shoulder + target must resolve.
			var skip_anims: Array = pin.get("skip_anims", [])
			if skip_anims.has(anim_name):
				continue
			var shoulder: Node2D = sprite_root.get_node_or_null(pin.shoulder) as Node2D
			var target: Node2D = sprite_root.get_node_or_null(pin.target) as Node2D
			if shoulder == null or target == null:
				clean = _emit(strict,
					"MISSING_PIN: anim=%s shoulder=%s target=%s — node not found" % [
						anim_name, pin.shoulder, pin.target]) and clean
				continue
			# Sample SCAN_STEPS evenly across the animation. Seek to
			# each, let the animation set marker positions, then read.
			for i in SCAN_STEPS + 1:
				var t: float = anim.length * float(i) / float(SCAN_STEPS)
				anim_player.seek(t, true)
				var target_body: Vector2 = body.to_local(target.global_position)
				var dist: float = (target_body - shoulder.position).length()
				if dist > max_reach + REACH_SLACK:
					clean = _emit(strict,
						"OUT_OF_REACH: anim=%s t=%.2f pin=%s dist=%.2f > %.2f (extra=%.2fpx)" % [
							anim_name, t, pin.target, dist, max_reach,
							dist - max_reach]) and clean
				elif dist < MIN_PIN_DIST:
					clean = _emit(strict,
						"COLLAPSE: anim=%s t=%.2f pin=%s dist=%.2f < %.2f — hand reads as elbow" % [
							anim_name, t, pin.target, dist, MIN_PIN_DIST]) and clean
	# Restore prior playhead so the validator doesn't disturb the
	# in-progress animation.
	if prior_anim != &"":
		anim_player.play(prior_anim)
		anim_player.seek(prior_pos, true)
	return clean

## Emit a violation at the configured severity. Returns false when
## strict so the caller can short-circuit.
static func _emit(strict: bool, msg: String) -> bool:
	if strict:
		push_error("[AnatomyValidator] " + msg)
		return false
	else:
		push_warning("[AnatomyValidator] " + msg)
		return true
