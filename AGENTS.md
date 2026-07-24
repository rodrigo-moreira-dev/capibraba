# Capibraba — Development Guide

## Project

3D multiplayer arena party game (capybara battle royale). Godot 4.7, GDScript, ENet, Jolt Physics.

## Quick commands

- **Run game**: Open in Godot 4.7 editor, press Play (main scene: `scenes/ui/main_menu.tscn`)
- **Export**: Use Godot's built-in export system

## Directory layout

```
scenes/          # .tscn scene files (levels/, player/, powerups/, ui/)
scripts/         # .gd scripts (game/, player/, powerups/, network/, ui/, arena/)
docs/            # Design documents
```

## Key files

| File | Purpose |
|---|---|
| `scripts/game/last_standing_manager.gd` | Main game mode: lives, deaths, kills, elimination, rounds |
| `scripts/player/player.gd` | Base CharacterBody3D controller |
| `scripts/player/player_extended.gd` | Extended player with abilities |
| `scripts/player/player_abilities.gd` | Power-up state machine |
| `scripts/network/network_manager.gd` | ENet multiplayer singleton |
| `scripts/game/match_settings.gd` | All configurable match parameters |
| `scripts/game/match_presets.gd` | 7 predefined match configs |
| `scripts/game/powerup_manager.gd` | Server-authoritative power-up spawning |
| `scripts/game/arena_event_manager.gd` | Random arena events |

## Conventions

- Server is authoritative for all game state
- Brazilian Portuguese for comments and UI text
- Follow existing code patterns; read neighboring files before adding new ones
- Power-ups extend `powerup_base.gd`
- UI screens each have a `.tscn` + `.gd` pair in their respective folders
