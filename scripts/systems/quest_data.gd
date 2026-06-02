class_name QuestData extends Resource
## A single quest's static definition. State (Offered/Accepted/etc.)
## lives in QuestSystem; this resource is data only.

@export var id: StringName
@export var title: String = ""
@export_multiline var offer_text: String = ""
@export_multiline var in_progress_text: String = ""
@export_multiline var turn_in_text: String = ""

@export_group("Objective (Stage 6 simple fetch)")
@export var required_item_id: StringName = &""
@export var required_count: int = 1

@export_group("Reward")
@export var reward_gold: int = 0
@export var reward_item_id: StringName = &""
