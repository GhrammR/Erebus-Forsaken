extends Node
## Stage 17.5 — headless-friendly sprite renderer.
##
## Iterates every registered sprite, instantiates each into a
## SubViewport, plays each canonical animation, captures frames as
## PNG to `docs/sprites/<sprite_id>/<state>[_<weapon>][_<shield>]_<frame>.png`.
## This folder is intentionally COMMITTED (excepted from .gitignore)
## so the agent can read prior renders between sessions without
## re-running the pipeline, and so review can happen via git diff.
##
## Stage 17.6 — adds Pythia (HUMAN, staff). Extends naturally to other
## sprites as they're added by adding entries to RENDER_PLAN.
##
## Invocation: godot --path . -- --render-sprites
## NOT --headless: needs a display server to drive the GL backend
## (WSL2's WSLg provides one). Output PNGs can be Read directly.

const SpriteSpecs = preload("res://test/sprite_specs.gd")
const AnatomyValidator = preload("res://scripts/systems/anatomy_validator.gd")

const FRAME_PATH := "res://docs/sprites/%s/%s_%d.png"
const STRIP_PATH := "res://docs/sprites/%s/%s_strip.png"
const DEBUG_STRIP_PATH := "res://docs/sprites/%s/%s_debug_strip.png"
# Reference-overlay strip: [reference photo | rendered strip]. Generated
# only when a variant declares a "reference" path. Lets us A/B a pose
# against a real-world photo before committing.
const REF_STRIP_PATH := "res://docs/sprites/%s/%s_ref.png"
# Stage 17.6 — per-variant text trace + pose-spec verifier report.
# The trace.txt holds per-frame numeric pose data (positions of both
# hands, both elbows, weapon angle, tip, butt) PLUS the verifier's
# PASS/FAIL diff against SpriteSpecs.SPECS for this variant. Reading
# numbers replaces squinting at 240×240 pixel strips.
const TRACE_PATH := "res://docs/sprites/%s/%s_trace.txt"
const VIEW_SIZE: Vector2i = Vector2i(240, 240)
# 12 frames per animation = ~24fps sampling on a typical 0.5s attack.
# Enough to read fluidity at a glance without flooding the folder.
const FRAME_COUNT: int = 12
const SPRITE_SCALE: float = 3.0  # zoom so 60px-tall sprite reads at game-scale

# Body-local Y values rendered as horizontal landmark lines on the
# debug strip. These let the AGENT (and you) objectively verify
# WHERE on the body each polygon and the hand sit in every frame —
# the cure for "I thought I fixed the hip thrust but the hand is
# still at the waist." Color-coded so the danger zone (hip/groin)
# is unmissable when the hand-tracker dot intersects it.
const _LANDMARKS: Array = [
	{ "y": -60.0, "color": Color(0.55, 0.55, 0.55), "label": "head_top" },
	{ "y": -44.0, "color": Color(0.55, 0.95, 0.55), "label": "shoulder" },
	{ "y": -37.0, "color": Color(0.55, 0.95, 0.55), "label": "chest" },
	{ "y": -28.0, "color": Color(0.95, 0.85, 0.30), "label": "waist" },
	{ "y": -22.0, "color": Color(0.95, 0.20, 0.20), "label": "HIP/GROIN" },
	{ "y": -12.0, "color": Color(0.55, 0.55, 0.95), "label": "knee" },
	{ "y":   0.0, "color": Color(0.50, 0.50, 0.50), "label": "ground" },
]

# What to render. Each entry: sprite scene + display id + which
# animation+equip variants to capture. `equip` is a dictionary that
# may contain "weapon" and/or "offhand" item ids — applied via the
# real Inventory + EquipmentPaperdoll path so what we render matches
# what the player would see.
const RENDER_PLAN := [
	{
		"id": "myrmidon",
		"class_id": &"myrmidon",
		"scene": "res://art/procedural/classes/myrmidon_sprite.tscn",
		"variants": [
			{ "name": "idle_bare",       "anim": &"idle",   "equip": {} },
			{ "name": "walk_bare",       "anim": &"walk",   "equip": {} },
			{ "name": "attack_bare",     "anim": &"attack", "equip": {} },
			{ "name": "idle_spear",      "anim": &"idle",   "equip": { "weapon": &"myrmidon_spear_starter" } },
			{ "name": "walk_spear",      "anim": &"walk",   "equip": { "weapon": &"myrmidon_spear_starter" } },
			{ "name": "attack_spear",    "anim": &"attack", "equip": { "weapon": &"myrmidon_spear_starter" } },
			# Note: buckler is built-in to the Myrmidon sprite and
			# Inventory has no canonical 'shield' starter to equip
			# in the OFFHAND slot for Act 1. attack_spear above
			# uses the no-shield two-handed thrust profile.
		],
	},
	{
		"id": "pythia",
		"class_id": &"pythia",
		"scene": "res://art/procedural/classes/pythia_sprite.tscn",
		"variants": [
			{ "name": "idle_bare",    "anim": &"idle",   "equip": {} },
			{ "name": "walk_bare",    "anim": &"walk",   "equip": {} },
			{ "name": "attack_bare",  "anim": &"attack", "equip": {} },
			{ "name": "idle_staff",   "anim": &"idle",   "equip": { "weapon": &"pythia_staff_starter" } },
			{ "name": "walk_staff",   "anim": &"walk",   "equip": { "weapon": &"pythia_staff_starter" } },
			{ "name": "attack_staff", "anim": &"attack", "equip": { "weapon": &"pythia_staff_starter" } },
			{ "name": "cast_staff",   "anim": &"cast",   "equip": { "weapon": &"pythia_staff_starter" } },
			# Equipped-armor variant. The z_index = 2 on StaffArm is
			# the only reason the staff doesn't disappear behind the
			# silken_robe chest overlay during the bop apex — this
			# variant exists to catch that regression visually.
			{ "name": "idle_geared",   "anim": &"idle",   "equip": {
				"weapon": &"pythia_staff_starter",
				"chest": &"silken_robe",
				"head": &"worn_helm",
				"legs": &"linen_wrap",
			} },
			{ "name": "attack_geared", "anim": &"attack", "equip": {
				"weapon": &"pythia_staff_starter",
				"chest": &"silken_robe",
				"head": &"worn_helm",
				"legs": &"linen_wrap",
			} },
		],
	},
	{
		"id": "shade_hunter",
		"class_id": &"shade_hunter",
		"scene": "res://art/procedural/classes/shade_hunter_sprite.tscn",
		"variants": [
			{ "name": "idle_bow",   "anim": &"idle",   "equip": {} },
			{ "name": "walk_bow",   "anim": &"walk",   "equip": {} },
			{ "name": "attack_bow", "anim": &"attack", "equip": {} },
		],
	},
]

# Per-class business-end polygon name (the pointiest forward-extending
# part of the weapon, queried via polygon.max_x for the tip tracker).
# Falls back to no-draw when a class isn't listed yet.
const _TIP_POLY: Dictionary = {
	&"myrmidon": &"Tip",
	&"pythia":   &"Orb",
}

var _root_vp: SubViewport = null
var _current_sprite: Node2D = null

# Where to plant the sprite's feet inside the SubViewport (origin
# top-left). 30px above the bottom edge, horizontally centered.
const _FEET_POS := Vector2(120, 210)

func _ready() -> void:
	print("--- sprite render ---")
	_ensure_output_dir()
	_setup_viewport()
	await get_tree().process_frame
	for plan in RENDER_PLAN:
		await _render_sprite_plan(plan)
	print("--- sprite render: done ---")
	get_tree().quit(0)

func _ensure_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/sprites")

func _setup_viewport() -> void:
	_root_vp = SubViewport.new()
	_root_vp.size = VIEW_SIZE
	_root_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_root_vp.transparent_bg = false
	# Dark background so the procedural sprite (which uses dark
	# leather/bronze) reads with contrast.
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.14)
	bg.size = VIEW_SIZE
	_root_vp.add_child(bg)
	# Mount the SubViewport inside a SubViewportContainer so it
	# actually ticks (free-floating SubViewports don't update).
	# No camera — sprites are positioned directly in viewport-local
	# coordinates (origin top-left) at _FEET_POS.
	var container := SubViewportContainer.new()
	container.add_child(_root_vp)
	add_child(container)

func _render_sprite_plan(plan: Dictionary) -> void:
	var id: String = plan["id"]
	var class_id: StringName = plan["class_id"]
	var scene: PackedScene = load(plan["scene"]) as PackedScene
	if scene == null:
		print("  SKIP  %s — scene not found" % id)
		return
	DirAccess.make_dir_recursive_absolute("res://docs/sprites/%s" % id)
	for variant in plan["variants"]:
		await _render_variant(scene, id, class_id, variant)

func _render_variant(scene: PackedScene, id: String, class_id: StringName,
		variant: Dictionary) -> void:
	# Tear down any prior sprite.
	if _current_sprite != null:
		_current_sprite.queue_free()
		_current_sprite = null
		await get_tree().process_frame
	# Build a minimal Inventory + Stats + EquipmentPaperdoll like
	# the player would have.
	var stats := Stats.new()
	stats.class_id = class_id
	var inv := Inventory.new()
	inv.class_id = class_id
	inv.stats = stats
	add_child(inv)
	# Instantiate sprite, parent to the SubViewport so it renders.
	# Position the sprite's pivot (feet, y=0) at _FEET_POS.
	var sprite: Node2D = scene.instantiate() as Node2D
	_root_vp.add_child(sprite)
	sprite.position = _FEET_POS
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_current_sprite = sprite
	# Paperdoll binding (same as the production game.gd path).
	var paperdoll := EquipmentPaperdoll.new()
	add_child(paperdoll)
	paperdoll.bind(sprite, inv, class_id)
	# Equip the variant's items.
	var equip: Dictionary = variant.get("equip", {})
	for slot in ["weapon", "offhand", "head", "chest", "legs"]:
		if equip.has(slot):
			inv.add_item(equip[slot])
			inv.equip(equip[slot])
	await get_tree().process_frame
	# Stage 17.8 — anatomy pre-flight. Walks every pin entry against
	# every animation keyframe and reports OUT_OF_REACH / COLLAPSE
	# violations. Promoted to strict (abort on violation) when the
	# environment defines `ANATOMY_STRICT=1` so CI can gate on it once
	# existing rigs are validated clean. Default report-only so a
	# legacy violation in one class doesn't block the whole pipeline.
	var pin_table = sprite.get(&"PIN_TABLE") if &"PIN_TABLE" in sprite else null
	if pin_table != null:
		var v_body: Node2D = sprite.get_node_or_null(^"Body") as Node2D
		var v_anim: AnimationPlayer = sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		var strict: bool = OS.get_environment("ANATOMY_STRICT") == "1"
		var ok: bool = AnatomyValidator.validate_sprite(
				sprite, v_body, pin_table, v_anim, strict)
		if strict and not ok:
			push_error("sprite_render: anatomy validator failed for %s/%s" % [id, variant["name"]])
			get_tree().quit(1)
			return
	# Play the animation, capture frames evenly across its length.
	var anim_name: StringName = variant["anim"]
	var anim_player: AnimationPlayer = sprite.get_node(^"AnimationPlayer") as AnimationPlayer
	var anim: Animation = anim_player.get_animation(anim_name)
	if anim == null:
		print("  SKIP  %s/%s — anim missing" % [id, variant["name"]])
		return
	var length: float = anim.length
	anim_player.play(anim_name)
	var frames: Array = []
	var debug_frames: Array = []
	for frame_i in FRAME_COUNT:
		var t := length * float(frame_i) / float(FRAME_COUNT - 1)
		anim_player.seek(t, true)
		# Give the renderer two frames to apply the seek + draw.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img: Image = _root_vp.get_texture().get_image()
		var path := FRAME_PATH % [id, variant["name"], frame_i]
		var fs_path := ProjectSettings.globalize_path(path)
		img.save_png(fs_path)
		print("  WROTE %s (anim=%s t=%.2f)" % [path, anim_name, t])
		frames.append(img)
		# Debug-overlay version: anatomical landmark lines + right-
		# hand tracker dot. Saved in a SEPARATE strip so the clean
		# strip remains presentation-ready, and so the agent has an
		# objective check ("hand dot vs. landmark lines") instead of
		# vibes-based eyeballing.
		var debug_img: Image = img.duplicate()
		_draw_landmarks(debug_img, sprite)
		_draw_arm_trackers(debug_img, sprite)
		_draw_tip_tracker(debug_img, sprite, class_id)
		debug_frames.append(debug_img)
	# Glue the frames into a single horizontal strip — much easier to
	# scrub for fluidity than reading 12 separate files.
	_save_strip(frames, id, variant["name"])
	_save_debug_strip(debug_frames, id, variant["name"])
	# Reference-photo overlay: if the variant declares a reference image
	# path, append it as a leading column so the rendered pose can be
	# A/B'd against a real-world photo without context-switching.
	var ref_path: String = variant.get("reference", "")
	if ref_path != "":
		_save_ref_strip(frames, ref_path, id, variant["name"])
	# Stage 17.6 — write per-frame numeric trace + pose-spec verifier.
	# Numbers replace squinting at the strip. Runs sequentially after
	# the strip is saved so the trace and the PNGs land in the same
	# folder atomically per variant.
	await _write_trace_and_verify(sprite, class_id, anim_player, anim_name,
			length, id, variant["name"])
	# Clean up paperdoll/inv for the next variant.
	paperdoll.queue_free()
	inv.queue_free()

# Concatenates the captured frames into a single horizontal strip and
# writes it next to the per-frame PNGs. The strip is the primary
# review artefact — flip through one image instead of N to see the
# animation curve.
func _save_strip(frames: Array, id: String, variant_name: String) -> void:
	if frames.is_empty():
		return
	_blit_strip(frames, STRIP_PATH % [id, variant_name])
	print("  STRIP %s" % (STRIP_PATH % [id, variant_name]))

func _save_debug_strip(frames: Array, id: String, variant_name: String) -> void:
	if frames.is_empty():
		return
	_blit_strip(frames, DEBUG_STRIP_PATH % [id, variant_name])
	print("  DEBUG %s" % (DEBUG_STRIP_PATH % [id, variant_name]))

# Reference-strip writer. Loads `ref_path` (a JPG/PNG photo the dev
# dropped in the repo), resizes it to frame height preserving aspect,
# and prepends it as a leading column on the rendered strip. The output
# is [reference | f0 | f1 | ... | fN] — one image to scan instead of
# alt-tabbing between a photo and the strip.
func _save_ref_strip(frames: Array, ref_path: String, id: String,
		variant_name: String) -> void:
	if frames.is_empty():
		return
	var ref_img: Image = Image.load_from_file(ProjectSettings.globalize_path(ref_path))
	if ref_img == null:
		print("  REF   skip %s — load failed: %s" % [variant_name, ref_path])
		return
	var first: Image = frames[0]
	var fh := first.get_height()
	var fw := first.get_width()
	# Scale reference to frame height preserving aspect.
	var rw := int(round(ref_img.get_width() * float(fh) / float(ref_img.get_height())))
	ref_img.resize(rw, fh, Image.INTERPOLATE_BILINEAR)
	# Match frame format so blit_rect doesn't reject the source.
	ref_img.convert(first.get_format())
	var total_w := rw + fw * frames.size()
	var out := Image.create(total_w, fh, false, first.get_format())
	out.blit_rect(ref_img, Rect2i(0, 0, rw, fh), Vector2i(0, 0))
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(0, 0, fw, fh), Vector2i(rw + fw * i, 0))
	var fs_path := ProjectSettings.globalize_path(REF_STRIP_PATH % [id, variant_name])
	out.save_png(fs_path)
	print("  REF   %s" % (REF_STRIP_PATH % [id, variant_name]))

func _blit_strip(frames: Array, path_template: String) -> void:
	var first: Image = frames[0]
	var fw := first.get_width()
	var fh := first.get_height()
	var strip := Image.create(fw * frames.size(), fh, false, first.get_format())
	for i in frames.size():
		var src: Image = frames[i]
		strip.blit_rect(src, Rect2i(0, 0, fw, fh), Vector2i(fw * i, 0))
	var fs_path := ProjectSettings.globalize_path(path_template)
	strip.save_png(fs_path)

# Draws horizontal landmark lines on `img` at the body-local Y values
# in _LANDMARKS, mapped through the sprite's screen position and
# scale.
func _draw_landmarks(img: Image, sprite: Node2D) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var sy: float = sprite.position.y
	for lm in _LANDMARKS:
		var vp_y := int(sy + float(lm["y"]) * SPRITE_SCALE)
		if vp_y < 0 or vp_y >= h:
			continue
		img.fill_rect(Rect2i(0, vp_y, w, 1), lm["color"])
		# Small color swatch on the right margin so stacked landmarks
		# (waist + hip 6px apart) stay distinguishable.
		img.fill_rect(Rect2i(w - 6, vp_y - 1, 6, 3), lm["color"])

# Draws tracker dots for both elbows, both hands, and any cosmetic
# LeftGrip on the weapon. Colors chosen so each tracker is
# distinguishable on the dark background.
const _ARM_TRACKERS: Array = [
	# (path,                                                  color,                   radius)
	[^"Body/ArmRShoulder/ElbowPivot",                         Color(0.30, 0.90, 0.90), 3],  # R elbow — cyan
	[^"Body/ArmLShoulder/ElbowPivot",                         Color(0.30, 0.55, 0.95), 3],  # L elbow — blue
	[^"Body/ArmRShoulder/ElbowPivot/Hand",                    Color(1.00, 0.10, 0.10), 4],  # R hand  — red
	[^"Body/ArmLShoulder/ElbowPivot/Hand",                    Color(1.00, 0.55, 0.75), 4],  # L hand  — pink
]
func _draw_arm_trackers(img: Image, sprite: Node2D) -> void:
	for tr in _ARM_TRACKERS:
		_draw_node_dot(img, sprite, tr[0], tr[1], tr[2])
	# Cosmetic LeftGrip on the weapon — magenta marker so we can see
	# whether the L-hand pink dot ACTUALLY lands on the staff grip
	# the spec calls for.
	_draw_left_grip_marker(img, sprite)

# If the weapon arm has a "LeftGrip" child, dot its polygon center.
func _draw_left_grip_marker(img: Image, sprite: Node2D) -> void:
	# Conventionally LeftGrip lives under StaffArm; generalize via
	# weapon-arm registry in case other weapons add their own.
	for class_id in [&"pythia", &"myrmidon", &"shade_hunter", &"ossuary_priest"]:
		var arm_path: StringName = EquipmentVisuals.weapon_arm_for(class_id)
		if arm_path == &"":
			continue
		var arm: Node2D = sprite.get_node_or_null(NodePath(String(arm_path))) as Node2D
		if arm == null:
			continue
		var lg: Polygon2D = arm.get_node_or_null(^"LeftGrip") as Polygon2D
		if lg == null:
			continue
		# Polygon center = average of vertices.
		var center := Vector2.ZERO
		for v in lg.polygon:
			center += v
		if lg.polygon.size() > 0:
			center /= float(lg.polygon.size())
		var world := arm.to_global(center)
		_draw_pixel_circle(img, int(world.x), int(world.y), 3,
				Color(0.95, 0.30, 0.95))
		return

# Weapon business-end tracker — orange dot at the +x extreme of the
# class's weapon tip polygon (spear tip / staff orb / etc.). Looks up
# the weapon arm path via EquipmentVisuals.weapon_arm_for(class_id)
# and the tip polygon child via _TIP_POLY. Falls back to no draw when
# the weapon arm isn't present (bare-hands variant) or the class
# isn't registered yet.
func _draw_tip_tracker(img: Image, sprite: Node2D, class_id: StringName) -> void:
	var arm_path: StringName = EquipmentVisuals.weapon_arm_for(class_id)
	if arm_path == &"":
		return
	var weapon_arm: Node2D = sprite.get_node_or_null(NodePath(String(arm_path))) as Node2D
	if weapon_arm == null:
		return
	var tip_name: StringName = _TIP_POLY.get(class_id, &"")
	if tip_name == &"":
		return
	var tip: Polygon2D = weapon_arm.get_node_or_null(NodePath(String(tip_name))) as Polygon2D
	if tip == null:
		return
	var best := Vector2(-INF, 0.0)
	for v in tip.polygon:
		if v.x > best.x:
			best = v
	if best.x == -INF:
		return
	var world_tip: Vector2 = weapon_arm.to_global(best)
	_draw_pixel_circle(img, int(world_tip.x), int(world_tip.y),
			3, Color(1.0, 0.55, 0.1, 1.0))

# Helper: draw a filled circle at world (cx, cy) on `img`.
func _draw_pixel_circle(img: Image, cx: int, cy: int, rad: int, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for dy in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			if dx * dx + dy * dy > rad * rad:
				continue
			var px := cx + dx
			var py := cy + dy
			if px >= 0 and px < w and py >= 0 and py < h:
				img.set_pixel(px, py, color)

# Helper: draw a tracker dot at the given node's global position.
func _draw_node_dot(img: Image, sprite: Node2D, node_path: NodePath,
		color: Color, rad: int) -> void:
	var node: Node2D = sprite.get_node_or_null(node_path) as Node2D
	if node == null:
		return
	var p := node.global_position
	_draw_pixel_circle(img, int(p.x), int(p.y), rad, color)

# =========================================================================
# Stage 17.6 — pose sampling, trace.txt, spec verifier
# =========================================================================
# These functions read the ACTUAL positions of the standard tracked
# nodes at the AnimationPlayer's current time, write a per-frame
# numeric report next to the strip PNGs, and run a PASS/FAIL pose-spec
# comparison via SpriteSpecs. Numbers replace squinting.

# Standard tracked nodes (per HUMAN-rig sprite). Path -> dictionary key
# in the sample dict. All positions returned in SPRITE-LOCAL coords
# (feet at (0,0), +x right, -y up — the authoring frame).
# Each entry: node path, sample-key, sample mode.
#   "origin"  — use node.global_position (correct for joints)
#   "centroid"— average the polygon vertices, then to_global (correct
#               for Hand polys whose visual is offset from origin)
const _TRACKED_NODES: Array = [
	[^"Body/ArmRShoulder",                     "right_shoulder", "origin"],
	[^"Body/ArmLShoulder",                     "left_shoulder",  "origin"],
	[^"Body/ArmRShoulder/ElbowPivot",          "right_elbow",    "origin"],
	[^"Body/ArmLShoulder/ElbowPivot",          "left_elbow",     "origin"],
	[^"Body/ArmRShoulder/ElbowPivot/Hand",     "right_hand",     "centroid"],
	[^"Body/ArmLShoulder/ElbowPivot/Hand",     "left_hand",      "centroid"],
]

# Sample the current pose. Returns a Dictionary with:
#   right_shoulder/left_shoulder: Vector2 sprite-local
#   right_elbow/left_elbow:       Vector2 sprite-local
#   right_hand/left_hand:         Vector2 sprite-local
#   weapon_angle_deg:             float (global rotation of weapon arm)
#   weapon_grip / weapon_tip / weapon_butt: Vector2 sprite-local
#   weapon_left_grip:             Vector2 sprite-local (if cosmetic LeftGrip exists)
func _sample_pose(sprite: Node2D, class_id: StringName) -> Dictionary:
	var sample: Dictionary = {}
	for entry in _TRACKED_NODES:
		var path: NodePath = entry[0]
		var key: String = entry[1]
		var mode: String = entry[2]
		var n: Node2D = sprite.get_node_or_null(path) as Node2D
		if n == null:
			continue
		if mode == "centroid" and n is Polygon2D:
			var poly: Polygon2D = n
			var center := Vector2.ZERO
			if poly.polygon.size() > 0:
				for v in poly.polygon:
					center += v
				center /= float(poly.polygon.size())
			sample[key] = sprite.to_local(n.to_global(center))
		else:
			sample[key] = sprite.to_local(n.global_position)
	# Weapon arm (per class).
	var arm_path: StringName = EquipmentVisuals.weapon_arm_for(class_id)
	if arm_path != &"":
		var arm: Node2D = sprite.get_node_or_null(NodePath(String(arm_path))) as Node2D
		if arm != null and arm.visible:
			sample["weapon_grip"] = sprite.to_local(arm.global_position)
			sample["weapon_angle_deg"] = rad_to_deg(arm.global_rotation)
			# Tip: max-x vertex of the tip polygon (Tip for spear, Orb
			# for staff, etc.).
			var tip_name: StringName = _TIP_POLY.get(class_id, &"")
			if tip_name != &"":
				var tip_poly: Polygon2D = arm.get_node_or_null(NodePath(String(tip_name))) as Polygon2D
				if tip_poly != null:
					var best := Vector2(-INF, 0.0)
					for v in tip_poly.polygon:
						if v.x > best.x:
							best = v
					if best.x != -INF:
						sample["weapon_tip"] = sprite.to_local(arm.to_global(best))
			# Butt: min-x vertex of the shaft polygon.
			var shaft: Polygon2D = arm.get_node_or_null(^"Shaft") as Polygon2D
			if shaft != null:
				var worst := Vector2(INF, 0.0)
				for v in shaft.polygon:
					if v.x < worst.x:
						worst = v
				if worst.x != INF:
					sample["weapon_butt"] = sprite.to_local(arm.to_global(worst))
			# Cosmetic LeftGrip (Pythia staff has this).
			var lg: Polygon2D = arm.get_node_or_null(^"LeftGrip") as Polygon2D
			if lg != null:
				var center := Vector2.ZERO
				for v in lg.polygon:
					center += v
				if lg.polygon.size() > 0:
					center /= float(lg.polygon.size())
				sample["weapon_left_grip"] = sprite.to_local(arm.to_global(center))
	return sample

# Writes the per-variant trace.txt + runs the pose-spec verifier.
func _write_trace_and_verify(sprite: Node2D, class_id: StringName,
		anim_player: AnimationPlayer, anim_name: StringName,
		length: float, id: String, variant_name: String) -> void:
	var spec: Dictionary = SpriteSpecs.spec_for(class_id, StringName(variant_name))
	var lines: PackedStringArray = []
	lines.append("# Pose trace — %s / %s" % [id, variant_name])
	lines.append("# anim=%s  length=%.3fs" % [anim_name, length])
	if not spec.is_empty():
		lines.append("# archetype=%s — %s" % [
			String(spec.get("archetype", "")),
			SpriteSpecs.archetype_description(spec.get("archetype", &"")),
		])
	lines.append("")
	lines.append("## Per-frame numeric pose (sprite-local coords; feet at (0,0), +x right, -y up)")
	lines.append("frame | t     | wpn° | R_hand        | L_hand        | R_elbow       | L_elbow       | tip           | butt")
	lines.append("------+-------+------+---------------+---------------+---------------+---------------+---------------+--------------")
	for frame_i in FRAME_COUNT:
		var t := length * float(frame_i) / float(FRAME_COUNT - 1)
		anim_player.seek(t, true)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var s := _sample_pose(sprite, class_id)
		lines.append("%5d | %5.3f | %s | %s | %s | %s | %s | %s | %s" % [
			frame_i, t,
			_fmt_deg(s.get("weapon_angle_deg")),
			_fmt_vec(s.get("right_hand")),
			_fmt_vec(s.get("left_hand")),
			_fmt_vec(s.get("right_elbow")),
			_fmt_vec(s.get("left_elbow")),
			_fmt_vec(s.get("weapon_tip")),
			_fmt_vec(s.get("weapon_butt")),
		])
	# Verifier section.
	lines.append("")
	if spec.is_empty():
		lines.append("## Spec verifier: (no spec registered for this variant)")
	else:
		lines.append("## Spec verifier — PASS/FAIL per keyframe")
		var keyframes: Array = spec.get("keyframes", [])
		var total_fails := 0
		for kf in keyframes:
			var t: float = kf["t"]
			anim_player.seek(t, true)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var s := _sample_pose(sprite, class_id)
			var fails: Array = _diff_pose(s, kf)
			lines.append("")
			lines.append("  keyframe t=%.3fs  phase=%s" % [t, String(kf.get("phase", &""))])
			if fails.is_empty():
				lines.append("    PASS")
			else:
				total_fails += fails.size()
				for f in fails:
					lines.append("    FAIL %s" % f)
		lines.append("")
		lines.append("Total failures: %d" % total_fails)
	var trace := "\n".join(lines)
	var path := TRACE_PATH % [id, variant_name]
	var fs_path := ProjectSettings.globalize_path(path)
	var f := FileAccess.open(fs_path, FileAccess.WRITE)
	if f != null:
		f.store_string(trace)
		f.close()
		print("  TRACE %s" % path)

# Compares a sampled pose against one spec keyframe. Returns an array
# of failure descriptions; empty means PASS. Only checks keys present
# in the spec.
func _diff_pose(sample: Dictionary, kf: Dictionary) -> Array:
	var fails: Array = []
	var tol_px: float = float(kf.get("tolerance_px", 4.0))
	var tol_deg: float = float(kf.get("tolerance_deg", 6.0))
	var vec_keys := ["right_hand", "left_hand", "right_elbow", "left_elbow",
			"weapon_tip", "weapon_butt", "weapon_grip", "weapon_left_grip"]
	for k in vec_keys:
		if not kf.has(k):
			continue
		var want: Vector2 = kf[k]
		if not sample.has(k):
			fails.append("%s: expected %s, got <missing>" % [k, _fmt_vec(want)])
			continue
		var got: Vector2 = sample[k]
		var d := got.distance_to(want)
		if d > tol_px:
			fails.append("%s: want %s, got %s, off by %.1f px (tol %.1f)" % [
				k, _fmt_vec(want), _fmt_vec(got), d, tol_px])
	if kf.has("weapon_angle_deg"):
		var want_a: float = kf["weapon_angle_deg"]
		if not sample.has("weapon_angle_deg"):
			fails.append("weapon_angle_deg: expected %.1f°, got <missing>" % want_a)
		else:
			var got_a: float = sample["weapon_angle_deg"]
			var diff: float = absf(_wrap_deg(got_a - want_a))
			if diff > tol_deg:
				fails.append("weapon_angle_deg: want %.1f°, got %.1f°, off by %.1f° (tol %.1f)" % [
					want_a, got_a, diff, tol_deg])
	return fails

static func _wrap_deg(d: float) -> float:
	while d > 180.0: d -= 360.0
	while d < -180.0: d += 360.0
	return d

static func _fmt_vec(v) -> String:
	if v == null:
		return "     <none>    "
	var vec: Vector2 = v
	return "(%+5.1f,%+5.1f)" % [vec.x, vec.y]

static func _fmt_deg(d) -> String:
	if d == null:
		return " <no>"
	return "%+4.0f" % float(d)
