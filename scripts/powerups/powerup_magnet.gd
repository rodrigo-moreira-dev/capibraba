extends "res://scripts/powerups/powerup_base.gd"

## PowerupMagnet - Atrai todos os jogadores próximos

const MAGNET_RADIUS := 12.0
const MAGNET_FORCE := 15.0

func _ready() -> void:
	powerup_name = "Imã"
	duration = 3.0
	super._ready()
	_setup_mesh()


func _setup_mesh() -> void:
	if mesh and mesh.get_child_count() > 0:
		var child := mesh.get_child(0)
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.8, 0.2, 0.8)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.5, 1.0)
			mat.emission_energy = 0.7
			child.set_surface_override_material(0, mat)


func _apply_effect(player: CharacterBody3D) -> void:
	player.activate_magnet(duration, MAGNET_RADIUS, MAGNET_FORCE)
