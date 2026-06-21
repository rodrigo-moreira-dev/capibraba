extends "res://scripts/player/projectile.gd"

## HomingProjectile - Projétil que persegue o jogador mais próximo

const HOMING_SPEED := 28.0
const TURN_RATE := 8.0
const DETECTION_RADIUS := 20.0

var _target: CharacterBody3D = null


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		_explode()
		return
	
	# Encontrar alvo
	if not _target or not is_instance_valid(_target):
		_find_target()
	
	# Perseguir alvo
	if _target:
		var to_target := (_target.global_position - global_position).normalized()
		direction = direction.lerp(to_target, TURN_RATE * delta).normalized()
	
	global_position += direction * HOMING_SPEED * delta


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	var closest: CharacterBody3D = null
	var closest_dist := DETECTION_RADIUS
	
	for p: CharacterBody3D in players:
		var dist := global_position.distance_to(p.global_position)
		if dist < closest_dist:
			closest = p
			closest_dist = dist
	
	_target = closest


func _ready() -> void:
	super._ready()
	
	# Mudar cor para indicar projétil guiado
	# (feito via mesh se necessário)
