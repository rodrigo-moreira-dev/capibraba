extends "res://scripts/powerups/powerup_base.gd"

## PowerupZeroGravity - Flutua por alguns segundos

func _ready() -> void:
	powerup_name = "Gravidade Zero"
	duration = 4.0
	super._ready()
	_setup_mesh()


func _setup_mesh() -> void:
	if mesh and mesh.get_child_count() > 0:
		var child := mesh.get_child(0)
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.7, 0.9, 1.0, 0.6)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(0.5, 0.8, 1.0)
			mat.emission_energy = 0.4
			child.set_surface_override_material(0, mat)


func _apply_effect(player: CharacterBody3D) -> void:
	player.activate_zero_gravity(duration)
