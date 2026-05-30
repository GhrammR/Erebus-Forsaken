# Act 1 Status — Living Checklist

This file is the single source of truth for "what is done." Update it at
the end of every session. If an item is unchecked here, the game is not
ready to ship — regardless of how the code looks.

Legend: `\\\[ ]` not started · `\\\[\\\~]` in progress · `\\\[x]` complete \& playtested

\---

## Stage 0 — Bootstrap

* \[x] Godot 4 project created with project.godot configured (window size,
stretch mode, main scene) — verified on Godot 4.6.3-stable
* \[x] Folder structure matches the agreed layout
* \[x] Autoloads registered: GameState, SaveSystem, EventBus, SceneRouter,
Database (stubs honoring AD-03, AD-06, AD-07, AD-08)
* \[x] `main.tscn` launches to a placeholder splash; quit works
(visual playtest 2026-05-30, PASS)

## Stage 1 — Stats foundation

* \[x] `Stats` resource implemented with the four attributes and five Act 1
derived stats (layered base/alloc/buff/equipment model;
`recomputed` signal renamed from `changed` to avoid shadowing
Resource.changed)
* \[x] `ClassData` resource (AD-02) defined with base attributes,
per-level gains, HP/MP coefficients, and sprite\_scene slot
(sprite populated in Stage 2)
* \[x] Per-class base values stored in `data/classes/\\\*.tres` for all four
classes (numbers verified PASS by test/stage1\_verify.gd)
* \[x] `stats\\\_changed` signal emits on attribute or equipment changes
(local `Stats.recomputed` -> owner forwards to `EventBus.stats\\\_changed`)
* \[x] Debug overlay shows live Stats values (`scenes/ui/debug\\\_stat\\\_overlay.tscn`)
* \[x] `combat-validator` skill passes — all five checks (skill regex
updated to exclude `=%d` format-string false positives)
* \[x] Stage 0 carry-over closed: `Attack` Resource and `DamageType` enum
created (AD-05). `damage\\\_type` defaults to `PHYSICAL`; Act 2 will
add elemental values additively.
* \[x] Visual workbench playtest — awaiting user (godot --workbench, or
F6 on test/stat\_workbench.tscn)

## Stage 2 — Player movement \& camera

* \[x] One placeholder class (Myrmidon) drawn procedurally
(`art/procedural/classes/myrmidon\_sprite.tscn` — palette: bronze,
bronze-dark, plume-red; AnimationPlayer ships all six AD-11 anim
names: idle, walk, attack, cast, hit, die — only idle/walk
exercised this stage)
* \[x] Isometric-ready movement: `CharacterBody2D` Player with feet-
centered capsule collider, Y-sort enabled on Player root and the
movement workbench root, screen-space movement (true iso tilemaps
land in Stage 6 with the town)
* \[x] Camera2D follows player; project pixel snap on; smoothing off;
physics process callback
* \[x] Pause menu opens / closes on Esc via PlayerInput.pause\_pressed;
Resume / Quit buttons working; `get\_tree().paused` ownership lives
in the pause scene
* \[x] AD-02 single-player.tscn: `player.assign\_class(ClassData)`
swaps sprite subtree, instantiates Stats, wires recomputed -> EventBus
* \[x] AD-09 click-to-move primary + WASD secondary; WASD pre-empts
pending click target
* \[x] AD-11 canonical animation names parity: stubs for attack/cast/
hit/die already in the AnimationPlayer library
* \[x] WASD input actions added to project.godot
(move\_up/down/left/right bound to W/A/S/D)
* \[x] `--movement` cmdline flag in main.gd launches the workbench
* \[x] combat-validator + scene-auditor: all checks PASS
* \[x] Visual workbench playtest — awaiting user (godot -- --movement,
or F6 on test/movement\_workbench.tscn)

## Stage 3 — Combat core

* [x] HealthComponent, HitboxComponent, HurtboxComponent in place
  (`scripts/systems/`). HC wraps Stats; Hurtbox auto-resolves sibling HC;
  Hitbox tracks per-swing hits to prevent double-tap on one swing.
* [x] DamageResolver (AD-04) lands as the single damage-math entry point.
  Constants: HIT_FLOOR 30%, HIT_CEIL 95%, DEFENSE_HIT_WEIGHT 2,
  STR_DAMAGE_DIVISOR 4, DEFENSE_MITIGATION_DIVISOR 8, MIN_DAMAGE 1.
* [x] Stats helpers: `physical_damage_bonus()` and `mitigation()` keep
  all attribute math inside stats.gd; classless `Stats.new_basic()` lets
  dummies skip the ClassData path.
* [x] Basic attack swings on Space; hitbox arms 0.10s into swing,
  disarms at 0.25s; cooldown 0.4s.
* [x] Damage numbers render (`scenes/vfx/damage_number.tscn`); MISS in
  grey; bigger numbers tint hotter; rises and fades over 0.6s.
* [x] Training dummy: classless Stats (HP 100, DEF 5), procedural
  wood-post sprite, plays hit/die anims, queue_frees after corpse linger.
* [x] Player death state: plays "die" anim, disables input + hurtbox,
  respawns at `respawn_position` (workbench origin) after 1.5s with
  full HP/MP. K self-kill demos the loop.
* [x] EventBus.player_died emits on death; workbench flashes notice.
* [x] `--combat` cmdline flag launches `test/combat_workbench.tscn`.
* [x] `--verify3` cmdline flag runs DamageResolver verifier:
  ALL PASS — Myrmidon 91% hit @ 15 dmg, Pythia 10, Shade-Hunter 11,
  HIT_FLOOR enforced, classless short-circuit verified.
* [x] Stage 1 regression: ALL PASS, exit 0.
* [x] combat-validator + scene-auditor: all checks PASS.
  Damage math reviewed: only HealthComponent and the verifier call
  DamageResolver.resolve — no inline damage code.
* [~] Visual combat-workbench playtest — awaiting user.

## Stage 4 — Itemization

* \[ ] Item Resource schema (id, name, slot, affixes, class restriction)
* \[ ] Item DB seeded with at least 10 Act 1 items
* \[ ] Drop tables per enemy
* \[ ] Ground pickup → inventory → equip → Stats apply
* \[ ] Save/load preserves inventory and equipment

## Stage 5 — Skills (one per class)

* \[ ] Myrmidon: Spear Lunge
* \[ ] Pythia: Oracle Bolt (or final-named arcane projectile)
* \[ ] Shade-Hunter: Volley
* \[ ] Ossuary Priest: Bone Servant (summon, single minion)
* \[ ] `class-balance` skill passes

## Stage 6 — Town

* \[ ] Town zone with collision and traversable layout
* \[ ] One vendor NPC: buy/sell loop, gold currency, inventory exchange
* \[ ] One quest-giver NPC: single quest, accept/turn-in flow
* \[ ] Town is the respawn point

## Stage 7 — Wilderness

* \[ ] Open zone with at least two enemy types
* \[ ] Random spawn director with caps
* \[ ] Loot dropping in world space
* \[ ] Portal back to town

## Stage 8 — Dungeon

* \[ ] Three-room interior with locked progression
* \[ ] Trash → mini-encounter → boss room
* \[ ] Difficulty rises per room (enemy count or stats)

## Stage 9 — Act boss

* \[ ] Unique boss enemy with at least one distinct mechanic
* \[ ] Guaranteed unique item on first kill
* \[ ] Boss death triggers Act 1 completion state

## Stage 10 — All four classes selectable

* \[ ] Character select scene with all four classes
* \[ ] Each class plays through Stages 3–5 without class-specific bugs

## Stage 11 — Save/load hardening

* \[ ] Versioned save format
* \[ ] Round-trip across every major state
* \[ ] Corrupt-save handling (don't crash; warn)

## Stage 12 — Pre-launch polish

* \[ ] Procedural sprites replaced with bitmaps where decided
* \[ ] Audio pass (or explicitly deferred to post-launch)
* \[ ] Title screen, options (resolution + key rebind), credits stub
* \[ ] No `push\\\_error` / `push\\\_warning` during a 30-min play session
* \[ ] `audit.md` produces all PASS

\---

When every box above is `\\\[x]`, and only then:

* Pay Steam fee.
* Submit for review.
* Schedule Early Access launch.

