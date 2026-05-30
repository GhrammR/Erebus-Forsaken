---
name: class-balance
description: Flag stat or skill changes that erode class identity. Runs against the class resource files and starter-skill definitions. Use whenever per-class numbers change.
---

# Class Balance

## When to invoke

- After edits to `data/classes/*.tres`.
- After edits to any starter skill (`data/skills/*.tres` or `skills/*.gd`).
- Before declaring a class "tuned."

## Class identity invariants (Act 1)

| Class          | Role       | Must remain true                                       |
|----------------|------------|--------------------------------------------------------|
| Myrmidon       | Tank       | Highest base HP, highest base STR, melee range only.   |
| Pythia         | Mage       | Highest base MP, highest base Pneuma, lowest HP pool.  |
| Shade-Hunter   | Ranged     | Highest base DEX, attack reach > melee classes.        |
| Ossuary Priest | Summoner   | Owns minion mechanic; lower direct dmg than Pythia.    |

## Checks

1. **Base stat ordering**
   - HP at level 1: Myrmidon > Shade-Hunter ≥ Ossuary Priest > Pythia.
   - MP at level 1: Pythia > Ossuary Priest > Shade-Hunter ≥ Myrmidon.
   - Violations flagged as FAIL.

2. **Attribute primaries**
   - Each class's per-level primary attribute gain ≥ all secondaries.
   - Primaries: Myr=STR, Pyt=Pneuma, SH=DEX, OP=Pneuma.

3. **Starter skill cost band**
   - Skill MP cost in `[5, 25]` at level 1.
   - Skill cooldown in `[0.5, 6.0]` seconds.

4. **No forbidden stat references**
   - Class and skill resources do not name `BlockChance`, `CastSpeed`,
     `HitRecovery`.

5. **Cross-class power check**
   - Per-skill DPS-on-target-dummy variance across classes < 25%.
     (Run via test scene; this is informational, not gating.)

## Report format

```
class-balance: <PASS|FAIL>
  [PASS] base HP ordering
  [FAIL] base MP ordering — Ossuary Priest (45) > Pythia (40)
  [PASS] attribute primaries
  [WARN] starter skill cost: Shade-Hunter `Volley` MP cost 28 (band max 25)
  [PASS] forbidden stat references
  [INFO] DPS variance: Myr 100, Pyt 112, SH 95, OP 88 — within band
```
