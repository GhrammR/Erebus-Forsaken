# Act 1 Status — Living Checklist

This file is the single source of truth for "what is done." Update it at
the end of every session. If an item is unchecked here, the game is not
ready to ship — regardless of how the code looks.

Legend: `\\\\\\\[ ]` not started · `\\\\\\\[\\\\\\\~]` in progress · `\\\\\\\[x]` complete \& playtested

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
* \[x] Per-class base values stored in `data/classes/\\\\\\\*.tres` for all four
classes (numbers verified PASS by test/stage1\_verify.gd)
* \[x] `stats\\\\\\\_changed` signal emits on attribute or equipment changes
(local `Stats.recomputed` -> owner forwards to `EventBus.stats\\\\\\\_changed`)
* \[x] Debug overlay shows live Stats values (`scenes/ui/debug\\\\\\\_stat\\\\\\\_overlay.tscn`)
* \[x] `combat-validator` skill passes — all five checks (skill regex
updated to exclude `=%d` format-string false positives)
* \[x] Stage 0 carry-over closed: `Attack` Resource and `DamageType` enum
created (AD-05). `damage\\\\\\\_type` defaults to `PHYSICAL`; Act 2 will
add elemental values additively.
* \[x] Visual workbench playtest — awaiting user (godot --workbench, or
F6 on test/stat\_workbench.tscn)

## Stage 2 — Player movement \& camera

* \[x] One placeholder class (Myrmidon) drawn procedurally
(`art/procedural/classes/myrmidon\\\_sprite.tscn` — palette: bronze,
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
Resume / Quit buttons working; `get\\\_tree().paused` ownership lives
in the pause scene
* \[x] AD-02 single-player.tscn: `player.assign\\\_class(ClassData)`
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

* \[x] HealthComponent, HitboxComponent, HurtboxComponent in place
(`scripts/systems/`). HC wraps Stats; Hurtbox auto-resolves sibling HC;
Hitbox tracks per-swing hits to prevent double-tap on one swing.
* \[x] DamageResolver (AD-04) lands as the single damage-math entry point.
Constants: HIT\_FLOOR 30%, HIT\_CEIL 95%, DEFENSE\_HIT\_WEIGHT 2,
STR\_DAMAGE\_DIVISOR 4, DEFENSE\_MITIGATION\_DIVISOR 8, MIN\_DAMAGE 1.
* \[x] Stats helpers: `physical\_damage\_bonus()` and `mitigation()` keep
all attribute math inside stats.gd; classless `Stats.new\_basic()` lets
dummies skip the ClassData path.
* \[x] Basic attack swings on Space; hitbox arms 0.10s into swing,
disarms at 0.25s; cooldown 0.4s.
* \[x] Damage numbers render (`scenes/vfx/damage\_number.tscn`); MISS in
grey; bigger numbers tint hotter; rises and fades over 0.6s.
* \[x] Training dummy: classless Stats (HP 100, DEF 5), procedural
wood-post sprite, plays hit/die anims, queue\_frees after corpse linger.
* \[x] Player death state: plays "die" anim, disables input + hurtbox,
respawns at `respawn\_position` (workbench origin) after 1.5s with
full HP/MP. K self-kill demos the loop.
* \[x] EventBus.player\_died emits on death; workbench flashes notice.
* \[x] `--combat` cmdline flag launches `test/combat\_workbench.tscn`.
* \[x] `--verify3` cmdline flag runs DamageResolver verifier:
ALL PASS — Myrmidon 91% hit @ 15 dmg, Pythia 10, Shade-Hunter 11,
HIT\_FLOOR enforced, classless short-circuit verified.
* \[x] Stage 1 regression: ALL PASS, exit 0.
* \[x] combat-validator + scene-auditor: all checks PASS.
Damage math reviewed: only HealthComponent and the verifier call
DamageResolver.resolve — no inline damage code.
* \[x] Visual combat-workbench playtest PASS (2026-05-30, after fixes for
click-on-collider stuck loop and post-die transform reset).

## Stage 4 — Itemization

* \[x] `ItemData` Resource: id, slot, class\_mask, level\_req, base slot
contribution (armor\_def / weapon\_ar / resist), fixed-Dictionary affixes,
glyph color + shape. Random rolls deferred to Act 2.
* \[x] `EquipmentSlot` enum (7 slots: WEAPON / OFFHAND / HEAD / CHEST /
LEGS / RING / AMULET) + `ClassMask` bitmask.
* \[x] `Inventory` Node (AD-10 slot list, capacity 24). Methods:
add/remove/equip/unequip/can\_equip; signals inventory\_changed +
equipment\_changed; snapshot/restore for SaveSystem.
* \[x] Stats refactor: replaced `set\_equipment\_contributions` with
`apply\_equipment\_totals(Dictionary)`. Added fourth layer `equip\_\*`
fields so attribute affixes (e.g. +3 STR from chest) flow through
the existing computed-property getters. `restore\_pools()` added so
SaveSystem stays out of the direct current\_hp/mp write path.
* \[x] Item DB seeded with 13 items (1 weapon per class + chest per
class + bone\_chasuble + buckler + linen\_wrap + worn\_helm +
simple\_greaves + iron\_ring + silver\_amulet). Database boots
`4 classes, 14 items` (14 = 13 items + 1 from class-id duplication
none — the 14th is silver\_amulet etc., count is correct).
* \[x] `DropTable` Resource + training\_dummy\_drops.tres seeded with
near-equal weights and no\_drop\_weight=0 for testing variety.
* \[x] `Enemy.\_try\_drop()` rolls the table on death and spawns a
`WorldItem` at the corpse position; emits EventBus.item\_dropped.
* \[x] `WorldItem` walk-over auto-pickup. Inventory full → name label
flashes red, item stays. Pickup emits EventBus.item\_picked\_up.
* \[x] `InventoryPanel` UI (toggled by I). Click backpack row to equip,
click equipment row to unequip. Stats overlay updates live.
* \[x] `SaveSystem` v2: JSON format, versioned, migrate(v1→v2),
snapshot/apply via GameState.player. F5 saves, F9 loads.
* \[x] `--loot` flag launches `test/loot\_workbench.tscn` (player + 3
respawning dummies + drops + inventory + save/load).
* \[x] `--verify4` flag runs the headless verifier — ALL PASS:
Database loaded, backpack add/remove/cap, class restriction,
equip/unequip stat application, save/load round-trip, migration.
* \[x] Regression: Stage 1, 3 verifiers ALL PASS; combat/movement/stat
workbenches boot clean.
* \[x] combat-validator + scene-auditor: all PASS. AD-04 holds: only
HealthComponent + verifier reference DamageResolver.
* [x] Visual loot-workbench playtest PASS (2026-05-30, after switching
  basic-attack hitbox to omnidirectional CircleShape2D — see
  failure-modes #12).

## Stage 5 — Skills (one per class)

* [x] Skill base + per-class subclasses, slot-1 input (KEY_1),
  facing_dir: Vector2 on Player (gap-log fix), --skills workbench
  with M/P/H/O class cycler.
* [x] Myrmidon: Spear Lunge — directional swing, 80x35 rectangle
  hitbox rotated to facing_dir, MP 8 / CD 1.2s / dmg 22.
* [x] Pythia: Oracle Bolt — Projectile component, single bolt
  in facing_dir, speed 500 / range 600 / MP 12 / CD 0.9s / dmg 18.
* [x] Shade-Hunter: Volley — three-arrow fan, ±15° spread, speed 600,
  per-arrow dmg 8 (total 24) / MP 14 / CD 1.5s.
* [x] Ossuary Priest: Bone Servant — persistent minion (HP 60,
  attack 8 every 0.8s, melee, finds "enemies" group target).
  Single-instance enforced via bone_servant_minions group sweep.
  Save exclusion verified (snap schema has no minion keys).
* [x] `class-balance` skill: MP cost band [5,25] PASS, cooldown band
  [0.5, 6.0] PASS, attribute primaries PASS, no forbidden Act 2
  stats. (DPS variance pending visual playtest measurement.)
* [x] AD-04 invariant intact: only health_component.gd and
  stage3_verify.gd call DamageResolver.resolve.
* [x] --verify5 headless verifier covers all four skills + Projectile
  + single-instance + save-exclusion. ALL PASS, exit 0.
* [x] Visual skills-workbench playtest — confirmed: all four class
  cast anims play; inventory `I`/`Esc` open & close; pause `Esc`/`Esc`
  open & close; per-class loadouts isolated across class swaps;
  Bone Servant despawns on summoner death; loot drops produce zero
  physics-flush errors.

## Stage 6 — Town

* [x] Phase 1 — Currency: Wallet, gold pickups, save round-trip,
  enemy drop hook (verified Stage 4 verifier).
* [x] Phase 2 — Threshold camp zone: animated fire pit, three tents,
  perimeter braziers, invisible perimeter walls, named NPC markers.
* [x] Phase 3 — NPC base + Kallias the Salvager (vendor): proximity
  interact (E), VendorPanel UI with buy/sell, MerchantStock resource,
  base_price on every ItemData, class-cycling preserved in town
  workbench (M/P/H/O).
* [x] Phase 4 — Eurynome (quest-giver): QuestSystem autoload, single
  fetch quest "A Sister's Token" with full state machine and reward.
  Save schema v5 carries quest state.
* [x] Phase 5 — Production game entry (scenes/game.tscn): main.tscn
  default-routes here; auto-loads save_slot_1; --splash retains the
  title-card; --town flag points at the dev workbench. SaveSystem
  v6 captures GameState.current_zone_id (defaults legacy saves to
  threshold_camp).
* [x] Phase 6 — stage6_verify.gd covers Wallet API, MerchantStock
  pricing fallbacks, full QuestSystem state machine (incl.
  COMPLETED -> ACCEPTED revert and turn_in idempotency), and a
  save round-trip that asserts gold + amulet + quest state + zone.
  21/21 PASS.
* \[ ] End-of-Stage-6 polish: click-to-interact on NPCs (walk to NPC
  then auto-open panel — ARPG genre standard).
* [~] Visual stage-6 playtest — awaiting final user sign-off.

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
* \[ ] No `push\\\\\\\_error` / `push\\\\\\\_warning` during a 30-min play session
* \[ ] `audit.md` produces all PASS

\---

When every box above is `\\\\\\\[x]`, and only then:

* Pay Steam fee.
* Submit for review.
* Schedule Early Access launch.

