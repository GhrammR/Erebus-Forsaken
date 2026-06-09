class_name SpriteOverrides extends Object
## Stage 17.8 — shared helper for tmp/recommended_stances.json reads.
##
## Every per-class sprite (ShadeHunter, Pythia, Myrmidon, OssuaryPriest)
## consumes the same JSON format: tuned rotations + positions + marker
## values keyed by class / stance / anim / phase / preset. This file
## centralizes the read + apply logic so all sprites get the feature
## without duplicating ~80 lines apiece.
##
## Usage pattern from a class sprite:
##   var configs := SpriteOverrides.load_for_class(&"pythia", stance_id)
##   # configs is { anim_name → { rest_rotations: {...}, strike_rotations: {...},
##   #                            bow_pos / nock_rest / ... } }
##   if configs.has(anim_name):
##       SpriteOverrides.inject_tuned_rotations(anim, configs[anim_name],
##               draw_frac, release_frac)
##
## Sprite is responsible for:
##   * Connecting AnimationPlayer.animation_started to a rebuild
##     callback so the latest tuned values land before each play.
##   * Skipping its own IK pin pass when the current anim is in the
##     "tuned" set (SpriteOverrides.is_tuned(cfg)).

const STANCE_FILE: String = "res://tmp/recommended_stances.json"
# Phase keys we treat as legacy "flat snapshot in the stance dict"
# markers — covers both the original REST/STRIKE pair AND the new
# BEGIN/MIDDLE/END trio so mixed files don't confuse the loader.
const PHASE_KEYS: PackedStringArray = [
	"REST", "STRIKE", "CHARGE", "RECOVERY",
	"BEGIN", "MIDDLE", "END",
]
const BEGIN_HOLD_SECONDS: float = 0.04

## Resolve { presets: {...}, active: <key> } indirection. Flat dicts
## pass through unchanged so legacy data still applies.
static func resolve_phase(phase_value: Variant) -> Dictionary:
	if typeof(phase_value) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = phase_value
	if d.has("presets"):
		var active: String = String(d.get("active", ""))
		var presets: Dictionary = d.get("presets", {})
		if presets.has(active):
			return presets[active]
		if presets.size() > 0:
			return presets.values()[presets.size() - 1]
		return {}
	return d

## Load and parse per-anim configs for a (class_id, stance_id) pair.
## Returns Dictionary[String → Dictionary]. Each inner dict carries
## rest_rotations, strike_rotations, plus class-specific fields the
## caller previously read off the raw phase snap (e.g. bow_pos for
## ShadeHunter, no-op for stances without weapon-arm tuning).
static func load_for_class(class_id: StringName, stance_id: StringName) -> Dictionary:
	var f := FileAccess.open(STANCE_FILE, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var classes: Dictionary = parsed
	var by_stance: Dictionary = classes.get(String(class_id), {}).get(String(stance_id), {})
	if by_stance.is_empty():
		return {}
	# Split mixed legacy + anim-keyed entries.
	var legacy_phases: Dictionary = {}
	var anim_blocks: Dictionary = {}
	for k in by_stance.keys():
		var ks: String = String(k)
		if PHASE_KEYS.has(ks):
			legacy_phases[ks] = by_stance[k]
		else:
			anim_blocks[ks] = by_stance[k]
	var configs: Dictionary = {}
	if not legacy_phases.is_empty():
		configs["global"] = _build_cfg(legacy_phases)
	for anim_name in anim_blocks:
		configs[String(anim_name)] = _build_cfg(anim_blocks[anim_name])
	return configs

static func _build_cfg(phases: Dictionary) -> Dictionary:
	var cfg: Dictionary = {}
	# Accept both BEGIN/MIDDLE/END (new) and REST/STRIKE (legacy) at
	# the same time. BEGIN supersedes REST; MIDDLE supersedes STRIKE;
	# END falls back to BEGIN (so animations end where they started).
	var rest: Dictionary = resolve_phase(phases.get("BEGIN", phases.get("REST", {})))
	var strike: Dictionary = resolve_phase(phases.get("MIDDLE", phases.get("STRIKE", {})))
	var ending: Dictionary = resolve_phase(phases.get("END", phases.get("REST", rest)))
	if rest.has("rotations"):    cfg["rest_rotations"] = rest["rotations"]
	if rest.has("positions"):    cfg["rest_positions"] = rest["positions"]
	if rest.has("markers"):      cfg["rest_markers"] = rest["markers"]
	if strike.has("rotations"):  cfg["strike_rotations"] = strike["rotations"]
	if strike.has("positions"):  cfg["strike_positions"] = strike["positions"]
	if strike.has("markers"):    cfg["strike_markers"] = strike["markers"]
	if ending.has("rotations"):  cfg["end_rotations"] = ending["rotations"]
	if ending.has("positions"):  cfg["end_positions"] = ending["positions"]
	if ending.has("markers"):    cfg["end_markers"] = ending["markers"]
	for k in ["weapon_arm_pos", "weapon_arm_rot", "NockMarker", "RiserMarker"]:
		if rest.has(k):    cfg["rest_" + k] = rest[k]
		if strike.has(k):  cfg["strike_" + k] = strike[k]
	return cfg

## True if the given config has any transform tuning that should
## suppress runtime pin/IK passes during this anim.
static func is_tuned(cfg: Dictionary) -> bool:
	return cfg.has("rest_rotations") or cfg.has("strike_rotations") 			or cfg.has("end_rotations") or cfg.has("rest_positions") 			or cfg.has("strike_positions") or cfg.has("end_positions")

## Back-compat entry point. It now injects all saved transforms, not
## only rotations, so older sprite call sites gain position playback.
static func inject_tuned_rotations(anim: Animation, cfg: Dictionary,
		draw_frac: float = 0.30, release_frac: float = 0.75) -> void:
	inject_tuned_transforms(anim, cfg, draw_frac, release_frac)

## Inject value tracks into `anim` for every tuned transform in `cfg`.
## Three phases drive interpolation:
##   t=0          -> BEGIN pose
##   t=mid_frac   -> MIDDLE pose, held to release_frac
##   t=length     -> END pose, fallback to BEGIN
## LINEAR interpolation is used so joints do not overshoot saved values.
static func inject_tuned_transforms(anim: Animation, cfg: Dictionary,
		draw_frac: float = 0.30, release_frac: float = 0.75) -> void:
	if anim == null:
		return
	_inject_float_property(anim, cfg, "rotations", "rotation", 0.0,
			draw_frac, release_frac)
	_inject_vec2_property(anim, cfg, "positions", "position", Vector2.ZERO,
			draw_frac, release_frac)

static func _inject_float_property(anim: Animation, cfg: Dictionary,
		key_suffix: String, property: String, fallback: float,
		draw_frac: float, release_frac: float) -> void:
	var rest: Dictionary = cfg.get("rest_" + key_suffix, {})
	var strike: Dictionary = cfg.get("strike_" + key_suffix, {})
	var ending: Dictionary = cfg.get("end_" + key_suffix, {})
	if rest.is_empty() and strike.is_empty() and ending.is_empty():
		return
	var paths: Dictionary = {}
	for p in rest.keys(): paths[p] = true
	for p in strike.keys(): paths[p] = true
	for p in ending.keys(): paths[p] = true
	for path in paths.keys():
		var prop_path := NodePath(String(path) + ":" + property)
		_remove_existing_track(anim, prop_path)
		var ti := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(ti, prop_path)
		anim.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
		var r0 := float(rest.get(path, fallback))
		var rn := float(ending.get(path, r0))
		anim.track_insert_key(ti, 0.0, r0)
		var begin_hold := minf(BEGIN_HOLD_SECONDS, anim.length * 0.20)
		if begin_hold > 0.0:
			anim.track_insert_key(ti, begin_hold, r0)
		if strike.has(path):
			var rs := float(strike[path])
			anim.track_insert_key(ti, anim.length * draw_frac, rs)
			anim.track_insert_key(ti, anim.length * release_frac, rs)
		anim.track_insert_key(ti, anim.length, rn)

static func _inject_vec2_property(anim: Animation, cfg: Dictionary,
		key_suffix: String, property: String, fallback: Vector2,
		draw_frac: float, release_frac: float) -> void:
	var rest: Dictionary = cfg.get("rest_" + key_suffix, {})
	var strike: Dictionary = cfg.get("strike_" + key_suffix, {})
	var ending: Dictionary = cfg.get("end_" + key_suffix, {})
	if rest.is_empty() and strike.is_empty() and ending.is_empty():
		return
	var paths: Dictionary = {}
	for p in rest.keys(): paths[p] = true
	for p in strike.keys(): paths[p] = true
	for p in ending.keys(): paths[p] = true
	for path in paths.keys():
		var prop_path := NodePath(String(path) + ":" + property)
		_remove_existing_track(anim, prop_path)
		var ti := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(ti, prop_path)
		anim.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
		var r0 := _vec2_from_variant(rest.get(path, fallback), fallback)
		var rn := _vec2_from_variant(ending.get(path, r0), r0)
		anim.track_insert_key(ti, 0.0, r0)
		var begin_hold := minf(BEGIN_HOLD_SECONDS, anim.length * 0.20)
		if begin_hold > 0.0:
			anim.track_insert_key(ti, begin_hold, r0)
		if strike.has(path):
			var rs := _vec2_from_variant(strike[path], r0)
			anim.track_insert_key(ti, anim.length * draw_frac, rs)
			anim.track_insert_key(ti, anim.length * release_frac, rs)
		anim.track_insert_key(ti, anim.length, rn)

static func _vec2_from_variant(v: Variant, fallback: Vector2) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float((v as Array)[0]), float((v as Array)[1]))
	return fallback

static func _remove_existing_track(anim: Animation, prop_path: NodePath) -> void:
	for ti in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_path(ti) == prop_path:
			anim.remove_track(ti)
