# Asset Pipeline

There are two categories of visual asset. Mixing them is a process failure.

## Category 1 — Procedural sprites (development default)

Written in GDScript using Godot's draw primitives or `Polygon2D` /
`ColorRect` nodes. Claude Code can author and modify these.

Every gameplay entity (player class, enemy, projectile, pickup, UI element)
ships first as a procedural sprite. This is **not** a placeholder in the
embarrassing sense — it is the correct asset for development. Procedural
sprites are:

- Cheap to iterate (a polygon change, not a re-export).
- Animatable via `AnimationPlayer` keyframing modulate, rotation, position.
- Distinct enough at isometric scale (~64px tall) for combat readability.
- Version-controlled as code, diffable in review.

### Authoring rules

- One `*_sprite.gd` (or scene) per entity, in `art/procedural/`.
- Use a fixed palette per faction, defined as `const Color` at top of file.
- Silhouette first: the shape must read at 32px before details are added.
- Animations driven by `AnimationPlayer`, never by `_process` math, so they
  survive the bitmap swap unchanged.

### Modular subtree contract

Every procedural sprite is a *layered subtree*, not a single Polygon2D
blob. The rule:

> One semantic part = one `Polygon2D` node, named for the part.

Why: the polish pass (bitmap swap, or richer procedural details like
flowing cloth, facial features, individual ribs, weapon textures) can
replace a single subnode without redrawing the rest of the sprite,
and the AnimationPlayer tracks (which reference NodePaths to those
named subnodes) keep working unchanged.

Reference layout for a humanoid:

```
SpriteRoot (Node2D)
├── Shadow                   (one Polygon2D)
├── Body (Node2D)            ← every part the hit-flash should tint
│   ├── HipCloth / Robe      (cloth layer behind bones)
│   ├── LegL, LegR           (separate, not a fused trapezoid)
│   ├── Pelvis, Spine
│   ├── Rib1, Rib2, Rib3, Sternum   (individual ribs, not one block)
│   ├── ArmRest              (resting / hanging arm)
│   ├── Skull, Jaw
│   ├── EyeSocketL, EyeSocketR
│   └── EyeGlowL, EyeGlowR
├── ArmAnchor (Node2D)       ← rotated by the attack animation
│   ├── ArmUpper, ArmLower
│   └── Claw / WeaponHead
└── AnimationPlayer
```

Hard requirements:

- Anything the hit-flash should tint must live under `Body`. The
  flash code targets `Body.modulate` (see `Enemy._flash_hit`).
- The arm that performs the attack lives under `ArmAnchor`. The
  attack anim rotates `ArmAnchor:rotation`, so flipping
  `_sprite_anchor.scale.x` mirrors the swing automatically — never
  hardcode left-vs-right swing logic.
- Default-facing is **right** (positive x). Owner scripts flip
  `_sprite_anchor.scale.x` to face left.
- Eye glows are separate from sockets so a bitmap polish pass can
  swap the socket without re-doing the glow shader/colour.
- Don't fuse parts ("a single trapezoid suggesting both legs" is
  the bug we're avoiding). One part, one node — even if the
  procedural rendering looks blobby today, the modular structure
  is what gives the polish pass somewhere to land.

Reference implementation:
`art/procedural/enemies/bone_servant_sprite.tscn` + `.gd`.
The Stage-5 fused-blob version was rewritten under this contract
in Stage 9 polish — match its structure when authoring new
procedural sprites and refactor older ones as their polish window
opens.

### Class visual identity (procedural era)

| Class          | Silhouette cue            | Palette anchor              |
|----------------|---------------------------|-----------------------------|
| Myrmidon       | Spear + round buckler     | Bronze, deep red plume      |
| Pythia         | Tall staff, robed shape   | Violet, gold trim           |
| Shade-Hunter   | Bow, hooded silhouette    | Charcoal, pale teal accent  |
| Ossuary Priest | Wand + bone shoulder bulk | Bone white, sickly green    |

## Category 2 — Bitmap / audio assets (hybrid polish layer)

PNG/texture/audio files. Sourced from:

- **AI generation pipeline** — see `rules/asset-generation.md` for the
  contract. Replicate (images/SFX/video), ElevenLabs (voice), and similar
  third-party services, wrapped behind `tools/asset_gen/` scripts. Files
  arrive in the repo via Git LFS (>1MB) or plain git (small assets),
  each accompanied by a reproducibility sidecar.
- **Kenney.nl** — free, open license.
- **OpenGameArt.org** — community, check license per asset.
- **Commissioned art** — when AI output is insufficient for a hero asset.

### Integration rule (the only one that matters)

> A bitmap or audio asset replaces a procedural form **only after** the
> mechanic it represents is fully functional, tested, and signed off.

If the Myrmidon's basic attack still has a damage bug, the Myrmidon does not
get a bitmap. Procedural sprite stays. Fix the bug first. This rule prevents
the most common solo-dev failure: spending a week on art for a system that
gets rewritten next week.

### Hybrid contract (2026-06-04)

Every visible entity in the game **must** have a working procedural form
*before* a bitmap is even attempted. The procedural form is what ships if
the bitmap pipeline produces nothing usable. Practical consequences:

- A new enemy lands with `art/procedural/enemies/<name>_sprite.tscn` and
  is playable. Only after the procedural form is in and the mechanic is
  signed off does generation get scheduled.
- A new item lands with its `ItemGlyph` color/shape entry on the resource.
  Only after the item itself works (drop → pickup → equip → effect)
  does an icon get generated.
- A new NPC lands with their procedural sprite and dialogue text. Only
  after the dialogue tree is in does voice line generation get scheduled.
- A missing bitmap **never** blocks a verifier, a stage closure, or a
  playtest. If the bitmap is broken or missing, the procedural form
  draws automatically.

### Swap mechanics (bitmap arrival)

When a bitmap arrives (generated or sourced):
1. Sidecar `.json` lands alongside it (see `rules/asset-generation.md`).
2. Drop file into `art/bitmap/<category>/`. Use Git LFS for >1MB.
3. Update the entity's scene to expose a `Sprite2D` child node and a
   procedural fallback child node, gated by `BitmapMode.enabled`.
4. The procedural script **stays** in the file tree. It is the fallback
   if a bitmap source becomes unavailable, fails to import, or is
   intentionally disabled (e.g., `--procedural-only` flag).
5. Verify the bitmap pivots at feet, matches the established silhouette,
   and reads at gameplay zoom.
6. Animations migrate from `AnimationPlayer` modulate/rotation tracks to
   sprite frame tracks. The animation **names** stay the same so calling
   code does not change.

## Audio

Same hybrid contract:
- **Procedural fallback**: silence with on-screen damage numbers and
  screen-shake cues (current `AudioBank` already no-ops on missing
  `.ogg` files — that's the procedural baseline).
- **Hybrid bitmap layer**: AI-generated SFX (Replicate/ElevenLabs SFX),
  AI-generated NPC voice (ElevenLabs), licensed music. Drop into
  `audio/sfx/`, `audio/voice/`, `audio/music/`. Sidecar `.json` required.

Audio is in scope as soon as the procedural baseline is solid — the
pipeline is the limiter, not the design.
