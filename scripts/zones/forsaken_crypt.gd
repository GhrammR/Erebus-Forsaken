class_name ForsakenCrypt extends Zone
## Stage 8 — three-room dungeon interior. Locked progression: each
## room gates the next via a kill-the-room contract. Player enters at
## the south end (from Blighted Reach), pushes north through the
## trash room → mini-encounter → boss-room placeholder (Stage 9 lands
## the real Act boss in the same Room 3 footprint).
##
## Spawning is handled directly here rather than via SpawnDirector
## because rooms have specific compositions and difficulty rises with
## depth. The director's roving cap model doesn't fit a scripted
## crawl. SpawnDirector still owns wilderness ambient spawns.
##
## Save semantics: AD-12 puts the dungeon under the same _zone_cache
## contract as the wilderness — leaving mid-crawl freezes the live
## roster, returning restores it, F5 persists the active zone state
## inline with the player. The elite_id-aware EnemyRegistry +
## SaveSystem extension handles the round-trip.

const _SHADE_WRETCH := "res://scenes/enemies/shade_wretch.tscn"
const _BOG_CALLER := "res://scenes/enemies/bog_caller.tscn"

## Room compositions. Each entry is { scene, elite_id, pos_offset }.
## pos_offset is relative to the room's spawn anchor center; we jitter
## within the room rectangle so two spawns don't overlap. Difficulty
## rises across rooms by both count and elite density (per brief).
const _ROOM_1_SPAWNS: Array = [
	{ "scene": _SHADE_WRETCH, "elite_id": &"" },
	{ "scene": _SHADE_WRETCH, "elite_id": &"" },
	{ "scene": _SHADE_WRETCH, "elite_id": &"" },
]

const _ROOM_2_SPAWNS: Array = [
	{ "scene": _SHADE_WRETCH, "elite_id": &"" },
	{ "scene": _SHADE_WRETCH, "elite_id": &"" },
	{ "scene": _SHADE_WRETCH, "elite_id": &"" },
	{ "scene": _SHADE_WRETCH, "elite_id": &"" },
	{ "scene": _BOG_CALLER,   "elite_id": &"elite_fast" },
]

const _ROOM_3_SPAWNS: Array = [
	{ "scene": _SHADE_WRETCH, "elite_id": &"elite_tough" },
	{ "scene": _BOG_CALLER,   "elite_id": &"elite_fast" },
]

const _ROOM_GROUPS: Array[StringName] = [
	&"crypt_room_1", &"crypt_room_2", &"crypt_room_3",
]

func _ready() -> void:
	zone_id = &"forsaken_crypt"
	super._ready()
	# If a load/cache snapshot will rehydrate the room, skip the
	# scripted spawn — Game pushes the snapshot into the SaveSystem
	# pending slot before instantiating us, same contract as the
	# wilderness director uses.
	if SaveSystem.has_pending_enemy_snapshot():
		return
	_spawn_initial.call_deferred()

func _spawn_initial() -> void:
	_spawn_room(0, _ROOM_1_SPAWNS, ^"Room1Anchors")
	_spawn_room(1, _ROOM_2_SPAWNS, ^"Room2Anchors")
	_spawn_room(2, _ROOM_3_SPAWNS, ^"Room3Anchors")

func _spawn_room(room_index: int, spawns: Array, anchor_parent: NodePath) -> void:
	var anchors_node := get_node_or_null(anchor_parent) as Node2D
	if anchors_node == null:
		push_warning("ForsakenCrypt: missing %s" % anchor_parent)
		return
	var anchors: Array[Marker2D] = []
	for c in anchors_node.get_children():
		var m := c as Marker2D
		if m != null:
			anchors.append(m)
	if anchors.is_empty():
		return
	var container := get_node_or_null(^"Enemies") as Node2D
	if container == null:
		container = self
	for i in spawns.size():
		var entry: Dictionary = spawns[i] as Dictionary
		var packed := load(String(entry.get("scene", ""))) as PackedScene
		if packed == null:
			continue
		var inst := packed.instantiate() as Enemy
		if inst == null:
			continue
		var elite_id := StringName(entry.get("elite_id", &""))
		if elite_id != &"":
			inst.elite_modifier = EnemyRegistry.elite_modifier_for(elite_id)
		var anchor := anchors[i % anchors.size()]
		container.add_child(inst)
		inst.global_position = anchor.global_position \
				+ Vector2(randf_range(-24, 24), randf_range(-24, 24))
		inst.add_to_group(_ROOM_GROUPS[room_index])

func _process(_delta: float) -> void:
	# Cheap polling: a room is "clear" once no live enemies remain in
	# its group. Group membership is set at spawn and never removed,
	# but queue_free drops them out automatically. Three rooms, polled
	# at frame rate, is well below the noise floor.
	_check_room(0, ^"Gate1")
	_check_room(1, ^"Gate2")
	# Room 3 has no gate to open — that's the boss room.

func _check_room(room_index: int, gate_path: NodePath) -> void:
	var gate := get_node_or_null(gate_path) as Gate
	if gate == null or gate.is_unlocked():
		return
	if _room_alive_count(room_index) == 0:
		gate.unlock()

func _room_alive_count(room_index: int) -> int:
	var group := _ROOM_GROUPS[room_index]
	var count := 0
	for n in get_tree().get_nodes_in_group(group):
		var e := n as Enemy
		if e == null or not is_instance_valid(e):
			continue
		if e.current_stats != null and e.current_stats.is_dead():
			continue
		count += 1
	return count

## Verifier hook: stage8_verify reads these to confirm the scene's
## structural contract (3 rooms × spawn anchors, 2 gates, return portal).
func get_room_count() -> int:
	return _ROOM_GROUPS.size()

func gate_paths() -> Array:
	return [^"Gate1", ^"Gate2"]
