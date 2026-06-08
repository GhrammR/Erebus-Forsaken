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
	for k in ["weapon_arm_pos", "weapon_arm_rot", "NockMarker", "RiserMarker"]:
		if rest.has(k):    cfg["rest_" + k] = rest[k]
		if strike.has(k):  cfg["strike_" + k] = strike[k]
	return cfg

## True if the given config has any rotation tuning that should
## suppress the runtime IK pin pass during this anim.
static func is_tuned(cfg: Dictionary) -> bool:
	return cfg.has("rest_rotations") or cfg.has("strike_rotations") \
			or cfg.has("end_rotations")

## Inject value tracks into `anim` for every tuned joint in `cfg`.
## Three phases drive interpolation:
##   t=0          → BEGIN pose (rest_rotations)
##   t=mid_frac   → MIDDLE pose (strike_rotations), held to release_frac
##   t=length     → END pose (end_rotations, fallback to BEGIN)
## LINEAR interpolation is used so the joint doesn't overshoot past
## the saved values between keyframes (cubic-bezier overshoot was
## producing the visible elbow flick at the end of the swing).
## Existing tracks on the same path are REMOVED first so caller-built
## tracks don't fight the override.
static func inject_tuned_rotations(anim: Animation, cfg: Dictionary,
		draw_frac: float = 0.30, release_frac: float = 0.75) -> void:
	if anim == null:
		return
	var rest_r: Dictionary = cfg.get("rest_rotations", {})
	var strike_r: Dictionary = cfg.get("strike_rotations", {})
	var end_r: Dictionary = cfg.get("end_rotations", {})
	if rest_r.is_empty() and strike_r.is_empty() and end_r.is_empty():
		return
	var paths: Dictionary = {}
	for p in rest_r.keys(): paths[p] = true
	for p in strike_r.keys(): paths[p] = true
	for p in end_r.keys(): paths[p] = true
	for path in paths.keys():
		var prop_path: NodePath = NodePath(String(path) + ":rotation")
		_remove_existing_track(anim, prop_path)
		var ti: int = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(ti, prop_path)
		anim.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
		var r0: float = float(rest_r.get(path, 0.0))
		var rn: float = float(end_r.get(path, r0))
		anim.track_insert_key(ti, 0.0, r0)
		if strike_r.has(path):
			var rs: float = float(strike_r[path])
			anim.track_insert_key(ti, anim.length * draw_frac, rs)
			anim.track_insert_key(ti, anim.length * release_frac, rs)
		anim.track_insert_key(ti, anim.length, rn)

static func _remove_existing_track(anim: Animation, prop_path: NodePath) -> void:
	for ti in range(anim.get_track_count() - 1, -1, -1):
		if anim.track_get_path(ti) == prop_path:
			anim.remove_track(ti)
