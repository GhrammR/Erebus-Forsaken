---
name: scene-auditor
description: Detect orphaned nodes, broken signal connections, missing @onready targets, and absolute path references in .tscn scene files. Run before any zone transition work and as part of audits.
---

# Scene Auditor

## When to invoke

- After significant scene-tree changes (renames, restructures).
- Before merging zone or UI work.
- Part of the `commands/audit.md` health check.

## What it checks

1. **Orphaned nodes**
   - Nodes referenced by `@onready var x = $Path` where `$Path` does not
     resolve in the scene's tree.
   - Nodes referenced by `[connection]` blocks whose target node is missing.

2. **Broken signal connections in `.tscn`**
   - `[connection signal="..." from="A" to="B" method="..."]` where B has
     no script, or the script has no such method.

3. **NodePath exports without value**
   - `@export var target: NodePath` with no inspector-set value and no
     code-side fallback.

4. **Forbidden path patterns**
   - `get_node("../../..")` and longer.
   - `get_tree().root.get_node("/root/Main/...")` from non-autoload scripts.
   - Absolute resource paths committed by mistake (e.g., user home dirs).

5. **Y-sort and pivot consistency**
   - Gameplay scenes flagged if their root or gameplay layer is not Y-sorted.
   - Sprite pivots not at feet (heuristic: `offset.y >= 0` warning).

6. **Autoload reference correctness**
   - Calls to autoload names not declared in `project.godot`.

## Report format

```
scene-auditor: <PASS|FAIL>
  scenes scanned: 23
  [FAIL] orphan @onready: player/player.gd:14 `$Sprite/Glow` missing
  [FAIL] broken signal: ui/inventory.tscn `pressed` → method `_on_close` missing
  [WARN] unset NodePath export: enemies/shade.gd `target`
  [PASS] no forbidden node paths
  [PASS] autoloads
```
