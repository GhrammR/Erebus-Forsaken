extends Node
## Stage 13 — master seed for the player's run. Stored once at
## new-game time (character-select hook), referenced by every
## procedural-generation system to derive deterministic sub-seeds
## per zone. Same master seed + same zone_id == same zone content,
## every machine, every load.
##
## AD-08: this autoload owns master_seed state only. Procgen
## consumers (ZoneProcgen, future waypoint placer, etc.) read from
## here and run their own RNG.
##
## Share-string format reuses the same base-32 alphabet as
## EndlessRun.encode_seed so users have one mental model for "share
## this seed with a friend." A master seed and an endless seed are
## semantically different but format-identical.

var master_seed: int = 0

## Mirrors EndlessRun._SEED_ALPHABET — same 5-bit, hyphen-formatted
## 8-char encoding. Drop I/O/0/1 to keep hand-transcription
## unambiguous. The shared alphabet means a player can paste a
## master-seed share string into endless's seed field by accident
## and get a valid (different) result rather than a parse error.
const _SEED_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func assign_random() -> int:
	# Pull from godot's RandomNumberGenerator. We seed it from
	# Time.get_unix_time_from_system() so the result is not just
	# the editor-default sequence, and randi() seeded from a clock
	# is good enough for "pick a master seed" — there is no
	# adversary trying to predict it.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	master_seed = int(rng.randi())
	DebugLog.write(&"transit", "world_seed assigned %d (%s)" % [
			master_seed, encode_seed(master_seed)])
	return master_seed

## Deterministic per-zone sub-seed derived from the master seed +
## the zone_id string + an optional salt. Same (master, zone, salt)
## always returns the same int, on every machine. ZoneProcgen uses
## salt=0 for prop placement; future systems can use other salts to
## get independent RNG streams for the same zone (e.g. enemy palette
## roll vs prop scatter).
func sub_seed(zone_id: StringName, salt: int = 0) -> int:
	# Composite a stable string and hash. hash() is stable across
	# 4.x Godot versions for primitive types.
	var key := "%d:%s:%d" % [master_seed, String(zone_id), salt]
	return int(key.hash())

func make_rng(zone_id: StringName, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sub_seed(zone_id, salt))
	return rng

## Encode a seed (master or sub) as `EREBUS-XXXX-XXXX`, an 8-char
## base-32 string with one hyphen for readability.
func encode_seed(s: int) -> String:
	var n := s
	if n < 0:
		n = -n
	var out := ""
	for i in 8:
		var idx: int = n & 0x1F  # 5 bits
		out += _SEED_ALPHABET.substr(idx, 1)
		n >>= 5
	return "EREBUS-%s-%s" % [out.substr(0, 4), out.substr(4, 4)]

func decode_seed(text: String) -> int:
	var stripped := text.replace("EREBUS-", "").replace("-", "")
	if stripped.length() < 8:
		return 0
	var out: int = 0
	for i in 8:
		var ch := stripped.substr(7 - i, 1)
		var idx: int = _SEED_ALPHABET.find(ch)
		if idx < 0:
			return 0
		out = (out << 5) | idx
	return out

# ---- save / load --------------------------------------------------------

func snapshot() -> int:
	return master_seed

func restore(value: int) -> void:
	master_seed = value

func clear_runtime() -> void:
	master_seed = 0
