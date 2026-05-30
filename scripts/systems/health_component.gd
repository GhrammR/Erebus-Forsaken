class_name HealthComponent extends Node
## Node-shaped façade over Stats. Per AD-01, Stats owns the HP numbers;
## HealthComponent owns the events and the damage-entry API. All damage
## funnels through here -> DamageResolver -> stats.take_damage.

signal damaged(amount: int, source: Node)
signal healed(amount: int)
signal died(killer: Node)

@export var stats: Stats

var _was_dead: bool = false

func _ready() -> void:
	if stats != null:
		_was_dead = stats.is_dead()
		stats.recomputed.connect(_on_stats_recomputed)

func set_stats(new_stats: Stats) -> void:
	if stats != null and stats.recomputed.is_connected(_on_stats_recomputed):
		stats.recomputed.disconnect(_on_stats_recomputed)
	stats = new_stats
	if stats != null:
		stats.recomputed.connect(_on_stats_recomputed)
		_was_dead = stats.is_dead()

func take_damage(attack: Attack) -> int:
	if stats == null or _was_dead:
		return 0
	var final_damage := DamageResolver.resolve(attack, stats)
	var taken := stats.take_damage(final_damage, attack)
	# Emit damaged even on 0 (miss) so the workbench/HUD can show "MISS".
	damaged.emit(taken, attack.source if attack != null else null)
	if not _was_dead and stats.is_dead():
		_was_dead = true
		died.emit(attack.source if attack != null else null)
	return taken

func heal(amount: int) -> void:
	if stats == null or _was_dead:
		return
	stats.restore_hp(amount)
	healed.emit(amount)

func is_dead() -> bool:
	return stats != null and stats.is_dead()

## Debug / scripted death. Bypasses DamageResolver's random hit roll
## but uses the full Stats path so the same signals fire as a normal
## fatal hit. Used by the Stage 3 workbench (K to demo respawn).
func kill(killer: Node) -> void:
	if stats == null or _was_dead:
		return
	var amount := stats.current_hp
	var atk := Attack.new()
	atk.base_damage = amount
	atk.source = killer
	var taken := stats.take_damage(amount, atk)
	damaged.emit(taken, killer)
	_was_dead = true
	died.emit(killer)

func _on_stats_recomputed() -> void:
	# If something else (respawn) revived the entity, clear our latch.
	if _was_dead and stats != null and not stats.is_dead():
		_was_dead = false
