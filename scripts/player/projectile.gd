extends Area3D

signal exploded(position: Vector3)

const SPEED    := 32.0
const LIFETIME := 3.0

var direction := Vector3.FORWARD
var _elapsed  := 0.0
var _active   := false


func _ready() -> void:
	monitoring = false
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	monitoring = true
	_active    = true
	body_entered.connect(func(_b: Node3D) -> void: _explode())
	area_entered.connect(func(_a: Area3D)  -> void: _explode())


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		_explode()
		return
	global_position += direction * SPEED * delta


func _explode() -> void:
	if not _active:
		return
	_active = false
	exploded.emit(global_position)
	queue_free()
