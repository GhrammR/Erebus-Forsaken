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

## Execution order (Strategic Review v2 — 2026-06-04)

**Scope reset:** Act 1's content target grew substantially. Single dual
release (Steam + itch.io same day; no demo cut). Stage numbers stay
stable for already-closed work; new stages are appended. Existing
"Stage 11 — Save/load hardening" renumbers to Stage 22; existing
"Stage 12 — Pre-launch polish" renumbers to Stage 23.

1. Stage 10 — Character select **[CLOSED]**
2. Stage 7.5 — Audio mini-stage **[CLOSED]**
3. Stage 8 — Dungeon **[CLOSED]**
4. Stage 9 — Act boss (interim — see Stage 18) **[CLOSED]**
5. Stage 9.5 — Feel Pass **[CLOSED]**
6. Stage 9.7 — Endless mode (interim placement — see Stage 19) **[CLOSED]**
7. Stage 9.8 — Quality of Life (Hearth Ember + potions) **[CLOSED]**
8. Stage 9.8.1 — Hotfix: Ember Maw-route bug **[CLOSED]**
9. Stage 11 — AI asset-generation pipeline **[CLOSED]**
10. Stage 12 — Town → wilderness walkable transition **[CLOSED]**
11. Stage 13 — Wilderness procedural generation **[CLOSED]**
12. Stage 14 — Waypoint system **[CLOSED]**
13. Stage 15 — Equipment paper-doll rendering (bare-hands default;
    helmet/weapon/armor slots tint the procedural sprite layers)
14. Stage 16 — Item icons (replace text rows with icon grid)
15. Stage 17.5 — Procedural sprite anatomy v2 (anatomy families +
    per-unique-boss bespoke; lands BEFORE Stage 17 so portraits can
    reference the refreshed in-world NPC sprites, and BEFORE Stage 18
    so new-boss + Stage 20 enemy authoring don't pay v1 anatomy tax)
15.5. Stage 17 — NPC voice + portraits (each town NPC ships an intro
    line, AI-generated voice + portrait — portrait prompts reference
    the Stage 17.5 in-world sprite)
16. Stage 18 — Boss state-machine cleanup + legacy Forsaken/Hekate
    rare-routing audit for the final-boss model
17. Stage 19 — The Maw entrance moves to town; gated behind first-quest
    completion (anchor model preserved)
18. Stage 20 — Wilderness content authorship: 10+ areas, 5+ dungeons,
    winding paths, 5+ quests, final-quest = defeat-the-boss request
19. Stage 21 — Feel pass at scale (revisit `rules/feel-pass.md` for the
    expanded content; balance all new zones)
20. Stage 22 — Save/load hardening (was Stage 11)
21. Stage 23 — Pre-launch polish (was Stage 12)
22. **Steam + itch.io dual launch** (`commands/launch-plan.md`)

Skipping or reordering this sequence requires explicit user approval
and a note appended to this file.

---

## Stage 10 — All four classes selectable

* \[x] Character select scene with all four classes
  (`scenes/ui/character_select.tscn` + `scripts/ui/character_select.gd`).
  Cards built from `Database.get_all_classes()` in M/P/H/O order
  (new `CLASS_ORDER` const in database.gd is the single source). Each
  card surfaces display name, primary attribute, and base STR/DEX/VIT/PNE.
* \[x] Boots from `main.tscn` before the save-resume path;
  `main.gd` forks on `SaveSystem.has_save()` — existing save → game.tscn
  unchanged; no save → character_select.tscn. The select scene stashes
  the pick in `GameState.pending_class_id` (transient, not saved) and
  swaps to game.tscn, which consumes the id in `_ready`.
* \[x] Each class plays through Stages 3–5 without class-specific bugs
  — covered by existing `--verify3 / --verify4 / --verify5` (all PASS
  this stage); the per-class workbench paths are unchanged.
* \[x] First-launch tutorial prompt
  (`scenes/ui/tutorial_prompt.tscn` + `scripts/ui/tutorial_prompt.gd`):
  non-modal panel at screen bottom, dismissible via Esc or the "Got it"
  button. Persistence in `user://settings.json` under
  `has_seen_tutorial` — separate from save_slot_1 so a wipe doesn't
  re-trigger it. Spawned by `game.gd` only on the new-game path.
  mouse_filter=2 on Panel/VBox/labels so it doesn't eat gameplay clicks.
* \[x] One-line pitch shown on character-select screen footer (exact
  copy from CLAUDE.md `## One-line pitch`)
* \[x] `--verify10` verifier (11/11 PASS): class roster + order, four
  ClassData resources, pending_class_id round-trip, tutorial flag
  persistence, settings-merge preserves other keys.
* \[x] Regression: --verify / --verify3 / --verify4 / --verify5 /
  --verify6 / --verify7 all PASS post-Stage-10.
* \[x] combat-validator + scene-auditor: PASS. No combat code touched;
  new UI scenes carry mouse_filter=2 on display-only Controls per
  failure-modes #9.

## Stage 7.5 — Audio mini-stage

* \[x] `AudioBank` autoload registered (`scripts/autoload/audio_bank.gd`).
  Single source of truth for sfx + ambient lookups; bank entries with
  missing .ogg paths no-op silently (placeholder rule, asset-pipeline.md).
  Pool of 6 `AudioStreamPlayer` nodes for sfx (round-robin) + one
  dedicated ambient player.
* \[x] 16-entry sfx bank covering the full `rules/feel-pass.md` contract
  (swing, hit_flesh, hit_crit, player_hurt, death_player, death_enemy,
  skill_cast, skill_ready, pickup_item, pickup_gold, drop_rare, levelup,
  quest_accept, quest_complete, save, load). .ogg files ship as
  placeholders — code lands now, audio drops in later.
* \[x] Ambient loops registered for both shipping zones (threshold_camp,
  blighted_reach). EventBus.zone_changed drives swap; ambient player
  auto-loops on `finished` if the import lacked loop=true.
* \[x] Master / Sfx / Ambient bus split in `audio/default_bus_layout.tres`
  (Sfx and Ambient send to Master). `project.godot` references the layout.
* \[x] Audio settings exposed in pause menu (3 HSliders: Master / SFX /
  Ambient). Live value_changed feeds AudioBank.set_*_volume; drag_ended
  persists into `user://settings.json` (merged with existing keys —
  tutorial flag survives).
* \[x] `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT/IN)` toggles
  `AudioServer.set_bus_mute(Master)` so the window losing focus mutes
  the entire output.
* \[x] Existing event call sites wired: Player.attack → swing,
  Player._on_damaged → player_hurt, Enemy._on_damaged → hit_flesh,
  Enemy._on_died emits EventBus.enemy_died → death_enemy, Skill.try_activate
  on success → skill_cast, game.gd save/load → save/load, game.gd
  _do_transit re-emits EventBus.zone_changed → ambient swap.
  Future-binding events (crit, skill_ready, drop_rare, levelup,
  quest_accept/complete) are in the bank but call sites land in Stage 9.5.
* \[x] `--verify7_5` verifier (35/35 PASS): sfx bank size + 16 contract
  keys, ambient bank, 3 buses present, volume round-trip + persistence,
  settings-merge preserves tutorial flag, defocus handler present,
  EventBus auto-wiring, all 8 call-site insertions present.
* \[x] Regression: --verify / --verify3 / --verify4 / --verify5 /
  --verify6 / --verify7 / --verify10 all PASS post-Stage-7.5.

## Stage 8 — Dungeon

* \[x] Three-room interior with locked progression
  (`scenes/zones/forsaken_crypt.tscn` + `scripts/zones/forsaken_crypt.gd`).
  Single zone — one `_zone_cache` entry, AD-12 compliant. Rooms are
  rectangular floor tints; player enters south, pushes north through
  R1 → R2 → R3.
* \[x] Trash → mini-encounter → boss room. R1: 3 shade_wretches. R2:
  4 wretches + 1 Fleet bog_caller (gate1 closes south corridor until
  cleared). R3 (boss-room placeholder): 1 Ironbound wretch + 1 Fleet
  bog_caller. Stage 9 lands the real Act boss in the same R3 footprint.
* \[x] Difficulty rises per room — enemy count (3/5/2 elite-heavy) +
  elite density per the brief.
* \[x] Elite enemy suffix system
  (`scripts/enemies/elite_modifier.gd` + `data/modifiers/elite_*.tres`):
  Fleet (+speed, +cadence), Ironbound (+hp, +dmg, +def, -speed),
  Brood-mother (+hp, spawns 2 wretches on death). Applied via
  `Enemy.elite_modifier` export; mults fold into Stats/AI/damage in
  `_apply_elite_pre_stats` + `_apply_elite_post_sprite`. SpawnDirector
  rolls elites via `elite_chance` + `elite_table` per zone. Save +
  cache round-trip via `EnemyRegistry.elite_modifier_for(id)`.
* \[x] **Affix tier — D3.A carve-out**: single fixed-roll prefix at
  25% drop chance. `data/affixes/prefix_table.tres` (PrefixTable):
  Mighty (+3 STR), Swift (+3 DEX), Stout (+3 VIT), Wise (+3 PNE),
  Hale (+15 HP), Plated (+5 Armor). HP routed via new `hp_max` key
  in `Stats.apply_equipment_totals`. NO suffixes, NO ranges, NO
  variable rolls. Act 2 affix scope remains forbidden.
* \[x] Per-drop instance system
  (`scripts/autoload/item_instance_registry.gd`): roll mints a
  synthetic instance_id (e.g. "shade_blade#7"); Database.get_item
  routes it to a synthesized ItemData clone with merged affixes,
  blue glyph_color, prefix-prepended display_name. Save schema v11
  persists the registry alongside inventory.
* \[x] Drop rarity colors: base = cream (white-tier),
  prefixed = `Color(0.45, 0.65, 1.0)` blue (rare-tier). Gold-tier
  (2+ prefixes) branch is wired in `synthesize` but no drop produces
  it this stage — that path is Stage 9 unique-item territory.
* \[x] Inventory cap bumped 24 → 36 (`Inventory.BACKPACK_CAPACITY`).
  No save migration needed — backpack is a dynamic Array; old 24-cap
  saves load cleanly.
* \[x] Wilderness south crypt entrance: portal at (0, 500) in
  Blighted Reach behind the existing tree line, with
  `FromForsakenCrypt` arrival marker so returns drop the player
  next to the door. Player discovers it by traversal — no hub-side
  teleport.
* \[x] Gates: `scripts/world/gate.gd` + `scenes/world/gate.tscn`
  (stone slab + cyan rune). Lock by default; on room clear the rune
  flares for 0.18s then the slab fades over 0.4s as the collider
  disables. Zone polls each frame; cheap.
* \[x] `--verify8` verifier (35/35 PASS): prefix table contents +
  stat coverage, elite modifier load + apply, instance registry roll
  determinism + statistical band, Database dispatch + synth shape,
  inventory cap, crypt scene structural contract (3 rooms × correct
  anchor counts, 2 gates, return portal), Blighted Reach entrance,
  SceneRouter wiring, save schema v11 + migration, registry
  round-trip, AudioBank ambient registration.
* \[x] Regression: --verify / --verify3 / --verify4 / --verify5 /
  --verify6 / --verify7 / --verify7_5 / --verify10 all PASS
  post-Stage-8.

## Stage 9 — Act boss

* \[x] Unique boss enemy with 3 distinct phases
  (`scripts/enemies/act_boss.gd` + `scenes/enemies/act_boss.tscn` +
  `art/procedural/enemies/act_boss_sprite.tscn`). HP-threshold state
  machine: P1_STALK (100→66%) melee chase; P2_CHANNEL (66→33%)
  rooted 3-orb fan every 1.6s; P3_FRENZY (33→0%) speed ×1.6,
  cadence ×0.5, alternating melee and 6-orb radial burst every 4s
  + 1 shade_wretch reinforcement on entry. Each transition fires
  a 0.3s invuln window, sprite-tint shift, skill_cast sfx,
  `cast` anim telegraph. Boss is its own AI rather than
  WildernessEnemy — phase-driven, not chase/kite. AD-04 damage path
  preserved (skill_hitbox scene + enemy_projectile via
  HealthComponent.take_damage).
* \[x] Guaranteed class-aware unique on first kill
  (`scripts/autoload/game_state.gd` `boss_first_kill` flag). On
  first death, `ActBoss._on_died` picks the unique that matches
  the live player's `class_data.id` from `UNIQUE_BY_CLASS` and
  drops it with the `drop_rare` sfx. Subsequent kills fall back
  to the normal drop table.
* \[x] Four uniques in `data/items/uniques/`:
  `forsaken_myrmidon_sigil` (+12 Spear Lunge, +3 STR),
  `forsaken_pythia_sigil` (+10 Oracle Bolt, +3 PNE),
  `forsaken_shade_hunter_sigil` (+12 Volley, +3 DEX),
  `forsaken_ossuary_priest_sigil` (+8 Bone Servant, +3 PNE).
  All amulet-slot, class-restricted, gold glyph tier.
* \[x] Item-specific affix interacts with a class skill: new
  `skill_bonus_<skill_id>` affix-key family.
  `Stats.apply_equipment_totals` fans these into `equip_skill_bonuses`
  dict; `Stats.get_skill_bonus(id)` returns the value;
  `Skill.effective_damage(caster)` folds it into outgoing damage.
  Each skill subclass sets `skill_id` in `_configure` and reads
  via `effective_damage` (SpearLunge: hitbox base_damage;
  OracleBolt: projectile damage; Volley: distributed across the
  3-arrow fan to avoid stacking; BoneServant: `bonus_damage` rides
  into `BoneServantMinion._hitbox.base_damage`).
* \[x] Boss death sets `GameState.act_1_complete = true` (and
  `boss_first_kill = true`). Save schema v11 → v12 persists both
  flags; `_migrate_v11_to_v12` seeds them false on legacy saves.
* \[x] Boss room hosts an explicit `EndlessPortalSlot` Marker2D at
  the north wall of R3 (`scenes/zones/forsaken_crypt.tscn`).
  Stage 9.7 spawns the endless portal here gated on
  `act_1_complete`.
* \[x] R3 placeholder (Ironbound wretch + Fleet bog_caller)
  replaced with single Act-boss spawn at the centered Room3 anchor;
  EnemyRegistry registers `&"act_boss"`.
* \[x] `--verify9` verifier (29/29 PASS): boss scene + class +
  enemy_id + HP + Phase enum size; all 4 uniques in Database with
  correct `skill_bonus_*` affix + gold glyph; Stats apply_equipment
  routing into equip_skill_bonuses + get_skill_bonus + Skill
  effective_damage; HP-threshold-driven phase transitions
  (P1→P2 at 66%, P2→P3 at 33%) via force_check_phase; EnemyRegistry
  resolution; GameState flag defaults + reset_run clears; save v12
  + v11→v12 migration; flag round-trip; EndlessPortalSlot marker
  present; R3 spawns exactly 1 ActBoss in the `crypt_room_3` group.
* \[x] Regression: --verify / --verify3 / --verify4 / --verify5 /
  --verify6 / --verify7 / --verify7_5 / --verify8 / --verify10
  all PASS post-Stage-9.

## Stage 9.5 — Feel Pass

* \[x] `CameraShake` autoload (`scripts/systems/camera_shake.gd`):
  `kick(amount, duration)`. Player Camera2D joins `&"feel_camera"`
  group at _ready; kick resolves via group lookup so workbenches
  without a player no-op cleanly. Multiple kicks merge — running
  tween is killed and replaced rather than stacked.
* \[x] `HitStop` autoload (`scripts/systems/hit_stop.gd`):
  `pulse(frames := 3)`. Slams `Engine.time_scale = 0.0` for the
  pulse duration, restores to 1.0 via a `process_always`
  SceneTreeTimer (ticks under zero time-scale). Second pulse
  during a running one extends rather than stacks.
* \[x] Crit math in DamageResolver: `CRIT_CHANCE = 0.05`,
  `CRIT_MULT = 2.0`. New `DamageResult` Resource
  (`scripts/systems/damage_result.gd`) replaces the bare `int`
  return so the crit flag rides alongside the magnitude. AD-04
  preserved — DamageResolver still owns the math; HealthComponent
  consumes the resource and emits the new local `crit_landed`
  signal alongside `damaged`. AD-08 EventBus whitelist preserved
  (crit_landed is per-emitter, not bus).
* \[x] DamageNumber crit variant: `is_crit` field, golden colour,
  1.4× scale, longer rise. `Game._on_combatant_crit` spawns the
  golden variant + plays `hit_crit` + `HitStop.pulse(3)` +
  `CameraShake.kick(3.0, 0.10)`. Wired for every combatant via
  `wire_combatant_vfx` (Player + zone enemies + scripted crypt
  spawns + Bone Servant via the existing `&"game_host"` path).
* \[x] Hit-flash on every enemy hurtbox — already landed Stage 9
  polish (Enemy + BoneServantMinion + Player tween-based flashes
  that target the same node anim_hit writes to).
* \[x] Player hit-taken camera shake: `CameraShake.kick(4.0, 0.12)`
  in `Player._on_damaged` (gated on `_amount > 0` + ALIVE).
* \[x] Gold-pickup pulse + HUD gold readout: new `HUD/GoldHUD`
  Label (bottom-right). `Game._on_wallet_pulse` listens to
  `Wallet.gold_changed`, tracks the previous total so negative
  deltas (vendor purchases) skip the pulse, scales the label
  1.3× → 1.0× over 0.18s, plays `pickup_gold` sfx.
* \[x] Rare-drop column-of-light VFX: `scenes/vfx/rare_drop_pillar.tscn`
  (`GPUParticles2D` + glow polygon, 1.6s auto-cleanup). 2px outline
  shader at `art/shaders/item_outline.gdshader` — neighbour-sampling
  pass with a pulsing alpha, applied to the WorldItem label via
  `_apply_rare_dress` when `glyph_color` matches the rare-tier blue
  or gold-tier (boss unique) palette.
* \[x] Cooldown ring overlay on skill icon
  (`scenes/ui/skill_icon.tscn` + `scripts/ui/skill_icon.gd`).
  `TextureProgressBar` clock-fill, ring fills as cooldown winds
  down. `skill_ready` sfx + outline pulse fire on the ready edge
  *only when `cooldown >= 1.0`* (Volley, Bone Servant) — fast-spam
  skills (Spear Lunge, Oracle Bolt) stay quiet.
* \[x] HUD chips:
  - `QuestChip` (top-left, slides in on QuestSystem ACCEPTED,
    flashes gold + clears on COMPLETED / TURNED_IN)
  - `ZoneNameToast` (top-right, 0.35s fade-in + 0.9s hold +
    0.5s fade-out on `EventBus.zone_changed`)
  - `KillCounter` (top-centre, ticks on `EventBus.enemy_died`,
    decays after 3s of no kills, folded into `_process`)
* \[x] Save / Load toast: `HUD/SaveToast` (top-left), driven by
  `SaveSystem.save_completed` / `load_completed` signals.
  1.0s hold + 0.5s fade. Green on success, red on failure.
  Existing `Status` label remains for non-save zone-enter messages.
* \[x] Level-up VFX: `scenes/vfx/level_up_ring.tscn` (expanding ring
  + `+N` popup). Listens to `EventBus.player_leveled`; no XP system
  emits in Act 1 but the call site is ready for Act 2.
* \[x] Quest audio wired: `quest_accept` / `quest_complete` sfx
  on `QuestSystem.quest_state_changed` (state 1 / 2-3).
* \[x] `--verify9_5` verifier (44/44 PASS): autoloads,
  DamageResult shape, crit rate band ([0.02, 0.10] over ~600
  hits), HC.crit_landed signal, DamageNumber.is_crit field,
  CameraShake / HitStop no-op cleanly, HUD nodes present
  (QuestChip / ZoneNameToast / KillCounter / SaveToast /
  GoldHUD / SkillIcon), VFX scenes load, outline shader loads,
  feel-pass contract audio (every event has a call site) +
  visuals (every event has a canonical hook marker in
  production code).
* \[x] `scene-auditor` check #10 documented (feel-pass contract
  coverage — every contract row needs both an audio call site
  and a visual hook; reuses the verifier's marker list).
* \[x] Regression: --verify / --verify3 / --verify4 / --verify5 /
  --verify6 / --verify7 / --verify7_5 / --verify8 / --verify9 /
  --verify10 all PASS post-Stage-9.5. Stage 3 verifier touched
  (`int` → `DamageResult.damage`) and filters crit hits when
  asserting the deterministic damage value.

## Stage 9.7 — Endless mode  *(CLOSED)*

* \[x] Endless mode portal in boss room (post-clear). `EndlessPortal`
  (extends Portal) is instantiated at `EndlessPortalSlot` by
  `ForsakenCrypt._maybe_spawn_endless_portal()` when
  `GameState.act_1_complete && !FeatureFlags.demo_mode`. Interact
  takes the rollback-anchor save via `SaveSystem.save_game()` BEFORE
  flipping `EndlessRun.active`, so the on-disk file represents the
  pre-portal state, then routes to `endless_arena`.
* \[x] Wave director: `EndlessDirector` extends `SpawnDirector` and
  scales `concurrent_cap`, `respawn_delay`, `elite_chance`, and
  `species` weights per wave via `_apply_wave_tuning(w)`:
  cap = `mini(6+w, 14)`, delay = `maxf(5-w*0.25, 1.5)`, elite =
  `minf(0.05+w*0.02, 0.30)`, quota = `6+w*2`. Four species bands
  (waves 1, 3, 5, 8) shift the wretch/bog_caller mix. 1.5s lull
  between waves. No map change between waves — fixed arena geometry.
* \[x] Wave counter HUD: `WaveCounter` Label in `game.tscn`. Game.gd
  subscribes to `EventBus.endless_wave_started/_completed` and
  `EndlessRun.stats_changed` to render `Wave N — X / Y`. Hidden
  unless `EndlessRun.active`.
* \[x] Run summary screen: `scenes/ui/endless_summary.tscn`
  (`CanvasLayer` layer 70). Surfaces waves / kills / gold gained /
  mm\:ss time + readonly seed LineEdit + Copy button
  (`DisplayServer.clipboard_set`). Esc closes via
  `return_requested`. Strategic Review #7 viral hook: shareable seed
  string `EREBUS-XXXX-XXXX` (40-bit base-32 with I/O/0/1 dropped for
  hand-transcription clarity, encode/decode round-trip verified).
* \[x] Endless runs are NOT saved. `SaveSystem.save_game()` no-ops
  while `EndlessRun.active`. Death triggers
  `EndlessRun.end_run()` → summary modal; the modal's
  "Return to Crypt" button calls `EndlessRun.rollback()` then
  `SaveSystem.load_game()` + `_resume_saved_zone()` to revert
  bytes-for-bytes to the pre-portal state. The corpse-run penalty
  (gold/gear drop) is skipped entirely during endless death.
* \[x] Disabled in demo build via
  `FeatureFlags.demo_mode` (project setting
  `application/feature_flags/demo_mode`). New `FeatureFlags`
  autoload reads the bool at boot; the crypt's portal spawn checks
  it before instantiating. `launch-plan.md` remains the source of
  truth for what demo_mode covers.
* \[x] `--verify9_7` verifier (26 / 26 PASS): autoloads,
  EventBus signals on whitelist, SceneRouter zone registration,
  seed round-trip, EndlessRun lifecycle (begin/record_kill/
  advance_wave/rollback), tuning curves at waves 1/3/5/10/20,
  species reweight, `_pick_species` determinism off
  `EndlessRun.seed`, arena scene structure, crypt portal gating
  (act_1_complete + demo_mode), save guard, game.tscn HUD
  declarations, summary modal API.
* \[x] Regression: --verify / --verify3 / --verify7 / --verify8 /
  --verify9 / --verify9_5 / --verify10 all PASS post-Stage-9.7.

### Stage 9.7 polish (2026-06-03)

User feedback identified zone redundancy (wilderness + endless were
near-identical farm loops) and a portal-spawn bug (post-boss flag
flip wasn't observed mid-session). Three design pivots locked:

* **Wilderness role:** campaign-only, finite respawns. Blighted Reach
  director gets `total_spawn_budget = 16`; once exhausted the zone
  permanently quiets for the save slot. The crypt remains scripted
  (kill-the-room contract, already finite). Drives all post-Act-1
  combat through the descent.
* **Reward model:** Tower of Ascension milestones. Floors 10 / 25 /
  50 / 100 grant one-time rewards that persist across runs even
  through `EndlessRun.rollback()`. Floor 10 = Vitality +1 (alloc),
  Floor 25 = Depth-Touched Charm (Amulet, +20 HP, class_mask=ALL),
  Floor 50 = "Delver" cosmetic title, Floor 100 = Crown of the
  Forsaken (Helm, +1 all attributes, ALL classes). Unique art ships
  procedural per Stage 12 charter; bitmap pass is parking-lot
  modular-sprite-polish.
* **Framing:** "Forsaken Depths" — endless zone reframed as a
  procedural descent below the crypt's boss room. Lore-coherent with
  the dungeon lexicon, dressed with stone walls, four braziers,
  central blood-sigil. HUD relabels Wave → Floor. Crypt portal
  display name "The Descent".

Implementation:

* \[x] Portal spawn bug — `ForsakenCrypt._on_any_enemy_died` listens
  for ActBoss death (filtered) and re-runs `_maybe_spawn_endless_
  portal()`. Idempotent via `has_endless_portal()` guard so re-entry
  doesn't double-spawn. EventBus whitelist preserved (reuses
  `enemy_died`).
* \[x] `SpawnDirector.total_spawn_budget` export + `_budget_remaining`
  state. -1 sentinel = unlimited (back-compat). >=0 decrements per
  spawn and gates `_spawn_one` at zero. `budget_remaining()` +
  `has_finite_budget()` helpers. Director joins `spawn_director`
  group for save discovery.
* \[x] SaveSystem schema v12 → v13. New keys: `director_budgets`
  (Dict[zone_name, int]), `endless_milestones` (Array[int]),
  `titles` (Array[String]). `_snapshot_director_budgets` walks the
  group; `consume_pending_director_budget` per-zone pop on director
  `_ready`. `_migrate_v12_to_v13` seeds empty defaults and rewrites
  stale `endless_arena` zone_id to `forsaken_depths` (defensive —
  endless never persists).
* \[x] Forsaken Depths rename: `endless_arena.tscn` →
  `forsaken_depths.tscn`, `EndlessArena` → `ForsakenDepths`,
  `EndlessEntry` → `DepthsEntry`. SceneRouter zone id updated.
  EndlessPortal target updated. Scene reskinned: stone wall tops,
  four corner braziers, central blood-sigil, brick floor seams.
* \[x] Tower of Ascension milestones: `EndlessRun.MILESTONES` dict
  keyed by floor. `_maybe_claim_milestone` fired from `advance_wave`
  (idempotent via `GameState.endless_milestones.has(floor)`).
  Reward kinds: `stat` (writes `alloc_*`), `item` (Inventory.add_item),
  `title` (`GameState.titles.append`). Per-emitter signal
  `milestone_reached(floor, reward)` (AD-08 — not EventBus).
* \[x] Rollback survival: `EndlessRun.begin` snapshots
  `_milestones_at_start`. `milestones_new_this_run()` returns the
  diff. `game.gd._on_endless_summary_return` reads it BEFORE
  rollback, then `EndlessRun.recommit_milestones()` re-grants after
  the save-load wipes them, then `SaveSystem.save_game()` persists.
  Permanent progress survives the run-end wipe.
* \[x] Two new uniques in `data/items/uniques/`:
  `depth_touched_charm.tres` (slot=AMULET, hp_max+20),
  `crown_of_the_forsaken.tres` (slot=HEAD, +1 all four attributes,
  4 def / 5 res base). class_mask=ALL on both. Database loads
  automatically (item count 18 → 20).
* \[x] HUD: Wave → Floor in label text. Summary modal:
  "TRIAL ENDED" → "DESCENT ENDED", "Waves cleared" → "Floors
  cleared", "Return to Crypt" → "Ascend". Crypt portal display
  name "The Descent".
* \[x] `MilestoneModal` (`scenes/ui/milestone_modal.tscn` + `.gd`,
  CanvasLayer layer 75): inline modal that pauses run via
  `Engine.time_scale = 0` while visible. Esc or Continue resumes.
  Game.gd wires `EndlessRun.milestone_reached` → show, modal
  `continue_pressed` → hide.
* \[x] `--verify9_7` extended to 42 / 42 PASS: finite budget gate
  + group registration + save snapshot/restore, milestone grants
  for all 3 reward kinds, idempotency on re-visit, both items
  loaded with correct affixes, save schema v13 + migration +
  stale-zone-id rewrite, milestone modal API. Existing checks
  updated for `forsaken_depths` rename.
* \[x] Stage 9 verifier relaxed: `SAVE_VERSION >= 12` (was `==`).
* \[x] Regression: all 12 verifiers
  (`verify / verify3 / verify4 / verify5 / verify6 / verify7 /
  verify7_5 / verify8 / verify9 / verify9_5 / verify9_7 /
  verify10`) PASS post-polish.

### Stage 9.7 polish — second pass (2026-06-04)

Three more bugs surfaced after the wilderness/crypt rework:

* \[x] Damage numbers missing in The Maw — `_wire_zone_combat_vfx`
  looked up the spawn director by hard-coded node name
  `^"SpawnDirector"`, but the depths' director is named
  `EndlessDirector` so the signal connect silently no-op'd and
  wave-spawned enemies never had their `HC.damaged` wired to the
  damage-number layer. Switched to class-based discovery
  (`as SpawnDirector` matches subclasses) — walks zone children
  and connects every SpawnDirector subclass node.
* \[x] Crypt rooms 1+2 respawning post-boss — extended the
  `act_1_complete` gate from R3 only to the entire `_spawn_initial`
  body. Once the boss falls, the whole dungeon is permanently quiet
  for that save slot. Gates 1 and 2 auto-unlock because
  `_room_alive_count` is 0 on first frame.
* \[x] Wilderness budget reset on re-entry — Game's `_zone_cache`
  was tracking enemies + loot but not director budgets. Added
  `director_budgets` to the snapshot via `_collect_director_budgets()`
  and push them through new `SaveSystem.set_pending_director_budget()`
  on transit; SpawnDirector's existing `consume_pending_director_budget`
  pop in `_ready` picks them up. In-session round-trip + save round-
  trip now both preserve the count.

### Stage 9.7 polish — third pass (2026-06-04)

User feedback after second-pass fixes:

* \[x] Naming redundancy "Forsaken Crypt" + "Forsaken Depths"
  resolved by renaming the depths to **"The Maw"** in user-facing
  strings only. Internal `zone_id` stays `forsaken_depths` (cheap
  — referenced by EndlessPortal, SceneRouter, save migration).
  `_zone_display_name` returns "The Maw"; crypt portal display_name
  now "The Maw"; summary modal title "DESCENT ENDED" →
  "THE MAW RECEDES".
* \[x] The Maw had no non-death exit — added a temporary
  **AscentSpire** Npc subclass at the depths center
  (`scripts/world/ascent_spire.gd` + `scenes/world/ascent_spire.tscn`).
  Interact calls `EndlessRun.end_run(false)` which emits
  `EventBus.endless_run_ended`; game.gd's new listener opens the
  summary modal. Both death and spire converge on a single
  end-of-run path. EndlessRun gained `ended_via_death` flag so
  game.gd knows whether to call `Player.respawn()` (yes on death,
  no on spire — alive player keeps their save-restored position).
  The spire is **interim**; Stage 9.8 Hearth Ember replaces it as
  the universal escape mechanism.
* \[x] Confirmed not a bug: Phase 3 boss reinforcement (one
  `shade_wretch` spawned via `ActBoss._spawn_phase3_add`) is the
  intended Phase 3 mechanic per Stage 9 scope, not a stray wave.
* \[x] Confirmed already parked: AI fails to path around walls
  when the player breaks line of sight —
  `parking_lot.md::monster-pathfinding` covers the "player runs
  behind a wall, enemy gives up entirely" case as an intentional
  fallback until navmesh lands (Earliest revisit: post-Stage-9.7,
  before itch.io demo).

### Stage 9.7 polish — fourth pass (2026-06-04)

User flagged three more issues from playtest screenshots:

* \[x] Lingering yellow vertical shape after kills with a rare drop
  — root cause: `rare_drop_pillar.tscn`'s `GlowCore` Polygon2D
  (12 × 38 px, gold) was rendering at constant 0.55 alpha for the
  full 1.6s pillar lifetime, reading as a "stuck decal" next to
  the loot. Fixed by adding a tween in
  `scripts/vfx/rare_drop_pillar.gd._ready` that fades
  `GlowCore.modulate.a` to 0 over `DURATION` with `TRANS_QUAD /
  EASE_IN` so the column dissipates instead of popping out.
* \[x] Player not spawning at The Maw centre — two compounded
  bugs. (1) `_place_player_for_arrival` used
  `mp != Vector2.ZERO` as a "marker exists" probe, which silently
  failed for `DepthsEntry` at (0, 0) and fell through to a less
  predictable fallback. Added `Zone.has_marker(name)` as an
  explicit node-existence check; `_place_player_for_arrival` now
  uses it. (2) The depths' anchor ring was 360-622px from centre,
  putting the closest N/S anchors right at the player's 720-tall
  viewport edge — monsters appeared to "spawn on top of the
  player." Reduced to 4 corner-only anchors at ±560 / ±360 (629px
  out) and bumped `min_distance_from_player` from 280 to 460 to
  enforce the safe gap.
* \[x] Crypt rollback respawn yanked the player to the south-wall
  `SpawnPoint` instead of the saved boss-room slot — `Player.
  respawn()` always teleports to `respawn_position`, which the
  zone transit clobbered to `get_spawn_position()`. Added
  `Player.revive_in_place()` that re-enables input + restores
  HP/MP without teleporting. `game.gd._on_endless_summary_return`
  now calls `revive_in_place` instead of `respawn` for the death
  path, preserving the save-restored position.
* \[x] Seed string question — explained in user-facing tooltip
  below the seed field: "Share this seed — others who run it see
  the same enemy mix." Currently seeds drive only
  `EndlessDirector._pick_species` + `_maybe_pick_elite` (anchor
  pick is player-position dependent, damage rolls are unseeded).
  Seed input UI parked at `parking_lot.md::seed-input-ui` for
  Stage 12 polish alongside leaderboards.

All twelve verifiers PASS post-fourth-pass.

### Stage 9.7 polish — fifth pass (2026-06-04)

User added two observations + a debug-infrastructure request:

* \[x] Diagnostic prints proved the player IS at `(0, 0)` after
  arrival into The Maw (arrival / settle / watch1 / watch2 all
  zero with zero velocity). The "instantly teleported to corner"
  perception turned out to be a different issue:
  `EndlessDirector.concurrent_cap = 7` at wave 1 + four corner-only
  anchors + zero per-spawn delay = seven wretches dogpiling from all
  four corners within ~7 frames. Fixed with:
  - **wave-start grace** `_WAVE_START_GRACE = 2.5s`: `_advance_wave_to`
    bumps `_cooldown_remaining` to suppress new spawns at wave
    transitions, so the player has a beat to orient.
  - **per-spawn stagger** `_SPAWN_INTERVAL = 0.45s`: override of
    `_spawn_one` bumps `_cooldown_remaining` after each spawn so
    the cap fills as a trickle rather than a frame-by-frame flood.
* \[x] Rare-drop pillar VFX retired entirely. World-item drops
  no longer instantiate `rare_drop_pillar`; the persistent outlined
  name label + glyph color carry rarity. Scene + script deleted;
  Stage 9.5 verifier updated; concept parked in
  `parking_lot.md::rare-drop-ground-vfx` for a future polish pass
  with proper beam-of-light implementation.
* \[x] **`DebugLog` autoload** (`scripts/systems/debug_log.gd`) —
  CLI-flag-gated logging so future bug hunts don't need the
  one-shot manual `print()` injection / removal cycle. Usage:
  ```
  godot -- --debug=transit,combat
  godot -- --debug=all --debug-file=session.log
  ```
  Categories shipped: `transit`, `combat`, `input`, `items`,
  `save`, `endless`, `ai`, `physics`, `skills`, `ui`. New flags
  auto-recognise — call `DebugLog.log(&"newflag", msg)` from any
  site and pass `--debug=newflag` to surface it. `--debug=all`
  always enables. Output format: `[T+12345ms][flag] msg`. Optional
  `--debug-file` mirrors stdout to a file with `flush()` per line
  so a crash mid-session still leaves a readable trail.
* \[x] Game.gd's transit prints converted to `DebugLog.log(&"transit",
  ...)`. Added per-frame position watch (180 frames / ~3s) under
  the `transit` flag that fires after each `_place_player_for_arrival`
  and prints any frame the player's position changes, with delta /
  velocity / click target / pending NPC context. This is the
  surface that would have caught the dogpile-not-teleport
  confusion in a single re-run.

## Stage 9.8 — Quality of Life  **[CLOSED 2026-06-04]**

Hearth Ember + Health/Mana potions landed alongside a unique Ichor
Potion, the AscentSpire retired, and governance for README sync +
dev-debug instrumentation added.

### Hearth Ember (consumable town return)

* \[x] `ItemData.Kind.EQUIPMENT/CONSUMABLE` enum added; `UseKind`
  enum dispatches the four use-paths.
  `data/items/consumables/hearth_ember.tres` ships with kind=1,
  use_kind=HEARTH_EMBER, channel=2s.
* \[x] Use path: 2-second channel — player can't move or attack
  (`Player._channeling` flag gates physics + attack + skill_1).
  Taking damage interrupts AND consumes the ember (confirmed
  decision over "just break"). On completion: outside Maw →
  `SceneRouter.go_to_zone(&"threshold_camp", &"SpawnPoint")`
  (uses existing host transit fade). In Maw → `EndlessRun.end_run(false)`
  → summary modal → rollback.
* \[x] Drop sources: 2-weight entry on `wilderness_basic_drops.tres`
  (shared by shade_wretch + bog_caller). Guaranteed Hearth Ember on
  Act boss first-kill alongside the class-restricted unique (added
  to `act_boss._drop_first_kill_unique`).
* \[x] Vendor stock: Kallias's `kallias_stock.tres` includes
  `hearth_ember` at its base price (150g).
* \[x] Channel SFX bank registered (`hearth_ember_channel`,
  `_complete`, `_break`) — placeholder audio per asset-pipeline rule.
  VFX (orange ring + particles) parked to Stage 12 polish; channel
  state is fully readable from the locked input + DebugLog trace.
* \[x] In The Maw: Ember routes through `EndlessRun.end_run(false)`
  — same rollback chain as the (now-retired) AscentSpire.

### Health + Mana potions + Ichor Potion (unique)

* \[x] `health_potion.tres` and `mana_potion.tres`: flat amount
  restored linearly over 3s (80 HP / 60 MP), per-type 8s cooldown.
* \[x] **Decision shift from spec:** instead of percentage standard
  potions, standard potions restore flat over time and a NEW unique
  `ichor_potion.tres` restores 50% HP + 50% MP **instantly** on its
  own 30s cooldown.
* \[x] Hotkeys 2 (health) / 3 (mana). Ichor is inventory-click only.
  PlayerInput routes through `ConsumableUse.try_use(player, id,
  inventory)`.
* \[x] Drop sources: 3/3/1-weight on wilderness drop table for
  health/mana/ichor. Ichor also rolls 25% on Act boss first-kill.
  Ichor NOT in vendor stock — uniqueness preserved.
* \[x] HUD: `scripts/ui/potion_bar.gd` builds three slot icons
  programmatically (red/blue/gold) with CooldownVeil pattern; left
  of SkillIcon. Slot dims when count == 0.

### Stage 9.8 closure criteria

* \[x] Demo build still surfaces Hearth Ember + potions — these are
  core affordances, not gated.
* \[x] AscentSpire decision: **retire**. Scene/script/uid deleted;
  `forsaken_depths.tscn` no longer references it.
* \[x] All twelve existing verifiers PASS post-Stage-9.8.
* \[x] `--verify9_8` covers: ConsumableUse autoload + API, ItemData
  enums, all four consumable resources, drop table augmentation,
  Kallias stock (positive + negative for Ichor), Inventory rejects
  consumables on `can_equip`, cooldown lifecycle, snapshot/restore
  round-trip, SAVE_VERSION == 14, v13→v14 migration installs the
  default cooldowns key, AscentSpire fully removed, PotionBar script
  + PlayerInput hotkey wiring present.

### Governance landed in this stage

* `rules/git-and-github.md` § **Documentation sync** — every commit
  that changes user-visible state updates `README.md` in the same
  commit. New CLAUDE.md non-negotiable #8 references it.
* `rules/testing.md` § **Dev-debug instrumentation** — every new
  system ships with a DebugLog flag + workbench affordance +
  headless verifier + failure-mode entries for non-obvious bugs.
* `rules/testing.md` § **Parse-time smoke test** — `godot --headless
  --quit-after 1 -- --splash` runs before any `.gd`-touching commit.

## Stage 9.8.1 — Hotfix: Ember Maw-route bug **[CLOSED 2026-06-04]**

**Diagnosis correction:** The original task description claimed the
summary modal failed to surface. Re-reading `/tmp/erebus.log`
(T+91604 `end_run via=ascend` → T+92944 `load_game OK
zone=forsaken_crypt` → T+92945 BIG_JUMP teleport) proved the modal +
rollback chain ran correctly. The real bug matched the user's
verbatim report: Ember-in-Maw landed the player at the pre-portal
anchor (crypt boss room) instead of Threshold Camp.

That's "working as designed" for the death case (rollback to anchor
preserves endless's no-save model) but wrong for Ember, which is the
voluntary town-return affordance. Stage 19 will incidentally fix the
anchor by moving the Maw entrance to town; 9.8.1 ensures Ember always
reads as "go to town" regardless of where the anchor lives.

* \[x] `EndlessRun.ended_via_ember: bool` added; `end_run(false)`
  sets it true (Ember), `end_run(true)` sets it false (death).
  Preserved across `rollback()` so game.gd's summary-return chain
  can read it after the load wipes other state.
* \[x] `end_run` DebugLog tag corrected: `via=ember` for the
  voluntary-exit branch (was `via=ascend`, a holdover from the
  retired AscentSpire).
* \[x] `game.gd::_on_endless_summary_return` branches on the flag:
  on Ember exit, after the existing rollback + load + milestone-
  recommit chain, sets `GameState.current_zone_id = threshold_camp`,
  re-saves, and force-transits to `threshold_camp / SpawnPoint`.
  Death path unchanged — still routes through `_resume_saved_zone()`.
  `[endless]` DebugLog entries trace which arm fired.
* \[x] `--verify9_8` extended (8 new asserts, 57 → 65 total):
  `ended_via_ember` field exists, flag flips correctly for both
  end_run branches, `rollback()` preserves the flag, game.gd source
  references `ended_via_ember` and routes to `threshold_camp`.
* \[x] All thirteen verifiers PASS post-hotfix.
* \[x] Smoke playtest: Ember inside Maw → summary modal → rollback
  → arrival at Threshold Camp `SpawnPoint` (user-confirmed 2026-06-04).
* \[x] Smoke playtest: Ember outside Maw (from crypt or wilderness)
  → SceneRouter transit → arrival at Threshold Camp `SpawnPoint`
  (user-confirmed 2026-06-04).

## Stage 11 — AI asset-generation pipeline  **[CLOSED 2026-06-04]**

Stage was previously "Save/load hardening" (renumbered to Stage 22).
The 2026-06-04 scope reset claimed Stage 11 for the hybrid art /
audio / video pipeline so every later stage can pull on it.

* \[x] `tools/asset_gen/` directory created with `gen_sprite.sh`,
  `gen_voice.sh`, `gen_sfx.sh`, `gen_video.sh` shells + shared
  `lib/common.sh` (secrets sourcing, sha256, sidecar writer +
  validator hook, JSON builder). All four wrappers ship in
  **dry-run mode** — they emit a stub asset + a full sidecar so the
  contract is exercised end-to-end without spend. `--live` flag is
  the explicit opt-in once a key file exists; live code paths are
  stubbed with `err "live mode not yet implemented"` until a real
  asset stage needs them.
* \[x] `tools/asset_gen/README.md` documents the `~/.config/erebus-secrets/`
  layout (replicate.env, elevenlabs.env, runway.env), wrapper usage,
  sidecar contract pointer, and cost discipline (per-stage $20 / $50 /
  $100+ ceilings from `rules/asset-generation.md`).
* \[x] Reproducibility sidecar schema validator
  (`tools/asset_gen/validate_sidecar.py`). Enforces every required
  key (tool, model, prompt, seed, params, output\_sha256,
  generated\_at ISO-8601 UTC, generated\_by, purpose, license,
  cost\_usd >= 0), known-tool whitelist, sha256 hex format. Run
  automatically by every wrapper write and exposed as a standalone
  CLI for repo-wide sweeps.
* \[x] `.gitattributes` configured for LFS: `*.ogg / *.wav / *.mp3 /
  *.webm / *.mp4 / *.mov` always go through LFS. Sidecars (`*.json`)
  explicitly pinned to plain git via `-filter -diff -merge text`.
  Large PNGs (>1MB) get tracked per-file via `git lfs track`
  at write time — small-PNG sprite case stays on plain git so the
  repo remains clonable without LFS.
* \[x] `BitmapMode` autoload (`scripts/systems/bitmap_mode.gd`),
  registered in `project.godot` after `ConsumableUse`. Default
  `enabled = true`. CLI flag `--procedural-only` (read from
  `OS.get_cmdline_user_args()` in `_ready`) forces OFF process-wide.
  Per-emitter `mode_changed(enabled: bool)` signal lets sprite
  scenes react to runtime toggle without polling. Sprite-side
  integration lands in Stage 15 (paper-doll); the autoload + flag
  are enough for Stage 11.
* \[x] Hybrid-baseline assertion section added to `commands/audit.md`
  (item #10). Covers: bitmap-without-procedural detection, the
  `--procedural-only` smoke launch as the runtime check, and a
  find-based sidecar sweep that fails on any committed binary with
  no `.json` sibling. Cost-ceiling reminder included.
* \[x] `--verify11` (33 / 33 PASS): every wrapper present +
  executable, validator accepts good fixture, validator rejects
  fixture missing required keys, dry-run `gen_sprite.sh` end-to-end
  + produced sidecar validates, `.gitattributes` LFS rules + sidecar
  carve-out, BitmapMode autoload (registered, default-on,
  `mode_changed` signal round-trips through `set_enabled`),
  `--procedural-only` source-level wiring, `rules/asset-generation.md`
  + `audit.md` hybrid section present.
* \[x] Regression: all 13 verifiers PASS post-Stage-11.

## Stage 12 — Town → wilderness walkable transition  **[CLOSED 2026-06-04]**

Replaced the camp↔wilderness Portal interactable with a walkable
seam: a WalkGate trigger sits in a gap in the perimeter wall and
auto-transits the player when they walk into it. The Crypt entrance
(and, in Stage 19, the Maw entrance in town) stay as discrete
Portal interactables — "explicit doorway" semantics where E-press
is appropriate.

* \[x] Decision: **stitched zones with on-the-edge trigger** (the
  act1-status.md "probable path"). One big zone fights the existing
  `Zone` autoload + `_zone_cache` model, and Stage 13's seeded
  procgen needs re-rollable boundaries per zone. Stitched is cheaper.
* \[x] `WalkGate` node (`scripts/world/walk_gate.gd` +
  `scenes/world/walk_gate.tscn`). `Area2D` with `collision_mask=2`
  (player CharacterBody2D layer). Procedural `RoadArt` Polygon2D
  child draws a dark earthy 40×120 path tile. Three re-entry guards:
  `_armed` (false for `ARMING_DELAY = 0.25s` after `_ready` so the
  initial physics flush can't fire), `_consumed` (one-shot flag so
  no two transits queue in a single frame), and caller-side marker
  placement outside the trigger shape (verifier enforces).
* \[x] `TownSouthGate` (`threshold_camp.tscn`) at `(0, 400)` pointing
  at `&"blighted_reach"` with `arrival_marker = &"FromTownGate"`.
  Camp south wall split into `S_west` (-380, 400) + `S_east`
  (380, 400), each 600×40, leaving a 160px gap centered on x=0.
* \[x] `WildernessNorthGate` (`blighted_reach.tscn`) at `(0, -600)`
  pointing at `&"threshold_camp"` with `arrival_marker =
  &"FromBlightedReach"`. Reach north wall split into `N_west`
  (-560, -600) + `N_east` (560, -600), each 880×40, leaving a 160px
  gap. New `FromTownGate` Marker2D at `(0, -540)` for camp→reach
  arrivals; existing `SpawnPoint` and `FromForsakenCrypt` markers
  unchanged.
* \[x] Save state survives the transition: WalkGate calls the same
  `SceneRouter.go_to_zone` → `host.transit_to_zone` chain as Portal,
  so `_zone_cache` + `SaveSystem` round-trip remain unchanged. No
  schema bump needed for this stage.
* \[x] DebugLog `[transit]` instrumentation: WalkGate logs
  `walkgate_entered <name> -> <zone> (arrival=<marker>)` on each
  successful trigger, so the trail is distinguishable from a Portal
  interact in the log. Existing `_do_transit` `[transit]` lines
  already cover the destination side.
* \[x] `--verify12` (32 / 32 PASS): WalkGate class + scene load,
  collision_mask=2, both gates present with correct target_zone +
  arrival_marker, both perimeter walls split (S_west/S_east,
  N_west/N_east, legacy single 'S'/'N' removed), legacy portals
  removed, CryptPortal retained, arrival markers verified to sit
  outside the destination's reverse trigger band, arming guard +
  one-shot guard + ARMING_DELAY constant present in source.
* \[x] `--verify7` updated: Portal-only assertion now accepts either
  Portal or WalkGate for the camp↔reach transit (Stage 12 contract).
* \[x] **Stage 12.1 — beyond-the-gate dressing.** User asked whether
  the wilderness should be visible from town (and vice versa). A full
  D2-style streaming world was rejected as a 2–4 week architectural
  rewrite that fights AD-12, Stages 13 + 19, and the per-zone save
  cache — see `parking_lot.md::streaming-world-architecture` for
  the revisit trigger. Instead, each zone ships a procedural dressing
  prop on the far side of its gap so the player sees "the world
  beyond" as they approach:
  - `BeyondWilderness` (camp, z_index=-50, south of TownSouthGate):
    dark mucky ground polygon + ground shadow, four darkened dead-tree
    instances (scaled 0.7–0.85, tinted misty grey-blue), low-alpha
    fog band straddling the wall plane.
  - `BeyondCamp` (reach, z_index=-50, north of WildernessNorthGate):
    warmer brown ground polygon + glow, a darkened firepit instance,
    three darkened tent instances, fog band.
  All purely visual — no physics, no enemies, no live data. Renders
  on every machine because it's just Polygon2D + scene instances.
* \[x] Regression: all 14 verifiers PASS post-Stage-12 + 12.1.
* \[ ] Smoke playtest (user-driven): walk south from Threshold Camp,
  see the wilderness silhouettes through the gap → walk into the gap
  → arrive in Blighted Reach near the north edge → walk north, see
  camp silhouettes through the gap → walk back through.

## Stage 13 — Wilderness procedural generation  **[CLOSED 2026-06-04]**

Pilot on Blighted Reach. Multi-zone chaining + min/max distance
gating + path winding are deferred to Stage 20 (wilderness authorship
at scale); Stage 13 builds the foundation that makes them trivial.

* \[x] `WorldSeed` autoload (`scripts/systems/world_seed.gd`,
  registered after BitmapMode in `project.godot`). Public API:
  `assign_random()`, `sub_seed(zone_id, salt=0) -> int`,
  `make_rng(zone_id, salt=0) -> RandomNumberGenerator`,
  `encode_seed(int) -> "EREBUS-XXXX-XXXX"`, `decode_seed(String)`,
  `snapshot/restore/clear_runtime`. Share-string format reuses
  EndlessRun's base-32 alphabet so users have one mental model
  for "share this seed."
* \[x] Sub-seed derivation: `hash("master:zone_id:salt")`. Same
  inputs → same int, every machine, every load. Salts (`SALT_PROPS=1`,
  `SALT_ANCHORS=2`, `SALT_PALETTE=3`) give independent RNG streams
  per concern so reshuffling props doesn't move anchors.
* \[x] Save schema **v14 → v15**: `world_seed` field added; migration
  defaults legacy saves to 0 (deterministic — reroll on new-game).
  `SaveSystem._apply` restores BEFORE `_resume_saved_zone` so the
  zone's procgen reads the right seed.
* \[x] Character-select hook: `_on_begin_pressed` calls
  `WorldSeed.assign_random()` before `change_scene_to_file(game.tscn)`.
  The save-resume branch in `main.gd` skips this screen so resumed
  games keep their previously-rolled seed.
* \[x] Tree variants (3, all procedural Polygon2D scenes):
  `dead_tree.tscn` (existing), `withered_pine.tscn` (taller / narrower,
  multi-bough silhouette), `broken_stump.tscn` (short / wide / jagged
  top).
* \[x] Rock variants (3, all procedural Polygon2D scenes):
  `rock_round.tscn` (small dome), `rock_angular.tscn` (jagged
  multi-face), `rock_flat.tscn` (wide slab with crack).
* \[x] Enemy palette swap system — `EnemySpritePalette`
  (`scripts/enemies/enemy_sprite_palette.gd`) attached as the script
  on each procedural sprite root. `palette_table` is baked in the
  scene per archetype; `apply(variant)` re-tints named Polygon2D
  children via `get_node_or_null(NodePath)`. Variant 0 = default
  (no-op). Variant 1 baked for both `shade_wretch_sprite.tscn`
  (paler ashen + cool eye glow) and `bog_caller_sprite.tscn` (rust-
  brown robe + amber orb). Zero shader cost — runs on any machine.
* \[x] `Enemy.palette_variant: int` export; `Enemy._ready` forwards
  it to the sprite via duck-typed `palette_variant` set BEFORE
  `add_child` so the sprite's first tint pass picks it up.
* \[x] `SpawnDirector.palette_per_archetype: Dictionary` (StringName
  → int). Zone procgen sets this once at zone load; `_spawn_one`
  forwards `palette_per_archetype[id]` to each new enemy.
  Director's `_collect_anchors` + initial spawn loop now deferred
  to next idle tick so the zone's `_ready` finishes populating
  `SpawnAnchors` before the scan runs.
* \[x] `ZoneProcgen` (`scripts/systems/zone_procgen.gd`, stateless
  Object). `generate_for(zone_id, bounds, exclusions, prop_count,
  anchor_count, tree_weight)` returns
  `{ props: [{kind, variant, pos, scale, rotation}], anchors:
  [Vector2], palette: {archetype: variant} }`. Reject-sampling
  enforces min-distance separation between props (28px) and
  between anchors (180px) plus exclusion-rect masking around gates
  / portals.
* \[x] `BlightedReach._ready` runs `ZoneProcgen.generate_for` with
  `PROP_BOUNDS = Rect2(-880, -480, 1760, 960)`, `EXCLUSIONS` for
  the WildernessNorthGate corridor and CryptPortal footprint,
  `PROP_COUNT=18`, `ANCHOR_COUNT=10`, `TREE_WEIGHT=0.65`.
  Populates `Trees` + `SpawnAnchors` containers and forwards the
  palette pick to SpawnDirector.
* \[x] `blighted_reach.tscn` trimmed: legacy T0–T11 + A0–A8 removed;
  Trees + SpawnAnchors are empty containers procgen fills at runtime.
* \[x] `--verify13` (55 / 55 PASS): WorldSeed API + autoload,
  sub_seed determinism (same inputs → same int) + divergence (across
  salts / zone_ids / master_seed), share-string encode round-trip,
  SAVE_VERSION ≥ 15 + v14 → v15 migration installs `world_seed`,
  all 3 tree + 3 rock variant scenes load, sprite scenes carry
  EnemySpritePalette + palette_table, `apply(1)` re-tints Body/Cloak,
  Enemy/SpawnDirector palette wiring source-asserted, ZoneProcgen
  result shape, determinism (same seed → identical props +
  palette), divergence (different master_seed → at least one prop
  differs), Blighted Reach scene trim + `_run_procgen` call site.
* \[x] Regression: all 15 verifiers PASS post-Stage-13.
  `--verify9_8` SAVE_VERSION assertion relaxed `== 14` → `>= 14`
  for forward compatibility.
* \[ ] Smoke playtest (user-driven): start a new game → confirm
  Blighted Reach loads with a fresh tree layout + at least one
  rock visible + enemies of one of the two palette flavors.
  Save → quit → reload → confirm the layout is byte-identical.
  Optional: start a second new game and confirm the layout
  differs (different master seed).

## Stage 14 — Waypoint system  **[CLOSED 2026-06-05]**

Theme name locked 2026-06-05: **"The Sundered Ferry"** (user explicit
approval). Charon's old ferry-paths still cross the underworld; you
light a brazier at each waypoint you find, and a spectral ferryman
returns to take you back. Brazier visual is procedural (cold blue-grey
flame; lights amber + adds soft halo on discovery via tween).
Bitmap polish deferred to Stage 21.

* \[x] `Waypoint` (`scripts/world/waypoint.gd` + `scenes/world/
  waypoint.tscn`) extends Portal so it inherits click-to-interact +
  selection ring + proximity prompt for free. Override `interact()`
  marks the zone discovered (`GameState.discovered_waypoints.append`),
  plays the discover SFX + tween once, and emits `menu_requested`
  instead of running a direct zone transit.
* \[x] Procedural brazier-on-pier visual: PierBase + PierTopEdge +
  StonePillar + Bowl + Flame (large) + FlameInner (highlight) +
  Glow halo. All Polygon2D — zero shader cost.
* \[x] `GameState.discovered_waypoints: Array` (zone_id strings).
  `reset_run` clears it.
* \[x] Save schema **v16 → v17** — `discovered_waypoints` key added;
  migration defaults legacy saves to empty array. New games re-roll
  fresh; loads carry the player's discovery list forward.
* \[x] `ZoneProcgen` extended: new `SALT_WAYPOINT = 4`; `generate_for`
  reject-samples a `waypoint_pos: Vector2` with a 220px exclusion
  radius against rolled anchors so the brazier never spawns inside
  a spawn ring. Falls back to bounds-center after 96 attempts.
* \[x] `BlightedReach._place_waypoint`: instantiates the Waypoint
  scene at the procgen pos, adds a `FromWaypoint` Marker2D 40px
  south for arrival placement. Idempotent against double `_ready`.
* \[x] `threshold_camp.tscn` gains a `FromWaypoint` Marker2D at
  (0, 140) — the hub has no brazier (it's the always-reachable
  default), just an arrival landing pad.
* \[x] `WaypointMenu` (`scenes/ui/waypoint_menu.tscn` +
  `scripts/ui/waypoint_menu.gd`, CanvasLayer layer 72). Title
  "The Sundered Ferry", subtitle "Choose a destination," list of
  buttons (Threshold Camp + every discovered wilderness zone, sans
  the origin), Close button. Pauses via `Engine.time_scale = 0` +
  `PROCESS_MODE_ALWAYS` (matches MilestoneModal / EndlessSummary
  pattern). Esc closes.
* \[x] `game.gd` hosts the menu, wires `Waypoint.menu_requested →
  _waypoint_menu.show_menu` in `_wire_zone_npcs`, and routes
  `_waypoint_menu.travel_requested → _do_transit(zone, true,
  "FromWaypoint", true)`. `[transit] waypoint_travel -> <zone>` log.
* \[x] AudioBank entries: `waypoint_discover`, `waypoint_travel`
  (placeholder .ogg files per asset-pipeline rule; code lands now,
  audio drops in later).
* \[x] `--verify14` (37 / 37 PASS): SAVE_VERSION ≥ 17 + v16 → v17
  migration installs `discovered_waypoints` empty,
  GameState field + reset_run clearance, Waypoint scene loads as
  Waypoint with display_name + flame/glow children, source asserts
  for `extends Portal` + `menu_requested` + discovery append,
  ZoneProcgen returns `waypoint_pos` within bounds + same seed →
  identical pos + different master_seed → different pos,
  WaypointMenu scene + show/hide API + travel_requested signal,
  source-level Engine.time_scale pause + resume + PROCESS_MODE_ALWAYS,
  Blighted Reach `_place_waypoint` consumes `waypoint_pos` + adds
  FromWaypoint, threshold_camp has FromWaypoint, AudioBank entries
  present, game.gd holds reference + connects + routes via
  FromWaypoint, game.tscn instances WaypointMenu, round-trip
  preservation through migrate.
* \[x] Regression: all 16 verifiers PASS post-Stage-14.
* \[x] **Stage 14.3 — brazier collision_layer doesn't block LOS
  (post-playtest fix).** User reported "mobs are not hostile until
  I move" after waypoint arrival. Diagnosis: Waypoint inherits
  Portal's StaticBody2D root which defaults to `collision_layer = 1`
  (the walls layer). Wilderness enemy LOS raycasts on the same
  layer, so the brazier's own capsule collider sat in the line of
  sight between every nearby enemy and the player. Moving even one
  step shifted the player out of the shadow and triggered aggro.
  Fix: Waypoint `collision_layer = 0` (non-blocking; player can
  walk through visually, but the brazier is small and the player
  rarely overlaps). Failure-mode entry added so the same trap
  catches future in-zone interactables (Stage 19 Maw-in-town +
  Stage 20 wilderness props). Verifier
  `--verify14::_verify_waypoint_does_not_block_los` guards regression.

* \[x] **Stage 14.2 — no-pause + damage interrupt (user-locked
  design call 2026-06-05).** First playtest of the menu used the
  MilestoneModal pause pattern (`Engine.time_scale = 0` on open).
  User asked whether to keep it or make waypoint use tactical —
  picked the tactical path. The menu no longer pauses; the world
  keeps moving. Taking damage instantly closes the menu (parallels
  the Hearth Ember channel-interrupt pattern — use the safe tool,
  stay safe). Backdrop alpha dropped to 0.18 and mouse_filter set
  to IGNORE so world clicks (movement, attacks) reach the player
  while the menu is up; only the panel + buttons catch input. The
  menu's `_hook_damage_interrupt` subscribes to
  `GameState.player.get_health_component().damaged` on show and
  unsubscribes on hide. Verifier source-asserts the no-pause +
  damage-wire contract so a future refactor can't silently revert.

* \[x] **Stage 14.1 — town hub brazier (post-playtest polish).**
  User reported that with only a Reach brazier, the system was
  "pointless" — walking back through the gate is identical. Added:
  - `Waypoint.starts_lit: bool` export. When true, the brazier is
    lit at all times, the discovery flow is skipped (no SFX, no
    array append, no tween).
  - Hand-placed town Waypoint in `threshold_camp.tscn` at (300, 180)
    with `starts_lit = true`. Acts as the always-available home
    dock.
  - `FromWaypoint` marker in town moved from camp-center (0, 140)
    to (300, 220) — adjacent to the brazier so waypoint arrivals
    land at the brazier, matching the wilderness behavior.
  - Stage 20 entry carries a note: when the second wilderness zone
    ships, the Reach brazier should relocate deeper into the chain
    so discovery represents real fast-travel value.
* \[ ] Smoke playtest (user-driven): start a new game → walk to
  the lit town brazier (east of campfire) → press E → menu opens
  with Threshold Camp suppressed (you're already there) →
  Blighted Reach appears only after discovery. Walk to Reach →
  discover its brazier → travel back via menu → arrive at the
  town brazier (not camp center).

## Stage 15.1 — Hotfix bundle (zone_id + weapon dmg + consumable prefix + save repair)  **[CLOSED 2026-06-05]**

Four bugs surfaced from Stage 15 playtest — all unrelated to the
paper-doll itself but all blocking the next playtest. Bundled into
one stage so the on-disk save format only bumps once.

* \[x] **Stale `current_zone_id` on transit** — `_do_transit` now
  writes `GameState.current_zone_id = zone_id`. Save migration
  v17→v18 repairs affected saves by snapping out-of-bounds
  positions back to the recorded zone's SpawnPoint. Per-zone
  bounds + spawn live in `SaveSystem._STALE_ZONE_REPAIR`.
  Failure-mode entry added.
* \[x] **Weapons did not contribute damage** — added
  `ItemData.base_weapon_damage`, rolled into
  `Stats.weapon_damage` via Inventory totals, folded into
  outgoing attack `base` by DamageResolver. Bare hands → 0,
  swing still resolves on `ATTACK_BASE_DAMAGE + STR/4`. Starter
  weapons backfilled: spear +10, bow +8, staff/wand +5.
* \[x] **Consumables rolled rare prefixes** — `maybe_roll_prefix`
  early-returns when the base item's kind is CONSUMABLE.
  Equipment drops still roll normally.
* \[x] **Save migration v17→v18** runs automatically on load.
  Affected playthrough recoverable without manual edit. When
  stale-zone repair triggers, the top-level `enemies` + `loot`
  snapshots are also dropped — they belonged to the zone the
  player was actually in and would otherwise spawn at wrong-zone
  coordinates (sometimes inside town with the player). The
  destination zone re-spawns from SpawnDirector defaults.
* \[x] `--verify15_1` covers all four: 25 assertions including
  the exact reported-save position (x=1.05, y=-584.24) repairing
  to threshold_camp SpawnPoint (0, 140), enemy/loot cleanup on
  stale repair, and in-bounds saves keeping their snapshots.

## Stage 15 — Equipment paper-doll rendering  **[CLOSED 2026-06-05]**

The procedural sprite gains slot layers. Equipping a helmet adds a
helmet node visible on the sprite; equipping a weapon adds the
weapon visual; unequipping a weapon reverts to a bare-hands stance.

* \[x] Procedural overlay layout: armor overlays (HEAD/CHEST/LEGS/
  OFFHAND) parent under each class sprite's existing `Body` node;
  no .tscn refactor needed. Per-class polygon geometry lives in
  `EquipmentVisuals` (autoload).
* \[x] Tier banding: overlay color reflects item magnitude (sum of
  base armor/AR/resist) — dull / normal / bright. Affix-only items
  read as dull, gating the visual feedback by quantity not type.
* \[x] `EquipmentPaperdoll` component on Player listens to
  `Inventory.equipment_changed` and maintains overlay nodes.
* \[x] Bare-hands rule: WEAPON slot empty → class's built-in weapon
  arm (SpearArm / StaffArm / BowArm / WandArm) is `.visible = false`.
  Equipping a weapon shows the arm + retints by tier. The
  AnimationPlayer track still drives the hidden arm (verified) so
  re-equipping snaps to the right rotation.
* \[x] Myrmidon offhand re-uses the built-in Buckler node (retinted
  in place); other classes get a procedural disc on the off-hip.
* \[x] RING / AMULET render nothing in Act 1 (verifier asserts).
* \[x] Class swap rebinds the paperdoll to the new sprite (Pythia →
  StaffArm + Pythia overlay polygons; verified).
* \[x] Hybrid art contract: procedural overlays are the always-
  shippable baseline. When Stage 11's bitmap pipeline produces a
  per-slot Sprite2D, the paperdoll will prefer it iff
  `BitmapMode.enabled` AND the sidecar is present. Procedural is
  never blocked on AI.
* \[x] Failure modes: paper-doll bind/_paint race (call_deferred
  pattern), hidden weapon arm vs AnimationPlayer track — both
  documented + verifier-guarded.
* \[x] `--verify15` covers: 35 assertions including registry tables,
  tier bands, overlay parenting under Body, bare-hands hide,
  weapon-on-equip show, unequip clears + frees overlay, class swap
  rebind, AnimationPlayer track survives visibility toggle.
* \[x] Save/load: nothing extra needed — equipment state lives in
  `Inventory.equipped` (already versioned). On load, restore() emits
  `equipment_changed` per slot and the paperdoll rebuilds from that.

## Stage 16 — Item icons (inventory grid)

Replace the text-row inventory UI with an icon grid. Drag/drop is
*not* in scope here (parked); single-click to equip / use persists
from current `inventory_panel.gd`.

* \[x] Per-item icon Control (`scripts/ui/item_icon.gd`,
  `class_name ItemIcon extends Control`). 40×40 cell, draws the
  same shape/color as `ItemGlyph` inside a tier-colored ring
  (`EquipmentVisuals.TIER_*`, shared with the paper-doll so
  rare items glow consistently in both UIs). Sidecar bitmap
  override at `res://data/icons/<item_id>.png` when present
  (procedural fallback when not — Stage 11 hybrid art policy).
* \[x] `InventoryPanel` (`scenes/ui/inventory_panel.{gd,tscn}`)
  swaps the two `VBoxContainer` lists for `GridContainer`s:
  backpack = 6 columns × 6 rows (36 cells = `Inventory.BACKPACK_CAPACITY`,
  AD-10), equipment = 3 columns × 4 rows in paper-doll layout
  (Head top-center, Amulet/Chest/Ring middle row, Legs lower,
  Weapon/Offhand bottom flanks). Empty slots render as a flat dark
  cell with a faint border.
* \[x] Single-click semantics from Stage 4/9.8 preserved: equipment
  cell → `Inventory.equip(id)` (or `unequip(slot)` from the
  equipment grid), consumable cell → `_on_consumable_pressed` →
  `ConsumableUse.try_use`. Disabled state (class/level lock,
  cooldown, channel-in-progress) dims the icon to 35% alpha and
  drops the `pressed` wiring.
* \[x] Hover tooltip (`PanelContainer` parented under the
  `CanvasLayer`, NOT under a cell — prevents `ScrollContainer`
  clipping; failure-modes entry added). Tooltip carries the same
  text the old row used (`_format_brief` / `_format_consumable_brief`)
  plus the slot name for equipment. Tooltip auto-flips above the
  cell when it would overflow the viewport bottom.
* \[x] `--verify16` (`test/stage16_verify.{gd,tscn}`, 19 PASS):
  - `ItemIcon` API surface (`set_item`, `set_empty`, `set_disabled`,
    `pressed`/`hovered` signals, `CELL_SIZE = 40×40`).
  - `BackGrid` is a 6-column `GridContainer` with exactly 36
    `ItemIcon` children.
  - `EquipGrid` is a 3-column `GridContainer` with 7 `ItemIcon`
    cells (one per `EquipmentSlot.ALL_SLOTS` entry).
  - Every backpack id resolves to a non-empty icon (no leftover text
    fallback).
  - Hovering an icon shows the tooltip and the tooltip text contains
    the item's display name + stats brief.
  - Consumable cell wires `pressed -> _on_consumable_pressed`
    (not `Inventory.equip`).
* \[x] Verifier matrix: Stages 1, 3, 4, 5, 6, 7, 7.5, 9, 9.5, 9.7,
  9.8, 10, 11, 12, 13, 14, 15, 15.1, 16 all PASS. Stage 8 still
  shows the pre-existing synth-prefix save round-trip failure
  inherited from before Stage 16 (unchanged by this stage; tracked
  separately).
* \[x] README updated (status line + `--verify16` in the verifier
  list).

## Stage 17 — NPC voice + portraits

Each town NPC gets a one-time intro line on first interact. The line
audio is AI-generated (ElevenLabs voice per NPC), the portrait is
AI-generated (Replicate). Procedural fallback: text-only intro with
no audio.

* \[ ] NPC roster: Kallias (vendor), Eurynome (quest-giver). Add
  others as town scope grows.
* \[ ] Each NPC defines a `voice_id` + `portrait_id` on their data
  resource. Missing assets fall back gracefully.
* \[ ] Dialog system extended to show a portrait + play voice line
  on first interact per save.
* \[ ] Voice generation budget: $5/NPC ceiling; prompts archive in
  the sidecar.
* \[ ] `--verify17` covers: NPC resource references resolve, dialog
  flow with + without assets, voice plays exactly once per save.

## Stage 17.5 — Procedural sprite anatomy v2

> **PARTIALLY SUPERSEDED 2026-06-13 by `rules/sprite-animation.md`.**
> The 2026-06-11 baseline reset collapsed every player/enemy/NPC onto
> the single white `baseline_white_sprite` rig and archived the old
> per-entity sprites. That changes this stage's premise:
> - The species roster is now **HUMAN / DEMON / BEAST / UNDEAD /
>   CONSTRUCT** (5 species). The old `HUMANOID` family collapses into
>   HUMAN+skin and `FLYING` becomes a locomotion *sub-variant*, not a
>   family — see the rule.
> - "Rebuild each existing sprite" is replaced by "**derive each
>   species rig from the white baseline, then express every named
>   character as a data-driven `CharacterDef`**" (registry, not scene
>   files). The execution moves to **Stage 17.6** (species rigs) and
>   **Stage 17.7** (character registry + selection).
> - The anatomy-family *part-set sketches* below remain the useful
>   reference for what each species rig must expose. Read them as rig
>   contracts, not as a list of sprites to hand-rebuild.
> - Bespoke unique bosses (Hexacheir) are unchanged — still registered
>   by id, not as a species skin.

Rebuild the procedural sprite anatomy across all four player
classes, all NPCs, and every existing enemy archetype around a set
of **anatomy families**. The Bone Servant's current anatomy is
*its own* — it's a skeleton — and stays as the UNDEAD family
anchor; it is NOT applied to humans or other creatures. Each
sprite picks an anatomy family appropriate to what it is.

Modular sprite contract (one Polygon2D per semantic part, AD-11) is
preserved across all families — only the part *set* per family
differs.

**Anatomy families (six shared + per-unique-boss bespoke):**

| Family    | Part-set sketch                                                    | Sprites this stage                                  |
|-----------|--------------------------------------------------------------------|------------------------------------------------------|
| HUMAN     | Skull-under-skin, neck, torso (no visible ribs), upper/lower arms, hands, hips, upper/lower legs, feet — full joint pivots. | 4 player classes (Myrmidon, Pythia, Shade-Hunter, Ossuary Priest) + NPCs (Kallias, Eurynome) |
| HUMANOID  | HUMAN base + species mods (extra digits, tail anchor, horn pair, etc.). Reserved part slots for Stage 20 monstrous mortals. | Contract only — no sprites yet                       |
| UNDEAD    | Skeleton subtype: skull, jaw, sternum, ribs, spine, pelvis, articulated limbs, hip cloth (Bone Servant template). Wraith subtype: hood + cloak + face void + tattered hem + articulated upper limbs; no legs (floats). | Bone Servant (skeleton-subtype anchor, **unchanged**), Shade Wretch (wraith subtype, **new anatomy**), Bog Caller (wraith subtype, **new anatomy**) |
| BEAST     | Quadruped base: head, body trunk, four legs with shoulder/hip pivots, tail anchor. | Contract only — no sprites yet                       |
| DEMON     | HUMAN base + infernal mods: horn pair, hoof feet option, vestigial wing anchors, glowing eye sockets; bespoke entries may exceed this part set. | Hexacheir (bespoke six-arm DEMON Act Boss); shared contract otherwise reserved for Stage 20 |
| FLYING    | Reduced/no leg set, paired wings with shoulder + elbow pivots, light torso, claw feet. | Contract only — no sprites yet                       |

**Per-unique-boss bespoke anatomies:** each named unique boss
(Hexacheir, the God-Spurned now; Hekate-Marked retained only for
legacy/rare routing; future Act 1 unique bosses if added) gets its
**own anatomy entry**, not
a family slot. This is what lets a unique boss be larger / smaller /
asymmetric / multi-armed / partially-disassembled — properties a
shared family rig can't carry. The bespoke entry still uses the
modular sprite contract (one Polygon2D per part), it just doesn't
have to match any family's part-name set.

This stage authors the bespoke entry for **Hexacheir, the
God-Spurned** (current Act Boss, `act_boss_sprite.tscn`) and retains
Hekate-Marked as legacy bespoke routing metadata only. Stage 18 must
extend/refactor the boss state machine without reverting this current
boss identity.

**Bone Servant fate:** keep as-is. Visual untouched. It becomes the
UNDEAD skeleton-subtype anchor; future skeletal enemies inherit its
part-name contract and tweak proportions/colors only. Stage 18 +
Stage 20 inherit the skeleton-subtype rig for free.

**Shade Wretch + Bog Caller fate:** both rebuilt against the new
UNDEAD wraith-subtype part set (Hood / Cloak / CloakInner /
TatteredHem / FaceVoid / Eyes / articulated arms / claws — no
legs). Cloak palettes preserved (void-grey, bog-green). Animations
rebuilt; Bog Caller behavior now uses bait, dodge, and re-cast
pressure instead of pure retreat.

**Resolved scope decisions (2026-06-05):**
- **Articulation:** full joints inside each family (shoulder /
  elbow / hip / knee where the family has those limbs; wing pivots
  for FLYING; tail pivots for BEAST/DEMON).
- **AI bitmap sidecars:** contract + verifier this stage; no real
  generation yet. First generated sets land alongside Stage 18 / 20
  content authoring.
- **Visual direction (HUMAN family only — others as authored):**
  mythic Greek archetypes. Shared HUMAN rig; class identity comes
  from clothing + accoutrements:
  - **Myrmidon** — bronze-age hoplite: leather cuirass, greaves,
    crested helm, shield strap across chest.
  - **Pythia** — oracle: stained linen robes, laurel circlet,
    bare feet, ash-smudged hands.
  - **Shade-Hunter** — hooded leather cloak, vambraces, quiver
    strap, soft boots.
  - **Ossuary Priest** — ash-grey vestments hemmed with bone
    fragments, ritual scars (cloth-covered), hooded skull cap.
  - **Kallias (NPC vendor)** — patched merchant cloak, belt of
    pouches, weathered hands.
  - **Eurynome (NPC quest-giver)** — heavier ceremonial robe,
    veil, sigil at the throat.

**Why this stage lands here, not later:** anatomy is the contract
`EquipmentVisuals.OVERLAYS` builds against AND what every sprite's
AnimationPlayer tracks reference. Doing the refactor after Stage 18
(boss state-machine and any replacement boss sprite) and Stage 20
(10+ new enemy archetypes) means redoing every overlay + animation. Stage 17 (NPC portraits) is
independent of in-world sprite anatomy, so the order is
17 → 17.5 → 18 onward.

* \[ ] **Family registry** at `scripts/systems/anatomy_families.gd`
  (autoload or static): one entry per family above with the
  canonical part-name list it exposes under `Body/`. Per-unique-
  boss bespoke entries register separately by sprite id, not by
  family. Single source of truth for the rest of the stage.
* \[ ] **HUMAN family** part set (drives 4 players + 2 NPCs):
  `Body/Head`, `Body/Neck`, `Body/Torso`, `Body/Hips`,
  `Body/UpperArmL/R`, `Body/ForearmL/R`, `Body/HandL/R`,
  `Body/ThighL/R`, `Body/ShinL/R`, `Body/FootL/R`. No visible
  ribcage. Full joint pivots. Plus the existing weapon-arm node
  per class (`SpearArm` / `StaffArm` / `BowArm` / `WandArm`)
  where applicable.
* \[ ] **UNDEAD family — skeleton subtype** part set: documents
  the existing Bone Servant part set (Skull, Jaw, Spine, Pelvis,
  Rib1/2/3, Sternum, HipCloth, LegL/R, ArmAnchor/ArmUpper/
  ArmLower/Claw) AS the canonical skeleton-subtype contract.
  Bone Servant sprite is NOT edited.
* \[ ] **UNDEAD family — wraith subtype** part set authored
  fresh: Hood, Cloak (outer), CloakInner (paler underlayer for
  motion depth), TatteredHem (frayed bottom edge — animates
  with motion), FaceVoid, EyeL/R, ShoulderL/R anchors,
  ArmUpperL/R, ArmLowerL/R, ClawL/R. No legs (wraiths float —
  bottom edge fades into the shadow). Shoulder + elbow pivots
  on the arms; hem pivot for cloth motion.
* \[ ] **Shade Wretch + Bog Caller** rebuilt around the new
  wraith subtype part set. Shade Wretch keeps its current
  aggressive lunge silhouette (claws forward); Bog Caller
  keeps its staff (now parented under the wraith arm rather
  than free-floating). Cloak palettes preserved (Shade Wretch =
  void-grey, Bog Caller = bog-green). All six canonical
  animations rebuilt against the new part set.
* \[ ] **HUMANOID, BEAST, DEMON, FLYING** — contract + part-set
  declarations only this stage. No sprites authored. Stage 20
  consumes them.
* \[ ] **Hexacheir, the God-Spurned** bespoke entry registered in
  the family registry as the current six-arm DEMON Act Boss anatomy.
  Hekate-Marked remains registry-only legacy/rare routing metadata
  unless Stage 18 explicitly re-scopes it.
* \[ ] **HUMAN sprites** rebuilt: 4 player classes + 2 NPCs
  rebuilt around the HUMAN part set with their respective
  clothing/accoutrement polygons layered on top under `Body/`.
* \[ ] `EquipmentVisuals.OVERLAYS` re-anchored to the HUMAN
  part set (HEAD → `Body/Head`, CHEST → `Body/Torso`, LEGS →
  `Body/Hips` + `Body/ThighL/R`). Tier ring + color logic
  unchanged. Equipment overlays are HUMAN-only by contract;
  enemies and NPCs never receive them.
* \[ ] All six canonical animations (`idle`, `walk`, `attack`,
  `cast`, `hit`, `die` — AD-11) rebuilt on each touched
  sprite against the new part set: 4 HUMAN players, 2 HUMAN
  NPCs, Shade Wretch (wraith), Bog Caller (wraith). Bone
  Servant animations preserved as-is — its sprite isn't
  rebuilt. Verifier source-checks no AnimationPlayer track on
  a touched sprite still references a v1 part name.
* \[ ] **AI bitmap-swap contract for sprite parts** (sidecar
  layer): each `Polygon2D` part may have an optional sibling
  `Sprite2D` at `res://data/sprites/<sprite_id>/<part>.png`.
  When present, the Sprite2D renders and the Polygon2D hides;
  when absent, the procedural polygon ships. Mirrors the
  item-icon sidecar pattern from Stage 16. Works for every
  family AND every bespoke unique-boss anatomy. Hybrid art
  policy preserved.
* \[ ] `failure-modes.md` entries: (a) AnimationPlayer track
  binding survives part renames only if the rename happens in
  one editor pass — split renames orphan tracks silently;
  (b) sidecar Sprite2D must inherit the parent Polygon2D's
  `z_index` or the layer order goes wrong on hidden-weapon-arm
  toggles; (c) applying a family's part set to a sprite that
  shouldn't have it (e.g., putting a ribcage on a Pythia)
  silently passes structural checks — verifier asserts each
  sprite's declared family matches its part set.
* \[ ] `--verify17_5` covers: family registry loads with the
  expected six families + Hexacheir bespoke DEMON entry + retained
  Hekate-Marked legacy entry; every HUMAN sprite (4 players + 2 NPCs)
  exposes the full HUMAN part set under `Body/`; Bone Servant still
  exposes its skeleton-subtype part set unchanged; Shade Wretch + Bog
  Caller expose the new wraith-subtype part set; every overlay
  in `EquipmentVisuals.OVERLAYS` resolves to an existing path
  on each HUMAN class; no AnimationPlayer track on a touched
  sprite references a v1 part name; sidecar Sprite2D path is
  honored when a fixture PNG is dropped at the expected path;
  family-mismatch assertion (a HUMAN sprite must not declare
  UNDEAD parts, and vice versa).
* \[ ] Stage close-out includes a screenshot pass: idle pose on
  all four classes + both NPCs + both wilderness enemies +
  Bone Servant + Hexacheir, before/after side-by-side for the
  sprites that changed, attached to the commit.

## Stage 17.6 — Species base rigs (derive from baseline)

Governed by `rules/sprite-animation.md`. Author the **five species
base rigs**, each derived from the white `baseline_white_sprite` /
`HumanRig` — never from a blank scene. One rig per species; sub-variants
are derivation modifiers, not new rigs. Procedural only; no bitmaps yet
(hybrid art policy).

**Progress note (2026-06-13):** the **data spine landed first** — the
species registry, sub-variant axis, anim_set contract, canonical-anim
lock, DebugLog roster, and `--verify17_6` (53 PASS) are in. The actual
new **procedural rig geometry** (DEMON/BEAST/CONSTRUCT parts, wraith
rebuild) is deliberately deferred to visually-iterated increments at the
pose-tuner workbench, per `feedback_procedural_is_placeholder` — authoring
a quadruped/wraith rig blind would produce garbage. Items below are split
accordingly.

Data spine (done this session):
* \[x] **HUMAN** — baseline rig registered as the species anchor in
  `AnatomyFamilies` (no new rig; the baseline *is* HUMAN).
* \[x] **CONSTRUCT** species added: `Family.CONSTRUCT` + part set
  (HUMAN joint names + `Faceplate` + `CoreGlow`) so HUMAN anim tracks
  bind unchanged.
* \[x] **Sub-variant axis** registered: UNDEAD `skeleton`/`wraith`/
  `revenant` (REVENANT enum added); `winged`/`quadruped` reserved for
  BEAST/DEMON. `FLYING`/`HUMANOID` demoted to legacy enum entries (no
  sprite may register to them).
* \[x] **anim_sets** declared against the canonical six
  (`idle/walk/attack/cast/hit/die` — AD-11): `human_default`,
  `wraith_float`, `quadruped`, `construct_rigid`. Each maps to a real
  `SpriteMotionStances` stance; `anim_set_for()`/`sub_variant_name()`
  resolvers added. Shade Wretch + Bog Caller now resolve to
  `wraith_float`.
* \[x] **DebugLog** `sprite` flag: `AnatomyFamilies` prints the full
  roster (species → anim_set per sprite) under `-- --debug=sprite`.
* \[x] `failure-modes.md` entry: anim-name drift (`hurt`/`death`) +
  legacy-family re-use, with prevention + recovery.
* \[x] `--verify17_6` (`test/stage17_6_verify.{gd,tscn}`, 53 PASS):
  five-species roster; CONSTRUCT part set keeps HUMAN joints; legacy
  families demoted + unused; canonical anims == AD-11 and never
  hurt/death; baseline builds all six; anim_set profiles + stances
  resolve; species defaults; resolver outputs; sub-variant names.
  `stage17_5_verify` re-run green (no regression).

Rig geometry (pending visual iteration — author at the workbench):

**Production order (binding, 2026-06-13).** Each sprite runs the proven
loop: derive/restore geometry from the baseline or
`art/procedural/archive/baseline_reset_2026_06_11/` (modular Polygon2D
parts) → build the six canonical anims via the species anim_set →
render strips to `docs/sprites/<id>/` → **Launch in Maw to play as it**
→ verifier assertions + failure-mode notes → iterate until it reads.
Most sprites exist archived: restore-and-refine, not author-blind.

- **Phase 1 — finish UNDEAD:** (1a) restore Bone Servant as the
  `skeleton` anchor; (1b) `revenant` sub-variant (HUMAN rig + decayed
  skin). Wraith already shipped + polished.
- **Phase 2 — HUMAN skins** (highest player-facing value): 4 classes
  (Myrmidon hoplite / Pythia oracle / Shade-Hunter hooded / Ossuary
  Priest ash) + 2 NPCs (Kallias, Eurynome) as skin/accoutrement layers
  on the shared baseline HUMAN rig. All archived — restore + refine.
- **Phase 3 — DEMON rig:** HUMAN base + horns / hooves / wing-anchors /
  eye-glow. Smallest non-human lift.
- **Phase 4 — CONSTRUCT rig:** HUMAN base + segmented joints +
  Faceplate/CoreGlow, `construct_rigid` anim_set.
- **Phase 5 — BEAST quadruped:** biggest deviation (four-leg gait,
  `quadruped` anim_set); authored last.
- **Phase 6 — bespoke bosses:** Hexacheir (act_boss) six-arm DEMON rig,
  registered by id (not a species skin).

Then **Stage 17.7** (CharacterDef registry + selection) consumes all of
the above.

* \[x] **UNDEAD wraith** rig geometry: hood + cloak + CloakInner +
  TatteredHem + FaceVoid + Eyes + articulated arms + claws, **no legs**,
  floats. Restored the proven archived wraith geometry to the live
  Shade Wretch + Bog Caller scenes (wired to `enemy_sprite_palette` /
  `SpriteRuntime2D`, which already carries the legless floating
  `_is_wraith_sprite()` motion branch); palettes preserved (void-grey /
  bog-green, staff+orb on Bog Caller). All six canonical anims build;
  resolves to `wraith_float`. Rendered to `docs/sprites/{shade_wretch,
  bog_caller}/` via `test/wraith_render.tscn` and reviewed — reads as a
  hooded floating wraith across idle/walk/attack/cast/hit/die.
  Asserted in `stage17_6_verify` (no legs, wraith part set, six anims);
  `stage17_5_verify` narrowed to exclude these two from baseline
  conformance (failure-mode #17.8 rule honored).
* \[x] **Wraith drift + hover (review pass 2026-06-13):** the wraith
  locomotion was rewritten from a stepping walk into a true **drift** in
  `SpriteRuntime2D` — no side-to-side step wobble, no rocking gait, just
  a slow vertical swell + trailing cloak/hem. The Body now **floats**
  (`hover_height`, ~6–7px) while the Shadow stays on the ground, opening
  a visible gap. Stance menus are **pruned per sprite**: wraiths get a
  single drift locomotion stance (no `lurch`/`stalk`), `dissolve`-only
  death, and the non-caster Shade Wretch is offered **no cast** stance
  (removed the stray "Chill" pose-tuner variant); Bog Caller keeps cast
  (it is a ranged caster). `stage17_6_verify` asserts the drift-only
  pruning + the off-ground hover; drift strips rendered to
  `docs/sprites/{shade_wretch,bog_caller}/_drift_strip.png`.
* \[x] **Drift-stance rename + all-sprites Maw launch (review pass 2):**
  the wraith locomotion stance `enemy_walk_hover` was renamed to
  `enemy_drift_hover` (a legless wraith should not be offered a "walk"
  stance); `stage17_6_verify` asserts no wraith locomotion stance id
  contains "walk". Separately, the pose-tuner **"Launch in Maw"** was
  half-built — it wrote `tmp/pose_tuner_launch.json` and started the
  game, but nothing consumed it for non-class sprites and the button was
  gated to player classes, so enemies/NPCs (e.g. the wraith) could not
  be launched. Now: the launcher writes `sprite_id` + `bucket` for ANY
  selected sprite, and `game.gd._apply_editor_launch` transits to The
  Maw so the chosen sprite can be previewed in real engine motion.
  Player-class launch path is unchanged.
* \[x] **Launch-in-Maw crash fix + play-AS-sprite (review pass 3):**
  the launcher crashed at `pose_tuner.gd` `_on_launch_game_pressed`
  with "Invalid access to key 'enemies' on a Dictionary" — the bucket
  guard used `_selected_stances.get(bk, {})`, whose default `{}` masks
  a *missing* key, so the bucket was never created and the next direct
  `[bk]` index threw. Fixed with a `has()` gate (same latent bug also
  fixed in the select-for-game handler). Behavior changed per user: a
  non-class sprite now makes the player **play AS** that sprite —
  `Player.set_avatar_sprite()` swaps the avatar to the procedural
  sprite scene (`sprite_scene` in the launch payload) while keeping
  Myrmidon mechanics, so movement/attacks drive the wraith's canonical
  anims and you fight the Maw's wave-spawned monsters. Verified
  end-to-end headless: `editor launch → preview avatar → player avatar
  -> ShadeWretchSprite (anim=yes)`, zero script errors.
* \[x] **UNDEAD skeleton** (Phase 1a, anchor): the archived bespoke
  skeleton was crude (single-polygon legs, one arm) — discarded. Bone
  Servant is **rebuilt on the shared HUMAN rig** (`HumanRig`, same
  anatomy as Myrmidon/baseline: two articulated arms with elbows, two
  legs with knees, real proportions) and **re-skinned as bone** in
  `bone_servant_sprite.{gd,tscn}`: bone-white limbs, a darkened chest
  cavity behind a bone-white ribcage + sternum, a tattered loincloth,
  and sickly-green eye-glow in dark sockets. Uses `SpriteRuntime2D`
  standard-leg anatomy (legs painted bone via `_standard_leg_color`) and
  the six canonical anims. This is the "skeleton = HUMAN rig + bone
  skin" sub-variant the model intends. `stage17_6_verify` asserts the
  HUMAN-rig parts + bone overlays + six anims + sub-variant=skeleton;
  `stage17_5_verify` lists bone_servant in the re-authored exclusion.
  Rendered to `docs/sprites/bone_servant/`.
* \[x] **UNDEAD revenant** rig (Phase 1b): HUMAN rig (full fleshed
  limbs) re-skinned as a gaunt risen corpse in `revenant_sprite.{gd,
  tscn}` — sickly grey-green necrotic flesh, a dirty torn tunic, a rip
  on the left chest with bone rib-slivers peeking through, a tattered
  hip rag, sunken sickly-green eye-glow, and one rotted (darker) arm for
  asymmetry. Registered `&"revenant"` UNDEAD/REVENANT in AnatomyFamilies
  (anim_set human_default; shamble comes from stance at character
  level). Six canonical anims via SpriteRuntime2D. `stage17_6_verify`
  asserts HUMAN-rig parts + decay overlays + six anims + sub-variant +
  parts-above-editor-BG. Rendered to `docs/sprites/revenant/`. Visual
  direction chosen by user: gaunt-corpse-in-torn-tunic + grey-green.
* \[x] **Phase 2 — HUMAN skins (data-driven system + all 6):**
  per user, built the **data-driven skin system first** —
  `scripts/systems/skin_library.gd` (`SkinLibrary`): `sprite_id` →
  `{ palette, parts:[{node,parent,poly,color,z}] }`. `SkinLibrary.apply`
  paints the shared HUMAN rig with the class palette + layers
  accoutrement Polygon2Ds (supports arbitrary parent paths, e.g. greaves
  on the knee pivot). This is the `skin` half of the Stage-17.7
  CharacterDef, brought forward. `baseline_white_sprite` now applies a
  SkinLibrary skin when one exists for its `sprite_id`, else the white
  baseline — so the existing class/NPC scenes auto-skin with **no
  bespoke scripts**. First skin authored: **Myrmidon** (bronze-age
  hoplite — bronze cuirass + waist band, shield strap, crested helm with
  red plume, bronze greaves; tan flesh). `stage17_6_verify` asserts the
  skin applies (accoutrement parts present, torso not white, six anims);
  `myrmidon` added to `stage17_5_verify` re-authored exclusion. Rendered
  to `docs/sprites/myrmidon/`. **All six authored as pure data:**
  Myrmidon (bronze hoplite), Pythia (violet oracle robe + gold circlet/
  laurel), Shade-Hunter (charcoal hood/cloak + teal quiver strap +
  vambraces/boots), Ossuary Priest (ash robe + hood + green chest sigil
  + bone-fragment hem), Kallias (patched merchant mantle/tunic + belt
  pouch), Eurynome (indigo ceremonial robe + veil + gold throat sigil).
  `stage17_6_verify` loops all six (skin registered, torso not white,
  accoutrements layered, six anims); all six in `stage17_5` re-authored
  exclusion. Rendered to `docs/sprites/<id>/`.
* \[~] **Phase 2 polish pass (readability):** user feedback — skins hard
  to decipher, no eyes, robed-walk looks static in editor.
  - **Faces/eyes (done):** `baseline_white_sprite._add_face()` adds
    sockets/eyes/brow/mouth (HumanRig face geo, z4 under helms/hoods) +
    always-visible eye glints (z6) to every **skinned** human. White
    placeholders + bespoke act_boss stay faceless (verifier-safe).
  - **Ossuary editor-walk diagnosed:** the walk anim is identical
    editor vs in-game (baseline_white_sprite has no IK/_process —
    `ik_enabled` is unused); the robe just hides the leg-swing and the
    editor walks in-place. Fix pending (shorten robe / skirt sway).
  - **Weapon display — all four done:** `baseline_white_sprite` paints +
    reveals the held weapon per `show_*` flag (tuner) — the same arms
    the in-game Stage-15 paper-doll reveals, so editor matches game.
    Spear (Myrmidon, on the arm → swings with attack); staff+violet orb
    (Pythia), bow+string (Shade-Hunter), wand+green glow (Ossuary)
    repositioned to the hand grip `_GRIP` and z-bumped (z5) so they
    aren't hidden behind robes. Render harness `show` flag +
    `<id>_armed` entries. Verified.
  - **Robed-walk visibility — done:** shortened the Pythia/Ossuary/
    Eurynome robes (+ their hem/trim/panel pieces) to mid-calf so the
    lower legs show and visibly swing during walk — reads as walking
    even standing in place in the editor, still robed. Verified via
    `_drift_strip`.
  - **Outlines + shading — done:** `baseline_white_sprite._apply_polish`
    adds, for every skinned human, a uniform dark outline behind each
    body/clothing part (`Geometry2D.offset_polygon`, child node so it
    follows animation) + a top-light/bottom-shadow vertex gradient for
    form. Tiny detail/glow parts (eyes/glints/orbs/sigils) skipped to
    stay crisp. Big decipherability win — parts now pop with clean
    edges + volume. Verified across the cast.

  **Phase 2 polish pass COMPLETE** — eyes/faces, weapon display (all 4),
  robed-walk visibility, outlines+shading all done. The HUMAN cast reads
  clearly, armed, with faces, and walks legibly.
* \[~] **Phase 2 review round (Pythia focus + QA tooling):**
  - **Sprite QA harness (3A) — done:** `test/sprite_qa.tscn` checks
    every registered sprite (anims build, NO orphaned tracks, no empty
    visible parts, no part below editor-BG z, sane bounds) → writes
    `docs/sprites/_qa_report.txt` + a labeled `_contact_sheet.png`. 11/11
    PASS. Documented as `rules/sprite-animation.md` §10; the workflow now
    grows a QA assertion + a failure-mode entry per new issue.
  - **Base-clothing vs equipment (2b-A) — rule locked + Pythia cut:**
    skins carry base clothing only; armor/headgear are equipment.
    Pythia recut to robe + trim/sash; circlet + laurel removed (→
    equipment). `rules/sprite-animation.md` §4 updated.
  - **Pythia face (2c/2d) — done:** elf-ear laurels removed; mouth/brow
    reshaped from flat bars to small tapered marks (`HumanRig`, shared).
  - **Editor weapon control (1A) — done:** root cause was the tuner
    binding the Stage-15 paper-doll for weapon-only variants, which
    installs `WeaponProfiles` IK pins that re-pose the weapon every frame
    and stomp slider edits. Fix: the tuner now binds the paper-doll ONLY
    when the variant equips *armor*; weapon-only/unarmed variants show
    the weapon via `show_*` (baseline's simple one-hand hold), fully
    controllable by the existing weapon-arm rotation/position sliders.
  - **Staff pose (2a-C) — done:** idle is now a vertical one-hand hold
    (the editor was showing the overridden two-hand `WeaponProfiles`
    grip; with 1A it uses `_paint_staff`'s vertical pose). Added an
    overhead chop to the attack anim (`Body/StaffArm:rotation` swing,
    gated on `show_staff`). Rendered `pythia_armed` idle+attack.
  - **Base-clothing recut — ALL classes done (2b-A "strip all"):** every
    skin is now base clothing only. Myrmidon → leather tunic + belt
    (helm/plume/cuirass/greaves/shield = equipment); Shade-Hunter →
    hunter tunic + belt + boots (hood/cloak/vambraces/quiver = equip);
    Ossuary → ash robe + bone hem + sigil (hood = equip); Kallias →
    tunic + belt + pouch (mantle = equip); Eurynome → ceremonial robe +
    panel + sigil (veil = equip); Pythia → linen robe + trim/sash
    (circlet/laurel = equip). All bare-headed with clean faces. QA 11/11,
    contact sheet refreshed, 17.5/17.6/13 green.
  - **WeaponProfiles aligned to one-hand holds — done:** fixed a latent
    bug (equipped weapons were *invisible* in-game — geometry was only
    painted under the editor's show_* flags). `baseline_white_sprite`
    now paints + z-bumps ALL weapon arms in `_ready` (so the in-game
    paper-doll reveals a painted weapon), and the baseline attack anim
    drives the weapon swings ungated (staff overhead chop, wand flick,
    spear arm-swing) so editor and game share them. `WeaponProfiles`
    `_build_weapon_anims` now returns `{}` for spear/staff/wand — it no
    longer imposes the two-handed grip; `install()` restores the baseline
    one-hand anims from the snapshot. Bow stays built-in; unarmed keeps
    the fist fallback.
  - **Equipment overlays verified — done:** the stripped armor/headgear
    is supplied by the existing Stage-15 `EquipmentVisuals` per-class
    overlays (HEAD Corinthian helm/diadem/circlet, CHEST cuirass/mantle/
    chasuble, LEGS greaves/robe-hem mounted on the knee pivots) + real
    armor items (`worn_helm`, `bronze_plate`, `simple_greaves`,
    `silken_robe`, `bone_chasuble`, `linen_wrap`…). Confirmed they layer
    cleanly over the NEW base clothing via geared renders
    (`docs/sprites/{myrmidon,pythia,ossuary_priest}_geared/`) through the
    real Inventory + EquipmentPaperdoll path — armored, robed, and caster
    classes all show equipped armor on top of base clothing. So 2b-A's
    "armor attaches later in game" is closed.
  - **Pending (polish, next):** overlay outlines/shading to match the
    base polish; fuller cuirass coverage now that it isn't decorating a
    baked cuirass; helm z over the face; bow-draw polish.
* \[ ] **DEMON** rig geometry: HUMAN base + horn pair, optional hoof
  feet, vestigial wing anchors, glowing eye sockets. Shared rig only;
  Hexacheir stays a bespoke id.
* \[ ] **BEAST** quadruped rig geometry derived from the baseline joint
  system (head, trunk, four legs w/ shoulder+hip pivots, tail); `winged`
  sub-variant adds paired wings. Biggest deviation — verify readability
  at ~32px. Build `quadruped` anims.
* \[ ] **CONSTRUCT** rig geometry: segmented/mechanical joints +
  metallic/stone skin + Faceplate/CoreGlow. Build `construct_rigid`
  anims (stiff interpolation, mechanical attack arc).
* \[ ] Modular contract (AD-11) preserved on every new rig — one
  Polygon2D per part, default-facing right, hit-flash parts under `Body`.
* \[ ] Extend `--verify17_6`: each new species rig exposes its declared
  part set; each anim_set builds all six canonical anims with no
  orphaned tracks; wraith has no legs; Bone Servant skeleton unchanged.
* \[ ] `failure-modes.md`: sidecar Sprite2D z_index inheritance;
  applying a species part set to the wrong species (silent structural
  pass).
* \[ ] Screenshot pass: idle on all five species + each UNDEAD
  sub-variant, attached to the closing commit.

## Stage 17.7 — Character registry + selection

Governed by `rules/sprite-animation.md`. Build the **data layer** that
selects what is displayed for any sprite slot. A character is a
`CharacterDef` record, not a scene.

* \[ ] `CharacterDef` resource + `CharacterRegistry` (autoload/static)
  loading `data/characters/*.tres`. Fields: `id`, `species`,
  `sub_variant`, `skin` (palette + accoutrement layer), `anim_set`,
  `stance_id`, `weapon_flags`, `equipment_slots` (HUMAN-only).
* \[ ] Runtime resolves an `id` → instantiate species rig → apply skin
  → build named anim_set → select stance → show declared weapon arms.
  Swapping the `CharacterDef` for a slot swaps **data only**, never a
  scene file.
* \[ ] Author `CharacterDef`s for the Act 1 cast: 4 player classes
  (HUMAN skins — bronze hoplite / oracle / hooded hunter / ash priest),
  2 NPCs (Kallias, Eurynome), current enemies (Bone Servant skeleton,
  Shade Wretch + Bog Caller wraith). Class identity comes from skin
  only — same HUMAN rig.
* \[ ] Migrate `ClassData.sprite_scene` + `Enemy.sprite_scene` →
  `character_id: StringName` resolved through the registry. PackedScene
  field kept as transitional fallback this stage, removed at stage
  close.
* \[ ] `EquipmentVisuals.OVERLAYS` re-anchored to the HUMAN rig part
  set; overlays resolve on every HUMAN character; enemies/NPCs never
  receive them.
* \[ ] Skin bitmap sidecar honored:
  `res://data/sprites/<character_id>/<part>.png` → Sprite2D renders,
  Polygon2D hides; absent → procedural ships. Missing bitmap blocks
  nothing.
* \[ ] DebugLog flag + workbench trigger to cycle through every
  registered `CharacterDef` and preview its skin + six anims.
* \[ ] `--verify17_7`: registry loads all expected ids; each id
  resolves to a live rig + builds six canonical anims; no live one-off
  `*_sprite.tscn` outside archive + bespoke bosses; species/sub-variant
  mismatch assertion; equipment overlays HUMAN-only; sidecar fixture
  PNG honored. Satisfies the "sprite animations complete" definition of
  done in `rules/sprite-animation.md` §9.
* \[ ] Screenshot pass: idle for every authored character, attached to
  the closing commit.

## Stage 18 — Boss state-machine cleanup + legacy rare-routing audit

Hexacheir, the God-Spurned is now the current first-demon Act Boss.
Stage 18 no longer assumes `act_boss.gd` is a Hekate-Marked Forsaken
entity to demote. Remaining work is state-machine cleanup around
`act_1_complete`, `boss_first_kill`, Maw portal gating, class-restricted
unique drops, and Eurynome's quest completion. Any Hekate/Forsaken rare
conversion must be scoped as separate legacy routing and must leave
Hexacheir's Act Boss identity intact.

* \[ ] Audit legacy Hekate/Forsaken routing; if retained as a rare,
  create a separate rare scene/script instead of stripping Hexacheir's
  `act_boss.gd` boss logic.
* \[ ] Class-restricted unique drop remains tied to the current Act Boss
  unless a later final-boss entity is explicitly introduced.
* \[ ] `act_1_complete` keys off the current Act Boss kill or the
  explicitly introduced replacement final-boss kill.
* \[ ] Eurynome's "defeat the boss" quest targets the current Act Boss
  or the explicitly introduced replacement final boss.
* \[ ] Maw portal gating (Stage 19) replaces the post-Act-Boss
  gate.
* \[ ] Save schema bump for any new state. Migration zeroes out the
  legacy `boss_first_kill` flag.
* \[ ] `--verify18` covers: state machine transitions; quest
  re-target; legacy save migration; Forsaken Rare drops correctly.

## Stage 19 — The Maw entrance moves to town

The Maw is no longer hidden at the back of the crypt. A visible
brazier / mouth-of-the-pit interactable in Threshold Camp leads
directly into The Maw. Gated: locked until the player has completed
at least one quest (gives EndlessRun an anchor to roll back to).

* \[ ] `MawEntrance` interactable in Threshold Camp. Locked state
  draws differently; locked interact shows a Eurynome flavor line.
* \[ ] Unlock condition: any quest is in state COMPLETED.
* \[ ] Stage 9.7's portal in `forsaken_crypt.gd` removed. Crypt
  becomes a finite explorable area; Forsaken Rare is its capstone.
* \[ ] EndlessRun's anchor model unchanged — anchor is still
  whichever zone the player saved in last. The town-gate path just
  ensures that save exists.
* \[ ] Save migration: legacy saves with a Maw-portal-spawned state
  clean up correctly on load.
* \[ ] `--verify19` covers: gate locked at fresh new-game, unlocked
  after first quest completion, interactable transits into Maw, exit
  via Ember/death returns to camp (not crypt).

## Stage 20 — Wilderness content authorship

The big content stage. 10+ wilderness zones, 5+ dungeons, winding
paths between, 5+ quests. This stage uses every piece of infrastructure
built in 11–19; if any of those is shaky, fix it before authorship.

* \[ ] Zone templates: 4–6 distinct wilderness templates (e.g.,
  Ashen Hollow, Veiled Marsh, Lethean Steps, Asphodel Path,
  Stygian Pass, Echoing Ribs). Names are working drafts.
* \[ ] Path winding: each zone has a "main road" that does not
  travel in a straight line; geometric or noise-based path shape.
* \[ ] 5+ dungeons distributed through the chain. Each is a
  multi-room interior with a small boss or capstone reward.
* \[ ] 5+ quests authored. Quest 1 = tutorial / first-quest gate
  for Maw. Quest 5 = "defeat the boss" town request.
* \[ ] Final boss encounter authored (designed; lands in this stage
  via Stage 18's state machine).
* \[ ] First-playthrough time-to-final-boss = 2+ hours.
* \[ ] **Sundered Ferry relocation (carry from Stage 14.1):** the
  Blighted Reach brazier is currently semi-pointless — the player
  can already walk back to town through the north gate, so its
  fast-travel value is zero when only one wilderness zone exists.
  Stage 14 placed it as foundation scaffolding. When zone 2+
  ships, move the Reach brazier deeper into the chain (zone 2 or
  later) so discovering a brazier represents real fast-travel
  value ("I can now skip the long walk back from this point"). The
  town brazier stays as the always-lit hub.
* \[ ] `--verify20` covers: zone count, quest count, dungeon count,
  Eurynome's final quest references the final boss, save round-trip
  works at the new content scale.

## Stage 21 — Feel pass at scale

The Stage 9.5 feel pass covered the systems that existed then.
Stage 21 re-applies the contract to everything authored in 12–20.

* \[ ] Every new zone has its ambient cue (`AudioBank` entry).
* \[ ] Every new enemy archetype has the full `feel-pass.md` cue
  set (hit, crit, death).
* \[ ] Every new quest beat plays a recognizable cue (accept,
  progress, complete).
* \[ ] Waypoint discovery + travel cues land.
* \[ ] Paper-doll equip cues (clink for armor, swing for weapon
  swap).
* \[ ] `--verify21` covers: every entity has the required cue
  entries (procedural-silence fallback counts; AI-generated audio
  is bonus).

## Stage 22 — Save/load hardening (was Stage 11)

* \[ ] Versioned save format (already in place, AD-07)
* \[ ] Round-trip across every major state at the new content scale
  (waypoints, paper-doll, voiced NPCs, procgen seeds).
* \[ ] Atomic save write: write to `save_slot_1.json.tmp`, fsync,
  rename. Prevents partial saves on crash mid-write (Failure
  Analysis #19).
* \[ ] Corrupt-save handling (don't crash; warn; offer to delete).
* \[ ] World-seed integrity check: a tampered seed value fails fast
  with a clear error instead of generating divergent zones.
* \[ ] Corrupt-save fixture test in `--verify22`.

## Stage 23 — Pre-launch polish (was Stage 12)

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

* Pay Steam fee + complete Steamworks paperwork.
* itch.io page ready (description, screenshots, trailer, build).
* Submit Steam build for review.
* Schedule **single dual launch** (Steam + itch.io same day) per
  `commands/launch-plan.md`. No staged demo; no Early Access split.

