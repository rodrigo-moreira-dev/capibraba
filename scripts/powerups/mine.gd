extends Area3D

## Mine - Mina que explode ao contato com jogadores

const EXPLOSION_RADIUS := 4.0
const EXPLOSION_FORCE := 22.0
const ARM_TIME := 1.0

var owner_id: int = -1
var _armed := false
var _armed_timer := 0.0


func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)
	
	# Criar visual
	var mesh_inst := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.3
	cylinder.height = 0.2
	mesh_inst.mesh = cylinder
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 1.0)
	mat.emission_energy = 0.5
	mesh_inst.set_surface_override_material(0, mat)
	add_child(mesh_inst)


func _process(delta: float) -> void:
	if _armed:
		return
	
	_armed_timer += delta
	if _armed_timer >= ARM_TIME:
		_armed = true
		monitoring = true
		# Mudar cor para indicar armada
		_update_visual_armed()


func _update_visual_armed() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.0, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.2, 0.3)
			mat.emission_energy = 1.5
			child.set_surface_override_material(0, mat)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.get_multiplayer_authority() == owner_id and _armed_timer < 3.0:
		return  # Não explodir no dono nos primeiros 3 segundos
	
	_explode()


func _explode() -> void:
	# Efeito visual
	var particles := GPUParticles3D.new()
	particles.amount = 25
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.global_position = global_position
	
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 12.0
	pm.gravity = Vector3(0, -5, 0)
	pm.scale_min = 0.3
	pm.scale_max = 0.6
	pm.color = Color(1.0, 0.3, 0.8)
	particles.process_material = pm
	
	get_tree().current_scene.add_child(particles)
	particles.emitting = true
	
	# Empurrar jogadores
	for p: CharacterBody3D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		var dist := p.global_position.distance_to(global_position)
		if dist > EXPLOSION_RADIUS:
			continue
		var push := (p.global_position - global_position).normalized()
		push.y = maxf(push.y, 0.4)
		var force := EXPLOSION_FORCE * (1.0 - dist / EXPLOSION_RADIUS)
		p.velocity += push * force
		
		# Registrar attacker para kill
		if p != get_tree().current_scene.get_node_or_null("Players/%d" % owner_id):
			p.last_attacker_id = owner_id
	
	queue_free()
