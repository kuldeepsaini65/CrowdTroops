# Gatecrush

A 3D crowd-cannon arcade game for Android, built with Godot 4 (GDScript).
See [CLAUDE.md](CLAUDE.md) for the full spec and [docs/PROMPTS.md](docs/PROMPTS.md) for the milestone prompts.

## Run

1. Install Godot 4.7 (standard build) and put `godot` on your PATH.
2. First time only, import the project so `class_name` scripts are registered:
   ```
   godot --headless --path . --import
   ```
   (Opening the project in the Godot editor does the same.)
3. Play: `godot --path .` or press F5 in the editor.

## Controls

| Action | Touch | Desktop |
|---|---|---|
| Move cannon | drag anywhere | A / D or ← / → |
| Fire | hold a finger down | hold Space (or hold the mouse button) |
| Pause | II button | P or Esc |

## Checks

```
godot --headless --path . --quit-after 300                              # boots the game, catches parse/runtime errors
godot --headless --path . --script res://tests/test_crowd_sim.gd        # sim + economy rule tests
```

## Layout

- `scripts/core/` — data-only crowd sim, MultiMesh renderer, FX pool, placeholder meshes
- `scripts/gameplay/` — game controller, cannon, gates, enemy fort, camera rig, level builder
- `scripts/data/` — `Tuning` constants/formulas and the `LevelDef` / `GateDef` / `UnitVisuals` resources
- `scripts/autoload/` — `GameEvents` signal bus, `SaveManager`, `AudioManager` (stub), `Haptics`
- `scripts/ui/` — HUD, pause and result overlays (minimal until Milestone 2)
