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

## Category 2 — Bitmap assets (post-Act-1-polish)

PNG/texture files. Claude Code **cannot** generate these. Approved sources:

- **Kenney.nl** — free, open license, isometric and dark-fantasy packs.
- **OpenGameArt.org** — community, check license per asset.
- **Midjourney / Stable Diffusion** — generated, ~$10–30/month.
- **Fiverr** — commissioned, $5–15 per sprite.

### Integration rule (the only one that matters)

> A bitmap asset replaces a procedural sprite **only after** the mechanic
> that sprite represents is fully functional, tested, and signed off.

If the Myrmidon's basic attack still has a damage bug, the Myrmidon does not
get a bitmap. Procedural sprite stays. Fix the bug first. This rule prevents
the most common solo-dev failure: spending a week on art for a system that
gets rewritten next week.

### Swap mechanics

When a bitmap arrives:
1. Drop file into `art/bitmap/<category>/`.
2. Swap the procedural `Node2D` for a `Sprite2D` in the entity scene.
3. Keep the procedural script in the file tree (do not delete). It is the
   fallback if the bitmap source becomes unavailable.
4. Verify the bitmap pivots at feet, matches the established silhouette,
   and reads at gameplay zoom.
5. Animations migrate from `AnimationPlayer` modulate/rotation tracks to
   sprite frame tracks. The animation *names* stay the same so calling code
   does not change.

## Audio

Same two-category model when audio enters scope:
- Category 1: silence with on-screen damage numbers and screen-shake cues.
- Category 2: licensed/sourced audio, integrated after mechanics are sound.

Audio is out of Act 1 scope until combat feel is settled.
