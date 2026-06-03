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
	var container: Node = _zone.get_node_or_null(^"Enemies")
	if container == null:
		container = _zone
	container.add_child(inst)
	inst.global_position = anchor.global_position
	_track(inst)
	enemy_spawned.emit(inst)

func _pick_anchor() -> Marker2D:
	var player := _player()
	var pool: Array[Marker2D] = []
	for a in _anchors:
		if player == null \
				or (a.global_position - player.global_position).length() >= min_distance_from_player:
			pool.append(a)
	if pool.is_empty():
		# Everything is too close to the player — defer this tick.
		return null
	return pool[randi() % pool.size()]

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
