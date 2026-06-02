class_name Kallias extends Npc
## Kallias the Salvager — older man who pulls usable gear from
## bodies the dark sends back. Vendor NPC; opens VendorPanel on E.

@export var stock: MerchantStock

signal vendor_open_requested(npc: Kallias)

func _ready() -> void:
	display_name = "Kallias the Salvager"
	super._ready()

func interact() -> void:
	vendor_open_requested.emit(self)
	interacted.emit(self)
