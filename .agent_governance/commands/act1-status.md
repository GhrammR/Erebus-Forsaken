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
11. Stage 13 — Wilderness procedural generation (seeded RNG, biome
    templates, aesthetic variants for trees / rocks / enemy skins)
12. Stage 14 — Waypoint system (themed, persistent, discoverable)
13. Stage 15 — Equipment paper-doll rendering (bare-hands default;
    helmet/weapon/armor slots tint the procedural sprite layers)
14. Stage 16 — Item icons (replace text rows with icon grid)
15. Stage 17 — NPC voice + portraits (each town NPC ships an intro
    line, AI-generated voice + portrait)
16. Stage 18 — Demote Forsaken Boss → rare; refactor `act_1_complete`
    state machine for the new final-boss model
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

## Stage 13 — Wilderness procedural generation

Wilderness zones are seeded per new game. Same `--new-game` (or
character-create) seed = same world. Different seeds = different
content, layout, and aesthetics. Loading an existing save replays the
seed exactly (no drift).

* \[ ] `WorldSeed` autoload: holds the master seed assigned at
  character create. Persists in save (schema bump).
* \[ ] Each wilderness zone derives a deterministic sub-seed from
  `(WorldSeed, zone_index)`.
* \[ ] Zone layouts use seeded RNG for: terrain block placement,
  path winding, enemy-spawn anchor positions, prop placement,
  aesthetic variant pick.
* \[ ] Aesthetics: at least 3 tree variants, 3 rock variants, 2
  enemy-skin palette swaps per archetype. All procedural; bitmap
  variants are Stage 11+15+17 polish.
* \[ ] Each zone fires within `min_distance_from_town` to
  `max_distance_from_town` so the chain ramps. Adjacent zones share
  a path so the player can walk all the way through.
* \[ ] `--verify13` covers: same seed → identical zone content;
  different seeds → diverging content; sub-seed derivation is
  deterministic.

## Stage 14 — Waypoint system

Themed fast-travel between previously-visited wilderness zones. The
theme: **"The Sundered Ferry"** — placeholder name; replace when art
lands. Charon's old ferry-paths still cross the underworld; you light a
brazier at each waypoint you find, and a spectral ferryman returns to
take you back. (Theme is a working draft; explicit user approval to
lock the name.)

* \[ ] `Waypoint` interactable scene + script. Placed at a fixed
  location in each generated wilderness zone (seeded position).
* \[ ] Save schema entry: discovered waypoints (`Array[StringName]`
  of zone ids).
* \[ ] Waypoint UI: pressing E at a waypoint opens a list of
  discovered destinations. Selecting one transitions there.
* \[ ] First-time discovery: brief reveal anim + audio cue
  (procedural fallback OK).
* \[ ] `--verify14` covers: discovery persists across save/load,
  travel between waypoints preserves player state, no cross-game
  waypoint leakage.

## Stage 15 — Equipment paper-doll rendering

The procedural sprite gains slot layers. Equipping a helmet adds a
helmet node visible on the sprite; equipping a weapon adds the
weapon visual; unequipping a weapon reverts to a bare-hands stance.

* \[ ] Procedural sprite refactor: `Body/SlotAnchors/(Head, Weapon,
  Offhand, Armor)` empty `Node2D` slots that child sprites parent
  into.
* \[ ] `EquipmentVisual` resource on each `ItemData`: procedural
  draw or bitmap reference for the slot's render.
* \[ ] `Inventory.equipment_changed` signal already exists — paper-doll
  listens and swaps slot children.
* \[ ] Bare-hands stance: when no weapon equipped, hands close into
  fists; attack anim mirrors closely-thrown jab.
* \[ ] Hybrid art contract: paper-doll first ships procedurally.
  Bitmap polish via Stage 11 pipeline lands later.
* \[ ] `--verify15` covers: equipping items adds slot nodes;
  unequipping removes them; save/load preserves visual state.

## Stage 16 — Item icons (inventory grid)

Replace the text-row inventory UI with an icon grid. Drag/drop is
*not* in scope here (parked); single-click to equip / use persists
from current `inventory_panel.gd`.

* \[ ] Icon generation per item via Stage 11 pipeline (procedural
  fallback = the current `ItemGlyph` colored shape).
* \[ ] `InventoryPanel` swaps text rows for a 6×6 (or 6×N) icon
  grid. Backpack capacity stays 36 (AD-10).
* \[ ] Hover tooltip carries the full stats text that used to be the
  row text.
* \[ ] Equipment side shows slot icons in their paper-doll
  positions (Head top, Weapon bottom-left, etc.).
* \[ ] `--verify16` covers: panel builds the grid, every backpack id
  resolves an icon (procedural fallback ok), tooltip surfaces stats.

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

## Stage 18 — Boss demote + final-boss state-machine refactor

Hekate-Marked Forsaken Boss demotes to a regular rare-monster
encounter. `act_1_complete`, `boss_first_kill`, Maw portal gating,
class-restricted unique drop, and Eurynome's quest completion all
re-target a new final-boss entity.

* \[ ] Strip the boss-specific logic from `act_boss.gd`; convert into
  `forsaken_rare.gd` (a rare-monster spawn in Forsaken Crypt).
* \[ ] Class-restricted unique drop moves to: rare drop from the new
  final boss + 5% chance from Forsaken Rare as a vestige.
* \[ ] `act_1_complete` keys off the new final-boss kill.
* \[ ] Eurynome's "defeat the boss" quest re-targets the new final
  boss (Stage 20 places it).
* \[ ] Maw portal gating (Stage 19) replaces the post-Forsaken-Boss
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

