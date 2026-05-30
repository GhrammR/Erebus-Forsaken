# Act 1 Status — Living Checklist

This file is the single source of truth for "what is done." Update it at
the end of every session. If an item is unchecked here, the game is not
ready to ship — regardless of how the code looks.

Legend: `[ ]` not started · `[~]` in progress · `[x]` complete & playtested

---

## Stage 0 — Bootstrap
- [x] Godot 4 project created with project.godot configured (window size,
      stretch mode, main scene) — verified on Godot 4.6.3-stable
- [x] Folder structure matches the agreed layout
- [x] Autoloads registered: GameState, SaveSystem, EventBus, SceneRouter,
      Database (stubs honoring AD-03, AD-06, AD-07, AD-08)
- [x] `main.tscn` launches to a placeholder splash; quit works
      (visual playtest 2026-05-30, PASS)

## Stage 1 — Stats foundation
- [x] `Stats` resource implemented with the four attributes and five Act 1
      derived stats (layered base/alloc/buff/equipment model;
      `recomputed` signal renamed from `changed` to avoid shadowing
      Resource.changed)
- [x] `ClassData` resource (AD-02) defined with base attributes,
      per-level gains, HP/MP coefficients, and sprite_scene slot
      (sprite populated in Stage 2)
- [x] Per-class base values stored in `data/classes/*.tres` for all four
      classes (numbers verified PASS by test/stage1_verify.gd)
- [x] `stats_changed` signal emits on attribute or equipment changes
      (local `Stats.recomputed` -> owner forwards to `EventBus.stats_changed`)
- [x] Debug overlay shows live Stats values (`scenes/ui/debug_stat_overlay.tscn`)
- [x] `combat-validator` skill passes — all five checks (skill regex
      updated to exclude `=%d` format-string false positives)
- [x] Stage 0 carry-over closed: `Attack` Resource and `DamageType` enum
      created (AD-05). `damage_type` defaults to `PHYSICAL`; Act 2 will
      add elemental values additively.
- [~] Visual workbench playtest — awaiting user (godot --workbench, or
      F6 on test/stat_workbench.tscn)

## Stage 2 — Player movement & camera
- [ ] One placeholder class (Myrmidon) drawn procedurally
- [ ] Isometric movement working with Y-sort and feet pivots
- [ ] Camera2D follows player with integer snap
- [ ] Pause menu opens/closes

## Stage 3 — Combat core
- [ ] HealthComponent, HitboxComponent, HurtboxComponent in place
- [ ] Basic attack swings, hits dummies, deals Stats-derived damage
- [ ] Damage numbers render
- [ ] Death state on player + enemy
- [ ] Respawn loop closes (player → town)

## Stage 4 — Itemization
- [ ] Item Resource schema (id, name, slot, affixes, class restriction)
- [ ] Item DB seeded with at least 10 Act 1 items
- [ ] Drop tables per enemy
- [ ] Ground pickup → inventory → equip → Stats apply
- [ ] Save/load preserves inventory and equipment

## Stage 5 — Skills (one per class)
- [ ] Myrmidon: Spear Lunge
- [ ] Pythia: Oracle Bolt (or final-named arcane projectile)
- [ ] Shade-Hunter: Volley
- [ ] Ossuary Priest: Bone Servant (summon, single minion)
- [ ] `class-balance` skill passes

## Stage 6 — Town
- [ ] Town zone with collision and traversable layout
- [ ] One vendor NPC: buy/sell loop, gold currency, inventory exchange
- [ ] One quest-giver NPC: single quest, accept/turn-in flow
- [ ] Town is the respawn point

## Stage 7 — Wilderness
- [ ] Open zone with at least two enemy types
- [ ] Random spawn director with caps
- [ ] Loot dropping in world space
- [ ] Portal back to town

## Stage 8 — Dungeon
- [ ] Three-room interior with locked progression
- [ ] Trash → mini-encounter → boss room
- [ ] Difficulty rises per room (enemy count or stats)

## Stage 9 — Act boss
- [ ] Unique boss enemy with at least one distinct mechanic
- [ ] Guaranteed unique item on first kill
- [ ] Boss death triggers Act 1 completion state

## Stage 10 — All four classes selectable
- [ ] Character select scene with all four classes
- [ ] Each class plays through Stages 3–5 without class-specific bugs

## Stage 11 — Save/load hardening
- [ ] Versioned save format
- [ ] Round-trip across every major state
- [ ] Corrupt-save handling (don't crash; warn)

## Stage 12 — Pre-launch polish
- [ ] Procedural sprites replaced with bitmaps where decided
- [ ] Audio pass (or explicitly deferred to post-launch)
- [ ] Title screen, options (resolution + key rebind), credits stub
- [ ] No `push_error` / `push_warning` during a 30-min play session
- [ ] `audit.md` produces all PASS

---

When every box above is `[x]`, and only then:
- Pay Steam fee.
- Submit for review.
- Schedule Early Access launch.
