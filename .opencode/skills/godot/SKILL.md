---
name: godot
description: Use when working with Godot Engine, GDScript, .tscn scene files, .tres resources, or Godot-specific project files. Covers player controllers, multiplayer networking, power-ups, UI scenes, arena logic, and Godot editor workflows.
---

# Godot Development Skill

## Project: Capibraba

A 3D multiplayer arena party game (capybara battle royale on lava platforms) built with Godot 4.7 + GDScript + ENet + Jolt Physics.

## Key architecture

```
scripts/
├── game/         # Core game logic (game_manager, last_standing_manager, powerup_manager, etc.)
├── player/       # Player controller, abilities, projectiles
├── powerups/     # Power-up base + individual power-up scripts
├── network/      # ENet multiplayer (network_manager.gd)
├── ui/           # All UI screen scripts
└── arena/        # Arena hazards (meteor, fire_pillar)

scenes/
├── levels/       # Arena .tscn files
├── player/       # Player, projectile scenes
├── powerups/     # Power-up pickup scenes
└── ui/           # UI screen scenes
```

## Autoloads (global singletons)

| Name | File | Role |
|---|---|---|
| `NetworkManager` | `scripts/network/network_manager.gd` | ENet host/join/disconnect |
| `GameSettings` | `scripts/game/game_settings.gd` | Persisted user settings |
| `MatchSettings` | `scripts/game/match_settings.gd` | Match configuration |
| `MatchPresets` | `scripts/game/match_presets.gd` | 7 preset configurations |

## Multiplayer model

- Server-authoritative: host controls spawning, damage, death, power-ups, events, win conditions
- Clients send input; server validates and applies
- RPCs for discrete events; `MultiplayerSynchronizer` for continuous state

## Adding new power-ups

1. Create `scripts/powerups/powerup_<name>.gd` extending `powerup_base.gd`
2. Create `scenes/powerups/powerup_<name>.tscn` with Area3D root
3. Register in `player_abilities.gd` state machine
4. Add to `MatchSettings` power-up pool
5. Add scene to `powerup_manager.gd` spawn pool

## Adding new arenas

1. Create `scenes/levels/<name>.tscn` with Node3D root
2. Add lava areas (Area3D + StaticBody3D with kill zones)
3. Add spawn points (Marker3D nodes)
4. Register in `arena_select.gd`

## GDScript conventions

- Tabs, 4-space width
- Godot 4 syntax: `@export`, `@onready`, `await`
- Typed variables where possible
- Brazilian Portuguese for comments/UI
- Signals at top of file
