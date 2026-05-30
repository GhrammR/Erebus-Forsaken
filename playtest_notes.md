# Playtest Notes

Format per session (see `.agent_governance/commands/playtest.md`):

```
## YYYY-MM-DD — stage <N>
- [bug] description
- [feel] subjective friction
- [idea] parking-lot candidate
- [done] confirmed working: <feature>
```

---

## 2026-05-30 — stage 2

- [done] Headless --movement: clean boot, Database 4 classes, no errors,
  no warnings. Sprite scene loads, animations build, no missing
  AnimationPlayer push_warning.
- [done] Headless --workbench (regression): clean.
- [done] Headless --verify (regression): ALL PASS, exit 0.
- [done] combat-validator: all 5 checks PASS.
- [done] scene-auditor: all 5 checks PASS (8 scenes).
- [pending] Visual playtest: F6 on test/movement_workbench.tscn.
  Verify: Myrmidon sprite renders with bronze body + red plume + spear
  + buckler + shadow; click-to-move drives the unit to the click point
  and stops; gold cross-hair marker visible at the target; WASD moves
  in 4 directions and cancels the click target; sprite flips L/R as
  intent.x crosses zero; camera follows without sub-pixel shimmer;
  Esc opens the pause menu and Resume/Quit work; idle and walk
  animations cycle.

## 2026-05-30 — stage 1

- [done] Headless --verify: ALL PASS. Per-class derived HP/MP/DEF/AR
  match design table. HP order Myr>SH>=OP>Pyt (150,100,80,60). MP order
  Pyt>OP>SH>=Myr (115,82,45,25). Damage clamps to 0 on overkill.
  spend_mp returns false on insufficient MP. Level 1->5 grows HP
  150->182. Equipment-contribution path applies correctly.
- [done] Headless --workbench: boots clean, Database loads 4 classes,
  no parse errors after class_name resolution fixes.
- [bug-fixed] Resource.changed shadowing → renamed signal to `recomputed`.
- [bug-fixed] @export var: Node illegal on Resource → Attack.source is
  plain var (constructed in code, never authored as .tres).
- [bug-fixed] strict typing required explicit bool/Key on Variant-yielding
  expressions in test code.
- [pending] Visual workbench playtest: F6 on test/stat_workbench.tscn,
  exercise 1-4 (class cycle), +/- (level), Q (damage), E (MP spend),
  R (heal). Confirm overlay updates exactly once per batch.

## 2026-05-30 — stage 0

- [done] Godot 4.6.3-stable installed (Linux x86_64, ~/bin/godot,
  symlinked into ~/.local/bin).
- [done] Headless boot: project parses, autoloads instantiate, Database
  prints `0 classes, 0 items, 0 enemies, 0 skills`, no errors.
- [done] Visual playtest PASS: build label + Stage 0 hint visible on
  dark background; Esc quits cleanly.
- Stage 0 closed.
