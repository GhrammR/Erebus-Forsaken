extends Node
## Stage 17.6 — one-off wraith rig renderer.
## Captures the six canonical anims for the restored UNDEAD wraith
## sub-variant sprites (shade_wretch, bog_caller) to PNG so the rig can
## be reviewed visually. Needs a display server (WSLg) — run WITHOUT
## --headless:  godot --path . res://test/wraith_render.tscn
##
## Output: res://docs/sprites/<id>/<anim>.png and a combined _strip.png.

const SCENES := [
	{ "id": &"shade_wretch", "path": "res://art/procedural/enemies/shade_wretch_sprite.tscn" },
	{ "id": &"bog_caller",   "path": "res://art/procedural/enemies/bog_caller_sprite.tscn" },
	{ "id": &"bone_servant", "path": "res://art/procedural/enemies/bone_servant_sprite.tscn" },
	{ "id": &"revenant", "path": "res://art/procedural/enemies/revenant_sprite.tscn" },
	{ "id": &"fiend", "path": "res://art/procedural/enemies/fiend_sprite.tscn" },
	{ "id": &"bronze_sentinel", "path": "res://art/procedural/enemies/sentinel_sprite.tscn" },
	{ "id": &"blighted_hound", "path": "res://art/procedural/enemies/hound_sprite.tscn" },
	{ "id": &"act_boss", "path": "res://art/procedural/enemies/act_boss_sprite.tscn" },
	{ "id": &"myrmidon", "path": "res://art/procedural/classes/myrmidon_sprite.tscn" },
	{ "id": &"myrmidon_armed", "path": "res://art/procedural/classes/myrmidon_sprite.tscn", "show": &"show_spear" },
	{ "id": &"pythia", "path": "res://art/procedural/classes/pythia_sprite.tscn" },
	{ "id": &"pythia_armed", "path": "res://art/procedural/classes/pythia_sprite.tscn", "show": &"show_staff" },
	{ "id": &"shade_hunter", "path": "res://art/procedural/classes/shade_hunter_sprite.tscn" },
	{ "id": &"shade_hunter_armed", "path": "res://art/procedural/classes/shade_hunter_sprite.tscn", "show": &"show_bow" },
	{ "id": &"ossuary_priest", "path": "res://art/procedural/classes/ossuary_priest_sprite.tscn" },
	{ "id": &"ossuary_armed", "path": "res://art/procedural/classes/ossuary_priest_sprite.tscn", "show": &"show_wand" },
	{ "id": &"kallias", "path": "res://art/procedural/npcs/kallias_sprite.tscn" },
	{ "id": &"eurynome", "path": "res://art/procedural/npcs/eurynome_sprite.tscn" },
]
const ANIMS: Array[StringName] = [&"idle", &"walk", &"attack", &"cast", &"hit", &"die"]
const CELL := Vector2i(120, 180)
const SCALE := 2.0
const FEET := Vector2(60, 160)

var _vp: SubViewport = null

func _ready() -> void:
	print("--- wraith render ---")
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	await get_tree().process_frame
	for rec_v in SCENES:
		var rec: Dictionary = rec_v
		await _render_one(rec)
	# Equipment-overlay verification: render classes with armor equipped
	# (HEAD/CHEST/LEGS) via the real Inventory + EquipmentPaperdoll path,
	# so the overlays layer over the new base clothing exactly as in-game.
	await _render_geared("myrmidon", "res://art/procedural/classes/myrmidon_sprite.tscn",
			["worn_helm", "bronze_plate", "simple_greaves"])
	await _render_geared("pythia", "res://art/procedural/classes/pythia_sprite.tscn",
			["worn_helm", "silken_robe", "linen_wrap"])
	await _render_geared("ossuary_priest", "res://art/procedural/classes/ossuary_priest_sprite.tscn",
			["worn_helm", "bone_chasuble", "linen_wrap"])
	print("--- wraith render: done ---")
	get_tree().quit(0)

func _render_geared(id: String, scene_path: String, item_ids: Array) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	DirAccess.make_dir_recursive_absolute("res://docs/sprites/%s_geared" % id)
	var holder := Node2D.new()
	holder.position = FEET
	holder.scale = Vector2(SCALE, SCALE)
	var sprite := packed.instantiate() as Node2D
	holder.add_child(sprite)
	_vp.add_child(holder)
	# Real equipment path: Stats -> Inventory -> EquipmentPaperdoll.
	var stats := Stats.new()
	stats.class_id = StringName(id)
	var inv := Inventory.new()
	inv.class_id = StringName(id)
	inv.stats = stats
	add_child(inv)
	var pd := EquipmentPaperdoll.new()
	add_child(pd)
	pd.bind(sprite, inv, StringName(id))
	await get_tree().process_frame
	for iid in item_ids:
		inv.add_item(StringName(iid))
		inv.equip(StringName(iid))
	await get_tree().process_frame
	var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim != null and anim.has_animation(&"idle"):
		anim.play(&"idle")
		anim.seek(0.0, true)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("res://docs/sprites/%s_geared/idle.png" % id)
	print("  saved %s_geared/idle.png" % id)
	holder.queue_free()
	pd.queue_free()
	inv.queue_free()
	await get_tree().process_frame

func _render_one(rec: Dictionary) -> void:
	var id: StringName = rec["id"]
	DirAccess.make_dir_recursive_absolute("res://docs/sprites/%s" % id)
	var packed := load(String(rec["path"])) as PackedScene
	if packed == null:
		print("  FAIL load %s" % id)
		return
	var frames: Array[Image] = []
	for anim_name in ANIMS:
		var holder := Node2D.new()
		holder.position = FEET
		holder.scale = Vector2(SCALE, SCALE)
		var sprite := packed.instantiate() as Node2D
		if rec.has("show") and StringName(rec["show"]) in sprite:
			sprite.set(rec["show"], true)
		holder.add_child(sprite)
		_vp.add_child(holder)
		await get_tree().process_frame
		var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if anim != null and anim.has_animation(anim_name):
			anim.play(anim_name)
			var len := anim.get_animation(anim_name).length
			anim.seek(len * 0.6, true)
		# Two frames: the first lets per-frame rigs (the bow pin driver on
		# get_tree().process_frame) pose against the seeked animation before
		# we capture, so the snapshot reflects the settled pose.
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		var path := "res://docs/sprites/%s/%s.png" % [id, anim_name]
		img.save_png(path)
		frames.append(img)
		print("  saved %s" % path)
		holder.queue_free()
		await get_tree().process_frame
	_save_strip(id, frames)
	await _save_walk_phase_strip(rec)

# Captures the walk/drift across 6 evenly-spaced phases so the glide can
# be read for side-to-side stepping (there should be none — pure vertical
# swell + hem trail).
func _save_walk_phase_strip(rec: Dictionary) -> void:
	var id: StringName = rec["id"]
	var packed := load(String(rec["path"])) as PackedScene
	if packed == null:
		return
	var phases := [0.0, 0.17, 0.34, 0.5, 0.67, 0.84]
	var frames: Array[Image] = []
	for ph in phases:
		var holder := Node2D.new()
		holder.position = FEET
		holder.scale = Vector2(SCALE, SCALE)
		var sprite := packed.instantiate() as Node2D
		holder.add_child(sprite)
		_vp.add_child(holder)
		await get_tree().process_frame
		var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if anim != null and anim.has_animation(&"walk"):
			anim.play(&"walk")
			anim.seek(anim.get_animation(&"walk").length * float(ph), true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		frames.append(_vp.get_texture().get_image())
		holder.queue_free()
		await get_tree().process_frame
	var w := CELL.x * frames.size()
	var strip := Image.create(w, CELL.y, false, frames[0].get_format())
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
	var path := "res://docs/sprites/%s/_drift_strip.png" % id
	strip.save_png(path)
	print("  saved %s" % path)

func _save_strip(id: StringName, frames: Array[Image]) -> void:
	if frames.is_empty():
		return
	var w := CELL.x * frames.size()
	var strip := Image.create(w, CELL.y, false, frames[0].get_format())
	for i in frames.size():
		strip.blit_rect(frames[i], Rect2i(Vector2i.ZERO, CELL),
				Vector2i(CELL.x * i, 0))
	var path := "res://docs/sprites/%s/_anim_strip.png" % id
	strip.save_png(path)
	print("  saved %s" % path)
