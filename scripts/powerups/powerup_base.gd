extends Area3D

## PowerupBase - Classe base para todos os power-ups
## Detecta colisão com jogadores e aplica efeito

signal collected(player: CharacterBody3D)

@export var powerup_name: String = "Power-up"
@export var duration: float = 5.0  # Duração do efeito (0 = instantâneo)
@export var rotate_speed: float = 2.0
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.3

var _base_y: float = 0.0
var _time: float = 0.0
var _collected: bool = false

@onready var mesh: Node3D = $Mesh if has_node("Mesh") else null


func _ready() -> void:
	add_to_group("powerup")
	_base_y = global_position.y
	body_entered.connect(_on_body_entered)

	# Criar mesh padrão se não existir
	if not mesh:
		_create_default_mesh()


func _process(delta: float) -> void:
	if _collected:
		return
	
	_time += delta
	
	# Rotação
	if mesh:
		mesh.rotation.y += rotate_speed * delta
	
	# Flutuar
	global_position.y = _base_y + sin(_time * bob_speed) * bob_height


func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return

	_collected = true
	_apply_effect(body)
	_play_collect_effect()

	# Pedir ao servidor para remover este power-up em TODOS os peers.
	# O efeito já foi aplicado localmente só ao jogador coletor (autoridade local).
	var net_id: int = int(get_meta("net_id", -1))
	var manager := get_tree().get_first_node_in_group("powerup_manager")
	if manager and net_id != -1 and manager.has_method("request_despawn"):
		manager.request_despawn.rpc_id(1, net_id)

	queue_free()


func _apply_effect(_player: CharacterBody3D) -> void:
	# Override nas subclasses
	pass


func _play_collect_effect() -> void:
	# Som e partículas de coleta
	pass


func _create_default_mesh() -> void:
	mesh = Node3D.new()
	add_child(mesh)
	
	var sphere := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.4
	sphere_mesh.height = 0.8
	sphere.mesh = sphere_mesh
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.YELLOW
	mat.emission_enabled = true
	mat.emission = Color.YELLOW
	mat.emission_energy = 0.5
	sphere.set_surface_override_material(0, mat)
	
	mesh.add_child(sphere)
