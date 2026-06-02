extends Node
## Tracks quest state for the active save. Quest definitions live in
## QuestData resources under data/quests/; state is a simple enum
## per quest id that the QuestPanel UI and NPCs read. SaveSystem
## snapshots `_states` so quests persist across save/load.

enum State {
	NOT_OFFERED,  ## NPC hasn't shown the offer yet
	OFFERED,      ## offered but not accepted
	ACCEPTED,     ## active — player working on it
	COMPLETED,    ## objective met (player has the required item)
	TURNED_IN,    ## reward delivered, quest closed
}

signal quest_state_changed(quest_id: StringName, new_state: int)

const QUESTS_DIR: String = "res://data/quests/"

var _defs: Dictionary = {}     # StringName -> QuestData
var _states: Dictionary = {}   # StringName -> int (State)

func _ready() -> void:
	_load_defs()

func _load_defs() -> void:
	if not DirAccess.dir_exists_absolute(QUESTS_DIR):
		return
	var dir := DirAccess.open(QUESTS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(QUESTS_DIR + file_name)
			if res is QuestData:
				_defs[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()

func get_quest(id: StringName) -> QuestData:
	return _defs.get(id, null)

func get_state(id: StringName) -> int:
	return int(_states.get(id, State.NOT_OFFERED))

func set_state(id: StringName, new_state: int) -> void:
	if get_state(id) == new_state:
		return
	_states[id] = new_state
	quest_state_changed.emit(id, new_state)

## Mark a quest as offered (first time the NPC opens dialog).
func offer(id: StringName) -> void:
	if get_state(id) == State.NOT_OFFERED:
		set_state(id, State.OFFERED)

func accept(id: StringName) -> void:
	if get_state(id) in [State.NOT_OFFERED, State.OFFERED]:
		set_state(id, State.ACCEPTED)

## Re-evaluate completion against the player's inventory. Called by
## the QuestPanel before deciding whether to show "Turn In".
func evaluate(id: StringName, inv: Inventory) -> void:
	if inv == null:
		return
	var q: QuestData = get_quest(id)
	if q == null or q.required_item_id == &"":
		return
	var st := get_state(id)
	if st != State.ACCEPTED and st != State.COMPLETED:
		return
	var have := 0
	for item_id in inv.backpack:
		if item_id == q.required_item_id:
			have += 1
	if have >= q.required_count and st == State.ACCEPTED:
		set_state(id, State.COMPLETED)
	elif have < q.required_count and st == State.COMPLETED:
		# Player removed the item after completing — revert.
		set_state(id, State.ACCEPTED)

## Consume the required item, pay the reward, mark turned-in.
## Returns true on success.
func turn_in(id: StringName, inv: Inventory, wallet: Wallet) -> bool:
	if get_state(id) != State.COMPLETED:
		return false
	var q: QuestData = get_quest(id)
	if q == null or inv == null or wallet == null:
		return false
	# Remove required items from backpack.
	var still_needed := q.required_count
	while still_needed > 0:
		if not inv.remove_item(q.required_item_id):
			# Defensive: completion drifted. Re-evaluate.
			evaluate(id, inv)
			return false
		still_needed -= 1
	if q.reward_gold > 0:
		wallet.add_gold(q.reward_gold)
	if q.reward_item_id != &"" and not inv.is_full():
		inv.add_item(q.reward_item_id)
	set_state(id, State.TURNED_IN)
	return true

# ---- save / restore -------------------------------------------------------

func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for id in _states.keys():
		out[String(id)] = int(_states[id])
	return out

func restore(data: Dictionary) -> void:
	_states.clear()
	for k in data.keys():
		_states[StringName(k)] = int(data[k])

func reset() -> void:
	_states.clear()
