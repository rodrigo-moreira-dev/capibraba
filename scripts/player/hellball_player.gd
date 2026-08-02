extends "res://scripts/player/player.gd"

## HellballPlayer - Jogador do modo Hellball
## Cada jogador tem duas armas:
##  - Charge Gun (Clique Esquerdo): segure para carregar e solte para
##    disparar um projétil que empurra rivais com força proporcional à carga.
##  - Teleport Gun (Clique Direito): dispara um orbe. Aperte de novo para se
##    teletransportar até ele, ou acerte um rival para trocar de lugar.

const CHARGE_PROJECTILE_SCENE := preload("res://scenes/player/charge_projectile.tscn")
const TELEPORT_ORB_SCENE      := preload("res://scenes/player/teleport_orb.tscn")

## Charge Gun
const CHARGE_MAX_TIME := 1.2
const CHARGE_MIN_PUSH := 16.0
const CHARGE_MAX_PUSH := 44.0
const CHARGE_COOLDOWN := 0.55
const CHARGE_RADIUS   := 5.0

## Teleport Gun
const TELEPORT_COOLDOWN := 0.4

## Ações básicas (Game Feel)
const PUNCH_RANGE    := 1.7
const PUNCH_FORCE    := 24.0
const PUNCH_COOLDOWN := 0.4
const PUNCH_WINDUP   := 0.08
const GUARD_KNOCKBACK_REDUCTION := 0.20  # guarda reduz o empurrão a 20%
const GUARD_SPEED_MULT := 0.5

var _charge_power    := 0.0
var _is_charging     := false
var _charge_timer    := 0.0
var _charge_cd       := 0.0
var _teleport_cd     := 0.0
var _punch_cd        := 0.0
var _teleport_orb = null
var _charge_indicator: MeshInstance3D
var _guard_shield: MeshInstance3D
var guarding := false
var _hitstop_count := 0


func _ready() -> void:
	super._ready()
	add_to_group("hellball_player")
	_build_charge_indicator()
	_build_guard_shield()


func _physics_process(delta: float) -> void:
	_charge_cd   = maxf(_charge_cd   - delta, 0.0)
	_teleport_cd = maxf(_teleport_cd - delta, 0.0)
	_punch_cd    = maxf(_punch_cd    - delta, 0.0)
	_update_charge(delta)
	_update_guard(delta)
	super._physics_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	if event.is_action_pressed("teleport_gun"):
		_on_teleport_pressed()
	if event.is_action_pressed("punch"):
		_try_punch()


# ═══════════════════════════════════════════════════════════════════════════════
# AÇÕES BÁSICAS — PUNCH / GUARD
# ═══════════════════════════════════════════════════════════════════════════════

func _try_punch() -> void:
	if _punch_cd > 0.0 or guarding:
		return
	_punch_cd = PUNCH_COOLDOWN
	SfxBus.play("punch")
	_play_punch_windup()
	await get_tree().create_timer(PUNCH_WINDUP).timeout
	if not is_inside_tree():
		return
	var dir: Vector3 = -aim_camera.global_basis.z
	dir.y = 0.0
	dir = dir.normalized()
	_broadcast_punch.rpc(global_position, dir, get_multiplayer_authority(), PUNCH_FORCE)
	SfxBus.play("punch_hit")
	_play_punch_impact_fx(dir)


@rpc("any_peer", "call_local", "reliable")
func _broadcast_punch(pos: Vector3, dir: Vector3, attacker_id: int, force: float) -> void:
	# Segurança: o atacante deve ser o remetente (0 = chamada local via call_local)
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and attacker_id != sid:
		return
	for p: CharacterBody3D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		if p == self:
			continue
		var to := p.global_position - pos
		to.y = 0.0
		var dist := to.length()
		if dist > PUNCH_RANGE:
			continue
		if to.normalized().dot(dir.normalized()) < 0.3:
			continue  # fora do cone frontal
		var push := dir * force * (1.0 - dist / PUNCH_RANGE)
		if p.get("guarding"):
			push *= GUARD_KNOCKBACK_REDUCTION
			SfxBus.play("guard_block")
		p.velocity += push
		p.last_attacker_id = attacker_id
		if p.has_method("play_hurt_feedback"):
			p.play_hurt_feedback(push.normalized())


func _play_punch_windup() -> void:
	mesh_pivot.scale = Vector3(0.92, 1.06, 0.92)
	var tween := create_tween()
	tween.tween_property(mesh_pivot, "scale", Vector3.ONE, 0.08)


func _play_punch_impact_fx(dir: Vector3) -> void:
	_spawn_burst(global_position + dir * PUNCH_RANGE * 0.8 + Vector3(0, 0.9, 0),
		Color(1.0, 0.85, 0.4, 0.9), 14, 0.3, 5.0)
	_shake(0.25, 0.12)


func _update_guard(delta: float) -> void:
	if not is_multiplayer_authority():
		if is_instance_valid(_guard_shield):
			_guard_shield.visible = guarding
		return
	guarding = Input.is_action_pressed("guard")
	if is_instance_valid(_guard_shield):
		_guard_shield.visible = guarding


func _apply_movement(delta: float) -> void:
	var mult := GUARD_SPEED_MULT if guarding else 1.0
	var dir := _input_dir_world()
	var accel := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, dir.x * speed * mult, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed * mult, accel * delta)


func _build_guard_shield() -> void:
	_guard_shield = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.85
	sm.height = 1.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.66, 0.96, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.66, 0.96)
	mat.emission_energy = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_guard_shield.mesh = sm
	_guard_shield.set_surface_override_material(0, mat)
	_guard_shield.position = Vector3(0, 0.6, 0)
	_guard_shield.visible = false
	add_child(_guard_shield)


# ═══════════════════════════════════════════════════════════════════════════════
# CHARGE GUN
# ═══════════════════════════════════════════════════════════════════════════════

func _update_charge(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if Input.is_action_pressed("shoot"):
		if not _is_charging and _charge_cd <= 0.0:
			_is_charging  = true
			_charge_power = 0.0
			_charge_timer = 0.0
		elif _is_charging:
			_charge_timer += delta
			_charge_power  = clampf(_charge_timer / CHARGE_MAX_TIME, 0.0, 1.0)
	elif _is_charging:
		_fire_charge()

	if is_instance_valid(_charge_indicator):
		_charge_indicator.visible = _is_charging
		if _is_charging:
			var s := 0.8 + _charge_power * 1.6
			_charge_indicator.scale = Vector3.ONE * s


func _fire_charge() -> void:
	_is_charging = false
	_charge_cd   = CHARGE_COOLDOWN

	var dir: Vector3 = -aim_camera.global_basis.z
	var proj := CHARGE_PROJECTILE_SCENE.instantiate()
	proj.direction = dir
	proj.force     = lerpf(CHARGE_MIN_PUSH, CHARGE_MAX_PUSH, _charge_power)
	proj.exploded.connect(_on_charge_explosion)
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(0.0, 0.5, 0.0) + dir * 1.2


func _on_charge_explosion(pos: Vector3, force: float) -> void:
	_broadcast_charge.rpc(pos, get_multiplayer_authority(), force)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _broadcast_charge(pos: Vector3, attacker_id: int, force: float) -> void:
	# Segurança: o atacante deve ser o remetente (0 = chamada local via call_local)
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and attacker_id != sid:
		return
	var local_hit := false
	for p: CharacterBody3D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		var dist := p.global_position.distance_to(pos)
		if dist > CHARGE_RADIUS:
			continue
		var push := (p.global_position - pos).normalized()
		push.y = maxf(push.y, 0.30)
		var falloff := 1.0 - dist / CHARGE_RADIUS
		var push_force := force * falloff
		if p.get("guarding"):
			push_force *= GUARD_KNOCKBACK_REDUCTION
			SfxBus.play("guard_block")
		p.velocity += push * push_force
		p.last_attacker_id = attacker_id
		if p == self:
			local_hit = true
		if p.has_method("play_hurt_feedback"):
			p.play_hurt_feedback(push)
	if local_hit:
		SfxBus.play("explosion")
		_hit_stop(0.05)
		_spawn_explosion_fx(pos)


func _spawn_explosion_fx(pos: Vector3) -> void:
	_spawn_burst(pos, Color(1.0, 0.55, 0.1, 0.9), 28, 0.45, 8.0)
	_spawn_burst(pos + Vector3(0, 0.6, 0), Color(0.35, 0.25, 0.2, 0.6), 16, 0.9, 3.0)


# ═══════════════════════════════════════════════════════════════════════════════
# TELEPORT GUN
# ═══════════════════════════════════════════════════════════════════════════════

func _on_teleport_pressed() -> void:
	if _teleport_cd > 0.0:
		return

	# Orbe ativo → teleporta até ele
	if is_instance_valid(_teleport_orb) and _teleport_orb.is_active:
		var pos: Vector3 = _teleport_orb.teleport_owner()
		if pos != Vector3.ZERO:
			global_position = pos
			velocity        = Vector3.ZERO
			_teleport_cd    = TELEPORT_COOLDOWN
			SfxBus.play("teleport")
			_play_teleport_effect.rpc()
			_spawn_burst(pos + Vector3(0, 1, 0), Color(0.3, 0.8, 1.0, 0.9), 22, 0.4, 5.0)
		return

	# Dispara um novo orbe
	var dir: Vector3 = -aim_camera.global_basis.z
	var orb := TELEPORT_ORB_SCENE.instantiate()
	orb.direction    = dir
	orb.owner_id     = get_multiplayer_authority()
	orb.owner_player = self
	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position + Vector3(0.0, 0.5, 0.0) + dir * 1.2
	_teleport_orb = orb


func on_orb_consumed(_orb: Node3D) -> void:
	_teleport_orb = null


@rpc("authority", "call_local", "reliable")
func _play_teleport_effect() -> void:
	var particles := _create_particles(25, 0.35, Color(0.30, 0.80, 1.0, 0.9))
	particles.global_position = global_position + Vector3(0, 1, 0)
	get_tree().current_scene.add_child(particles)
	particles.emitting = true


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FEEL — SQUASH & STRETCH / DANO / HIT-STOP / SHAKE
# ═══════════════════════════════════════════════════════════════════════════════

func _process_jump() -> void:
	var prev_vy := velocity.y
	super._process_jump()
	if velocity.y > prev_vy + 1.0:
		_play_jump_feedback()


func _process_dash(delta: float) -> void:
	var prev_dashing := _is_dashing
	super._process_dash(delta)
	if _is_dashing and not prev_dashing:
		_play_dash_feedback()


func _post_move() -> void:
	var was_grounded := is_on_floor()
	super._post_move()
	if not was_grounded and is_on_floor():
		_play_land_feedback()


func _play_jump_feedback() -> void:
	mesh_pivot.scale = Vector3(0.9, 1.14, 0.9)
	var tween := create_tween()
	tween.tween_property(mesh_pivot, "scale", Vector3.ONE, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_land_feedback() -> void:
	mesh_pivot.scale = Vector3(1.14, 0.82, 1.14)
	var tween := create_tween()
	tween.tween_property(mesh_pivot, "scale", Vector3.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_burst(global_position + Vector3(0, 0.15, 0), Color(0.5, 0.42, 0.32, 0.5), 7, 0.4, 2.5)


func _play_dash_feedback() -> void:
	mesh_pivot.scale = Vector3(1.25, 0.86, 1.25)
	var tween := create_tween()
	tween.tween_property(mesh_pivot, "scale", Vector3.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Chamado por RPC quando este jogador é empurrado/atingido.
func play_hurt_feedback(dir: Vector3) -> void:
	mesh_pivot.scale = Vector3(1.16, 0.84, 1.16)
	var tween := create_tween()
	tween.tween_property(mesh_pivot, "scale", Vector3.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash_hurt()
	_shake(0.35, 0.18)
	_spawn_burst(global_position + Vector3(0, 0.9, 0), Color(1, 1, 1, 0.9), 12, 0.3, 4.0)
	SfxBus.play("hurt")


## Animação de troca (Teleport Gun): encolhe e "estica" de volta.
func play_swap_flash() -> void:
	var tween := create_tween()
	tween.tween_property(mesh_pivot, "scale", Vector3(0.4, 0.4, 0.4), 0.08)
	tween.tween_property(mesh_pivot, "scale", Vector3.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func flash_hurt() -> void:
	var mat := body_mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 4.0
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(mat):
		mat.emission_enabled = false
		mat.emission_energy_multiplier = 0.0


func _hit_stop(duration := 0.05) -> void:
	# Contador evita race condition: hit-stops sobrepostos estendem em vez de
	# restaurar cedo demais. É por-cliente (cada peer tem seu Engine.time_scale).
	_hitstop_count += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstop_count -= 1
	if _hitstop_count <= 0:
		Engine.time_scale = 1.0


func _shake(strength: float, duration: float) -> void:
	if is_instance_valid(camera_rig) and camera_rig.has_method("shake"):
		camera_rig.shake(strength, duration)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _build_charge_indicator() -> void:
	_charge_indicator = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	var mat := StandardMaterial3D.new()
	mat.albedo_color     = Color(1.0, 0.60, 0.10)
	mat.emission_enabled = true
	mat.emission         = Color(1.0, 0.50, 0.0)
	mat.emission_energy  = 2.0
	mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	_charge_indicator.mesh = sm
	_charge_indicator.set_surface_override_material(0, mat)
	_charge_indicator.position = Vector3(0, -0.15, -0.9)
	_charge_indicator.visible  = false
	aim_camera.add_child(_charge_indicator)


func _create_particles(amount: int, lifetime: float, color: Color) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount       = amount
	particles.lifetime     = lifetime
	particles.one_shot     = true
	particles.explosiveness = 1.0

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -4, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.7
	pm.color = color
	particles.process_material = pm

	return particles


func _spawn_burst(pos: Vector3, color: Color, amount: int, life: float, vel: float) -> void:
	var particles := _create_particles(amount, life, color)
	particles.global_position = pos
	if particles.process_material is ParticleProcessMaterial:
		var pm := particles.process_material as ParticleProcessMaterial
		pm.initial_velocity_min = vel * 0.5
		pm.initial_velocity_max = vel
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
