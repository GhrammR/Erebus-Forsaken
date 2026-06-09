extends Node
## Stage 17.8 — direct test that user-tuned joint rotations actually
## persist through play() instead of snapping back to defaults.
##
## Reads tmp/recommended_stances.json, instantiates each affected
## sprite, plays each tuned anim, advances time, and reads back the
## joint rotation. Fails LOUDLY if the value doesn't match the saved
## one. Run with:
##   godot res://test/tuned_rotation_verify.tscn

const TOL: float = 0.02   # radians

const SPRITES: Dictionary = {
	&"shade_hunter": "res://art/procedural/classes/shade_hunter_sprite.tscn",
	&"pythia":       "res://art/procedural/classes/pythia_sprite.tscn",
	&"myrmidon":     "res://art/procedural/classes/myrmidon_sprite.tscn",
}

const PHASE_KEYS: PackedStringArray = [
	"REST", "STRIKE", "CHARGE", "RECOVERY",
	"BEGIN", "MIDDLE", "END",
]

func _ready() -> void:
	print("=== tuned_rotation_verify ===")
	var f := FileAccess.open("res://tmp/recommended_stances.json", FileAccess.READ)
	if f == null:
		print("  no recommended_stances.json yet — skipping")
		get_tree().quit(0)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		print("  bad JSON")
		get_tree().quit(1)
		return
	var fails: int = 0
	for class_id in (data as Dictionary):
		fails += await _check_class(StringName(class_id), data[class_id])
	if fails == 0:
		print("=== ALL PASS ===")
		get_tree().quit(0)
	else:
		print("=== %d FAILURES ===" % fails)
		get_tree().quit(1)

func _check_class(class_id: StringName, by_stance: Dictionary) -> int:
	if not SPRITES.has(class_id):
		return 0
	var scene: PackedScene = load(SPRITES[class_id])
	var fails: int = 0
	for stance in by_stance.keys():
		var stance_id := StringName(stance)
		fails += await _check_stance(scene, class_id, stance_id, by_stance[stance])
	return fails

func _check_stance(scene: PackedScene, class_id: StringName,
		stance_id: StringName, by_anim: Dictionary) -> int:
	# Spin up a SubViewport so the sprite + AnimationPlayer can run.
	var vp := SubViewport.new()
	vp.size = Vector2i(120, 200)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var cont := SubViewportContainer.new()
	cont.add_child(vp)
	add_child(cont)
	var sprite: Node2D = scene.instantiate() as Node2D
	if &"stance_id" in sprite:
		sprite.stance_id = stance_id
	vp.add_child(sprite)
	await get_tree().process_frame
	var anim_player: AnimationPlayer = sprite.get_node(^"AnimationPlayer")
	var fails: int = 0
	for anim in by_anim.keys():
		var anim_name := StringName(anim)
		# Skip phase keys and the synthetic legacy bucket; only real
		# AnimationPlayer names are probed here.
		if String(anim) in PHASE_KEYS or String(anim) == "global":
			continue
		var phases: Variant = by_anim[anim]
		if typeof(phases) != TYPE_DICTIONARY: continue
		# Play the anim and advance so animation_started injection/replay has run.
		var anim_str: String = String(anim_name)
		if anim_str == "global": anim_str = "idle"
		if not anim_player.has_animation(StringName(anim_str)): continue
		anim_player.play(StringName(anim_str))
		await get_tree().process_frame
		var anim_res: Animation = anim_player.get_animation(StringName(anim_str))
		for phase_variant in ["BEGIN", "MIDDLE", "END"]:
			var phase_name: String = String(phase_variant)
			var phase: Dictionary = _phase_for(phases, phase_name)
			var expected_rots: Dictionary = phase.get("rotations", {})
			if expected_rots.is_empty(): continue
			for path in expected_rots.keys():
				var n: Node2D = sprite.get_node_or_null(NodePath(String(path))) as Node2D
				if n == null:
					print("  [SKIP] %s/%s/%s — path missing: %s" % [
						class_id, stance_id, anim_str, path])
					continue
				var want: float = float(expected_rots[path])
				if not _has_rotation_track(anim_res, String(path)):
					print("  [FAIL] %s/%s/%s/%s/%s — missing rotation track" % [
						class_id, stance_id, anim_str, phase_name, path])
					fails += 1
					continue
				var probe: float = _probe_time(anim_res, String(path), phase_name, want)
				anim_player.seek(probe, true)
				await get_tree().process_frame
				var got: float = n.rotation
				if abs(want - got) <= TOL:
					print("  [PASS] %s/%s/%s/%s/%s @ t=%.2f  want=%.4f got=%.4f" % [
						class_id, stance_id, anim_str, phase_name, path, probe, want, got])
				else:
					print("  [FAIL] %s/%s/%s/%s/%s @ t=%.2f  want=%.4f got=%.4f  Δ=%.4f" % [
						class_id, stance_id, anim_str, phase_name, path, probe,
						want, got, got - want])
					fails += 1
	cont.queue_free()
	await get_tree().process_frame
	return fails

static func _phase_for(phases: Dictionary, phase_name: String) -> Dictionary:
	match phase_name:
		"BEGIN":
			return _resolve(phases.get("BEGIN", phases.get("REST", {})))
		"MIDDLE":
			return _resolve(phases.get("MIDDLE", phases.get("STRIKE", {})))
		"END":
			var rest: Variant = phases.get("BEGIN", phases.get("REST", {}))
			return _resolve(phases.get("END", rest))
	return {}

static func _has_rotation_track(anim: Animation, path: String) -> bool:
	if anim == null:
		return false
	var prop_path := NodePath(path + ":rotation")
	for ti in range(anim.get_track_count()):
		if anim.track_get_path(ti) == prop_path:
			return true
	return false

static func _probe_time(anim: Animation, path: String, phase_name: String, want: float) -> float:
	if anim == null:
		return 0.0
	if phase_name == "BEGIN":
		return 0.0
	if phase_name == "END":
		return anim.length
	var prop_path := NodePath(path + ":rotation")
	for ti in range(anim.get_track_count()):
		if anim.track_get_path(ti) != prop_path:
			continue
		for ki in range(anim.track_get_key_count(ti)):
			var t: float = anim.track_get_key_time(ti, ki)
			if t <= TOL or t >= anim.length - TOL:
				continue
			var v: float = float(anim.track_get_key_value(ti, ki))
			if abs(v - want) <= TOL:
				return t
	return anim.length * 0.30

static func _resolve(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	if d.has("presets"):
		var active: String = String(d.get("active", ""))
		var presets: Dictionary = d.get("presets", {})
		if presets.has(active):
			return presets[active]
		if presets.size() > 0:
			return presets.values()[presets.size() - 1]
	return d
