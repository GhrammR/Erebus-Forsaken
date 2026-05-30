# Stat System — Single Source of Truth

All stat math in Erebus Forsaken passes through one place: `Stats` (a Resource
class that hangs off every combatant). No script computes damage, defense, HP,
or MP from raw attributes inline. If you see `vitality * 4` outside the Stats
resource, that is a bug — fix it.

## Core attributes (4)

| Attribute  | Domain | Description                                      |
|------------|--------|--------------------------------------------------|
| Strength   | int    | Physical damage, equipment STR requirements      |
| Dexterity  | int    | Attack rating, defense contribution, ranged dmg  |
| Vitality   | int    | MaxHP                                            |
| Pneuma     | int    | MaxMP — Greek for breath/spirit/soul             |

Attribute names are fixed. Do not rename `Pneuma` to `Energy`, `Mana`,
`Spirit`, or anything else, even in temporary variables.

## Derived stats — Act 1 (5)

| Stat          | Formula (provisional, tune in stage 2)               |
|---------------|------------------------------------------------------|
| MaxHP         | `base_hp[class] + vitality * vit_per_hp[class]`      |
| MaxMP         | `base_mp[class] + pneuma * pneuma_per_mp[class]`     |
| Defense       | `dexterity / 4 + sum(armor.defense)`                 |
| AttackRating  | `dexterity * 5 + weapon.attack_rating + level * 5`   |
| Resistances   | `clamp(sum(gear.resist), 0, 75)` — single combined % |

Per-class constants live in `data/classes/<class>.tres`. Never hardcode them
in combat scripts. Tuning happens by editing the resource, not the formula.

## Derived stats — FORBIDDEN until Act 2

The following exist nowhere in the codebase during Act 1 development:

- `BlockChance`
- `CastSpeed`
- `HitRecovery`

Forbidden means:
- No fields on Stats, Item, or Class resources.
- No UI elements showing them — not even as `0%` placeholders.
- No tooltip text, no item affix names, no comments referencing them.
- No "future-proofing" stubs. Add them when Act 2 starts, not before.

If a class fantasy seems to demand one of these, design around it. Pythia's
"fast casting" identity is expressed through MP cost and skill cooldown in
Act 1 — not CastSpeed.

## Single combined Resistance

Act 1 uses one resistance number, not four. No fire/cold/lightning/poison
split. The split arrives with the elemental damage types in Act 2.

## Stat application order

1. Base from class.
2. Add per-level gains.
3. Add allocated attribute points.
4. Sum equipped item bonuses (flat first, then % multipliers).
5. Apply temporary buffs/debuffs last.

Recompute on equip change, level up, attribute spend, buff apply/expire.
Never recompute every frame.

## Invariants

- HP and MP are clamped to `[0, MaxHP]` / `[0, MaxMP]` on every write.
- AttackRating and Defense are non-negative.
- Resistance is clamped `[0, 75]` even before gear caps it.
- All stat changes emit `stats_changed` signal exactly once per batch update.
