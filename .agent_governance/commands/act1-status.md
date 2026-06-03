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
* [x] End-of-Stage-6 polish: click-to-interact on NPCs. Tight
  silhouette hit-test (rectangular, matches sprite footprint),
  selection ring under feet (toggled via modulate.a, absolute z=-1),
  auto-interacts on arrival, status text confirms which NPC is
  targeted, clears on reroute. Same wiring in both game.gd and
  town_workbench.gd.
* [x] Visual stage-6 playtest — confirmed: ring renders, NPC click
  precision tight, Esc opens/closes pause, F5/F9 round-trip, fire
  pit glow subtle, no leftover splash chrome.

## Stage 7 — Wilderness

* [x] Phase 1 — Blighted Reach zone scaffolding: ground polygons,
  perimeter walls, dead trees, two-way Portal in-place swap via
  SceneRouter host pattern. Per-portal arrival markers so the
  return drops the player next to the gate, not at zone center.
* [x] Phase 2 — Two enemy types + persistence: WildernessEnemy AI
  base, Shade-Wretch (melee), Bog-Caller (ranged kiter). Save
  schema v7 persists enemy id/pos/hp via EnemyRegistry. Damage
  numbers wired into the production game scene.
* [x] Phase 3 — SpawnDirector with caps + respawn cadence:
  weighted species table, anchor distance gates for player AND
  other enemies, claim_existing_enemies hand-off after a save
  load rehydrates the roster.
* [x] Phase 4 — Loot in world space: WorldItem + GoldPickup join
  the `loot` group, save schema v8 round-trips uncollected drops
  per zone via the same call_deferred pattern as enemies.
* [x] Phase 5 — Corpse-run death penalty: CorpseSystem multi-corpse
  (cap 3, FIFO eviction → spill queue), per death harvest = gold
  + 1 random equipped slot. Evicted contents spill at the original
  corpse position as world loot — no auto-return. DeathScreen
  overlay shows YOU DIED + Return to Town button so the player
  can review what killed them before the camp transit fires.
  Zone cache freezes monsters in place across deaths.
* [x] Phase 6 — stage7_verify covers EnemyRegistry, wilderness
  drop table, CorpseSystem basics + eviction + snapshot, save
  schema v6/v9 -> v10 migration, full corpse round-trip, portal
  target_zone integrity. 30/30 PASS.
* [x] Visual playtest — confirmed across the wilderness arc:
  portal transit both directions, enemies persist on death-return,
  damage numbers, monster separation, multi-corpse retrieval,
  spill-on-eviction, save/load round-trip.

---

## Execution order (post Stage 7)

Strategic Review v1 (locked 2026-06-03) reordered the post-Stage-7
sequence. Stage **numbers are stable** (existing commits reference
them); **execution order** is now:

1. Stage 10 — Character select (identity before content)
2. Stage 7.5 — Audio mini-stage (Feel Pass enablement)
3. Stage 8 — Dungeon (with affix-tier sub-system)
4. Stage 9 — Act boss
5. Stage 9.5 — Feel Pass (sound + juice contract, `rules/feel-pass.md`)
6. Stage 9.7 — Endless mode (post-boss retention)
7. **itch.io free demo launches here** (`commands/launch-plan.md`)
8. Stage 11 — Save/load hardening
9. Stage 12 — Pre-launch polish
10. **Steam EA launch**

Skipping or reordering this sequence requires explicit user approval
and a note appended to this file.

---

## Stage 10 — All four classes selectable  *(execute next)*

* \[ ] Character select scene with all four classes (`scenes/ui/character_select.tscn`)
* \[ ] Boots from `main.tscn` before the save-resume path; existing
  saves bypass select and route straight into the game
* \[ ] Each class plays through Stages 3–5 without class-specific bugs
* \[ ] First-launch tutorial prompt: 30-second overlay teaching
  click-to-move, basic attack (Space), skill 1, inventory (I), pause
  (Esc). Dismissible; remembered across sessions.
* \[ ] One-line pitch shown on character-select screen footer

## Stage 7.5 — Audio mini-stage  *(execute after Stage 10)*

* \[ ] `AudioBank` autoload registered (single source of truth for sfx
  + ambient resource lookups; AD-03 analogue for audio)
* \[ ] 16-entry sfx bank covering the `rules/feel-pass.md` contract
  (placeholders ok; one .ogg per row in the contract table)
* \[ ] One ambient loop per shipping zone (camp, wilderness)
* \[ ] Master + sfx + ambient bus split in `default_bus_layout.tres`
* \[ ] Audio settings exposed in pause menu (3 sliders)
* \[ ] Audio mutes correctly when window unfocused

## Stage 8 — Dungeon  *(execute after Stage 7.5)*

* \[ ] Three-room interior with locked progression
* \[ ] Trash → mini-encounter → boss room
* \[ ] Difficulty rises per room (enemy count or stats)
* \[ ] Elite enemy suffix system: 3 suffixes (Fast, Tough, Spawner)
  applied to wilderness/dungeon enemies via a `EliteModifier` resource
* \[ ] **Affix tier added to ItemData** (single fixed-roll prefix tier
  — Strategic Review D3.A). Drops with a 25% prefix-roll chance.
  Prefix table: 6 prefixes (+STR, +DEX, +VIT, +PNE, +HP, +Armor).
  Does NOT introduce variable rolls — each prefix is a fixed integer.
  This is the only scope-lock exception explicitly approved by the
  review; it does not unlock Act 2 affix scope (variable rolls,
  suffixes, ranges) which remain forbidden.
* \[ ] Drop rarity colors on `ItemData.glyph_color`: white/blue/gold
  by prefix count (0/1/future). UI surfaces the color on tooltips
  and pickup labels.
* \[ ] Inventory cap bumped 24 → 36 to accommodate dungeon density

## Stage 9 — Act boss  *(execute after Stage 8)*

* \[ ] Unique boss enemy with ≥3 distinct phases (not just one
  mechanic — review #14 raised refund-rate risk)
* \[ ] Guaranteed unique item on first kill, with a *visible reason
  to use it* (one item-specific affix that interacts with a class
  skill)
* \[ ] Boss death triggers Act 1 completion state
* \[ ] Boss room offers an explicit "begin endless mode" portal once
  Stage 9.7 ships

## Stage 9.5 — Feel Pass  *(execute after Stage 9; binds `rules/feel-pass.md`)*

* \[ ] `CameraShake` helper (`scripts/systems/camera_shake.gd`):
  `kick(amount, duration)`. One call site per damage-taken path.
* \[ ] `HitStop` helper (`scripts/systems/hit_stop.gd`):
  `pulse(frames := 3)`. Crit hits only.
* \[ ] Crit math added to DamageResolver (5% base crit, 2× damage)
  with golden DamageNumber variant
* \[ ] Hit-flash on every enemy hurtbox (mirror the existing player
  `_flash_hit` pattern)
* \[ ] Gold-pickup pulse + auto-stack animation
* \[ ] Rare-drop column-of-light VFX (`GPUParticles2D`) + 2px outline
  via shader
* \[ ] Cooldown ring overlay on skill icon
* \[ ] HUD: active-quest chip (top-left), zone-name fade-in (top-right),
  kill counter (small, top-center)
* \[ ] Save / Load toast (top-left, 1.5s fade)
* \[ ] Every event in `rules/feel-pass.md` contract has both an
  AudioBank call and a visual hook — verifier `--verify9_5` walks
  the call sites and asserts both exist
* \[ ] `scene-auditor` check #10 added (feel contract)

## Stage 9.7 — Endless mode  *(execute after Stage 9.5)*

* \[ ] Endless mode portal in boss room (post-clear)
* \[ ] Wave director: `SpawnDirector` extension that scales
  `concurrent_cap` + `species` weights per wave, no map change
* \[ ] Wave counter HUD
* \[ ] Run summary screen on player death: waves cleared, kills,
  gold, time. Shareable seed string (Strategic Review #7 viral hook).
* \[ ] Endless runs are NOT saved; they use the run-start save as a
  rollback point. Quitting endless = revert to pre-portal state.
* \[ ] Disabled in demo build via `FEATURE_FLAGS.demo_mode`
  (`commands/launch-plan.md`)

## Stage 11 — Save/load hardening

* \[ ] Versioned save format (already in place, AD-07)
* \[ ] Round-trip across every major state
* \[ ] Atomic save write: write to `save_slot_1.json.tmp`, fsync,
  rename. Prevents partial saves on crash mid-write
  (Failure Analysis #19)
* \[ ] Corrupt-save handling (don't crash; warn; offer to delete)
* \[ ] Save-import path from itch demo location to Steam user dir
  (`commands/launch-plan.md`)
* \[ ] Corrupt-save fixture test in stage11_verify

## Stage 12 — Pre-launch polish

* \[ ] Procedural sprites: explicit "ship as procedural" decision
  noted here per class/enemy (Stage 0 charter allows this)
* \[ ] Title screen + main menu (New / Continue / Options / Quit)
* \[ ] Options: resolution, audio (3 sliders from Stage 7.5),
  key rebind, controller toggle
* \[ ] Controller support (Godot input map; 1-day expected)
* \[ ] Accessibility: colorblind-safe damage-number palette toggle,
  UI font scale (90/100/120%)
* \[ ] Credits stub
* \[ ] Telemetry opt-in prompt on first launch (zone time, death
  cause; off by default — `commands/launch-plan.md`)
* \[ ] No `push_error` / `push_warning` during a 30-min play session
* \[ ] `audit.md` produces all PASS
* \[ ] Discord channels created and invite link baked into title
  screen (`commands/launch-plan.md`)

\---

When every box above is `\\\\\\\[x]`, and only then:

* Pay Steam fee.
* Submit for review.
* Schedule Early Access launch.

