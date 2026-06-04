class_name EndlessPortal extends Portal
## Stage 9.7 — the boss-room portal into the endless trial. Behaves
## like a normal Portal (E to interact, click-to-interact, prompt) but
## interact() is overridden so the save is captured BEFORE
## EndlessRun.active flips and BEFORE the scene swap. That on-disk
## save IS the rollback anchor; if the write fails we abort entry
## rather than route into an un-revertable run.

func interact() -> void:
	if EndlessRun.active:
		return
	if not SaveSystem.save_game():
		push_warning("EndlessPortal: rollback save failed — entry aborted.")
		return
	var seed: int = randi()
	EndlessRun.begin(seed)
	interacted.emit(self)
	SceneRouter.go_to_zone(&"forsaken_depths", &"DepthsEntry")
