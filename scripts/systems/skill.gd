class_name Skill extends Node
## Base class for Stage 5 class skills. Each class has exactly ONE
## active skill in Act 1 (scope-lock: no skill trees). Subclasses
## override `_configure()` to set their tunables, and `_execute()` to
## perform the actual swing / projectile / summon.
##
## Cooldown lives here. MP cost is spent through Stats.spend_mp.
## Damage (when applicable) routes through DamageResolver via the
## existing HealthComponent.take_damage path (AD-04).
##
## Cooldowns DO NOT persist across save/load (scope-lock + gap-log).

signal skill_used(display_name: String)
signal skill_failed(reason: String)   ## "cooldown" | "insufficient_mp" | "no_stats" | "no_target"

# Tunables — subclass overrides in _configure(). Class-balance audits
# the [5, 25] MP and [0.5, 6.0] cooldown bands.
var display_name: String = "Unnamed Skill"
var mp_cost: int = 10
var cooldown: float = 1.0
var base_damage: int = 10
var range_px: float = 100.0

var _cd_remaining: float = 0.0

func _init() -> void:
	_configure()

func _process(delta: float) -> void:
	if _cd_remaining > 0.0:
		_cd_remaining = maxf(_cd_remaining - delta, 0.0)

## Public entry — call from the owner (Player) when the skill key fires.
## Returns true on success. Emits `skill_used` or `skill_failed`.
func try_activate(caster: Node, facing_dir: Vector2) -> bool:
	if _cd_remaining > 0.0:
		skill_failed.emit("cooldown")
		return false
	var stats: Stats = _stats_of(caster)
	if stats == null:
		skill_failed.emit("no_stats")
		return false
	if not stats.spend_mp(mp_cost):
		skill_failed.emit("insufficient_mp")
		return false
	_cd_remaining = cooldown
	_execute(caster, facing_dir)
	skill_used.emit(display_name)
	return true

func cooldown_remaining() -> float:
	return _cd_remaining

func cooldown_fraction() -> float:
	return _cd_remaining / cooldown if cooldown > 0.0 else 0.0

func is_ready() -> bool:
	return _cd_remaining <= 0.0

# ---------------------------------------------------------------- overrides

## Set display_name, mp_cost, cooldown, base_damage, range_px here.
func _configure() -> void:
	pass

## Perform the skill effect. Caster's MP has already been spent and
## cooldown set when this is called. Subclass implements the swing /
## projectile / summon. facing_dir is a unit Vector2 (or ZERO if the
## caster has no current facing intent).
func _execute(_caster: Node, _facing_dir: Vector2) -> void:
	pass

# ---------------------------------------------------------------- helpers

static func _stats_of(node: Node) -> Stats:
	if node == null:
		return null
	if "current_stats" in node:
		return node.current_stats as Stats
	return null
