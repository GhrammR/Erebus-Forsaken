# Testing — Definition of Done

A feature is not "done" because the code compiles. It is done when each item
below is true. If you cannot tick every box, the feature is in progress.

## Universal checklist (every feature)

- [ ] Runs from the editor without errors or warnings in the output panel.
- [ ] Exercised manually in a playtest with notes captured.
- [ ] No new entries in `push_error` / `push_warning` during normal play.
- [ ] Save → quit → load round-trip preserves the feature's relevant state.
- [ ] The mechanic survives the player dying and respawning.
- [ ] Procedural sprite (or current art) reads correctly at game zoom.

## Combat feature additions

- [ ] Damage numbers shown on screen match `Stats` calculations.
- [ ] Hit registers on every collidable enemy in test zone, none in town.
- [ ] Enemy reaches 0 HP → death animation → loot drop → corpse cleanup.
- [ ] Player reaches 0 HP → death state → respawn at town with penalty TBD.
- [ ] MP cost deducts; cannot cast at 0 MP; clamps never go negative.

## Itemization additions

- [ ] Item drops from at least one enemy in test zone.
- [ ] Item picked up enters inventory.
- [ ] Item equipped updates Stats (verify in debug overlay).
- [ ] Item unequipped reverts Stats exactly to pre-equip values.
- [ ] Item persists across save/load while in inventory and while equipped.
- [ ] Class restriction prevents wrong class from equipping.

## Scene/zone additions

- [ ] Zone loads from at least two transition points.
- [ ] Re-entering the zone does not duplicate enemies or loot.
- [ ] Camera follows player with no clipping at zone edges.
- [ ] Pathfinding (if used) finds a route between any two reachable points.
- [ ] Y-sort order correct: player can stand behind and in front of props.

## Class additions

- [ ] Selectable on character select.
- [ ] Starts at level 1 with documented base stats from class resource.
- [ ] Auto-attack works at correct range (melee vs ranged).
- [ ] Starter skill works, costs MP, has cooldown, hits intended targets.
- [ ] Death and respawn loop completes end-to-end.

## How to run a playtest

See `commands/playtest.md`. Each session ends with at least a 5-minute
play-through of the most recently changed area. Capture friction notes
even if you fix nothing this session.

## Test scenes

A dedicated `test/` directory hosts isolated scenes for combat (one player,
three dummies), loot (forced drops), and stats (debug overlay). These are
not shipped — they are workbenches. Do not let production scenes depend on
them.

## Workbench UI-parity rule

Every workbench (`test/*_workbench.tscn`) MUST instantiate the full
persistent UI suite, not just the system under test. Skill, combat, loot,
and stat workbenches all share the same player and the same input map, so
they must all expose the same surfaces — otherwise a workbench passes its
own narrow test while quietly breaking save/load, inventory, or pause from
the player's perspective.

Required nodes in every workbench scene:

- `PauseMenu` (instance of `scenes/ui/pause_menu.tscn`)
- `InventoryPanel` (instance of `scenes/ui/inventory_panel.tscn`)
- `DebugStatOverlay` (instance of `scenes/ui/debug_stat_overlay.tscn`)
- `HUD` CanvasLayer with at minimum a `Help` label and `DebugInfo` label
- `DamageNumberLayer` Node2D
- `ClickMarker` + `GridGuides` Node2D helpers
- `Background` ColorRect with `mouse_filter = 2` (IGNORE) — see
  failure-modes #14, must not eat click-to-move

Required `_ready()` wiring against `Player.get_input()`:

- `pause_pressed → PauseMenu.toggle`
- `inventory_toggle_pressed → InventoryPanel.toggle`
- `save_pressed → SaveSystem.save_game` (with status feedback)
- `load_pressed → SaveSystem.load_game` (with status feedback,
  re-bind inventory + stats overlay + re-wire skill signals after load —
  the load path re-runs `assign_class` which replaces nodes)
- `click_target_set` / `click_target_cleared → ClickMarker`

The `Help` label should advertise the full keymap including I/F5/F9,
even if the workbench's headline feature doesn't use them. A user testing
skills should still be able to open their inventory.

Why this rule exists: the skills workbench shipped without an
`InventoryPanel` instance, so pressing `I` did nothing. The bug was
invisible to the skill-specific verifier — workbench tests verify the
system under test, not the cross-cutting UI. The rule is the only place
this gets caught.
