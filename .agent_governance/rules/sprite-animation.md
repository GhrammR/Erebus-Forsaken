# Sprite Animation — Base Rig, Species, and the Character Registry

This rule governs how every animated character in the game is built,
skinned, and animated. It exists because the project drifted: sprites
were polished one-off, per-entity, until a 2026-06-11 baseline reset
collapsed every player / enemy / NPC onto a single white rig. This
rule locks the model that came out of that reset so it never drifts
again.

Read `rules/asset-pipeline.md` first — the **modular subtree contract**
(one semantic part = one `Polygon2D`, AD-11) and the **hybrid art
policy** (procedural is the always-shippable baseline; bitmap is
optional polish) are assumed here, not repeated.

---

## 1. The baseline reality (2026-06-11 reset)

There is exactly **one** active procedural rig: the white human at
`art/procedural/baseline_white_sprite.gd`, built on `HumanRig`
(`scripts/systems/human_rig.gd`). Every former per-class / per-enemy /
per-NPC sprite was archived under
`art/procedural/archive/baseline_reset_2026_06_11/`. They are
reference, not live code. Do not un-archive them; re-derive from the
baseline instead.

> The white baseline rig is the **canonical basis for all human
> sprites and the starting point for every other species rig.** No
> character sprite is authored from a blank scene. You derive.

The baseline already carries the full animation substrate:

- `HumanRig` — the humanoid part tree (skull-under-skin, neck, torso,
  hips, upper/lower arms, hands, upper/lower legs, feet, full joint
  pivots) plus optional weapon-arm nodes (`SpearArm` / `StaffArm` /
  `BowArm` / `WandArm`).
- `SpriteMotionStances` — builds the six canonical animations.
- `SpriteRuntime2D` / `SpriteOverrides` / `StanceSelection` — per-entity
  stance selection and pose-tuner injection.
- `EnemySpritePalette` — per-variant recolor on top of the shared rig.

These systems stay. This rule does not rebuild them; it defines the
**data layer** that selects among them per character.

---

## 2. Species roster (Act 1, locked)

Five species. Each has **one base rig**, derived from the white
baseline, registered once. Everything specific to a named character is
data on top of its species rig — never a new rig.

| Species    | Derives from baseline by…                                                                 | Anatomy notes |
|------------|--------------------------------------------------------------------------------------------|---------------|
| **HUMAN**  | Nothing — the baseline *is* the HUMAN rig.                                                  | All four player classes + all human NPCs (Kallias, Eurynome) skin this rig. |
| **DEMON**  | HUMAN base + infernal mods: horn pair, optional hoof feet, vestigial wing anchors, glowing eye sockets. | Bespoke unique bosses (Hexacheir) register their own anatomy, not the shared DEMON rig — see §6. |
| **BEAST**  | The largest deviation. Quadruped base (head, trunk, four legs w/ shoulder+hip pivots, tail) **derived from** the baseline joint system, not its silhouette. A winged sub-variant adds paired wings. | Quadruped + winged are *sub-variants* of BEAST, not new species. |
| **UNDEAD** | Three sub-variants off the baseline: **skeleton** (existing Bone Servant part set — the anchor), **revenant** (HUMAN rig, decayed skin/anim), **wraith** (hood + cloak + face void + tattered hem, no legs, floats). | Floating is a locomotion sub-variant, not a species. |
| **CONSTRUCT** | HUMAN base + rigid/mechanical anim profile + metallic/stone skin; segmented joints (bronze automaton, animated statue — Talos-type). | Rigidity is an animation-set property, not a separate rig. |

**Locomotion is not a species.** Floating (wraith), flying (winged
beast/demon), and quadruped gaits are **sub-variants** expressed as a
derivation modifier + an animation-set choice, never a top-level
species. This supersedes the old Stage-17.5 `FLYING` and `HUMANOID`
family slots: `HUMANOID` collapses into HUMAN+skin; `FLYING` becomes a
sub-variant flag. Those two enum entries survive in
`AnatomyFamilies.Family` as **legacy/deprecated** only — no sprite may
register to them, and they are slated for removal once nothing
references them. New work uses the five species + the sub-variant
axis.

Adding a sixth species is out of scope until Act 1 ships
(`rules/scope-lock.md`). Park new-species ideas in `parking_lot.md`.

---

## 3. The character registry (the core mechanism)

Selecting "what is displayed" for any sprite slot goes through **one**
data-driven registry. A character is **not** a scene; it is a
`CharacterDef` record that names which species rig to instantiate and
how to dress + move it.

```
CharacterDef
├── id              StringName   — unique, e.g. &"myrmidon", &"shade_wretch", &"kallias"
├── species         enum         — HUMAN | DEMON | BEAST | UNDEAD | CONSTRUCT
├── sub_variant      StringName   — &"" | &"skeleton" | &"revenant" | &"wraith" | &"quadruped" | &"winged"
├── skin            SkinDef      — palette + accoutrement layer (see §4)
├── anim_set        StringName   — which animation profile to build (see §5)
├── stance_id       StringName   — SpriteMotionStances stance (idle/walk posture)
├── weapon_flags     { spear, staff, bow, wand, … }  — which weapon-arm nodes show
└── equipment_slots bool         — HUMAN only: does this char receive paper-doll overlays
```

Runtime contract:

> Given a `CharacterDef.id`, the runtime instantiates the species base
> rig, applies the skin, builds the named animation set, selects the
> stance, and shows the declared weapon arms. Selecting a different
> `CharacterDef` for the same slot swaps **only data** — never a
> different scene file.

This replaces the per-entity `sprite_scene` PackedScene pattern.
`ClassData.sprite_scene` and `Enemy.sprite_scene` migrate to a
`character_id: StringName` that resolves through the registry. (The
PackedScene field may remain as a transitional fallback during the
migration stage, then be removed.)

**Implemented (Stage 17.7):** `CharacterRegistry`
(`scripts/systems/character_registry.gd`) is the single source of truth
"who can be displayed." It is a **code registry** — a `CHARACTERS` dict
keyed by `character_id` — consistent with `AnatomyFamilies` /
`SkinLibrary` / `SpriteMotionStances` (NOT per-character `.tres`; the
original `.tres` plan was dropped to match the codebase's registry
pattern). It holds only `{ scene, bucket, weapon, equipment_slots }` per
id and **aggregates** the rest: species / sub_variant / anim_set from
`AnatomyFamilies`, skin presence from `SkinLibrary` — no duplication.
`CharacterRegistry.def(id)` returns the full aggregated CharacterDef;
`scene_for(id)` / `instantiate(id)` build the sprite. `ClassData` and
`Enemy` carry a `character_id` that resolves through the registry, with
the legacy `sprite_scene` export as the transitional fallback. Verified
by `test/stage17_7_verify.tscn` (roster, scene resolution + six anims,
def consistency, equipment-slots HUMAN-player-only, ClassData wiring).

---

## 4. Skin layer contract

A skin is the visible identity dressed onto a species rig. It is
**additive** and **modular** (AD-11): one accoutrement = one
`Polygon2D` layered under `Body/`.

- **Palette** — `const Color` set per skin (faction/character anchor).
  Recolors the base rig parts; reuses the `EnemySpritePalette` path for
  enemies.
- **Accoutrements** — clothing / armor-look / horns / cloak / bone
  fragments, each a named `Polygon2D` added under `Body/`, never fused.
- **Class identity (HUMAN)** comes entirely from skin, not rig:
  Myrmidon = bronze hoplite kit; Pythia = oracle robes + laurel;
  Shade-Hunter = hooded leather + quiver; Ossuary Priest = ash
  vestments + bone hem.

A skin must read in silhouette at ~32px before details are added. A
skin never changes the rig's part *names* — that would orphan
AnimationPlayer tracks (§7).

**Base clothing vs equipment (locked 2026-06-15, "2b-A").** A skin
carries **base clothing only** — the under-layer worn beneath armor
(tunic, robe, sash, boots). It must **not** bake in armor or headgear
(helm, cuirass, greaves, circlet, hood, pauldrons): those are
**equipment**, layered on at runtime by the Stage-15 paper-doll
(`EquipmentVisuals`) when the player equips an item, so any equipped
piece sits cleanly over the base clothing. Rule of thumb: if a player
could loot/equip/replace it, it is equipment, not skin. (Pythia is the
reference cut: base = linen robe + trim/sash; the gold circlet + laurel
moved to equipment.)

**Face + accessory readability.** Face features (eyes/brow/mouth) must
be small, tapered shapes — a flat full-width bar reads as a floating
rectangle, not a mouth. Accessories must not sit at the **silhouette
edge of the head**: leaves/spikes/feathers flanking the skull read as
ears/horns ("elf-ear laurel" bug). Keep them above the brow or clearly
inside the silhouette.

**Bitmap path (hybrid):** each `Polygon2D` part may have an optional
sibling `Sprite2D` at `res://data/sprites/<character_id>/<part>.png`.
Present → Sprite2D renders, Polygon2D hides. Absent → procedural part
ships. Mirrors the Stage-16 item-icon sidecar. A missing bitmap never
blocks anything.

---

## 5. Animation set contract

Every character builds the **six canonical animations** (AD-11):
`idle`, `walk`, `attack`, `cast`, `hit`, `die`. These names are the
ones the live codebase plays (`player.gd`, `enemy.gd`, `act_boss.gd`,
`bone_servant_minion.gd`, `sprite_runtime_2d.gd`) — do **not** rename
them to `hurt`/`death` or anything else; that orphans every caller and
every AnimationPlayer track. The animation **names are invariant**
across every species, sub-variant, and character — calling code
(`AnimationPlayer.play(&"attack")`) never branches on who the
character is.

An **anim_set** is a named profile that parameterizes how those six are
built for a body type / temperament:

- `human_default` — the baseline stances.
- `wraith_float` — no leg motion; the wraith **drifts** (a slow
  vertical swell + trailing hem), never a stepping walk; the Body
  **floats above the ground** (`hover_height`) while the Shadow stays
  on the ground plane. Locomotion stance options are pruned to
  drift-only — a drifting sprite is never offered a footed gait
  (`lurch`/`stalk`), and a non-caster wraith is offered no cast pose.
- `quadruped` — four-leg gait, head-lead. **Built by the sprite, not the
  shared biped builder.** `SpriteRuntime2D`'s `_anim_*` methods animate the
  HUMAN tracks (`Arm*Shoulder`, `Leg*Hip`) — a quadruped has none of those,
  so a BEAST sprite OVERRIDES the six builders (except `_anim_hit`, a
  body-modulate flash that works on any rig) and overrides
  `_uses_standard_leg_anatomy()` to return `false` so the injected biped
  legs are never added. The rig is its own four-leg frame
  (trunk/neck/head, `LegFront{L,R}` + `LegBack{L,R}` each with a knee
  pivot, tail) laid on the same joint-pivot/rotation-track system, NOT the
  biped silhouette. (Implemented Stage 17.10: the Blighted Hound,
  `&"blighted_hound"` — a lean blighted canine; the shared BEAST baseline.
  A winged sub-variant would add paired wings.)
- `construct_rigid` — stiff interpolation, mechanical attack arc.
  **Enforced by the sprite, not the runtime builder.** `SpriteRuntime2D`
  builds the six anims with organic CUBIC easing for every species; a
  CONSTRUCT re-times every built track to **LINEAR** after build
  (`sentinel_sprite._make_rigid()`) so it snaps between poses instead of
  easing. The `"rigid": true` flag on the anim_set is a declaration the
  verifier checks — it does not by itself stiffen the motion. A new
  construct variant must call the same re-time, or it animates organic.
  (Implemented Stage 17.9: the Bronze Sentinel, `&"bronze_sentinel"` —
  HUMAN rig re-skinned as a riveted bronze juggernaut with a Faceplate +
  molten CoreGlow; the shared CONSTRUCT baseline.)
- (others authored as species land.)

Anim sets are built by `SpriteMotionStances` profiles, tuned per
character by `SpriteOverrides` (`tmp/recommended_stances.json` pose
tuner) + `StanceSelection`. Driven by `AnimationPlayer` keyframes, never
`_process` math — so the bitmap swap (frame tracks) keeps the same anim
names and calling code is untouched.

> "Select what character is displayed" = pick a `CharacterDef.id`.
> "Apply the correct attack/walk/cast/idle" = its `anim_set` +
> `stance_id`. One choice, both effects.

---

## 5b. Weapon mount contract (Stage 17.8 — hands stay on weapons)

**`WeaponRig` is the single source of truth** (`scripts/systems/weapon_rig.gd`).
Each weapon kind (SPEAR / STAFF / WAND / BOW) declares its geometry, grip,
and attack/cast PATTERN once, and ANY sprite that exposes the shared hand
rig mounts it the same way — player classes, NPCs, and enemies alike.
`WeaponRig.kind_for(sprite_id)` maps a sprite to its weapon (so the Bog
Caller wields the very same wand as the Ossuary Priest, just with a
wraith skin); `mount()` welds + paints it; `add_attack()` / `add_cast()`
contribute the pre-designed pattern (spear = couched lunge, staff/wand =
overhead chop, bow = draw-and-loose). A new sprite that can equip a
weapon needs **zero** per-sprite weapon authoring. Per-weapon patterns
live in `WeaponRig`, never copied into individual sprites.

A held weapon's grip must **never leave the wielding hand in any
animation**. The mechanism is structural, not per-animation authoring:

1. **Weld the weapon under the hand.** A weapon's root node is parented
   under its wielding hand's `ElbowPivot`
   (`Body/Arm{R|L}Shoulder/ElbowPivot`) at the grip point
   `GRIP_LOCAL = (0, 10)` (elbow-local hand centroid). Its geometry is
   authored grip-local (origin = the hand). Because the weapon is a
   *descendant* of the hand, it follows the hand rigidly through every
   frame of every animation — the grip cannot drift off. The shared
   baseline does this in `baseline_white_sprite._mount_weapons()` (the
   reset left Staff/Bow/Wand at body/root level — that is the
   "detaches while walking / when attacking" bug). New weapons get
   parented the same way; **never** anchor a weapon at body or root
   level and try to keep it in place with a fixed position.
2. **Strike = rotation, never translation.** A weapon's swing is the
   weapon node's own `:rotation` (which pivots about the grip) and/or
   the wielding arm's rotation. A weapon arm must **never** get a
   `:position` track — that slides the grip off the hand. Drive a
   lunge/thrust by stepping the **Body** forward (the hand, and the
   welded weapon, travel with it), not by translating the weapon.
3. **Wielding hands.** Spear/staff/wand/**bow** all weld to the **right**
   hand. A two-hander (the bow) welds its primary grip (riser) to the
   right hand and pins only its *second* hand (left → nock) during the
   draw — see the two-model note below.
4. **Paper-doll paths follow the mount.** `EquipmentVisuals.WEAPON_ARMS`
   points at the welded path (under the ElbowPivot); the paper-doll only
   toggles `.visible`, so the welded location is the single source.

**QA gate (enforced, not eyeballed):** `test/sprite_qa.gd` fails any
sprite whose weapon arm is not welded under an `ElbowPivot`, carries a
`:position` track, or whose grip origin leaves its hand's grip point
(> 0.75 px) when each of the six animations is sampled across its
timeline. "A weapon that doesn't connect to a hand during any animation"
is a **hard FAIL** — it is caught here once, not hand-fixed per sprite.

### Two sanctioned grip models

1. **Welded** (one-handed: spear / staff / wand). The weapon is parented
   under the wielding hand's `ElbowPivot`. Sprite QA checks the weld +
   grip-on-hand.
2. **Welded primary + pinned draw** (two-handed: the bow). The PRIMARY
   grip is still **welded** (the bow's riser welds to the right hand) so
   the weapon is *structurally* held — it can never detach, in any frame,
   in the editor, or with IK disabled, and the same QA weld/grip check
   covers it. Only the SECOND hand is runtime-pinned: the left hand pins
   to the bow's `NockMarker` during the attack draw
   (`baseline_white_sprite._apply_bow_rig`), the nock animates
   back→release, and the bowstring is rebuilt each frame `tip→nock→tip`.
   Do **not** make a two-hander *only* runtime-pinned with no welded grip
   — a pin that stops (ik off, a paused editor frame, the gap between
   non-looping anims) drops the weapon, and that fragility is invisible to
   a static check (this is exactly why the "bow on the ground, separated
   from the hand" bug slipped past QA the first time).

> Picking a model: weld the primary grip ALWAYS (structural, statically
> checkable); add a draw/second-hand pin only for the extra hand a
> two-hander needs. Never rely on a runtime pin for the only grip.

### Animation-pose rules (learned the hard way)

- **Cast never folds the arms inward.** Raising the arms by rotating them
  *across the torso centre* buries them (and any welded weapon) behind
  the body/skin. Cast raises arms **up-and-out** (the overhead
  invocation).
- **A chop pivots on the HAND, not the arm.** A staff/wand "downward
  chop" is driven by the WEAPON's own `:rotation` about the grip (tip/orb
  arcs from upright → wind back → down-forward), with only a small arm
  lift for power. Driving the chop by swinging the whole arm makes the
  arm+weapon one long lever — a staff reads as an "extended arm" and a
  short wand looks buried in the forearm. Keep the implement reading as a
  held implement; the hand is the pivot.
- **A raised weapon stays VERTICAL.** When the arm lifts a welded weapon
  overhead to cast, the arm rotation would otherwise tip the weapon to
  point at the ground. Counter it on the weapon's own `:rotation` so the
  weapon reads as held high and upright (the bow is raised the same way,
  kept vertical via a counter-rotation). Don't leave a raised weapon
  pointing down.
- **Free arms render ABOVE the base clothing.** A robe/tunic/cloak
  (`SkinLibrary` parts at z2–3) must not bury the arms — the free-arm
  parts sit at z4 (`baseline_white_sprite._layer_free_arms`), under the
  head/helm (z5) and glints (z6). Sprite QA fails a skinned HUMAN whose
  arm parts render behind any base-clothing polygon (the "arms behind the
  skin" guard). Enemies/bosses paint bespoke parts and are exempt.
- **Enemy/skeleton gait mirrors the HUMAN baseline.** Walk swings the
  arms opposite the legs; attack is a single-arm *reach* (shoulder +
  elbow), NOT a rotation on every arm/claw/hand node at once (that reads
  as a flail). Only the multi-armed boss keeps the broad multi-arm sweep.
- **Wraiths are humanoid from the waist up.** Shade Wretch + Bog Caller
  are built on the shared `HumanRig` (`wraith_sprite.gd`) — SAME size as
  the player cast, articulated shoulder/elbow arms that HANG DOWN like a
  character's, ending in claws, using the same reach attack as everyone
  else. A cloak/hood drape the torso; there are NO legs (the only
  deviation) so the wraith drifts. Do not author a bespoke oversized
  wraith rig with splayed arms — that is the size/posture bug this
  rebuild fixed.
- **A hovering body never topples or animates about the feet pivot.** A
  wraith's `die` is a fade + sink in place (centred), not the grounded
  topple — rotating a floating body about the feet throws it off-axis
  ("off-centred dissolve/collapse"). The hover height is also seated as
  the Body's **resting** position (not only inside the anim keys) so a
  static editor preview floats with a shadow gap instead of standing.

### Out of scope until the AI pipeline

Multi-directional / foreshortened poses (front / rear / left / right
facing) are **deferred to the Stage 11 AI bitmap pipeline**. Procedural
rigs are required only to be side-view readable (L/R is a flip). Do not
build a 4-direction procedural rig without an explicit scope override —
it reshapes the whole rig + animation contract for placeholder art.

---

## 6. Unique bosses are bespoke, not registry skins

Named unique bosses (Hexacheir, the God-Spurned now; Hekate-Marked as
legacy/rare routing metadata) get their **own anatomy entry**, not a
species rig + skin. This is what lets a boss be larger, asymmetric,
multi-armed, or partially-disassembled — properties a shared rig can't
carry. A bespoke boss still obeys the modular contract (one Polygon2D
per part) and still builds the six canonically-named animations; it
just doesn't have to match a species part-name set. Register bespoke
bosses by `id`, separate from the species registry.

---

## 7. Invariants (never violate)

- **Default-facing is right** (positive x). Owners flip the sprite
  anchor's `scale.x` to face left. Never hardcode left/right swing.
- **Hit-flash target:** anything the flash tints lives under `Body`
  (`Enemy._flash_hit` targets `Body.modulate`).
- **Part-name stability:** AnimationPlayer tracks bind to NodePaths.
  Renaming a part orphans its tracks **silently**. Rename in a single
  editor pass or not at all. Verifier source-checks that no live track
  references an archived/v1 part name.
- **One species rig per species.** A second rig for the same species is
  a process failure — it should have been a sub-variant or a skin.
- **Procedural ships.** No character is blocked on a bitmap, a voice
  line, or an AI asset. The procedural rig + skin is complete on its
  own (`rules/scope-lock.md` art policy).
- **Debug instrumentation** (per `feedback_debug_instrumentation`):
  every new species rig / anim_set ships with a `DebugLog` flag, a
  workbench trigger to view it, a verifier assertion, and
  `failure-modes.md` entries before commit.

---

## 8. Workflow

**To add a species rig:**
1. Derive from `baseline_white_sprite` / `HumanRig` — copy, modify the
   part set, register the species + its base part-name list.
2. Author its default `anim_set` against the six canonical names.
3. Register it in `CharacterRegistry.CHARACTERS` **and** add it to the
   sprite editor catalog (`test/pose_tuner.gd` — `CLASSES` with its five
   anim variants + a `STANCE_CATALOGS` mapping). A registered sprite that
   is not in the editor cannot be reviewed/tuned — "all new sprites must
   be available to review in the editor"
   (`stage17_5_verify._verify_editor_catalog_covers_registry` enforces it).
4. Add verifier coverage (part set present, anims build, no orphaned
   tracks) + failure-mode entries.

**To add or re-skin a character:**
1. Create/edit a `CharacterDef` `.tres` in `data/characters/`.
2. Set species + sub_variant + skin palette/accoutrements + anim_set +
   stance + weapon flags.
3. Point the entity (`ClassData.character_id` / `Enemy.character_id`)
   at the id. No new scene file.

**Never:** author a one-off `*_sprite.tscn` per character, fuse parts
into a blob, rename parts mid-pass, or polish a procedural rig past
side-view-readable before the Stage-11 bitmap pipeline window
(`feedback_procedural_is_placeholder`).

---

## 9. Definition of done ("sprite animations complete")

Sprite animation is **done for Act 1** when:

- All five species rigs are registered and derive from the baseline.
- Every player class, NPC, and enemy archetype in scope resolves
  through a `CharacterDef` (no live one-off sprite scenes outside the
  archive + bespoke bosses).
- Each `CharacterDef` builds all six canonical animations under its
  declared anim_set, with no orphaned tracks.
- `EquipmentVisuals` overlays resolve on every HUMAN character;
  enemies/NPCs never receive equipment overlays.
- The registry verifier (`--verify`) passes: species coverage, per-
  character anim build, part-name stability, sidecar honored when a
  fixture PNG is present, family/species-mismatch assertions.
- A screenshot pass (idle on every species + a representative
  character each) is attached to the closing commit.

This rule is binding. If a request would author a sprite outside this
model, name this rule, point to the registry path it bypasses, and
offer the in-model equivalent (`rules/scope-lock.md` §Enforcement).

---

## 10. Sprite QA workflow (verification)

Every sprite change is verified by the **Sprite QA harness**
(`test/sprite_qa.tscn`) before it's considered done. For each
registered sprite it asserts, and writes `docs/sprites/_qa_report.txt`
plus a labeled `docs/sprites/_contact_sheet.png`:

1. scene loads + instantiates;
2. `AnimationPlayer` present, all six canonical anims build;
3. **no orphaned animation tracks** — every track path resolves to a
   live node (catches part renames / rig mismatches);
4. every **visible-in-tree** `Polygon2D` has real geometry (≥3 pts) —
   catches unpainted/empty parts;
5. **no part at/below the editor background z** (occlusion guard);
6. parts stay within a sane bounding box (catches blown-up polygons).

Run it (`godot --path . res://test/sprite_qa.tscn`; headless for checks,
with a display for the contact sheet) after any sprite/skin/rig edit.
**Every new sprite-polish issue we hit gets (a) a check added here if it
is machine-detectable, and (b) a `failure-modes.md` entry** — that is
how the workflow learns. The contact sheet is the human/agent eyeball
pass for issues a machine can't judge (proportions, pose readability,
colour identity).

**Equipment-overlay check.** Because skins are base clothing only (§4),
armor is verified by **geared renders** — `test/wraith_render.gd`
equips HEAD/CHEST/LEGS items through the real Inventory +
EquipmentPaperdoll path and saves `docs/sprites/<class>_geared/idle.png`.
After any change to base skins OR `EquipmentVisuals` overlays, re-check a
geared render to confirm armor still layers cleanly over the base
clothing (no gaps, no double-armor, correct z over robes).
