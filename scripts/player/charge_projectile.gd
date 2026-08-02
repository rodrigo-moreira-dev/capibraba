extends Area3D

## ChargeProjectile - Projétil do Charge Gun (modo Hellball)
## Viaja na direção do alvo e explode, empurrando jogadores com força
## proporcional à carga acumulada. A atribuição do abate é feita pelo
## jogador que disparou (via last_attacker_id).

signal exploded(position: Vector3, force: float)

const SPEED    := 30.0
const LIFETIME := 2.5

var direction := Vector3.FORWARD
var force     := 20.0
var _elapsed  := 0.0
var _active   := false

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	monitoring = false
	_setup_visual()
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	monitoring = true
	_active    = true
	body_entered.connect(func(_b: Node3D) -> void: _explode())
	area_entered.connect(func(_a: Area3D)  -> void: _explode())


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= LIFETIME:
		_explode()
		return
	global_position += direction * SPEED * delta


func _setup_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color        = Color(1.0, 0.55, 0.10)
	mat.emission_enabled    = true
	mat.emission            = Color(1.0, 0.45, 0.0)
	mat.emission_energy     = 2.0
	mesh.set_surface_override_material(0, mat)
	# Projétil maior conforme a carga
	var s := 1.0 + clampf((force - 12.0) / 40.0, 0.0, 0.8)
	mesh.scale = Vector3.ONE * s


func _explode() -> void:
	if not _active:
		return
	_active = false
	exploded.emit(global_position, force)
	queue_free()
