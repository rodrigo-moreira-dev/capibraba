extends "res://scripts/player/player.gd"

## PlayerExtended - Extende o player com sistema de habilidades e power-ups
## Este script substitui player.gd quando funcionalidades extras estão ativadas

const HOMING_PROJECTILE_SCENE := preload("res://scenes/player/homing_projectile.tscn")
const MINE_SCENE := preload("res://scenes/powerups/mine.tscn")

## Sistema de habilidades e power-ups
var abilities: Node


func _ready() -> void:
	# Inicializar sistema de habilidades antes de chamar super
	abilities = preload("res://scripts/player/player_abilities.gd").new()
	abilities.name = "Abilities"
	add_child(abilities)
	abilities.initialize(self)

	super._ready()

	# Conectar sinais de habilidades
	abilities.shield_changed.connect(_on_shield_changed)
	abilities.speed_boost_changed.connect(_on_speed_boost_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# MOVIMENTO OVERRIDE - Integra power-ups de movimento (velocidade/gravidade/pulo)
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_movement(delta: float) -> void:
	var dir := _input_dir_world()
	var accel := acceleration if is_on_floor() else air_acceleration
	var eff_speed: float = speed * (abilities.speed_multiplier if is_instance_valid(abilities) else 1.0)
	velocity.x = move_toward(velocity.x, dir.x * eff_speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * eff_speed, accel * delta)


func _apply_gravity(delta: float) -> void:
	# Gravidade zero: flutua (amortece o vertical em vez de cair)
	if is_instance_valid(abilities) and abilities.zero_gravity_active:
		velocity.y = move_toward(velocity.y, 0.0, 6.0 * delta)
		return
	super._apply_gravity(delta)


func _process_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return
	if is_on_floor() or _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_count = 1
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	elif is_on_wall_only():
		var n := get_wall_normal()
		velocity.x = n.x * wall_jump_push
		velocity.z = n.z * wall_jump_push
		velocity.y = wall_jump_velocity
		_jump_count = 1
		_jump_buffer_timer = 0.0
	elif _jump_count < MAX_JUMPS:
		velocity.y = double_jump_velocity
		_jump_count += 1
		_jump_buffer_timer = 0.0
	elif is_instance_valid(abilities) and abilities.consume_extra_jump():
		# Pulo extra temporário concedido por power-up
		velocity.y = double_jump_velocity
		_jump_count += 1
		_jump_buffer_timer = 0.0


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	
	if not is_multiplayer_authority():
		return
	
	_process_ability_input(event)


func _process_ability_input(event: InputEvent) -> void:
	# Gancho (tecla G ou botão de habilidade)
	if event.is_action_pressed("ability_grapple") and abilities.can_use_grappling_hook():
		_use_grappling_hook()
	
	# Teleporte (tecla T)
	if event.is_action_pressed("ability_teleport") and abilities.can_teleport():
		_use_teleport()
	
	# Congelar (tecla F)
	if event.is_action_pressed("ability_freeze") and abilities.can_freeze():
		_use_freeze()
	
	# Ground Pound (tecla V no ar)
	if event.is_action_pressed("ability_ground_pound") and abilities.can_ground_pound():
		abilities.use_ground_pound()
	
	# Colocar mina (tecla B)
	if event.is_action_pressed("ability_mine") and abilities.has_mine:
		_place_mine()


# ═══════════════════════════════════════════════════════════════════════════════
# HABILIDADES
# ═══════════════════════════════════════════════════════════════════════════════

func _use_grappling_hook() -> void:
	var anchor: Vector3 = abilities.use_grappling_hook()
	if anchor != Vector3.ZERO:
		var to_anchor := anchor - global_position
		velocity += to_anchor.normalized() * 25.0


func _use_teleport() -> void:
	var target: Vector3 = abilities.use_teleport()
	global_position = target
	velocity = Vector3.ZERO
	_play_teleport_effect.rpc()


func _use_freeze() -> void:
	var target: CharacterBody3D = abilities.use_freeze()
	if target and target.has_method("freeze_player"):
		target.freeze_player.rpc(MatchSettings.freeze_duration)


func _place_mine() -> void:
	if not abilities.consume_mine():
		return
	
	var mine := MINE_SCENE.instantiate()
	mine.owner_id = get_multiplayer_authority()
	mine.global_position = global_position - Vector3(0, 0.5, 0)
	get_tree().current_scene.add_child(mine, true)


@rpc("authority", "call_local", "reliable")
func _play_teleport_effect() -> void:
	var particles := _create_particles(20, 0.3, Color(0.5, 0.8, 1.0, 0.8))
	particles.global_position = global_position
	get_tree().current_scene.add_child(particles)
	particles.emitting = true


# ═══════════════════════════════════════════════════════════════════════════════
# SHOOTING OVERRIDE
# ═══════════════════════════════════════════════════════════════════════════════

func _shoot() -> void:
	_shoot_timer = SHOOT_COOLDOWN
	var dir: Vector3 = -aim_camera.global_basis.z
	
	var proj: Area3D
	if abilities.has_homing_projectile:
		proj = HOMING_PROJECTILE_SCENE.instantiate()
		abilities.consume_homing_projectile()
	else:
		proj = PROJECTILE_SCENE.instantiate()
	
	proj.direction = dir
	proj.exploded.connect(_on_explosion)
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0.0, 0.5, 0.0) + dir * 1.3


# ═══════════════════════════════════════════════════════════════════════════════
# LAVA OVERRIDE - Com escudo
# ═══════════════════════════════════════════════════════════════════════════════

func on_lava_contact() -> void:
	# Verificar escudo primeiro
	if abilities.consume_shield():
		velocity.x *= 0.15
		velocity.z *= 0.15
		velocity.y = LAVA_BOUNCE_FORCE
		_bounce_timer = BOUNCE_COOLDOWN
		_play_shield_block_effect()
		return
	
	super.on_lava_contact()


# ═══════════════════════════════════════════════════════════════════════════════
# EXPLOSÃO OVERRIDE - Com escudo
# Sobrescreve o RPC herdado de player.gd que aplica o empurrão da explosão.
# Em cada peer só o jogador da autoridade local (`p`) é afetado, então o escudo
# é consumido só no peer dono daquele jogador (sem duplicar entre clientes).
# ═══════════════════════════════════════════════════════════════════════════════

@rpc("any_peer", "call_local", "unreliable_ordered")
func _broadcast_explosion(pos: Vector3, attacker_id: int) -> void:
	for p: CharacterBody3D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		var dist: float = p.global_position.distance_to(pos)
		if dist > EXPLOSION_RADIUS:
			continue

		# Escudo: bloqueia 1 explosão
		if p.get("abilities") != null and p.abilities.consume_shield():
			var fx := _create_particles(30, 0.4, Color(0.3, 0.7, 1.0, 0.8))
			fx.global_position = p.global_position + Vector3(0, 1, 0)
			get_tree().current_scene.add_child(fx)
			fx.emitting = true
			continue

		var push: Vector3 = (p.global_position - pos).normalized()
		push.y = maxf(push.y, 0.35)
		p.velocity += push * EXPLOSION_FORCE * (1.0 - dist / EXPLOSION_RADIUS)
		p.last_attacker_id = attacker_id


func _play_shield_block_effect() -> void:
	var particles := _create_particles(30, 0.4, Color(0.3, 0.7, 1.0, 0.8))
	particles.global_position = global_position + Vector3(0, 1, 0)
	get_tree().current_scene.add_child(particles)
	particles.emitting = true


# ═══════════════════════════════════════════════════════════════════════════════
# RPC - Habilidades externas
# ═══════════════════════════════════════════════════════════════════════════════

@rpc("authority", "call_local", "reliable")
func freeze_player(duration: float) -> void:
	set_physics_process(false)
	await get_tree().create_timer(duration).timeout
	set_physics_process(true)


@rpc("authority", "call_local", "reliable")
func apply_external_impulse(impulse: Vector3) -> void:
	velocity += impulse


# ═══════════════════════════════════════════════════════════════════════════════
# POWER-UP API
# ═══════════════════════════════════════════════════════════════════════════════

func grant_shield() -> void:
	abilities.grant_shield()


func apply_speed_boost(multiplier: float, duration: float) -> void:
	abilities.apply_speed_boost(multiplier, duration)


func grant_extra_jump(duration: float) -> void:
	abilities.grant_extra_jump(duration)


func grant_homing_projectile() -> void:
	abilities.grant_homing_projectile()


func grant_mine() -> void:
	abilities.grant_mine()


func activate_magnet(duration: float, radius: float, force: float) -> void:
	abilities.activate_magnet(duration, radius, force)


func activate_zero_gravity(duration: float) -> void:
	abilities.activate_zero_gravity(duration)


func apply_wind(force: Vector3, duration: float) -> void:
	abilities.apply_wind(force, duration)


# ═══════════════════════════════════════════════════════════════════════════════
# CALLBACKS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_shield_changed(active: bool) -> void:
	# Atualizar visual do escudo
	pass


func _on_speed_boost_changed(multiplier: float) -> void:
	# Feedback visual de velocidade
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _create_particles(amount: int, lifetime: float, color: Color) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3.ZERO
	pm.color = color
	particles.process_material = pm
	
	return particles
