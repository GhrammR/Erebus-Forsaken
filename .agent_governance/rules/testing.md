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

## Dev-debug instrumentation (every new system)

A system that ships without instrumentation is a system whose bugs will be
debugged with `print` statements added under time pressure. Stage 9.7's
corner-teleport hunt took multiple sessions because the instrumentation
that ultimately found it (DebugLog + physics-tick watcher + per-site
`[SITE:]` markers) didn't exist until the bug forced it. The point of
this rule is to front-load that work so the *next* bug is cheap to find.

Every new system MUST ship with all four of the following before the
stage that introduced it can be closed:

1. **At least one DebugLog flag**, registered in
   `scripts/systems/debug_log.gd`'s known-categories list, written at
   every state transition the system can fail at — spawn, destruction,
   damage entry, save snapshot, save restore, cooldown start/expire,
   signal emit/receive, etc. Cost: one line. Payoff: the next time
   something goes wrong you turn on the flag and read the trace instead
   of guessing.
2. **A workbench affordance** when the system has player-facing
   behaviour. If a `test/*_workbench.tscn` exists for the system's
   area, the workbench gets a key, button, or CLI shortcut that
   force-triggers the system without requiring full game progression.
   Example: a workbench should let the user spawn a Hearth Ember into
   inventory at will, not require them to play to the Act boss every
   time they want to test the channel path.
3. **A headless verifier** — either `--verifyN` for the introducing
   stage or a clearly-labeled extension to a prior verifier. The
   verifier asserts the system's *invariants*, not its happy path:
   resource shape, save round-trip integrity, signal whitelist
   compliance (AD-08), cooldown clamps, illegal-state rejection. CI
   runs verifiers; manual playtest does not.
4. **A failure-mode entry** in `rules/failure-modes.md` for every
   non-obvious bug discovered during the stage. Format: symptom → root
   cause → prevention pattern → recovery recipe. The prevention pattern
   is what stops a similar bug in the next system; without it the entry
   is half-finished.

The four items are not negotiable per-feature — every new system goes
through them. If one genuinely does not apply (e.g., a pure data-only
class with no runtime state has no DebugLog flag), say so explicitly
in the stage closure rather than silently skipping it.

## Parse-time smoke test (every commit)

Before staging any commit that touches `.gd` files, run the headless
parse-check:

```bash
godot --headless --path . --quit-after 1 -- --splash
```

This boots the project just far enough to surface parse errors and
autoload-init crashes, then exits. It is *not* a verifier — it is a
30-second guard against the failure mode where a typo in a script the
session never exercised lands in a commit and the next session opens
to a broken project. Stage 9.7 documented this as failure mode #24
("var placement"); the smoke test is its institutional shield.

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

Every workbench (`test/*_workbench.tscn`) that contains a `Player`
instance MUST instantiate the full persistent UI suite, not just the
system under test. They all share the same player and the same input
map, so they must all expose the same surfaces — otherwise a workbench
passes its own narrow test while quietly breaking save/load, inventory,
or pause from the player's perspective.

Workbenches without a Player (e.g., `stat_workbench` which exercises
Stats directly) are exempt from the UI-parity rule but should still use
non-conflicting keybinds.

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

## Modal UI — Esc-to-close contract

Every modal UI (inventory, future stash/quest log/character sheet/etc.)
MUST close itself on Esc without opening the pause menu underneath.

The mechanism: the modal overrides `_input(event)` (NOT
`_unhandled_input` — priority matters) and, while `visible`, intercepts
`KEY_ESCAPE`, calls its own close path, then calls
`get_viewport().set_input_as_handled()`. This consumes the event before
`PlayerInput._unhandled_input` runs, so `pause_pressed` never fires.

The modal's open-key (e.g., `I` for inventory) continues to be routed
via `PlayerInput`'s signal to the panel's `toggle()` — handling open
and close on the same key is symmetric and free. Only Esc needs the
priority interception.

Reference implementation: `scenes/ui/inventory_panel.gd::_input`.
