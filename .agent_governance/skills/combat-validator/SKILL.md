---
name: combat-validator
description: Audit combat-related changes against stat-system invariants. Run before committing combat code. Verifies that damage math only happens in Stats, that the three deferred stats are not referenced, and that signals follow the event-bus pattern.
---

# Combat Validator

## When to invoke

- After any edit to `Stats`, `HealthComponent`, `HitboxComponent`,
  damage-dealing skills, or enemy AI.
- Before declaring a combat feature "done" per `rules/testing.md`.

## What it checks

1. **Stat-source-of-truth**
   - `grep -rn -E "(strength|dexterity|vitality|pneuma)\s*\*" --include="*.gd"`
     outside `stats.gd` → fail. All arithmetic on attributes lives in Stats.

2. **Forbidden Act 2 stats**
   - `grep -rni -E "block_?chance|cast_?speed|hit_?recovery" --include="*.gd" --include="*.tres" --include="*.tscn"`
     → any match fails.

3. **HP/MP clamping**
   - Every assignment to `current_hp` or `current_mp` must clamp via the
     setter, or use the `take_damage` / `spend_mp` method. Direct
     `current_hp = X` outside Stats fails.
   - Audit regex (excludes `==` comparisons and `=%d` format-string
     labels; both produced false positives in Stage 1):
     ```
     grep -rnE "current_(hp|mp)\s*=[^=%]" --include="*.gd" \
       scripts/ scenes/ test/ | grep -v "scripts/systems/stats.gd"
     ```
     Expected: empty output.

4. **Signal hygiene**
   - Combat signals are declared on emitters and connect via code in
     `_ready`. Any editor-wired combat signal (in `.tscn` `[connection]`
     blocks) is flagged for review.

5. **Damage resolution path**
   - All damage routes through `HealthComponent.take_damage(amount, source)`.
     Direct `hp -= dmg` is a fail.

## Report format

```
combat-validator: <PASS|FAIL>
  [PASS] stat source of truth
  [FAIL] forbidden Act 2 stats — found `cast_speed` in scripts/ui/tooltip.gd:42
  [PASS] hp/mp clamping
  [WARN] editor-wired signal: enemies/myrmidon_grunt.tscn `died` → ui/hud
  [PASS] damage resolution path
```

Fail blocks "done." Warn surfaces for human judgment.
