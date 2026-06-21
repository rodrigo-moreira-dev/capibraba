extends RigidBody3D

## Meteor - Meteoro que cai e explode ao impacto

const EXPLOSION_RADIUS := 5.0
const EXPLOSION_FORCE := 22.0

var _active := true


func _ready() -> void:
	# Configurar física
	gravity_scale = 1.5
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_impact)
	
	# Criar mesh
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	mesh_inst.mesh = sphere
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.3, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy = 2.0
	mesh_inst.set_surface_override_material(0, mat)
	add_child(mesh_inst)
	
	# Trail
	var trail := GPUParticles3D.new()
	trail.amount = 20
	trail.lifetime = 0.3
	trail.speed_scale = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0, 1, 0)
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.2
	pm.scale_max = 0.5
	pm.color = Color(1.0, 0.5, 0.1, 0.6)
	trail.process_material = pm
	add_child(trail)


func _on_impact(_body: Node) -> void:
	if not _active:
		return
	_active = false
	_explode()


func _explode() -> void:
	var pos := global_position
	
	# Efeito visual
	var particles := GPUParticles3D.new()
	particles.amount = 30
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.global_position = pos
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -5, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.6
	pm.color = Color(1.0, 0.4, 0.1)
	particles.process_material = pm
	
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	
	# Empurrar jogadores
	for p: CharacterBody3D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		var dist := p.global_position.distance_to(pos)
		if dist > EXPLOSION_RADIUS:
			continue
		var push := (p.global_position - pos).normalized()
		push.y = maxf(push.y, 0.3)
		var force := EXPLOSION_FORCE * (1.0 - dist / EXPLOSION_RADIUS)
		p.velocity += push * force
	
	# Auto-destruir após efeito
	await get_tree().create_timer(0.6).timeout
	queue_free()
