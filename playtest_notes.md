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

## 2026-06-01 — stage 5

- [done] --verify5 ALL PASS through six phases:
  - All four skills construct with class-balance bands satisfied.
  - SpearLunge spawns directional hitbox at facing_dir * 40, rotated
    to facing_dir.angle(), with the correct base_damage and owner_body.
  - Cooldown blocks immediate re-cast.
  - MP cost deducted via Stats.spend_mp (25 -> 17 for Myrmidon).
  - OracleBolt: projectile speed=500, max_distance=600.
  - Volley: exactly 3 projectiles, unit-vector directions, total
    angular spread = 2 * FAN_SPREAD_RAD (~0.52 rad).
  - BoneServant first cast spawns 1 minion in group; re-cast keeps
    exactly 1 (single-instance via group sweep + queue_free).
  - Save schema confirmed to exclude minion-related keys.
- [done] Regression: --verify, --verify3, --verify4 ALL PASS.
- [done] All workbenches boot clean: --workbench, --movement,
  --combat, --loot, --skills.
- [done] AD-04 invariant: DamageResolver only called from
  health_component.gd and stage3_verify.gd.
- [pending] Visual playtest of --skills workbench:
  - Press M/P/H/O to cycle classes; confirm skill HUD updates with
    correct name + MP + CD + base damage.
  - Press 1 to fire skill in current facing direction.
    Myrmidon: rectangle hitbox lands ahead of player; dummy takes
    ~22 damage on hit; second press within 1.2s shows
    "Skill failed: cooldown".
    Pythia: violet bolt travels forward; despawns on first dummy or
    after ~600px; ~18 damage per hit.
    Shade-Hunter: three pale arrows fan out; each despawns on its
    own first hit; ~8 damage per arrow.
    Ossuary Priest: skeletal minion appears in facing direction;
    walks to nearest dummy; melee attacks at ~0.8s intervals; second
    cast frees the old minion and spawns a fresh one.
  - F5 save with minion alive; F9 load; minion should be absent
    after load (save exclusion).
  - Esc opens pause menu; pause-during-skill doesn't crash anything.

## 2026-05-30 — stage 4

- [done] --verify4 (Inventory + Stats apply + SaveSystem round-trip):
  ALL PASS. Database loads 14 items. Backpack add/remove/cap correct.
  Class restriction rejects silken_robe for Myrmidon. equip apply path:
  AR 105->140 (matches expected — weapon +30 + DEX-bonus from amulet
  +5). Save/load preserves level=3, str=42, position, equipped count.
  Migration v1->v2 adds inventory + bumps version.
- [done] --verify (Stage 1 regression): ALL PASS after Stats refactor.
- [done] --verify3 (Stage 3 regression): ALL PASS after switching the
  classless-Stats test to apply_equipment_totals.
- [done] --loot, --combat, --movement, --workbench: clean boot, no
  warnings.
- [done] combat-validator + scene-auditor: all PASS.
- [bug-during-impl] Stats refactor removed set_equipment_contributions,
  breaking stage1 + stage3 verifiers. Updated both to apply_equipment_totals.
- [bug-during-impl] Stage 4 verifier's AR expectation didn't account for
  silver_amulet's +1 DEX (which adds +5 AR via the dex*5 formula).
  Fixed the expected value.
- [bug-fixed] Basic-attack hitbox was a 28x30 rectangle parented under
  SpriteAnchor at (24, -22). The SpriteAnchor.scale.x flip mirrored it
  L/R, but nothing covered up/down — dummies directly above or below
  the player took no damage. Switched the hitbox to a CircleShape2D
  (radius 40) centered at (0, -22) so the basic attack is
  omnidirectional cleave (Diablo Whirlwind / Hammer style). Stage 5's
  Spear Lunge will be properly directional with a facing_dir vector.
  Recorded as failure-modes.md #12.
- [known/deferred] Sprite only flips L/R — does not face up/down.
  Procedural Myrmidon ships only two facings; 8-way directional sprites
  arrive with bitmap art in Stage 12. The cleave hitbox above means
  this no longer affects gameplay correctness, only visual feel.
- [done] Visual loot-workbench playtest PASS after hitbox fix.
- [bug-fixed] Click-to-move dead zones, particularly an 80-pixel circle
  around the player. Root cause: Area2D.input_pickable defaults to true
  and silently consumes mouse events inside the area, even with no
  input_event handler. The new 40-radius cleave hitbox + the
  HurtboxComponents + WorldItem.PickupArea all stole clicks. Fix:
  input_pickable=false in HitboxComponent._ready / HurtboxComponent._ready
  / WorldItem._ready. Recorded as failure-modes.md #13; scene-auditor
  check #8 added.

## 2026-06-01 — stage 4 close (dead-zone bug, definitive fix)

- [bug-fixed] Persistent screen-quadrant click dead zones. Several
  sessions of diagnosis (false leads: stretch_mode, panel auto-grow,
  RichTextLabel selection). A tree-walking diagnostic that listed
  every Control with mouse_filter != IGNORE surfaced the actual
  culprits in one pass: (1) main scene's Background ColorRect
  (1280x720, STOP); (2) hidden PauseMenu's Dimmer ColorRect (1280x720,
  STOP, visible=true on the Control despite parent CanvasLayer.visible
  = false); (3) hidden PauseMenu's centered Panel (240x160, STOP).
  Root cause: Godot 4 CanvasLayer.visible=false stops rendering but
  does NOT disable child Control input.
- [fix] (a) main.tscn Background + labels get mouse_filter=2;
  (b) pause_menu CanvasLayer process_mode set to WHEN_PAUSED so it
  processes nothing while the game is unpaused; (c) pause_menu.gd and
  inventory_panel.gd own an _set_input_active helper that recursively
  toggles every child Control between STOP and IGNORE on show/hide;
  (d) stretch_mode changed canvas_items -> viewport so mouse coords
  always normalize to the 1280x720 base.
- [done] Visual movement-workbench playtest PASS — dead zones gone
  across the entire viewport.
- [governance] failure-modes.md #14 recorded; scene-auditor check #9
  added; diagnostic snippet preserved for future hunts.

## 2026-05-30 — stage 3

- [done] --verify3 (DamageResolver verifier): ALL PASS, exit 0. Myrmidon
  91.4% hit rate dealing 15/swing vs DEF=5 dummy. Pythia 10/swing,
  Shade-Hunter 11/swing. HIT_FLOOR=30% enforced for zero-AR attacker.
  Stats helpers and classless short-circuit verified.
- [done] --verify (Stage 1 regression): ALL PASS, exit 0.
- [done] --combat: clean boot, Database 4 classes, no errors, no warnings.
  Player + 3 dummies instantiate, components wire up.
- [done] --movement, --workbench regression: clean.
- [done] combat-validator + scene-auditor: all PASS. AD-04 verified —
  DamageResolver.resolve only called from HealthComponent and the
  verifier.
- [bug-fixed] Click-to-move on a dummy caused the player to orbit/jitter
  forever — collision blocked the player from reaching the click target
  within ARRIVE_THRESHOLD, and move_and_slide tangent-slid them around.
  Fix: stuck detection in PlayerInput (STUCK_FRAMES=20, STUCK_MIN_MOVEMENT=1px).
  Recorded as failure-modes.md #10.
- [bug-fixed] K-kill respawn left the Myrmidon lying on its side with
  semi-transparent modulate. The `die` AnimationPlayer track keyed
  rotation->PI/2 and modulate.a->0.3, and `idle` didn't reset them.
  Fix: Player._respawn() now resets sprite_root.rotation and modulate,
  stops AnimationPlayer, then plays `idle`. Recorded as
  failure-modes.md #11.
- [done] Visual playtest after fixes: PASS on all checklist items —
  click-stuck cleanly drops the target, K-respawn produces an upright
  full-opacity Myrmidon at origin.

## 2026-05-30 — stage 2

- [done] Headless --movement: clean boot, Database 4 classes, no errors,
  no warnings. Sprite scene loads, animations build, no missing
  AnimationPlayer push_warning.
- [done] Headless --workbench (regression): clean.
- [done] Headless --verify (regression): ALL PASS, exit 0.
- [done] combat-validator: all 5 checks PASS.
- [done] scene-auditor: all 5 checks PASS (8 scenes).
- [bug-fixed] Click-to-move appeared broken in the visual playtest. Root
  cause: passive Control nodes (Background ColorRect, HUD Labels, stat
  overlay Panel/Margin/Label) all defaulted to mouse_filter = STOP and
  silently absorbed mouse events before PlayerInput._unhandled_input
  could see them. Fixed by setting mouse_filter = 2 (IGNORE) on every
  passive Control. Recorded as failure-modes.md #9; scene-auditor #7
  now flags it.
- [done] Visual playtest after fix: click-to-move works.
- [pending] Stage 2 close also needs: WASD-cancel, sprite flip, pause
  menu, camera follow confirmed in same session.
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
