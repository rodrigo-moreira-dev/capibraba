extends "res://scripts/powerups/powerup_base.gd"

## PowerupTripleJump - Adiciona 1 pulo extra temporário

func _ready() -> void:
	powerup_name = "Pulo Extra"
	duration = 15.0
	super._ready()
	_setup_mesh()


func _setup_mesh() -> void:
	if mesh and mesh.get_child_count() > 0:
		var child := mesh.get_child(0)
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 1.0, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.8, 0.2)
			mat.emission_energy = 0.6
			child.set_surface_override_material(0, mat)


func _apply_effect(player: CharacterBody3D) -> void:
	player.grant_extra_jump(duration)
