# Erebus Forsaken

A dark-fantasy, Greek-mythology isometric ARPG. Solo development in Godot 4.

> **Status:** Pre-alpha. Stages 0–14 complete (bootstrap, stats,
> movement, combat, items, skills, town + quests, wilderness, dungeons,
> interim act boss, feel pass, endless mode, consumables + potions,
> Ember Maw-route hotfix, AI asset-generation pipeline, walkable
> town↔wilderness seam, seeded wilderness procgen, Sundered Ferry
> waypoints). Strategic Review v2 (2026-06-04) reset Act 1's content
> target: 10+ wilderness zones, 5+ dungeons, 5+ quests, paper-doll
> equipment, AI-generated voice + portraits, waypoints, seeded procgen,
> all sized for 2+ hours of first-run gameplay. Stages 15–21 (Strategic
> Review v2) are the path there; Stages 15 (paper-doll equipment
> rendering) and 16 (inventory icon grid) are **done** — equipped
> helmets/chests/legs/offhand render on the procedural class sprite,
> weapon arms hide on bare hands, and the inventory replaces text rows
> with a 6×6 icon grid plus a paper-doll equipment layout and hover
> tooltips. Release plan: **single dual launch on Steam + itch.io
> the same day** when content-complete — no staged demo, no EA split.
> The project is being built in public from the first commit.

---

## What it is

Erebus Forsaken is a single-player isometric action RPG drawing on the spirit
of *Diablo II* and the atmosphere of Greek underworld myth. Loot, classes,
dungeons, an act boss, and one focused vertical slice — that is the entire
pre-launch goal. No multiplayer, no live-service, no roadmap promises beyond
what is checked off in the project's own status file.

Four classes are planned for Act 1:

- **Myrmidon** — front-line warrior, spear and buckler
- **Pythia** — oracle-mage, staff and elemental arts
- **Shade-Hunter** — ranged hunter of escaped underworld spirits
- **Ossuary Priest** — death-rite summoner

## Why this exists

I wanted to build the ARPG I keep wishing someone else would: small, dark,
tightly-tuned, and *finished*. A polished one-act game beats a sprawling
half-built four-act game every time.

## How development is run

This repository is governed by [`.agent_governance/CLAUDE.md`](.agent_governance/CLAUDE.md)
and the rule files alongside it. The governance folder is not decoration —
it is the binding charter that AI tooling and future-me must follow before
touching code. If you are curious how a solo developer can use AI agents
without the project drifting into mush, that folder is the answer.

Highlights worth a look:

- [Act 1 status checklist](.agent_governance/commands/act1-status.md) — the
  living definition of "done."
- [Scope lock](.agent_governance/rules/scope-lock.md) — what is explicitly
  *not* in Act 1.
- [Architecture decisions](.agent_governance/rules/architecture-decisions.md)
  — locked design calls (AD-01 … AD-11).
- [Failure modes](.agent_governance/rules/failure-modes.md) — known ways
  solo ARPGs collapse, and how this one tries not to.

## Current state

- Godot 4.6.3 project, GDScript, GL Compatibility renderer.
- Autoloads: `GameState`, `SaveSystem` (versioned, AD-07), `EventBus`
  (whitelisted signals, AD-08), `SceneRouter`, `Database` (AD-03),
  `ItemInstanceRegistry`, `CameraShake`, `AudioBank`, `DebugLog`,
  `EndlessRun`, `ConsumableUse`.
- Stat system: four attributes (Strength / Dexterity / Vitality / Pneuma),
  five Act 1 derived stats (MaxHP, MaxMP, Defense, AttackRating,
  Resistance). All four classes' base values live in `data/classes/`.
  Stats math goes through one Resource (AD-01); no inline attribute
  arithmetic. Crit math added in Stage 9.5.
- Player: one `CharacterBody2D` scene, class injected at runtime via
  `assign_class(ClassData)` (AD-02). Click-to-move primary, WASD
  secondary (AD-09). All four classes (Myrmidon, Pythia, Shade-Hunter,
  Ossuary Priest) drawn procedurally. Pause menu, camera follow,
  sprite L/R flip, in-place revive, corpse-run death penalty.
- Combat: every hit funnels through `DamageResolver.resolve()` (AD-04).
  `HealthComponent`, `HitboxComponent`, `HurtboxComponent` as composed
  Nodes/Areas. Damage numbers, crit math, hit-stop, screen shake,
  feel pass (Stage 9.5) on every player-affecting event.
- Skills: one skill per class (Stage 5), cooldowns + costs, HUD skill icon
  with cooldown veil.
- Items: `ItemData` Resources for weapons / armor / uniques / consumables
  across 7 equipment slots. Class-restricted unique sigils guaranteed on
  first Act boss kill. `Inventory` is a 36-slot list (AD-10) with
  per-class loadouts. Drops go through `WorldItem` walk-over auto-pickup,
  and `SaveSystem` v14 round-trips full state to versioned JSON storing
  item IDs (AD-06), not paths. Item-outline shader for rare drops on
  the ground.
- Consumables (Stage 9.8 / 9.8.1): Hearth Ember (2s channel → Threshold
  Camp; in The Maw ends the run via `EndlessRun.end_run(false)` and
  routes to Threshold Camp on summary close, NOT the pre-portal anchor;
  damage cancels + consumes), Health/Mana Potions (flat HoT/MoT over 3s, per-type 8s
  cooldown, hotkeys `2`/`3`), Ichor Potion (unique 50% HP + 50% MP
  instant, 30s cooldown). HUD potion bar with per-slot cooldown veil.
  Cooldown remainders persist across save/load (no quit-and-load reset).
- Zones: Threshold Camp (town, NPCs, vendor Kallias, quest-giver Eurynome,
  workbench), Blighted Reach (wilderness, finite spawn budget), Forsaken
  Crypt (multi-room dungeon w/ act boss Hexacheir, the God-Spurned — the
  first six-armed demon), Forsaken Depths ("The Maw" — endless mode w/
  Tower of Ascension milestones).
- Endless mode (Stage 9.7): post-boss portal to The Maw, EndlessDirector
  with wave scaling, milestone rewards at 10/25/50/100, summary modal with
  seed string, EndlessRun.end_run rollback chain.
- Save system: v14 schema with backward migration chain (v1 → v14),
  per-zone state lifecycle (AD-12), corpse persistence across saves.
- Procedural sprites only (AD-11). All six canonical animation names ship
  on every sprite so the eventual bitmap swap is a node-type change, not
  a code rewrite. Player classes, enemies, and NPCs share the same editable
  runtime surface for pose overrides, stance selection, and click-drag parts.
- Weapon system (Stage 17.8): a shared `WeaponRig` owns each weapon's
  geometry, grip, and attack/cast pattern (spear = couched lunge, staff/
  wand = overhead chop, bow = draw-and-loose), so ANY sprite — player,
  NPC, or enemy — wields a weapon identically with no per-sprite work (the
  Bog Caller shares the Ossuary Priest's wand under a wraith skin). Every
  weapon's primary grip is welded to the wielding hand, so it can never
  detach; a two-hander adds a runtime pin only for its second hand — the
  bow's left hand draws the nock, bowstring rebuilt per frame. The staff stays in-hand while walking, the spear lunges
  tip-first, the wand chops tip-first, the bow draws-and-looses, and a
  raised cast weapon is held high + vertical (not tipped at the ground).
  Free arms render above the base clothing (no more arms buried behind a
  robe). Enemy/skeleton gait mirrors the human baseline (arms
  counter-swing, knees bend, single-arm reach instead of a flail);
  wraiths are humanoid waist-up, drift with a visible hover gap in the
  editor, and dissolve in place. `test/sprite_qa.gd` hard-fails any sprite
  whose weapon leaves its hand or whose arms render behind the skin.
  Launching a sprite into The Maw replaces the prior preview window
  (no more window flood).
- Species rigs (Stages 17.6–17.10): all five locked species now have a
  built baseline rig — four derived from the shared white HUMAN rig, plus a
  bespoke quadruple frame for BEAST: HUMAN (player classes + NPCs, skinned),
  UNDEAD (skeleton Bone Servant, revenant, drifting wraiths), DEMON (the
  lean `fiend`: horns/hooves/wing-anchors/tail/ember eyes), CONSTRUCT (the
  Bronze Sentinel: a riveted bronze juggernaut with a faceplate + molten
  furnace-core, animated stiff/mechanical via LINEAR re-timing), and BEAST
  (the `blighted_hound`: a four-legged quadruped — trunk/neck/snout + four
  knee-pivoted legs + tail — that trots, lunge-bites, snarls, and collapses).
  Bespoke bosses (Hexacheir) are the remaining sprite phase.
- DebugLog autoload (Stage 9.7): flag-gated logging with file mirror,
  12 categories, `--debug=flag1,flag2` CLI for targeted instrumentation.
- Sprite render pipeline (Stage 17.5/17.6): `--render-sprites` flag
  drives a SubViewport pass that captures every (sprite, equip,
  animation) variant to `docs/sprites/<id>/`, including a debug-strip
  overlay (anatomical landmark lines + per-joint tracker dots) and a
  per-variant `_trace.txt` with numeric pose data + PASS/FAIL diff
  against `test/sprite_specs.gd` keyframes. Numbers replace
  pixel-squinting when iterating procedural animations.
- Sprite-authoring infrastructure (Stage 17.7): marker-based dual-IK
  pin system in `HumanRig.apply_pins` (each class declares a PIN_TABLE
  of shoulder→Marker2D entries; arms follow markers every frame),
  motion-archetype library (`MotionArchetypes.add_arc_overhead /
  thrust_linear / charge_release / conduit_lift`) so attacks are
  composed from named patterns instead of hand-keyed tracks, an
  interactive `pose_tuner.tscn` with live slider tweaking + pose-dump,
  reference-image overlay in `sprite_render`, and per-frame reach
  validation that warns when a pin target falls outside arm reach.
  ShadeHunter now ships with a welded recurve bow + CHARGE_RELEASE
  draw animation built on the new infrastructure.
- Anatomy validator + stance catalog (Stage 17.8):
  `AnatomyValidator.validate_sprite` walks every pin × every animation
  keyframe at sprite spawn, reporting OUT_OF_REACH (target beyond arm
  length) and COLLAPSE (target so close the hand reads as the elbow)
  violations. Soft mode by default (push_warning) so legacy rigs don't
  block; `ANATOMY_STRICT=1` env var promotes to abort-on-violation for
  CI gates. Stance candidates live in `scripts/systems/stances/*.gd`
  per weapon type (e.g. `bow_stances.gd` lists `forward_high_ready /
  low_ready_diag / high_aim`); a sprite picks one via `stance_id`
  export var. `pose_tuner` gains F3 to cycle candidates and 1-5 keys
  to score the current (stance, anim, phase) into
  `tmp/stance_scores.json` — accumulated scores let future agent runs
  bias toward patterns you rated highly. The editor sidebar is fully
  scrollable, labels rotation/position slider groups with a legend, exposes
  drag handles for weapons/elbows/hands/claws/fingers, and can launch the
  current player-class sprite directly into The Maw for manual animation
  debugging.

## Running it

```bash
godot --path .
```

Workbench flags (each launches an isolated test harness):

```bash
godot --path . -- --workbench    # stat workbench         (Stage 1)
godot --path . -- --movement     # movement workbench     (Stage 2)
godot --path . -- --combat       # combat workbench       (Stage 3)
godot --path . -- --loot         # loot + inventory       (Stage 4)
godot --path . -- --skills       # skills workbench       (Stage 5)
godot --path . -- --town         # town / NPCs / quests   (Stage 6)
```

Headless verifiers (CI-friendly, exit 0 on pass):

```bash
godot --headless --path . -- --verify       # Stats math              (Stage 1)
godot --headless --path . -- --verify3      # DamageResolver          (Stage 3)
godot --headless --path . -- --verify4      # Inventory + save        (Stage 4)
godot --headless --path . -- --verify5      # Skills                  (Stage 5)
godot --headless --path . -- --verify6      # Town / quests / vendor  (Stage 6)
godot --headless --path . -- --verify7      # Wilderness              (Stage 7)
godot --headless --path . -- --verify7_5    # Audio + transitions     (Stage 7.5)
godot --headless --path . -- --verify8      # Dungeon                 (Stage 8)
godot --headless --path . -- --verify9      # Act boss + uniques      (Stage 9)
godot --headless --path . -- --verify9_5    # Feel pass + crit + LOS  (Stage 9.5)
godot --headless --path . -- --verify9_7    # Endless mode + The Maw  (Stage 9.7)
godot --headless --path . -- --verify9_8    # Consumables + potions   (Stage 9.8)
godot --headless --path . -- --verify10     # Character select        (Stage 10)
godot --headless --path . -- --verify11     # AI asset-gen pipeline   (Stage 11)
godot --headless --path . -- --verify12     # Walkable town seam      (Stage 12)
godot --headless --path . -- --verify13     # Seeded wilderness procgen (Stage 13)
godot --headless --path . -- --verify14     # Sundered Ferry waypoints (Stage 14)
godot --headless --path . -- --verify15     # Equipment paper-doll    (Stage 15)
godot --headless --path . -- --verify15_1   # 15.1 hotfix bundle      (Stage 15.1)
godot --headless --path . -- --verify16     # Inventory icon grid     (Stage 16)
```

Debug instrumentation (Stage 9.7):

```bash
godot --path . -- --debug=combat,spawn      # enable named DebugLog flags
godot --path . -- --debug=all               # enable all 12 categories
```

Logs print to stdout and mirror to `tmp/erebus.log` for post-mortem.

Requires Godot 4.6 or newer. No build steps, no package install.

## Tech

- Godot 4.6 (GDScript only — no C#, no GDExtension)
- Target platform: Windows / Steam
- Procedural sprites first (drawn from code); bitmap art replaces them only
  after each mechanic is finished — see [`asset-pipeline.md`](.agent_governance/rules/asset-pipeline.md).

## Roadmap

There is no roadmap beyond Act 1. Act 1 ships when every box in
[`act1-status.md`](.agent_governance/commands/act1-status.md) is checked.
Anything past Act 1 is parked until then. The Strategic Review v2
roadmap (Stages 11–23) covers AI asset pipeline, town-to-wilderness
walking, seeded procgen, waypoints, paper-doll equipment, item icons,
NPC voice + portraits, boss demote + new final boss, Maw moved to
town, the 10+ zones / 5+ dungeons / 5+ quests content target, feel
pass at scale, save hardening, and pre-launch polish — culminating in
a single Steam + itch.io dual launch.

## Procedural-plus-AI hybrid art

Procedural sprites drawn in GDScript are the always-shippable baseline
([`rules/asset-pipeline.md`](.agent_governance/rules/asset-pipeline.md)).
AI-generated bitmap, voice, and SFX are an optional polish layer; if a
generated asset isn't ready, the procedural form ships and the feature
is no less complete. The generation pipeline contract lives in
[`rules/asset-generation.md`](.agent_governance/rules/asset-generation.md)
and arrives in Stage 11.

## Contributing

Not accepting external contributions during Early Access development. Issues
and feedback are welcome once the project is further along.

## License

No license is committed yet, so default copyright applies: all rights
reserved by the author. A license will be selected and added before any
binary distribution.

## Acknowledgements

- Built with [Godot Engine](https://godotengine.org/).
- Procedural-art-first workflow influenced by countless solo devs who
  shipped despite not being artists.
