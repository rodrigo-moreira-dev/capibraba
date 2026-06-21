extends Node

## MatchPresets - Configurações predefinidas de partida (autoload singleton)

const PRESETS := {
	"classic": {
		"name": "🎹 Clássico",
		"description": "Configuração padrão do jogo original",
		"settings": {
			"lives_per_player": 3,
			"match_time_limit": 0.0,
			"rounds_to_win": 0,
			"sudden_death_time": 0.0,
			"kill_streak_enabled": false,
			"powerups_enabled": false,
			"arena_events_enabled": false,
			"ability_grappling_hook_enabled": false,
			"ability_teleport_enabled": false,
			"ability_freeze_enabled": false,
			"ability_body_push_enabled": false,
			"ability_air_dash_enabled": false,
			"ability_ground_pound_enabled": false,
		}
	},
	"chaos": {
		"name": "💥 Caos Total",
		"description": "Tudo ativado! Máxima diversão e confusão",
		"settings": {
			"lives_per_player": 5,
			"match_time_limit": 0.0,
			"rounds_to_win": 0,
			"sudden_death_time": 2.0,
			"kill_streak_enabled": true,
			"powerups_enabled": true,
			"powerup_spawn_interval": 8.0,
			"powerup_shield_enabled": true,
			"powerup_superspeed_enabled": true,
			"powerup_triple_jump_enabled": true,
			"powerup_homing_projectile_enabled": true,
			"powerup_mine_enabled": true,
			"powerup_magnet_enabled": true,
			"powerup_zero_gravity_enabled": true,
			"arena_events_enabled": true,
			"arena_event_interval": 15.0,
			"event_meteor_rain_enabled": true,
			"event_earthquake_enabled": true,
			"event_strong_wind_enabled": true,
			"event_fire_pillars_enabled": true,
			"ability_grappling_hook_enabled": true,
			"ability_teleport_enabled": true,
			"ability_freeze_enabled": true,
			"ability_body_push_enabled": true,
			"ability_air_dash_enabled": true,
			"ability_ground_pound_enabled": true,
		}
	},
	"competitive": {
		"name": "🏆 Competitivo",
		"description": "Rounds, kill streak e sudden death para partidas sérias",
		"settings": {
			"lives_per_player": 3,
			"match_time_limit": 5.0,
			"rounds_to_win": 3,
			"sudden_death_time": 3.0,
			"kill_streak_enabled": true,
			"powerups_enabled": false,
			"arena_events_enabled": false,
			"ability_grappling_hook_enabled": false,
			"ability_teleport_enabled": false,
			"ability_freeze_enabled": false,
			"ability_body_push_enabled": false,
			"ability_air_dash_enabled": false,
			"ability_ground_pound_enabled": false,
		}
	},
	"powerup_fiesta": {
		"name": "⭐ Festa de Power-ups",
		"description": "Só power-ups, sem habilidades permanentes",
		"settings": {
			"lives_per_player": 5,
			"match_time_limit": 0.0,
			"rounds_to_win": 0,
			"sudden_death_time": 0.0,
			"kill_streak_enabled": false,
			"powerups_enabled": true,
			"powerup_spawn_interval": 6.0,
			"powerup_shield_enabled": true,
			"powerup_superspeed_enabled": true,
			"powerup_triple_jump_enabled": true,
			"powerup_homing_projectile_enabled": true,
			"powerup_mine_enabled": true,
			"powerup_magnet_enabled": true,
			"powerup_zero_gravity_enabled": true,
			"arena_events_enabled": false,
			"ability_grappling_hook_enabled": false,
			"ability_teleport_enabled": false,
			"ability_freeze_enabled": false,
			"ability_body_push_enabled": false,
			"ability_air_dash_enabled": false,
			"ability_ground_pound_enabled": false,
		}
	},
	"ninja": {
		"name": "🥷 Ninja",
		"description": "Todas as habilidades de movimento ativadas",
		"settings": {
			"lives_per_player": 3,
			"match_time_limit": 0.0,
			"rounds_to_win": 0,
			"sudden_death_time": 0.0,
			"kill_streak_enabled": false,
			"powerups_enabled": false,
			"arena_events_enabled": false,
			"ability_grappling_hook_enabled": true,
			"ability_teleport_enabled": true,
			"ability_freeze_enabled": false,
			"ability_body_push_enabled": false,
			"ability_air_dash_enabled": true,
			"ability_ground_pound_enabled": true,
		}
	},
	"apocalypse": {
		"name": "🌋 Apocalipse",
		"description": "Eventos de arena extremos com plataformas perigosas",
		"settings": {
			"lives_per_player": 5,
			"match_time_limit": 0.0,
			"rounds_to_win": 0,
			"sudden_death_time": 1.0,
			"kill_streak_enabled": true,
			"powerups_enabled": true,
			"powerup_spawn_interval": 15.0,
			"powerup_shield_enabled": true,
			"powerup_superspeed_enabled": false,
			"powerup_triple_jump_enabled": true,
			"powerup_homing_projectile_enabled": false,
			"powerup_mine_enabled": false,
			"powerup_magnet_enabled": false,
			"powerup_zero_gravity_enabled": true,
			"arena_events_enabled": true,
			"arena_event_interval": 10.0,
			"event_meteor_rain_enabled": true,
			"event_earthquake_enabled": true,
			"event_strong_wind_enabled": true,
			"event_fire_pillars_enabled": true,
			"moving_platforms_enabled": false,
			"trampolines_enabled": false,
			"danger_zones_enabled": true,
			"breaking_platforms_enabled": true,
			"auto_cannons_enabled": true,
			"ability_grappling_hook_enabled": true,
			"ability_teleport_enabled": false,
			"ability_freeze_enabled": false,
			"ability_body_push_enabled": false,
			"ability_air_dash_enabled": true,
			"ability_ground_pound_enabled": false,
		}
	},
	"quick": {
		"name": "⚡ Partida Rápida",
		"description": "1 vida, sudden death imediato, máximo de ação",
		"settings": {
			"lives_per_player": 1,
			"match_time_limit": 3.0,
			"rounds_to_win": 0,
			"sudden_death_time": 1.0,
			"kill_streak_enabled": false,
			"powerups_enabled": false,
			"arena_events_enabled": true,
			"arena_event_interval": 12.0,
			"event_meteor_rain_enabled": true,
			"event_earthquake_enabled": false,
			"event_strong_wind_enabled": true,
			"event_fire_pillars_enabled": false,
			"ability_grappling_hook_enabled": false,
			"ability_teleport_enabled": false,
			"ability_freeze_enabled": false,
			"ability_body_push_enabled": false,
			"ability_air_dash_enabled": false,
			"ability_ground_pound_enabled": false,
		}
	},
}


func apply_preset(preset_id: String) -> void:
	var preset: Dictionary = PRESETS.get(preset_id, {})
	if preset.is_empty():
		return

	var settings: Dictionary = preset.get("settings", {})
	for key in settings:
		if MatchSettings.get(key) != null:
			MatchSettings.set(key, settings[key])


func get_preset_name(preset_id: String) -> String:
	var preset: Dictionary = PRESETS.get(preset_id, {})
	return preset.get("name", preset_id)


func get_preset_description(preset_id: String) -> String:
	var preset: Dictionary = PRESETS.get(preset_id, {})
	return preset.get("description", "")


func get_all_presets() -> Dictionary:
	return PRESETS
