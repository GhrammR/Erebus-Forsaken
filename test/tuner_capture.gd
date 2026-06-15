extends Node
## Faithful replica of pose_tuner._load_current's sprite setup, to
## capture exactly what the editor shows for bone_servant and compare
## against the plain in-game render. Run with a display (WSLg):
##   godot --path . res://test/tuner_capture.tscn

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(360, 360)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.14)
	bg.size = Vector2(360, 360)
	bg.z_index = -100
	vp.add_child(bg)
	var fl := Polygon2D.new()
	fl.position = Vector2(180, 324)
	var fpts: PackedVector2Array = []
	for i in 28:
		var t := TAU * i / 28
		fpts.append(Vector2(58.0 * cos(t), 13.0 * sin(t)))
	fl.polygon = fpts
	fl.color = Color(0.02, 0.015, 0.025, 0.72)
	fl.z_index = -50
	vp.add_child(fl)
	add_child(vp)
	await get_tree().process_frame

	var scene := load("res://art/procedural/enemies/bone_servant_sprite.tscn") as PackedScene
	var s := scene.instantiate() as Node2D
	if &"stance_id" in s:
		s.stance_id = &"enemy_walk_lurch"
	if &"sprite_id" in s:
		s.sprite_id = &"bone_servant"
	if &"stance_bucket" in s:
		s.stance_bucket = &"enemies"
	if &"ik_enabled" in s:
		s.ik_enabled = false
	s.position = Vector2(180, 320)
	s.scale = Vector2(3, 3)
	vp.add_child(s)
	# boost editor shadows (z=-5) like the tuner
	for child in s.find_children("*", "Polygon2D", true, false):
		if String(child.name).contains("Shadow"):
			(child as Polygon2D).z_index = -5
	await get_tree().process_frame
	# Diagnostics: do the leg polygons exist / painted / positioned?
	for p in ["Body/LegLHip", "Body/LegLHip/Thigh", "Body/LegLHip/KneePivot",
			"Body/LegLHip/KneePivot/Shin", "Body/LegLHip/KneePivot/Foot",
			"Body/LegRHip/Thigh"]:
		var n := s.get_node_or_null(NodePath(p))
		if n == null:
			print("  LEG %s = <MISSING>" % p)
		elif n is Polygon2D:
			var poly := n as Polygon2D
			print("  LEG %s pts=%d color=%s vis=%s z=%d gpos=%s" % [
				p, poly.polygon.size(), poly.color, poly.visible, poly.z_index, poly.global_position])
		else:
			print("  LEG %s (Node2D) pos=%s vis=%s gpos=%s" % [
				p, (n as Node2D).position, (n as Node2D).visible, (n as Node2D).global_position])
	var anim := s.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	for variant in [&"idle", &"walk"]:
		if anim != null and anim.has_animation(variant):
			anim.play(variant)
			anim.pause()
			anim.seek(0.0, true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("res://docs/sprites/bone_servant/_tuner_%s.png" % variant)
		print("saved _tuner_%s.png" % variant)
	get_tree().quit(0)
