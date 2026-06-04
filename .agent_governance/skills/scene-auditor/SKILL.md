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

9. **Hidden UI scenes still eating input** (failure-modes.md #14)
   - For each hideable UI scene (pause menu, inventory panel, modal
     dialog, tooltip), walk the subtree at startup and confirm every
     Control has `mouse_filter = IGNORE` while the scene is hidden.
   - Required pattern: a script-side `_set_input_active(bool)` method
     called from `_ready`, `open`, and `hide`. See `pause_menu.gd`
     and `inventory_panel.gd`.
   - Workbench-friendly audit:
     ```gdscript
     # Walk get_tree().root at startup, fail on:
     #   Control where mouse_filter != IGNORE AND parent CanvasLayer.visible == false
     ```

8. **CollisionObject2D consuming gameplay clicks** (failure-modes.md #13)
   - Every gameplay `Area2D`, `CharacterBody2D`, `StaticBody2D`, or
     `RigidBody2D` that is not meant to handle mouse input must have
     `input_pickable = false` — in its `.tscn` *or* set in `_ready()`
     via an actor/component script.
   - WARN: any of the above node types whose `.tscn` doesn't set
     `input_pickable = false` **and** whose script doesn't disable
     it in code. Default `true` silently consumes click-to-move
     events within the collision shape — produces invisible
     "dead zones" where the body sits.
   - Audit grep (fast first-pass):
     ```
     grep -rnE '\[node.*type="(Area2D|CharacterBody2D|StaticBody2D|RigidBody2D)"' \
       --include="*.tscn" scenes/ test/
     ```
     Then for each, verify either the .tscn or the script disables
     `input_pickable`.

10. **Feel-pass contract coverage** (rules/feel-pass.md)
    - Every row of the feel-pass.md event table must have both an
      AudioBank call site and a visual hook somewhere in
      production code (`scripts/`, `scenes/`).
    - Audio side: grep for `play_sfx(&"<id>"` OR a bare `&"<id>"`
      reference (covers dynamic lookups like
      `AudioBank._PICKUP_SFX.get(id, &"pickup_item")`).
    - Visual side: grep for the row's canonical marker (HUD node
      name, VFX preload, CameraShake/HitStop call, or scene
      preload). The Stage 9.5 verifier
      (`test/stage9_5_verify.gd::_verify_contract_visuals`) carries
      the canonical marker list; scene-auditor reuses it.
    - FAIL if either column is missing for any contract row.
    - WARN if a row's marker appears only in a workbench
      (`test/`) directory and nowhere in production code.

7. **Passive Controls absorbing input** (failure-modes.md #9)
   - Any `Control` subtype meant for display only (backgrounds,
     HUD labels, debug overlays, decorative panels) must set
     `mouse_filter = 2` (`MOUSE_FILTER_IGNORE`) in its `.tscn`.
   - Heuristic audit: for each Control node lacking `mouse_filter`
     in its scene block, flag it unless the scene is clearly an
     interactive UI scene (pause menu, character select, etc.).
   - Quick scan:
     ```
     # Find Control-derived nodes that don't set mouse_filter:
     for f in $(find scenes test -name '*.tscn'); do
       awk '/type=\"(ColorRect|Label|PanelContainer|MarginContainer|RichTextLabel|TextureRect|Container)\"/ {n=$0; flag=0; next} /^\[node/ {if (n && !flag) print FILENAME":"NR": "n; n=""} /mouse_filter\s*=/ {flag=1}' "$f"
     done
     ```
   - WARN, not FAIL — sometimes a scene's author intentionally wants
     the default. Surface for review.

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
