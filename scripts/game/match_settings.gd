extends Node

## MatchSettings - Configurações de partida selecionáveis
## Este recurso controla todas as funcionalidades ativadas/desativadas

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES GERAIS
# ═══════════════════════════════════════════════════════════════════════════════

## Número de vidas por jogador (1, 3, 5, 10)
var lives_per_player: int = 3

## Limite de tempo da partida em segundos (0 = sem limite)
var match_time_limit: float = 0.0

## Número de rounds para vencer (0 = sem rounds, eliminação única)
var rounds_to_win: int = 0

## Sudden Death - plataforma encolhe após X segundos (0 = desativado)
var sudden_death_time: float = 0.0

## Kill Streak - bônus por eliminações consecutivas
var kill_streak_enabled: bool = false
var kill_streak_bonus: int = 3  # Vidas extras a cada X kills

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORIA 1: POWER-UPS E ITENS
# ═══════════════════════════════════════════════════════════════════════════════

var powerups_enabled: bool = false
var powerup_spawn_interval: float = 12.0

var powerup_shield_enabled: bool = true        ## 1.1 - Protege de 1 explosão/lava
var powerup_superspeed_enabled: bool = true    ## 1.2 - Velocidade aumentada
var powerup_triple_jump_enabled: bool = true   ## 1.3 - Pulo extra temporário
var powerup_homing_projectile_enabled: bool = true ## 1.4 - Projétil guiado
var powerup_mine_enabled: bool = true          ## 1.5 - Mina de contato
var powerup_magnet_enabled: bool = true        ## 1.6 - Atrai jogadores
var powerup_zero_gravity_enabled: bool = true  ## 1.7 - Flutuar

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORIA 2: MECÂNICAS DE ARENA
# ═══════════════════════════════════════════════════════════════════════════════

var arena_events_enabled: bool = false
var arena_event_interval: float = 20.0

var event_meteor_rain_enabled: bool = true     ## 2.1a - Chuva de meteoros
var event_earthquake_enabled: bool = true      ## 2.1b - Terremoto (empurra todos)
var event_strong_wind_enabled: bool = true     ## 2.1c - Vento forte lateral
var event_fire_pillars_enabled: bool = true    ## 2.1d - Pilares de fogo

var moving_platforms_enabled: bool = false     ## 2.2 - Plataformas móveis
var trampolines_enabled: bool = false          ## 2.3 - Trampolins
var danger_zones_enabled: bool = false         ## 2.4 - Zonas de perigo
var breaking_platforms_enabled: bool = false   ## 2.5 - Plataformas que quebram
var auto_cannons_enabled: bool = false         ## 2.6 - Canhões automáticos

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORIA 3: HABILIDADES DO JOGADOR
# ═══════════════════════════════════════════════════════════════════════════════

var ability_grappling_hook_enabled: bool = false  ## 3.1 - Gancho
var ability_teleport_enabled: bool = false        ## 3.2 - Teleporte curto
var ability_freeze_enabled: bool = false          ## 3.3 - Congelar jogador
var ability_body_push_enabled: bool = false       ## 3.4 - Empurrão corporal
var ability_air_dash_enabled: bool = false        ## 3.5 - Dash aéreo extra
var ability_ground_pound_enabled: bool = false    ## 3.6 - Golpe de área

# Configurações de habilidades
var grappling_hook_range: float = 15.0
var grappling_hook_cooldown: float = 3.0
var teleport_distance: float = 8.0
var teleport_cooldown: float = 4.0
var freeze_duration: float = 2.0
var freeze_cooldown: float = 8.0
var ground_pound_force: float = 30.0
var ground_pound_cooldown: float = 5.0

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORIA 4: SISTEMA DE JOGO ( já coberto acima )
# ═══════════════════════════════════════════════════════════════════════════════

var game_mode_variant: String = "standard"  # "standard", "teams", "ffa", "king_of_hill"

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORIA 5: COSMÉTICOS E FEEDBACK
# ═══════════════════════════════════════════════════════════════════════════════

var particle_hit_effects_enabled: bool = true
var sound_impact_enhanced: bool = true
var kill_cam_enabled: bool = false

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORIA 6: SOCIAL E UI
# ═══════════════════════════════════════════════════════════════════════════════

var quick_chat_enabled: bool = false
var post_match_stats_enabled: bool = true
var private_room: bool = false
var room_password: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# SAVE/LOAD
# ═══════════════════════════════════════════════════════════════════════════════

const SAVE_PATH := "user://match_settings.cfg"


func save() -> void:
	var cfg := ConfigFile.new()
	
	# Gerais
	cfg.set_value("general", "lives_per_player", lives_per_player)
	cfg.set_value("general", "match_time_limit", match_time_limit)
	cfg.set_value("general", "rounds_to_win", rounds_to_win)
	cfg.set_value("general", "sudden_death_time", sudden_death_time)
	cfg.set_value("general", "kill_streak_enabled", kill_streak_enabled)
	cfg.set_value("general", "kill_streak_bonus", kill_streak_bonus)
	
	# Power-ups
	cfg.set_value("powerups", "enabled", powerups_enabled)
	cfg.set_value("powerups", "spawn_interval", powerup_spawn_interval)
	cfg.set_value("powerups", "shield", powerup_shield_enabled)
	cfg.set_value("powerups", "superspeed", powerup_superspeed_enabled)
	cfg.set_value("powerups", "triple_jump", powerup_triple_jump_enabled)
	cfg.set_value("powerups", "homing_projectile", powerup_homing_projectile_enabled)
	cfg.set_value("powerups", "mine", powerup_mine_enabled)
	cfg.set_value("powerups", "magnet", powerup_magnet_enabled)
	cfg.set_value("powerups", "zero_gravity", powerup_zero_gravity_enabled)
	
	# Arena Events
	cfg.set_value("arena", "events_enabled", arena_events_enabled)
	cfg.set_value("arena", "event_interval", arena_event_interval)
	cfg.set_value("arena", "meteor_rain", event_meteor_rain_enabled)
	cfg.set_value("arena", "earthquake", event_earthquake_enabled)
	cfg.set_value("arena", "strong_wind", event_strong_wind_enabled)
	cfg.set_value("arena", "fire_pillars", event_fire_pillars_enabled)
	cfg.set_value("arena", "moving_platforms", moving_platforms_enabled)
	cfg.set_value("arena", "trampolines", trampolines_enabled)
	cfg.set_value("arena", "danger_zones", danger_zones_enabled)
	cfg.set_value("arena", "breaking_platforms", breaking_platforms_enabled)
	cfg.set_value("arena", "auto_cannons", auto_cannons_enabled)
	
	# Habilidades
	cfg.set_value("abilities", "grappling_hook", ability_grappling_hook_enabled)
	cfg.set_value("abilities", "teleport", ability_teleport_enabled)
	cfg.set_value("abilities", "freeze", ability_freeze_enabled)
	cfg.set_value("abilities", "body_push", ability_body_push_enabled)
	cfg.set_value("abilities", "air_dash", ability_air_dash_enabled)
	cfg.set_value("abilities", "ground_pound", ability_ground_pound_enabled)
	
	# Cosméticos
	cfg.set_value("cosmetics", "particle_effects", particle_hit_effects_enabled)
	cfg.set_value("cosmetics", "enhanced_sounds", sound_impact_enhanced)
	cfg.set_value("cosmetics", "kill_cam", kill_cam_enabled)
	
	# Social
	cfg.set_value("social", "quick_chat", quick_chat_enabled)
	cfg.set_value("social", "post_match_stats", post_match_stats_enabled)
	
	cfg.save(SAVE_PATH)


func load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	
	# Gerais
	lives_per_player = cfg.get_value("general", "lives_per_player", 3)
	match_time_limit = cfg.get_value("general", "match_time_limit", 0.0)
	rounds_to_win = cfg.get_value("general", "rounds_to_win", 0)
	sudden_death_time = cfg.get_value("general", "sudden_death_time", 0.0)
	kill_streak_enabled = cfg.get_value("general", "kill_streak_enabled", false)
	kill_streak_bonus = cfg.get_value("general", "kill_streak_bonus", 3)
	
	# Power-ups
	powerups_enabled = cfg.get_value("powerups", "enabled", false)
	powerup_spawn_interval = cfg.get_value("powerups", "spawn_interval", 12.0)
	powerup_shield_enabled = cfg.get_value("powerups", "shield", true)
	powerup_superspeed_enabled = cfg.get_value("powerups", "superspeed", true)
	powerup_triple_jump_enabled = cfg.get_value("powerups", "triple_jump", true)
	powerup_homing_projectile_enabled = cfg.get_value("powerups", "homing_projectile", true)
	powerup_mine_enabled = cfg.get_value("powerups", "mine", true)
	powerup_magnet_enabled = cfg.get_value("powerups", "magnet", true)
	powerup_zero_gravity_enabled = cfg.get_value("powerups", "zero_gravity", true)
	
	# Arena Events
	arena_events_enabled = cfg.get_value("arena", "events_enabled", false)
	arena_event_interval = cfg.get_value("arena", "event_interval", 20.0)
	event_meteor_rain_enabled = cfg.get_value("arena", "meteor_rain", true)
	event_earthquake_enabled = cfg.get_value("arena", "earthquake", true)
	event_strong_wind_enabled = cfg.get_value("arena", "strong_wind", true)
	event_fire_pillars_enabled = cfg.get_value("arena", "fire_pillars", true)
	moving_platforms_enabled = cfg.get_value("arena", "moving_platforms", false)
	trampolines_enabled = cfg.get_value("arena", "trampolines", false)
	danger_zones_enabled = cfg.get_value("arena", "danger_zones", false)
	breaking_platforms_enabled = cfg.get_value("arena", "breaking_platforms", false)
	auto_cannons_enabled = cfg.get_value("arena", "auto_cannons", false)
	
	# Habilidades
	ability_grappling_hook_enabled = cfg.get_value("abilities", "grappling_hook", false)
	ability_teleport_enabled = cfg.get_value("abilities", "teleport", false)
	ability_freeze_enabled = cfg.get_value("abilities", "freeze", false)
	ability_body_push_enabled = cfg.get_value("abilities", "body_push", false)
	ability_air_dash_enabled = cfg.get_value("abilities", "air_dash", false)
	ability_ground_pound_enabled = cfg.get_value("abilities", "ground_pound", false)
	
	# Cosméticos
	particle_hit_effects_enabled = cfg.get_value("cosmetics", "particle_effects", true)
	sound_impact_enhanced = cfg.get_value("cosmetics", "enhanced_sounds", true)
	kill_cam_enabled = cfg.get_value("cosmetics", "kill_cam", false)
	
	# Social
	quick_chat_enabled = cfg.get_value("social", "quick_chat", false)
	post_match_stats_enabled = cfg.get_value("social", "post_match_stats", true)


func reset_to_defaults() -> void:
	lives_per_player = 3
	match_time_limit = 0.0
	rounds_to_win = 0
	sudden_death_time = 0.0
	kill_streak_enabled = false
	kill_streak_bonus = 3
	
	powerups_enabled = false
	powerup_spawn_interval = 12.0
	powerup_shield_enabled = true
	powerup_superspeed_enabled = true
	powerup_triple_jump_enabled = true
	powerup_homing_projectile_enabled = true
	powerup_mine_enabled = true
	powerup_magnet_enabled = true
	powerup_zero_gravity_enabled = true
	
	arena_events_enabled = false
	arena_event_interval = 20.0
	event_meteor_rain_enabled = true
	event_earthquake_enabled = true
	event_strong_wind_enabled = true
	event_fire_pillars_enabled = true
	moving_platforms_enabled = false
	trampolines_enabled = false
	danger_zones_enabled = false
	breaking_platforms_enabled = false
	auto_cannons_enabled = false
	
	ability_grappling_hook_enabled = false
	ability_teleport_enabled = false
	ability_freeze_enabled = false
	ability_body_push_enabled = false
	ability_air_dash_enabled = false
	ability_ground_pound_enabled = false
	
	particle_hit_effects_enabled = true
	sound_impact_enhanced = true
	kill_cam_enabled = false
	
	quick_chat_enabled = false
	post_match_stats_enabled = true


func get_enabled_powerups() -> Array[String]:
	var result: Array[String] = []
	if powerup_shield_enabled: result.append("shield")
	if powerup_superspeed_enabled: result.append("superspeed")
	if powerup_triple_jump_enabled: result.append("triple_jump")
	if powerup_homing_projectile_enabled: result.append("homing_projectile")
	if powerup_mine_enabled: result.append("mine")
	if powerup_magnet_enabled: result.append("magnet")
	if powerup_zero_gravity_enabled: result.append("zero_gravity")
	return result


func get_enabled_events() -> Array[String]:
	var result: Array[String] = []
	if event_meteor_rain_enabled: result.append("meteor_rain")
	if event_earthquake_enabled: result.append("earthquake")
	if event_strong_wind_enabled: result.append("strong_wind")
	if event_fire_pillars_enabled: result.append("fire_pillars")
	return result


func any_ability_enabled() -> bool:
	return ability_grappling_hook_enabled or ability_teleport_enabled or \
		   ability_freeze_enabled or ability_body_push_enabled or \
		   ability_air_dash_enabled or ability_ground_pound_enabled
