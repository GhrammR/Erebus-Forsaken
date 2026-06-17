extends Node
## Sprite QA harness (Stage 17.6 — agentic sprite-verification workflow).
##
## For EVERY registered sprite it runs automated checks that catch the
## classes of bug we've hit polishing sprites, and writes a pass/fail
## report to docs/sprites/_qa_report.txt. With a display it also saves a
## labeled idle contact sheet (docs/sprites/_contact_sheet.png) for the
## human/agent eyeball pass.
##
## Checks per sprite:
##   1. scene loads + instantiates
##   2. AnimationPlayer present
##   3. all six canonical anims build (idle/walk/attack/cast/hit/die)
##   4. NO orphaned animation tracks (track path resolves to a live node)
##   5. every Polygon2D part has real geometry (>=3 points) — catches
##      unpainted/empty parts (the reset-left-weapons bug)
##   6. NO part at/below the editor background z (-100) — occlusion guard
##      (the legs-hidden-behind-editor-bg bug)
##   7. parts stay within a sane bounding box (catches a stray vertex /
##      blown-up polygon)
##
## Run headless for checks:  godot --headless --path . res://test/sprite_qa.tscn
## Run with display for the sheet too (WSLg).

const SpriteMotionStances = preload("res://scripts/systems/stances/sprite_motion_stances.gd")
const SkinLibrary = preload("res://scripts/systems/skin_library.gd")
const CANON := [&"idle", &"walk", &"attack", &"cast", &"hit", &"die"]
const EDITOR_BG_Z := -100
const SANE_MIN := Vector2(-40, -90)
const SANE_MAX := Vector2(40, 30)

# Stage 17.8 — weapon-mount contract (see baseline_white_sprite.gd):
# a held weapon's root is welded under its wielding hand's ElbowPivot at
# the grip point, so the grip can never leave the hand in any animation.
const WEAPON_ARM_SUFFIXES := ["SpearArm", "StaffArm", "BowArm", "WandArm"]
const GRIP_LOCAL := Vector2(0, 10)   # hand centroid, elbow-local
const GRIP_EPS := 0.75               # px tolerance for "grip on hand"
const GRIP_PHASES := [0.0, 0.34, 0.67, 1.0]
# Arm-layering check: free-arm parts must render at/above the base
# clothing so a robe/cloak can't bury the arms. Face/detail parts above
# the arms (eyes, glints, emblem) are excluded from the clothing scan.
const ARM_PART_PATHS := [
	"Body/ArmLShoulder/UpperArm", "Body/ArmLShoulder/ElbowPivot/Forearm",
	"Body/ArmLShoulder/ElbowPivot/Hand",
	"Body/ArmRShoulder/UpperArm", "Body/ArmRShoulder/ElbowPivot/Forearm",
	"Body/ArmRShoulder/ElbowPivot/Hand",
]
const CLOTHING_EXCLUDE_TOKENS := ["Glint", "_OL", "Eye", "Socket", "Brow",
	"Mouth", "Orb", "Sigil", "Head", "Neck"]

const SPRITES := [
	{ "id": &"myrmidon", "path": "res://art/procedural/classes/myrmidon_sprite.tscn" },
	{ "id": &"pythia", "path": "res://art/procedural/classes/pythia_sprite.tscn" },
	{ "id": &"shade_hunter", "path": "res://art/procedural/classes/shade_hunter_sprite.tscn" },
	{ "id": &"ossuary_priest", "path": "res://art/procedural/classes/ossuary_priest_sprite.tscn" },
	{ "id": &"kallias", "path": "res://art/procedural/npcs/kallias_sprite.tscn" },
	{ "id": &"eurynome", "path": "res://art/procedural/npcs/eurynome_sprite.tscn" },
	{ "id": &"bone_servant", "path": "res://art/procedural/enemies/bone_servant_sprite.tscn" },
	{ "id": &"revenant", "path": "res://art/procedural/enemies/revenant_sprite.tscn" },
	{ "id": &"shade_wretch", "path": "res://art/procedural/enemies/shade_wretch_sprite.tscn" },
	{ "id": &"bog_caller", "path": "res://art/procedural/enemies/bog_caller_sprite.tscn" },
	{ "id": &"act_boss", "path": "res://art/procedural/enemies/act_boss_sprite.tscn" },
	{ "id": &"fiend", "path": "res://art/procedural/enemies/fiend_sprite.tscn" },
	{ "id": &"bronze_sentinel", "path": "res://art/procedural/enemies/sentinel_sprite.tscn" },
]

var _lines: PackedStringArray = []
var _fail := 0
var _vp: SubViewport = null
var _headless := false

func _ready() -> void:
	print("--- Sprite QA ---")
	# Assertions run in any mode; the contact-sheet render needs a real
	# display (WSLg). Headless = checks only (CI-friendly, no GPU stall).
	_headless = DisplayServer.get_name() == "headless"
	if not _headless:
		_setup_viewport()
		await get_tree().process_frame
	var sheet_imgs: Array[Image] = []
	for rec_v in SPRITES:
		var rec: Dictionary = rec_v
		var img := await _check_sprite(rec)
		if img != null:
			sheet_imgs.append(img)
	_save_report()
	if not _headless:
		_save_contact_sheet(sheet_imgs)
	print("--- Sprite QA: %s ---" % ("ALL PASS" if _fail == 0 else "%d ISSUES" % _fail))
	get_tree().quit(_fail)

func _log(s: String) -> void:
	print(s)
	_lines.append(s)

func _check_sprite(rec: Dictionary) -> Image:
	var id: StringName = rec["id"]
	var issues: PackedStringArray = []
	var packed := load(String(rec["path"])) as PackedScene
	if packed == null:
		_record(id, ["scene FAILED to load"])
		return null
	var sprite := packed.instantiate() as Node2D
	if &"sprite_id" in sprite:
		sprite.sprite_id = id
	add_child(sprite)
	await get_tree().process_frame

	var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim == null:
		issues.append("no AnimationPlayer")
	else:
		for n in CANON:
			if not anim.has_animation(n):
				issues.append("missing anim '%s'" % n)
		# Orphaned tracks: every track path must resolve to a live node.
		for n in CANON:
			if not anim.has_animation(n):
				continue
			var a := anim.get_animation(n)
			for t in a.get_track_count():
				var node_part := String(a.track_get_path(t)).split(":")[0]
				if node_part != "" and sprite.get_node_or_null(NodePath(node_part)) == null:
					issues.append("anim '%s' orphaned track -> %s" % [n, node_part])

	# Part geometry + z + bounds.
	var empties := 0
	var below_bg := 0
	var oob := 0
	for poly in sprite.find_children("*", "Polygon2D", true, false):
		var p := poly as Polygon2D
		# Effective visibility — a hidden weapon arm's empty child polys
		# are fine (they're not shown); only flag parts actually drawn.
		if not p.is_visible_in_tree():
			continue
		if p.polygon.size() < 3:
			empties += 1
		if p.z_index <= EDITOR_BG_Z:
			below_bg += 1
		for v in p.polygon:
			if v.x < SANE_MIN.x or v.x > SANE_MAX.x or v.y < SANE_MIN.y or v.y > SANE_MAX.y:
				oob += 1
				break
	if empties > 0:
		issues.append("%d visible part(s) with empty geometry" % empties)
	if below_bg > 0:
		issues.append("%d part(s) at/below editor BG z (would hide)" % below_bg)
	if oob > 0:
		issues.append("%d part(s) outside sane bounds" % oob)

	await _check_weapon_grips(sprite, anim, issues)
	# Arm-over-clothing layering applies to the skinned HUMAN cast (robe/
	# tunic over the shared rig). Enemies/bosses paint bespoke parts
	# (ribs, horns, loincloth) that are intentionally layered and don't
	# span the arms, so they are exempt.
	if SkinLibrary.has(id):
		_check_arm_layering(sprite, issues)

	_record(id, issues)
	var img: Image = null
	if not _headless:
		img = await _snap(sprite, id)
	sprite.queue_free()
	return img

# Stage 17.8 — WEAPON GRIP CHECK. For every weapon arm on the sprite:
#   1. (structural) it must be welded under a hand (parent = ElbowPivot);
#   2. it must carry no :position track (that would slide the grip away);
#   3. (behavioral) across every animation, sampled at several phases, the
#      weapon's grip origin must stay on its hand's grip point.
# This is the durable guard for "a weapon that doesn't connect to a hand
# during any animation FAILS" — body-level weapons drift in walk/attack
# and are caught here instead of having to be hand-fixed per sprite.
func _check_weapon_grips(sprite: Node2D, anim: AnimationPlayer, issues: PackedStringArray) -> void:
	var arms: Array[Node2D] = []
	for n in sprite.find_children("*", "Node2D", true, false):
		var nm := String(n.name)
		for suf in WEAPON_ARM_SUFFIXES:
			if nm.ends_with(suf):
				arms.append(n as Node2D)
				break
	if arms.is_empty():
		return
	# 1 + 2: static structural checks.
	var live: Array[Node2D] = []
	for arm in arms:
		var parent := arm.get_parent()
		var pname := String(parent.name) if parent != null else "<none>"
		if pname != "ElbowPivot":
			issues.append("weapon '%s' not welded to a hand (parent=%s)" % [arm.name, pname])
			continue
		live.append(arm)
		if anim == null:
			continue
		var arm_path := String(sprite.get_path_to(arm)) + ":position"
		for n in CANON:
			if not anim.has_animation(n):
				continue
			var a := anim.get_animation(n)
			for t in a.get_track_count():
				if String(a.track_get_path(t)) == arm_path:
					issues.append("weapon '%s' has a :position track in '%s' (slides grip off hand)" % [arm.name, n])
					break
	# 3: behavioral — sample each anim and confirm the grip rides the hand.
	if anim == null or live.is_empty():
		return
	var flagged: Dictionary = {}
	for n in CANON:
		if not anim.has_animation(n):
			continue
		var length := anim.get_animation(n).length
		for ph in GRIP_PHASES:
			anim.play(n)
			anim.seek(length * float(ph), true)
			await get_tree().process_frame
			for arm in live:
				if flagged.has(arm.name):
					continue
				var hand := arm.get_parent() as Node2D
				var grip_world := hand.to_global(GRIP_LOCAL)
				var off := arm.global_position.distance_to(grip_world)
				if off > GRIP_EPS:
					flagged[arm.name] = true
					issues.append("weapon '%s' grip left the hand in '%s' @%d%% (%.1fpx)" % [
							arm.name, n, int(float(ph) * 100.0), off])

# ARM LAYERING (Stage 17.8c). A robe/cloak must not bury the arms: each
# visible free-arm part must render at or above every base-clothing
# polygon (Body-parented, excluding face/detail parts above the arms).
# Catches "arms behind the skin" instead of leaving it to eyeballing.
func _check_arm_layering(sprite: Node2D, issues: PackedStringArray) -> void:
	var body := sprite.get_node_or_null(^"Body") as Node2D
	if body == null:
		return
	var clothing_max := -9999
	var clothing_name := ""
	for c in body.get_children():
		if not (c is Polygon2D) or not (c as Polygon2D).is_visible_in_tree():
			continue
		var nm := String(c.name)
		var skip := false
		for tok in CLOTHING_EXCLUDE_TOKENS:
			if nm.contains(tok):
				skip = true
				break
		if skip:
			continue
		if (c as Polygon2D).z_index > clothing_max:
			clothing_max = (c as Polygon2D).z_index
			clothing_name = nm
	if clothing_max == -9999:
		return
	for path in ARM_PART_PATHS:
		var p := sprite.get_node_or_null(NodePath(path)) as Polygon2D
		if p == null or not p.is_visible_in_tree():
			continue
		if p.z_index < clothing_max:
			issues.append("arm '%s' (z=%d) renders behind clothing '%s' (z=%d) — buried" % [
					p.name, p.z_index, clothing_name, clothing_max])

func _record(id: StringName, issues: PackedStringArray) -> void:
	if issues.is_empty():
		_log("  PASS  %s" % id)
	else:
		_fail += 1
		_log("  FAIL  %s:" % id)
		for i in issues:
			_log("          - %s" % i)

# ---- contact sheet -------------------------------------------------------

func _setup_viewport() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(120, 150)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

func _snap(sprite: Node2D, _id: StringName) -> Image:
	# Reparent into the capture viewport at a readable scale; restore not
	# needed (sprite is freed after).
	if sprite.get_parent() == self:
		remove_child(sprite)
	var holder := Node2D.new()
	holder.position = Vector2(60, 132)
	holder.scale = Vector2(2, 2)
	holder.add_child(sprite)
	_vp.add_child(holder)
	var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
		anim.seek(0.0, true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	_vp.remove_child(holder)
	holder.remove_child(sprite)
	add_child(sprite)
	return img

func _save_contact_sheet(imgs: Array[Image]) -> void:
	if imgs.is_empty():
		return
	var cols := 6
	var cw := 120
	var ch := 150
	var rows := int(ceil(float(imgs.size()) / cols))
	var sheet := Image.create(cw * cols, ch * rows, false, imgs[0].get_format())
	sheet.fill(Color(0.10, 0.10, 0.12))
	for i in imgs.size():
		var cx := (i % cols) * cw
		var cy := (i / cols) * ch
		sheet.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, Vector2i(cw, ch)), Vector2i(cx, cy))
	sheet.save_png("res://docs/sprites/_contact_sheet.png")
	_log("contact sheet -> docs/sprites/_contact_sheet.png")

func _save_report() -> void:
	var f := FileAccess.open("res://docs/sprites/_qa_report.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines))
		f.close()
