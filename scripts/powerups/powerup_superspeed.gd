extends "res://scripts/powerups/powerup_base.gd"

## PowerupSuperspeed - Aumenta velocidade por 5 segundos

func _ready() -> void:
	powerup_name = "Super Velocidade"
	duration = 5.0
	super._ready()
	_setup_mesh()


func _setup_mesh() -> void:
	if mesh and mesh.get_child_count() > 0:
		var child := mesh.get_child(0)
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.5, 0.0)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.3, 0.0)
			mat.emission_energy = 0.8
			child.set_surface_override_material(0, mat)


func _apply_effect(player: CharacterBody3D) -> void:
	player.apply_speed_boost(2.0, duration)  # 2x velocidade
