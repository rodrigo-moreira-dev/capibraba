extends Node

const TILE_SIZE := 3.6
const TILE_GAP  := 0.4
const GRID_SIZE := 5
const TILE_H    := 2.0

@export var remove_interval: float = 15.0
@export var min_tiles:       int   = 5

var _tiles: Array = []
var _timer: float = 0.0


func _ready() -> void:
	_generate_tiles()


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_timer += delta
	if _timer >= remove_interval and _tiles.size() > min_tiles:
		_timer = 0.0
		var removable := _tiles.size() - min_tiles
		var idx       := randi() % removable
		_remove_tile.rpc(idx)


@rpc("authority", "call_local", "reliable")
func _remove_tile(idx: int) -> void:
	if idx >= _tiles.size():
		return
	var tile: StaticBody3D = _tiles[idx]
	_tiles.remove_at(idx)
	if is_instance_valid(tile):
		tile.queue_free()


func _generate_tiles() -> void:
	var mesh_res  := BoxMesh.new()
	mesh_res.size  = Vector3(TILE_SIZE, TILE_H, TILE_SIZE)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.25)
	mat.roughness    = 0.88

	var shape_res   := BoxShape3D.new()
	shape_res.size   = Vector3(TILE_SIZE, TILE_H, TILE_SIZE)

	var step: float = TILE_SIZE + TILE_GAP
	var off:  float = (GRID_SIZE - 1) * step * 0.5

	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var tile := StaticBody3D.new()
			tile.position = Vector3(col * step - off, 0.0, row * step - off)

			var mi := MeshInstance3D.new()
			mi.mesh = mesh_res
			mi.set_surface_override_material(0, mat)
			tile.add_child(mi)

			var cs := CollisionShape3D.new()
			cs.shape = shape_res
			tile.add_child(cs)

			add_child(tile)
			_tiles.append(tile)
