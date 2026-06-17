extends "res://scripts/systems/sprite_runtime_2d.gd"
## CONSTRUCT species rig (Phase 4) — the Bronze Sentinel.
##
## Built on the shared HUMAN rig (HumanRig — articulated arms/elbows,
## legs/knees) and re-skinned as a heavy bronze automaton: a broad,
## blocky juggernaut clad in riveted bronze plate with verdigris in the
## seams, a featureless faceplate (no eyes/mouth — a single ember eye-
## slit), and a molten furnace-core glowing through the chest. This is
## the shared CONSTRUCT baseline other constructs derive from
## (anim_set = construct_rigid; the six canonical anims come from
## SpriteRuntime2D, re-timed to LINEAR interpolation so the motion reads
## stiff/mechanical instead of organic). Construct part set per
## rules/sprite-animation.md §2 / AnatomyFamilies.PARTS[CONSTRUCT]: the
## HUMAN joint names (so the anim tracks bind 1:1) + Faceplate + CoreGlow.

const BRONZE: Color      = Color(0.62, 0.45, 0.18)   # bronze plate
const BRONZE_DARK: Color = Color(0.42, 0.30, 0.12)   # shaded bronze
const BRONZE_HI: Color   = Color(0.80, 0.62, 0.32)   # bronze highlight
const VERDIGRIS: Color   = Color(0.30, 0.52, 0.42)   # green seam patina
const RIVET: Color       = Color(0.30, 0.22, 0.10)
const SOCKET: Color      = Color(0.10, 0.07, 0.04)
const CORE: Color        = Color(1.0, 0.55, 0.15)    # molten furnace-core
const CORE_HOT: Color    = Color(1.0, 0.80, 0.40)
const SHADOW: Color      = Color(0.0, 0.0, 0.05, 0.45)

# Juggernaut half-widths — wider/thicker than the HUMAN baseline so the
# sentinel looms over the player cast (~1.2x). Same JOINT positions and
# segment drop-lengths as HumanRig, so the anim tracks still bind 1:1;
# only the silhouette swells.
const SHOULDER_HALF: float = 13.5
const STERNUM_HALF: float  = 11.5
const WAIST_HALF: float    = 9.5
const HIP_HALF: float      = 10.5
const UPPER_ARM_HALF: float = 3.8
const FOREARM_HALF: float   = 3.2
const THIGH_HALF: float     = 4.8
const SHIN_HALF: float      = 4.0

func _ready() -> void:
	sprite_id = &"bronze_sentinel"
	stance_bucket = &"enemies"
	stance_id = &"enemy_idle_watch"
	var body := get_node_or_null(^"Body") as Node2D
	if body != null:
		HumanRig.apply(body, BRONZE, BRONZE_DARK)
	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = _wide_shadow()
		shadow.color = SHADOW
	# setup paints the standard legs + builds the six anims; bulk + plate
	# AFTER so the heavy bronze limbs aren't overwritten by paint_leg.
	setup_sprite_runtime()
	if body != null:
		_constructify(body)
	# A construct moves in stiff, mechanical steps — strip the organic
	# easing so the six anims snap between keyframes (the "rigid" read the
	# construct_rigid anim_set names).
	_make_rigid()

# Layers the bronze-automaton read on top of the painted HUMAN rig.
func _constructify(body: Node2D) -> void:
	_bulk_core(body)
	_bulk_limbs(body)
	# Chest cuirass plate with a riveted rim, over the broadened torso.
	_overlay(body, "ChestPlate", _chest_plate(), BRONZE_HI, 2)
	for cx in [-7.5, 0.0, 7.5]:
		_overlay(body, "ChestRivet%d" % int(cx),
				_ellipse(Vector2(cx, HumanRig.STERNUM - 1.0), 0.9, 0.9), RIVET, 3)
	# Heavy bronze pauldrons broaden the shoulders into a juggernaut line.
	_overlay(body, "PauldronL", _pauldron(-1.0), BRONZE_HI, 3)
	_overlay(body, "PauldronR", _pauldron(1.0), BRONZE_HI, 3)
	# Verdigris bands at the segmented joints (elbows + knees) sell the
	# "assembled from parts" read.
	for side in ["L", "R"]:
		_overlay_at(body, "Arm%sShoulder/ElbowPivot" % side, "JointBand",
				_band(HumanRig.FOREARM_HALF + 1.2), VERDIGRIS, 1)
		_overlay_at(body, "Leg%sHip/KneePivot" % side, "JointBand",
				_band(SHIN_HALF + 1.0), VERDIGRIS, 0)
	# Featureless faceplate over the head — a riveted bronze mask, no face.
	_overlay(body, "Faceplate", _faceplate(), BRONZE, 5)
	_overlay(body, "FaceplateSeam", _faceplate_seam(), BRONZE_DARK, 5)
	# A single horizontal ember eye-slit glows through the faceplate.
	_overlay(body, "EyeSlitSocket",
			_rect(Vector2(-3.4, HumanRig.HEAD_MID), Vector2(3.4, HumanRig.HEAD_MID + 1.2)), SOCKET, 5)
	_overlay(body, "EyeGlowSlit",
			_rect(Vector2(-3.0, HumanRig.HEAD_MID + 0.2), Vector2(3.0, HumanRig.HEAD_MID + 1.0)), CORE, 6)
	# Molten furnace-core glowing through the chest, with hot inner kernel,
	# plus faint seam glow lines bleeding orange between the plates.
	_overlay(body, "CoreSeamV",
			_rect(Vector2(-0.7, HumanRig.STERNUM - 5.0), Vector2(0.7, HumanRig.WAIST + 1.0)), CORE, 3)
	_overlay(body, "CoreGlow",
			_ellipse(Vector2(0.0, (HumanRig.STERNUM + HumanRig.WAIST) * 0.5), 3.2, 4.0), CORE, 4)
	_overlay(body, "CoreKernel",
			_ellipse(Vector2(0.0, (HumanRig.STERNUM + HumanRig.WAIST) * 0.5), 1.5, 2.0), CORE_HOT, 4)

# Broaden the torso + hips + neck into the juggernaut trunk.
func _bulk_core(body: Node2D) -> void:
	_repaint(body, "Torso", PackedVector2Array([
		Vector2(-SHOULDER_HALF, HumanRig.SHOULDERS),
		Vector2(SHOULDER_HALF, HumanRig.SHOULDERS),
		Vector2(STERNUM_HALF, HumanRig.STERNUM),
		Vector2(WAIST_HALF, HumanRig.WAIST),
		Vector2(-WAIST_HALF, HumanRig.WAIST),
		Vector2(-STERNUM_HALF, HumanRig.STERNUM),
	]), BRONZE)
	_repaint(body, "Hips", PackedVector2Array([
		Vector2(-WAIST_HALF, HumanRig.WAIST),
		Vector2(WAIST_HALF, HumanRig.WAIST),
		Vector2(HIP_HALF, HumanRig.HIPS),
		Vector2(-HIP_HALF, HumanRig.HIPS),
	]), BRONZE_DARK)
	_repaint(body, "Neck", PackedVector2Array([
		Vector2(-4.2, HumanRig.CHIN), Vector2(4.2, HumanRig.CHIN),
		Vector2(4.6, HumanRig.NECK_BOTTOM), Vector2(-4.6, HumanRig.NECK_BOTTOM),
	]), BRONZE_DARK)

# Thicken the HUMAN-rig limbs into blocky bronze segments with banded
# blocky hands/feet. Pivot-local coords keep the HumanRig drop lengths so
# the anim tracks still bind 1:1.
func _bulk_limbs(body: Node2D) -> void:
	for side in ["L", "R"]:
		_repaint(body, "Arm%sShoulder/UpperArm" % side, _seg(UPPER_ARM_HALF, UPPER_ARM_HALF - 0.4, HumanRig.ELBOW_DROP), BRONZE.darkened(0.10))
		_repaint(body, "Arm%sShoulder/ElbowPivot/Forearm" % side, _seg(FOREARM_HALF, FOREARM_HALF - 0.4, HumanRig.WRIST_DROP), BRONZE_DARK)
		# Blocky bronze fist.
		_repaint(body, "Arm%sShoulder/ElbowPivot/Hand" % side, _rect(
				Vector2(-3.2, HumanRig.WRIST_DROP), Vector2(3.2, HumanRig.WRIST_DROP + 4.4)), BRONZE_HI)
		_repaint(body, "Leg%sHip/Thigh" % side, _seg(THIGH_HALF, THIGH_HALF - 0.4, HumanRig.KNEE_DROP), BRONZE.darkened(0.10))
		_repaint(body, "Leg%sHip/KneePivot/Shin" % side, _seg(SHIN_HALF, SHIN_HALF - 0.4, HumanRig.ANKLE_DROP), BRONZE_DARK)
		# Blocky bronze foot — a wide flat slab.
		_repaint(body, "Leg%sHip/KneePivot/Foot" % side, PackedVector2Array([
			Vector2(-3.0, HumanRig.ANKLE_DROP), Vector2(5.0, HumanRig.ANKLE_DROP),
			Vector2(5.0, HumanRig.ANKLE_DROP + 3.2), Vector2(-3.0, HumanRig.ANKLE_DROP + 3.2),
		]), BRONZE.darkened(0.18))

# Re-time every built animation to LINEAR interpolation so the construct
# snaps between poses (mechanical) instead of easing (organic). This is
# what makes the shared SpriteRuntime2D anims read as construct_rigid.
func _make_rigid() -> void:
	if _anim == null:
		return
	var lib := _anim.get_animation_library(&"")
	if lib == null:
		return
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		for t in a.get_track_count():
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)

# ---- geometry helpers ----------------------------------------------------

func _wide_shadow() -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 18
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(13.5 * cos(t), 2.0 + 4.0 * sin(t)))
	return pts

func _chest_plate() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-STERNUM_HALF + 0.5, HumanRig.SHOULDERS + 2.0),
		Vector2(STERNUM_HALF - 0.5, HumanRig.SHOULDERS + 2.0),
		Vector2(WAIST_HALF - 0.5, HumanRig.WAIST - 1.0),
		Vector2(0.0, HumanRig.WAIST + 1.5),
		Vector2(-WAIST_HALF + 0.5, HumanRig.WAIST - 1.0),
	])

# Heavy bronze pauldron capping the shoulder for `side` (-1 L, +1 R).
func _pauldron(side: float) -> PackedVector2Array:
	var sx := side * HumanRig.SHOULDER_HALF
	return PackedVector2Array([
		Vector2(sx - side * 3.0, HumanRig.SHOULDERS - 1.0),
		Vector2(sx + side * 4.5, HumanRig.SHOULDERS - 0.5),
		Vector2(sx + side * 5.0, HumanRig.SHOULDERS + 4.5),
		Vector2(sx + side * 1.0, HumanRig.SHOULDERS + 5.5),
		Vector2(sx - side * 3.0, HumanRig.SHOULDERS + 3.0),
	])

func _faceplate() -> PackedVector2Array:
	var top := HumanRig.HEAD_TOP + 1.0
	var bot := HumanRig.CHIN - 0.5
	var hw := HumanRig.HEAD_HALF_W - 0.3
	return PackedVector2Array([
		Vector2(-hw, top + 2.0), Vector2(0.0, top),
		Vector2(hw, top + 2.0), Vector2(hw, bot - 2.0),
		Vector2(0.0, bot), Vector2(-hw, bot - 2.0),
	])

func _faceplate_seam() -> PackedVector2Array:
	return _rect(Vector2(-0.6, HumanRig.HEAD_TOP + 2.0), Vector2(0.6, HumanRig.CHIN - 1.0))

# A thin band ring (segmented-joint collar) of half-width `hw`.
func _band(hw: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-hw, -0.9), Vector2(hw, -0.9),
		Vector2(hw, 0.9), Vector2(-hw, 0.9),
	])

# A tapered limb segment from (0,0) to (0,len): top half-width `htop`,
# bottom half-width `hbot`.
func _seg(htop: float, hbot: float, length: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-htop, 0), Vector2(htop, 0),
		Vector2(hbot, length), Vector2(-hbot, length),
	])

func _rect(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(a.x, a.y), Vector2(b.x, a.y),
		Vector2(b.x, b.y), Vector2(a.x, b.y),
	])

func _repaint(parent: Node2D, path: String, pts: PackedVector2Array, color: Color) -> void:
	var p := parent.get_node_or_null(NodePath(path)) as Polygon2D
	if p == null:
		return
	p.polygon = pts
	p.color = color

func _overlay(parent: Node2D, node_name: String, pts: PackedVector2Array,
		color: Color, z: int) -> void:
	var p := parent.get_node_or_null(NodePath(node_name)) as Polygon2D
	if p == null:
		p = Polygon2D.new()
		p.name = node_name
		parent.add_child(p)
	p.polygon = pts
	p.color = color
	p.z_index = z

# Overlay a Polygon2D under a nested pivot (e.g. a band at an ElbowPivot).
func _overlay_at(body: Node2D, pivot_path: String, node_name: String,
		pts: PackedVector2Array, color: Color, z: int) -> void:
	var pivot := body.get_node_or_null(NodePath(pivot_path)) as Node2D
	if pivot == null:
		return
	_overlay(pivot, node_name, pts, color, z)

func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 12
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts
