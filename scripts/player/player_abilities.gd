## PlayerAbilities - Sistema de habilidades e power-ups para o jogador
## Este script extende as capacidades do player.gd

extends Node

# ═══════════════════════════════════════════════════════════════════════════════
# SINAIS
# ═══════════════════════════════════════════════════════════════════════════════

signal shield_changed(active: bool)
signal speed_boost_changed(multiplier: float)
signal extra_jumps_changed(count: int)
signal ability_cooldown_changed(ability: String, remaining: float)

# ═══════════════════════════════════════════════════════════════════════════════
# POWER-UPS - Estado
# ═══════════════════════════════════════════════════════════════════════════════

## Escudo - protege de 1 explosão ou lava
var has_shield: bool = false

## Boost de velocidade
var speed_multiplier: float = 1.0
var speed_boost_timer: float = 0.0

## Pulos extras
var extra_jumps: int = 0
var extra_jump_timer: float = 0.0

## Projétil guiado
var has_homing_projectile: bool = false

## Mina disponível
var has_mine: bool = false

## Imã ativo
var magnet_active: bool = false
var magnet_timer: float = 0.0
var magnet_radius: float = 12.0
var magnet_force: float = 15.0

## Gravidade zero
var zero_gravity_active: bool = false
var zero_gravity_timer: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# HABILIDADES - Cooldowns
# ═══════════════════════════════════════════════════════════════════════════════

var grappling_hook_cooldown: float = 0.0
var teleport_cooldown: float = 0.0
var freeze_cooldown: float = 0.0
var ground_pound_cooldown: float = 0.0
var air_dash_cooldown: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# VENTO
# ═══════════════════════════════════════════════════════════════════════════════

var wind_force: Vector3 = Vector3.ZERO
var wind_timer: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# REFERÊNCIA AO PLAYER
# ═══════════════════════════════════════════════════════════════════════════════

var _player: CharacterBody3D


func initialize(player: CharacterBody3D) -> void:
	_player = player


func _process(delta: float) -> void:
	_tick_powerups(delta)
	_tick_abilities(delta)
	_apply_magnet(delta)
	_apply_wind(delta)


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESSAMENTO
# ═══════════════════════════════════════════════════════════════════════════════

func _tick_powerups(delta: float) -> void:
	# Speed boost
	if speed_boost_timer > 0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0:
			speed_multiplier = 1.0
			speed_boost_changed.emit(1.0)
	
	# Extra jumps
	if extra_jump_timer > 0:
		extra_jump_timer -= delta
		if extra_jump_timer <= 0:
			extra_jumps = 0
			extra_jumps_changed.emit(0)
	
	# Magnet
	if magnet_timer > 0:
		magnet_timer -= delta
		if magnet_timer <= 0:
			magnet_active = false
	
	# Zero gravity
	if zero_gravity_timer > 0:
		zero_gravity_timer -= delta
		if zero_gravity_timer <= 0:
			zero_gravity_active = false


func _tick_abilities(delta: float) -> void:
	grappling_hook_cooldown = maxf(grappling_hook_cooldown - delta, 0.0)
	teleport_cooldown = maxf(teleport_cooldown - delta, 0.0)
	freeze_cooldown = maxf(freeze_cooldown - delta, 0.0)
	ground_pound_cooldown = maxf(ground_pound_cooldown - delta, 0.0)
	air_dash_cooldown = maxf(air_dash_cooldown - delta, 0.0)


func _apply_magnet(delta: float) -> void:
	# Roda em todos os peers; só age sobre o jogador da autoridade local,
	# puxando-o em direção a qualquer portador de ímã. (magnet_active é
	# replicado via MultiplayerSynchronizer — ver player.tscn.)
	if not _player.is_multiplayer_authority():
		return

	for other: CharacterBody3D in _player.get_tree().get_nodes_in_group("player"):
		if other == _player:
			continue
		var ab = other.get("abilities")
		if ab == null or not ab.magnet_active:
			continue

		var dist := _player.global_position.distance_to(other.global_position)
		if dist > ab.magnet_radius or dist < 0.6:
			continue

		var pull := (other.global_position - _player.global_position).normalized()
		_player.velocity += pull * ab.magnet_force * (1.0 - dist / ab.magnet_radius) * delta


func _apply_wind(delta: float) -> void:
	if wind_timer <= 0:
		return
	
	wind_timer -= delta
	_player.velocity += wind_force * delta
	
	if wind_timer <= 0:
		wind_force = Vector3.ZERO


# ═══════════════════════════════════════════════════════════════════════════════
# POWER-UPS - API
# ═══════════════════════════════════════════════════════════════════════════════

func grant_shield() -> void:
	has_shield = true
	shield_changed.emit(true)


func consume_shield() -> bool:
	if has_shield:
		has_shield = false
		shield_changed.emit(false)
		return true
	return false


func apply_speed_boost(multiplier: float, duration: float) -> void:
	speed_multiplier = multiplier
	speed_boost_timer = duration
	speed_boost_changed.emit(multiplier)


func grant_extra_jump(duration: float) -> void:
	extra_jumps += 1
	extra_jump_timer = maxf(extra_jump_timer, duration)
	extra_jumps_changed.emit(extra_jumps)


func consume_extra_jump() -> bool:
	if extra_jumps > 0:
		extra_jumps -= 1
		if extra_jumps == 0:
			extra_jump_timer = 0
		extra_jumps_changed.emit(extra_jumps)
		return true
	return false


func grant_homing_projectile() -> void:
	has_homing_projectile = true


func consume_homing_projectile() -> bool:
	if has_homing_projectile:
		has_homing_projectile = false
		return true
	return false


func grant_mine() -> void:
	has_mine = true


func consume_mine() -> bool:
	if has_mine:
		has_mine = false
		return true
	return false


func activate_magnet(duration: float, radius: float, force: float) -> void:
	magnet_active = true
	magnet_timer = duration
	magnet_radius = radius
	magnet_force = force


func activate_zero_gravity(duration: float) -> void:
	zero_gravity_active = true
	zero_gravity_timer = duration


# ═══════════════════════════════════════════════════════════════════════════════
# HABILIDADES - API
# ═══════════════════════════════════════════════════════════════════════════════

func can_use_grappling_hook() -> bool:
	return MatchSettings.ability_grappling_hook_enabled and grappling_hook_cooldown <= 0


func use_grappling_hook() -> Vector3:
	if not can_use_grappling_hook():
		return Vector3.ZERO
	
	grappling_hook_cooldown = MatchSettings.grappling_hook_cooldown
	ability_cooldown_changed.emit("grappling_hook", grappling_hook_cooldown)
	
	# Retornar ponto de ancoragem
	var origin := _player.global_position + Vector3(0, 1, 0)
	var direction: Vector3 = -_player.camera_rig.global_basis.z
	
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * MatchSettings.grappling_hook_range
	)
	query.exclude = [_player.get_rid()]
	
	var result := space.intersect_ray(query)
	if result:
		return result.position
	
	return Vector3.ZERO


func can_teleport() -> bool:
	return MatchSettings.ability_teleport_enabled and teleport_cooldown <= 0


func use_teleport() -> Vector3:
	if not can_teleport():
		return _player.global_position
	
	teleport_cooldown = MatchSettings.teleport_cooldown
	ability_cooldown_changed.emit("teleport", teleport_cooldown)
	
	var direction := _input_dir_world()
	if direction == Vector3.ZERO:
		direction = -_player.mesh_pivot.global_basis.z
	
	direction.y = 0
	direction = direction.normalized()
	
	var target := _player.global_position + direction * MatchSettings.teleport_distance
	target.y = _player.global_position.y
	
	# Verificar se posição é válida
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		target + Vector3(0, 2, 0),
		target + Vector3(0, -2, 0)
	)
	
	var result := space.intersect_ray(query)
	if result:
		target.y = result.position.y + 1.0
	
	return target


func can_freeze() -> bool:
	return MatchSettings.ability_freeze_enabled and freeze_cooldown <= 0


func use_freeze() -> CharacterBody3D:
	if not can_freeze():
		return null
	
	freeze_cooldown = MatchSettings.freeze_cooldown
	ability_cooldown_changed.emit("freeze", freeze_cooldown)
	
	# Encontrar jogador mais próximo na frente
	var closest: CharacterBody3D = null
	var closest_dist := 10.0
	
	for p: CharacterBody3D in _player.get_tree().get_nodes_in_group("player"):
		if p == _player:
			continue
		
		var to_player := p.global_position - _player.global_position
		var dist := to_player.length()
		
		if dist < closest_dist:
			# Verificar se está na frente
			var forward: Vector3 = -_player.mesh_pivot.global_basis.z
			if to_player.normalized().dot(forward) > 0.5:
				closest = p
				closest_dist = dist
	
	return closest


func can_ground_pound() -> bool:
	return MatchSettings.ability_ground_pound_enabled and ground_pound_cooldown <= 0 and not _player.is_on_floor()


func use_ground_pound() -> bool:
	if not can_ground_pound():
		return false
	
	ground_pound_cooldown = MatchSettings.ground_pound_cooldown
	ability_cooldown_changed.emit("ground_pound", ground_pound_cooldown)
	
	# Aplicar impulso para baixo
	_player.velocity.y = -20.0
	
	return true


func can_air_dash() -> bool:
	return MatchSettings.ability_air_dash_enabled and air_dash_cooldown <= 0 and not _player.is_on_floor()


func use_air_dash() -> bool:
	if not can_air_dash():
		return false
	
	air_dash_cooldown = _player.dash_cooldown
	ability_cooldown_changed.emit("air_dash", air_dash_cooldown)
	
	var direction := _input_dir_world()
	if direction == Vector3.ZERO:
		direction = -_player.mesh_pivot.global_basis.z
	
	_player.velocity = direction * _player.dash_speed
	_player.velocity.y = 2.0
	
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# VENTO
# ═══════════════════════════════════════════════════════════════════════════════

func apply_wind(force: Vector3, duration: float) -> void:
	wind_force = force
	wind_timer = duration


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _input_dir_world() -> Vector3:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if raw.length_squared() < 0.01:
		return Vector3.ZERO
	var cam_basis: Basis = _player.camera_rig.global_transform.basis
	var forward   := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
	var right     := Vector3( cam_basis.x.x, 0.0,  cam_basis.x.z).normalized()
	return (forward * -raw.y + right * raw.x).normalized() * raw.length()


# ═══════════════════════════════════════════════════════════════════════════════
# SINCRONIZAÇÃO MULTIPLAYER
# ═══════════════════════════════════════════════════════════════════════════════

func get_state() -> Dictionary:
	return {
		"has_shield": has_shield,
		"speed_multiplier": speed_multiplier,
		"extra_jumps": extra_jumps,
		"has_homing": has_homing_projectile,
		"has_mine": has_mine,
	}


func set_state(state: Dictionary) -> void:
	has_shield = state.get("has_shield", false)
	speed_multiplier = state.get("speed_multiplier", 1.0)
	extra_jumps = state.get("extra_jumps", 0)
	has_homing_projectile = state.get("has_homing", false)
	has_mine = state.get("has_mine", false)
