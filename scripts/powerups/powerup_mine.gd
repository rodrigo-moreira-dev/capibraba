extends "res://scripts/powerups/powerup_base.gd"

## PowerupMine - Coloca uma mina que explode ao contato

const MINE_SCENE := preload("res://scenes/powerups/mine.tscn")

func _ready() -> void:
	powerup_name = "Mina"
	duration = 0.0
	super._ready()
	_setup_mesh()


func _setup_mesh() -> void:
	if mesh and mesh.get_child_count() > 0:
		var child := mesh.get_child(0)
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.1, 0.5)
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.2, 0.8)
			mat.emission_energy = 0.5
			child.set_surface_override_material(0, mat)


func _apply_effect(player: CharacterBody3D) -> void:
	player.grant_mine()
