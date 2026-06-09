# Scope Lock — Act 1 Definition

This rule exists because solo ARPGs die from sprawl, not from missing features.
A polished one-act game outsells a half-built four-act game. Treat every
expansion request as a threat to ship date until proven otherwise.

**2026-06-04 scope expansion (logged):** Act 1's content target grew
substantially with explicit user approval. The Act-2 lock below is
unchanged — it is *tighter* now, because the bigger Act 1 makes it more
tempting to bleed into Act 2 territory. Resist that.

## Act 1 contains (target for content-complete release)

- One **town** — hub area with multiple NPC slots: vendor (Kallias),
  quest-giver (Eurynome), and additional roles as they land. Town is also
  the entry point for The Maw (Stage 19 moves it here from the Crypt).
- **10+ wilderness zones** linked by walkable paths (no portal hops
  between adjacent wilderness areas). Procedurally generated per
  new-game seed; aesthetics vary across runs. Each zone has at least
  one road/path that winds rather than runs straight to the next exit.
- **5+ dungeons** scattered through the wilderness chain. Each dungeon
  is optional and yields meaningful loot or quest objective.
- **One final Act boss** — climactic encounter at the end of the chain.
  Current Act Boss identity: Hexacheir, the God-Spurned, first demon
  encounter and six-arm bespoke rig. Hekate-Marked is retained only as
  legacy/rare routing metadata unless Stage 18 explicitly re-scopes it.
- **Waypoint system** — themed, persistent, discoverable. Lets players
  fast-travel to previously-visited wilderness zones for revisits.
- **5+ quests per Act** — semi-related to town/wilderness needs; final
  quest is the town's request to defeat the final boss.
- **All four classes playable**: Myrmidon, Pythia, Shade-Hunter,
  Ossuary Priest.
- **Core loot system** — items drop, items equip, equipped stats apply,
  items persist. Equipment changes character appearance (paper-doll;
  bare-hands default until a weapon equips). Items shown as icons in
  inventory, not text rows.
- **Core combat** — basic attack, one class skill per class, enemy AI,
  death, respawn at town. Crit math + feel pass landed pre-expansion.
- **Save and load** — single character slot per session is fine for Act 1.
  Multiple save slots is post-launch scope.
- **The Maw (endless mode)** — town-accessible challenge dungeon. Gated
  behind the player completing at least one quest (Stage 19 — the gate
  satisfies the rollback-anchor requirement). The Maw is a side activity,
  not on the critical path to the final boss.
- **NPC voice + portrait** — each town NPC has a one-time intro line
  with spoken audio (AI-generated, hybrid art policy).
- **Target playtime to final boss** — 2+ hours for a first run.

## Release plan

**Single dual launch — Steam + itch.io same day.** No staged free demo,
no Early Access split between platforms. Act 1 ships when every entry
above is content-complete, every verifier PASSes, and the launch-plan
checklist is complete. See `commands/launch-plan.md`.

## Explicitly out of scope until Act 1 ships

- Acts 2, 3, 4 — no zones, no enemies, no items, no narrative.
- The three deferred stats (`BlockChance`, `CastSpeed`, `HitRecovery`).
- Crafting, gambling, gem socketing, runewords, enchantments.
- Multiplayer, co-op, trading, leaderboards, achievements.
- Difficulty modes beyond a single Act 1 baseline.
- Multiple save slots, cloud save, controller remapping UI.
- Stash, shared stash, inventory tabs.
- Skill trees beyond the one starter skill per class. (Tree comes after the
  core loop is proven.)
- Cosmetic options, transmog, dyes.
- Mobile considerations of any kind.
- Steam integration (achievements, workshop, cloud) — only after $100 fee is
  justified by a finished Act 1.

## Allowed exceptions

A single second skill per class is permitted *only after* every other Act 1
checklist item is complete and playtested. Until then, one skill per class.

## Art policy (hybrid, 2026-06-04)

Procedural sprites remain the **always-shippable baseline**. AI-generated
bitmap is an **optional polish layer**: if a generated asset isn't ready,
the feature ships with its procedural drawing and is no less complete for
it. The hybrid contract is locked in `rules/asset-pipeline.md` and the
generation pipeline lives in `rules/asset-generation.md`. A new feature
**must** ship its procedural form before its bitmap form is even attempted.

## Enforcement

If the user requests out-of-scope work:
1. Name the rule.
2. Point to which Act 1 item the work would displace.
3. Offer the smallest equivalent that fits Act 1, or defer.

Do not silently comply. Do not partially comply. Surface the conflict.
