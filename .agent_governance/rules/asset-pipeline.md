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
