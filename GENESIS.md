# EREBUS FORSAKEN — PROJECT GENESIS PROMPT

I am building a PC isometric ARPG called **Erebus Forsaken**. Target platform is Steam (Windows primary). Mobile is a future port, not a current concern. I am a solo developer using Claude Code as my primary AI assistant.

**Engine:** Godot 4
**Language:** GDScript
**Distribution:** Steam Early Access after Act 1 is complete and polished

---

## BUSINESS REALITY

These facts must inform every architectural and scope decision:

- The Steam publishing fee is $100. It is not paid until Act 1 is fully playable and polished. Do not reference or plan around publishing until that milestone is reached.
- Steam visibility for solo indie ARPGs is real but not guaranteed. The games that find audiences are tight and intentional, not large and half-finished. A polished one-act game outperforms a sprawling buggy four-act game every time.
- Speed is the enemy. Rushing mechanics to reach content milestones produces shallow systems that collapse under player scrutiny. Every mechanic must feel finished before the next one begins.
- Claude Code and Codex cannot generate bitmap image files (PNGs, textures). They can write code that draws procedural sprites from geometric primitives — and that is the correct approach during development.

## ART PIPELINE REALITY

There are two distinct categories of "art" in this project. Understanding the difference determines the entire development workflow.

**Procedural sprites (Claude Code writes these):**
Claude and Codex generate GDScript that draws characters, enemies, projectiles, and UI elements using Godot's drawing primitives — `draw_rect()`, `draw_circle()`, `draw_polygon()`, `draw_line()`, `ColorRect`, `Polygon2D`. A Myrmidon is a layered set of colored polygons. A Shade-Hunter is a dark silhouette with a bow shape. These are fully animatable via `AnimationPlayer`. Every mechanic ships with procedural sprites. No mechanic ever waits for art.

**Bitmap assets (external tools only):**
Claude and Codex cannot generate PNG or texture files. When Act 1 is mechanically complete and polished, bitmap art replaces procedural sprites through these sources:
- Kenney.nl — free isometric and dark fantasy asset packs, open license
- OpenGameArt.org — free community assets, many dark fantasy themed
- Midjourney or Stable Diffusion — generated sprites and backgrounds, approximately $10-30/month
- Fiverr — individual sprites commissioned per asset, $5-15 each

**Governance rule:** Bitmap assets are integrated only after the mechanic they represent is fully functional and tested. Procedural sprites are never an embarrassment — they are the proof the mechanic works.

---

## THE GAME

Dark fantasy Greek mythology. Diablo 2 in spirit — isometric, loot-driven, dark, atmospheric.

### Four Classes

- **Myrmidon** — Tank/Physical. Spear and buckler. Front-line warrior drawn from the elite soldiers of Greek legend.
- **Pythia** — Mage/Elementalist. Staff. Named for the Oracle of Delphi — commands elemental forces through divine prophecy and arcane sight.
- **Shade-Hunter** — Rogue/Ranged. Bow. A hunter of literal underworld shades — spirits of the dead that have escaped Erebus. Her identity is tied directly to the world's mythology.
- **Ossuary Priest** — Summoner/Necromancer. Wand. A death-rite priest who commands bones, souls, and the boundary between living and dead.

### Core Attributes

| Attribute | Description |
|---|---|
| Strength | Governs physical damage and equipment requirements |
| Dexterity | Governs attack rating, defense, and ranged effectiveness |
| Vitality | Governs MaxHP and survivability |
| Pneuma | Greek for breath/spirit/soul. Governs MaxMP and spell capacity |

### Derived Stats — Act 1 Only

Five derived stats. Three are explicitly locked until Act 2. Do not implement locked stats under any circumstances during Act 1 development.

**Active in Act 1:**
| Stat | Source |
|---|---|
| MaxHP | Vitality formula |
| MaxMP | Pneuma formula |
| Defense | Dexterity + armor |
| AttackRating | Dexterity + weapon |
| Resistances | Gear only — single combined value |

**Locked until Act 2 — forbidden scope:**
- BlockChance
- CastSpeed
- HitRecovery

---

## ACT 1 SCOPE — COMPLETE DEFINITION

Act 1 is the entire game until Steam launch. It contains exactly:

- One town (hub, NPC vendors, quest givers)
- One wilderness zone (open traversal, random enemies, loot)
- One dungeon (multi-room, increasing difficulty)
- One Act boss (unique mechanics, drops unique loot)
- All four classes playable from character select
- Core loot system (items drop, items equip, stats apply)
- Core combat (attack, skill, death, respawn)
- Save and load

Nothing outside this list exists until every item on this list is complete and polished.

---

## AGENTIC GOVERNANCE

Before any code or scenes are created, establish a `.agent_governance/` folder at the project root. This folder controls how we build. Every rule exists to prevent a specific failure mode.

Create the following structure:

```
.agent_governance/
  rules/
    scene-architecture.md     # how scenes connect, node tree rules, no spaghetti
    gdscript-standards.md     # coding standards, signal discipline, no magic numbers
    stat-system.md            # single source of truth for all stats and formulas
    scope-lock.md             # Act 1 definition — what is forbidden until Act 1 ships
    asset-pipeline.md         # placeholder rules, how real assets get integrated
    testing.md                # what must be tested before any feature is done
    failure-modes.md          # known ways this project can collapse and how to prevent them
  skills/
    combat-validator/         # auto-check combat changes for stat consistency
    scene-auditor/            # check for orphaned nodes and broken signals
    class-balance/            # flag stat changes that break class identity
  commands/
    playtest.md               # how to run and what to verify each session
    audit.md                  # full project health check
    act1-status.md            # living checklist of Act 1 completion criteria
  CLAUDE.md                   # master index, role, tone, non-negotiables
```

The CLAUDE.md for this project must establish:
- **Role:** Godot 4 architect and GDScript engineer
- **Tone:** Direct, no filler, flag problems before they compound
- **Non-negotiables:**
  - Never skip the scope lock
  - Never build Act 2 content while Act 1 has open items
  - Always keep something runnable after every session
  - Placeholders are valid and respected — art never blocks mechanics
  - The three deferred stats do not exist until Act 2
  - Depth before speed — every mechanic finished before the next begins

---

## YOUR FIRST TASK

Do not write game code yet. Do three things first:

1. Write the complete contents of every `.agent_governance/` file listed above, tailored specifically to an isometric ARPG in Godot 4. Rules must be specific enough to prevent real bugs — not generic enough to be ignored. The stat-system.md must document the Act 1 / Act 2 split explicitly and treat the three deferred stats as forbidden scope. The failure-modes.md must include: scope creep, art blocking mechanics, shallow systems rushed for content, and context loss between sessions.

2. Propose the full Godot project folder structure — scenes, scripts, resources, assets — keeping engine-level systems separate from game-content files.

3. Propose the build order for Act 1 in stages. Each stage must leave the project in a runnable state. Flag any stat design or structural decision that will cause problems later and suggest the fix now before it is expensive.

After I approve governance, structure, and build order — we begin Stage 1. One stage at a time. No exceptions.
