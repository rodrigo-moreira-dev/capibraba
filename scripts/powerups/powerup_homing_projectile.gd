extends "res://scripts/powerups/powerup_base.gd"

## PowerupHomingProjectile - Próximo projétil persegue alvos

func _ready() -> void:
	powerup_name = "Míssil Guiado"
	duration = 0.0  # Próximo disparo
	super._ready()
	_setup_mesh()


func _setup_mesh() -> void:
	if mesh and mesh.get_child_count() > 0:
		var child := mesh.get_child(0)
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.0, 0.3)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.0, 0.2)
			mat.emission_energy = 1.0
			child.set_surface_override_material(0, mat)


func _apply_effect(player: CharacterBody3D) -> void:
	player.grant_homing_projectile()
