class_name Eurynome extends Npc
## Eurynome — stranded primordial sea-spirit turned mortal-seeming.
## Quest-giver for "A Sister's Token". Single quest, single turn-in.

signal quest_open_requested(npc: Eurynome)

@export var quest_id: StringName = &"eurynome_relic"

func _ready() -> void:
	display_name = "Eurynome"
	super._ready()

func interact() -> void:
	# Offer the quest the first time we talk; QuestSystem ignores
	# re-offers after the player has already moved past NOT_OFFERED.
	QuestSystem.offer(quest_id)
	quest_open_requested.emit(self)
	interacted.emit(self)
