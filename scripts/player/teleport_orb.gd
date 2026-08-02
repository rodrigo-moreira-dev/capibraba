extends Area3D

## TeleportOrb - Orbe do Teleport Gun (modo Hellball)
## Ao acertar um jogador rival, pede ao servidor para validar e trocar as
## posições dos dois. Enquanto estiver ativo (voando ou plantado), o dono
## pode se teleportar até ele apertando o Teleport Gun novamente.

const SPEED          := 24.0
const LIFETIME       := 6.0   # tempo máximo de voo
const PLANT_LIFETIME := 4.0   # tempo "plantado" após bater em parede/piso

var direction    := Vector3.FORWARD
var owner_id     := 1
var owner_player: Node3D = null
var is_active    := false

var _elapsed := 0.0
var _planted := false

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	monitoring = false
	_setup_visual()
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	monitoring = true
	is_active  = true
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not is_active:
		return
	_elapsed += delta
	if _planted:
		if _elapsed >= PLANT_LIFETIME:
			_despawn()
		return
	if _elapsed >= LIFETIME:
		_despawn()
		return
	global_position += direction * SPEED * delta


func _setup_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color     = Color(0.30, 0.80, 1.0)
	mat.emission_enabled = true
	mat.emission         = Color(0.20, 0.60, 1.0)
	mat.emission_energy  = 2.5
	mesh.set_surface_override_material(0, mat)

	var trail := GPUParticles3D.new()
	trail.amount     = 24
	trail.lifetime   = 0.25
	trail.speed_scale = 1.5
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.15
	pm.scale_max = 0.35
	pm.color = Color(0.30, 0.80, 1.0, 0.70)
	trail.process_material = pm
	add_child(trail)


func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return
	if body.is_in_group("player"):
		var other_id: int = body.get_multiplayer_authority()
		if other_id == owner_id:
			return  # ignora o próprio dono
		# TROCA: o servidor valida e aplica a troca em todos os peers
		is_active = false
		var mgr := get_tree().get_first_node_in_group("hellball_manager")
		if mgr and mgr.has_method("request_swap"):
			if multiplayer.has_multiplayer_peer():
				mgr.request_swap.rpc_id(1, owner_id, other_id)
		_notify_owner_consumed()
		queue_free()
		return
	# Bateu em parede/piso → planta e aguarda o dono teleportar
	if not _planted:
		_planted = true
		_elapsed = 0.0
		_set_planted_visual()


## Chamado pelo dono: retorna a posição atual e consome o orbe.
func teleport_owner() -> Vector3:
	if not is_active:
		return Vector3.ZERO
	is_active = false
	var pos := global_position
	_notify_owner_consumed()
	queue_free()
	return pos


func _set_planted_visual() -> void:
	var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color    = Color(0.50, 0.90, 1.0)
		mat.emission_energy = 4.0


func _despawn() -> void:
	if not is_active:
		return
	is_active = false
	_notify_owner_consumed()
	queue_free()


func _notify_owner_consumed() -> void:
	if is_instance_valid(owner_player) and owner_player.has_method("on_orb_consumed"):
		owner_player.on_orb_consumed(self)
