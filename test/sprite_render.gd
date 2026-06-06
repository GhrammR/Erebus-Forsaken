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
## Currently renders Myrmidon (the only HUMAN sprite authored in
## Stage 17.5 so far). Extends naturally to other sprites as they're
## added by adding entries to RENDER_PLAN.
##
## Invocation: godot --path . -- --render-sprites
## NOT --headless: needs a display server to drive the GL backend
## (WSL2's WSLg provides one). Output PNGs can be Read directly.

const FRAME_PATH := "res://docs/sprites/%s/%s_%d.png"
const STRIP_PATH := "res://docs/sprites/%s/%s_strip.png"
const VIEW_SIZE: Vector2i = Vector2i(240, 240)
# 12 frames per animation = ~24fps sampling on a typical 0.5s attack.
# Enough to read fluidity at a glance without flooding the folder.
const FRAME_COUNT: int = 12
const SPRITE_SCALE: float = 3.0  # zoom so 60px-tall sprite reads at game-scale

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
]

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
	if equip.has("weapon"):
		inv.add_item(equip["weapon"])
		inv.equip(equip["weapon"])
	if equip.has("offhand"):
		inv.add_item(equip["offhand"])
		inv.equip(equip["offhand"])
	await get_tree().process_frame
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
	# Glue the frames into a single horizontal strip — much easier to
	# scrub for fluidity than reading 12 separate files.
	_save_strip(frames, id, variant["name"])
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
	var first: Image = frames[0]
	var fw := first.get_width()
	var fh := first.get_height()
	var strip := Image.create(fw * frames.size(), fh, false, first.get_format())
	for i in frames.size():
		var src: Image = frames[i]
		strip.blit_rect(src, Rect2i(0, 0, fw, fh), Vector2i(fw * i, 0))
	var path := STRIP_PATH % [id, variant_name]
	var fs_path := ProjectSettings.globalize_path(path)
	strip.save_png(fs_path)
	print("  STRIP %s" % path)
