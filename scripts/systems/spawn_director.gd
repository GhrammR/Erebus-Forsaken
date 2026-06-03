class_name SpawnDirector extends Node
## Per-zone enemy spawner. Lives as a child of a Zone, reads
## `SpawnAnchors/*` Marker2D siblings as candidate spots, keeps a
## rolling roster of `concurrent_cap` enemies. After each death the
## director cools down for `respawn_delay` seconds before the next
## spawn becomes eligible — combat has breathing room, but pacing
## stays steady.
##
## Species are weighted: each entry is a Dictionary
##   { "id": StringName, "weight": int }
## resolved through EnemyRegistry. Anchors closer than
## `min_distance_from_player` to the live player are skipped so the
## player isn't ambushed on top of themselves.
##
## Load coordination: if SaveSystem has a pending enemy snapshot,
## the director skips its initial spawn. Game._spawn_enemy_snapshot
## populates the zone; then Game calls claim_existing_enemies() so
## the director takes over cap + respawn accounting from there.
##
## Save state: the director itself is transient — the saved roster
## reflects who was alive at save time and the cooldown resets on
## load. Intentional. Persisting the timer feels overbuilt for
## Phase 3 and can be revisited if pacing drifts.

signal enemy_spawned(enemy: Enemy)

@export var species: Array[Dictionary] = []
@export var concurrent_cap: int = 6
@export var respawn_delay: float = 5.0
@export var initial_spawn_count: int = 4
@export var min_distance_from_player: float = 240.0
## Separate anchors from already-spawned enemies too, so the
## initial 4-pack doesn't drop two wretches on the same pixel and
## look like a single enemy. Smaller than the player gate — we
## just want visual breathing room.
@export var min_distance_from_others: float = 60.0

## Stage 8 — per-spawn elite roll. When > 0, each spawn picks an
## EliteModifier uniformly from elite_table. Wilderness ships ~5%;
## the dungeon room 2/3 directors run higher rates via per-zone
## overrides. Empty table => roll is skipped regardless of chance.
@export_range(0.0, 1.0, 0.01) var elite_chance: float = 0.0
@export var elite_table: Array[EliteModifier] = []

var _zone: Node = null
var _anchors: Array[Marker2D] = []
var _cooldown_remaining: float = 0.0
var _tracked_enemies: Array[Enemy] = []

func _ready() -> void:
	_zone = get_parent()
	_collect_anchors()
	if SaveSystem.has_pending_enemy_snapshot():
		# A load is queued: skip initial spawn. Game will call
		# claim_existing_enemies() after it spawns the snapshot.
		return
	for i in initial_spawn_count:
		_spawn_one.call_deferred()

func _collect_anchors() -> void:
	_anchors.clear()
	var holder := _zone.get_node_or_null(^"SpawnAnchors") if _zone != null else null
	if holder == null:
		push_warning("SpawnDirector: no SpawnAnchors sibling — no spawns will fire.")
		return
	for c in holder.get_children():
		var m := c as Marker2D
		if m != null:
			_anchors.append(m)

func _process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_prune_invalid()
	if _cooldown_remaining > 0.0:
		return
	if _tracked_enemies.size() >= concurrent_cap:
		return
	_spawn_one()

func _prune_invalid() -> void:
	var i := _tracked_enemies.size() - 1
	while i >= 0:
		var e := _tracked_enemies[i]
		if e == null or not is_instance_valid(e):
			_tracked_enemies.remove_at(i)
		i -= 1

func _spawn_one() -> void:
	if _zone == null or not is_instance_valid(_zone):
		return
	if _anchors.is_empty() or species.is_empty():
		return
	var anchor := _pick_anchor()
	if anchor == null:
		return
	var id := _pick_species()
	if id == &"":
		return
	var packed := EnemyRegistry.scene_for(id)
	if packed == null:
		push_warning("SpawnDirector: no scene for enemy_id '%s'" % id)
		return
	var inst := packed.instantiate() as Enemy
	if inst == null:
		return
	# Assign the elite modifier BEFORE add_child so Enemy._ready folds
	# the mults into Stats/sprite in one pass.
	var em := _maybe_pick_elite()
	if em != null:
		inst.elite_modifier = em
	var container: Node = _zone.get_node_or_null(^"Enemies")
	if container == null:
		container = _zone
	container.add_child(inst)
	inst.global_position = anchor.global_position
	_track(inst)
	enemy_spawned.emit(inst)

func _maybe_pick_elite() -> EliteModifier:
	if elite_chance <= 0.0 or elite_table.is_empty():
		return null
	if randf() >= elite_chance:
		return null
	return elite_table[randi() % elite_table.size()]

func _pick_anchor() -> Marker2D:
	var player := _player()
	var pool: Array[Marker2D] = []
	for a in _anchors:
		if player != null \
				and (a.global_position - player.global_position).length() < min_distance_from_player:
			continue
		if _has_enemy_within(a.global_position, min_distance_from_others):
			continue
		pool.append(a)
	if pool.is_empty():
		# Everything is occupied or too close to the player — defer
		# this tick. The director retries next frame; once an enemy
		# wanders or dies, anchors free up.
		return null
	return pool[randi() % pool.size()]

func _has_enemy_within(pos: Vector2, radius: float) -> bool:
	for e in _tracked_enemies:
		if e == null or not is_instance_valid(e):
			continue
		if (e.global_position - pos).length() < radius:
			return true
	return false

func _pick_species() -> StringName:
	var total: int = 0
	for entry_v in species:
		var entry: Dictionary = entry_v as Dictionary
		total += int(entry.get("weight", 0))
	if total <= 0:
		return &""
	var r: int = randi() % total
	var acc: int = 0
	for entry_v in species:
		var entry: Dictionary = entry_v as Dictionary
		acc += int(entry.get("weight", 0))
		if r < acc:
			return StringName(entry.get("id", &""))
	return &""

func _track(e: Enemy) -> void:
	_tracked_enemies.append(e)
	var hc := e.get_node_or_null(^"HealthComponent") as HealthComponent
	if hc != null and not hc.died.is_connected(_on_tracked_died):
		hc.died.connect(_on_tracked_died)

func _on_tracked_died(_killer: Node) -> void:
	_cooldown_remaining = respawn_delay

## Called by Game after a load-time snapshot apply: the snapshot's
## enemies are already in the zone; take ownership for cap + respawn
## accounting and re-emit enemy_spawned so subscribers (damage
## numbers, etc.) wire them too.
func claim_existing_enemies() -> void:
	if _zone == null or not is_instance_valid(_zone):
		return
	for n in _zone.find_children("*", "Enemy", true, false):
		var e := n as Enemy
		if e == null or e in _tracked_enemies:
			continue
		_track(e)
		enemy_spawned.emit(e)

func _player() -> Node2D:
	var p: Node = GameState.player
	return p as Node2D if p != null and is_instance_valid(p) else null
