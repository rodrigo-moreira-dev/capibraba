extends "res://scripts/powerups/powerup_base.gd"

## PowerupShield - Protege de 1 explosão ou toque na lava

func _ready() -> void:
	powerup_name = "Escudo"
	duration = 0.0  # Dura até ser usado
	super._ready()
	_setup_mesh()


func _setup_mesh() -> void:
	if mesh and mesh.get_child_count() > 0:
		var child := mesh.get_child(0)
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 0.7, 1.0, 0.7)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.5, 1.0)
			mat.emission_energy = 0.8
			child.set_surface_override_material(0, mat)


func _apply_effect(player: CharacterBody3D) -> void:
	player.grant_shield()
