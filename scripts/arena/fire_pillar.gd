extends Area3D

## FirePillar - Pilar de fogo que aparece e causa empurrão

const WARNING_TIME := 1.0
const ACTIVE_TIME := 2.5
const EXPLOSION_FORCE := 18.0
const RADIUS := 2.0

var _state := "warning"
var _timer := 0.0

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	monitoring = false
	_create_visual()
	body_entered.connect(_on_body_entered)


func _create_visual() -> void:
	mesh = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = RADIUS
	cylinder.bottom_radius = RADIUS
	cylinder.height = 8.0
	mesh.mesh = cylinder
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.0)
	mat.emission_energy = 1.5
	mesh.set_surface_override_material(0, mat)
	mesh.position.y = 4.0
	add_child(mesh)


func _process(delta: float) -> void:
	_timer += delta
	
	match _state:
		"warning":
			if _timer >= WARNING_TIME:
				_state = "active"
				_timer = 0.0
				monitoring = true
				_set_active_visual()
		"active":
			if _timer >= ACTIVE_TIME:
				_state = "fading"
				_timer = 0.0
		"fading":
			var alpha := 1.0 - (_timer / 0.5)
			if alpha <= 0:
				queue_free()
			else:
				_update_alpha(alpha)


func _set_active_visual() -> void:
	if mesh and mesh.get_surface_override_material(0):
		var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
		mat.albedo_color = Color(1.0, 0.5, 0.0, 0.8)
		mat.emission_energy = 3.0


func _update_alpha(alpha: float) -> void:
	if mesh and mesh.get_surface_override_material(0):
		var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
		mat.albedo_color.a = alpha * 0.8


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return
	
	var push := (body.global_position - global_position)
	push.y = 0.5
	push = push.normalized()
	body.velocity += push * EXPLOSION_FORCE
