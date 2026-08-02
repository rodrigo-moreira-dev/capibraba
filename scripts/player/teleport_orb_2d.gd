extends Area2D

## TeleportOrb2D - Orbe 2D do Teleport Gun (Hellball Plataforma/Topdown)
## Ao acertar um jogador rival, pede ao servidor para validar e trocar as
## posições dos dois. Enquanto ativo, o dono pode se teleportar até ele.

const SPEED          := 260.0
const LIFETIME       := 6.0
const PLANT_LIFETIME := 4.0

var direction    := Vector2.RIGHT
var owner_id     := 1
var owner_player: Node2D = null
var is_active    := false

var _elapsed := 0.0
var _planted := false

@onready var visual: Node2D = $Visual
@onready var collision: CollisionShape2D = $Collision


func _ready() -> void:
	monitoring = false
	_build_visual()
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	monitoring = true
	is_active  = true
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if not is_active:
		return
	_elapsed += delta
	if _planted:
		if _elapsed >= PLANT_LIFETIME:
			_despawn()
		return
	if _elapsed >= LIFETIME:
		_despawn()
		return
	global_position += direction * SPEED * delta


func _build_visual() -> void:
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	var glow := Polygon2D.new()
	glow.polygon = _circle_polygon(0.5)
	glow.color = Color(0.3, 0.8, 1.0, 0.28)
	visual.add_child(glow)
	var core := Polygon2D.new()
	core.polygon = _circle_polygon(0.26)
	core.color = Color(0.30, 0.80, 1.0)
	visual.add_child(core)


func _circle_polygon(radius: float, segments := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("player"):
		var other_id: int = body.get_multiplayer_authority()
		if other_id == owner_id:
			return  # ignora o próprio dono
		is_active = false
		var mgr := get_tree().get_first_node_in_group("hellball_manager_2d")
		if mgr and mgr.has_method("request_swap"):
			if multiplayer.has_multiplayer_peer():
				mgr.request_swap.rpc_id(1, owner_id, other_id)
		_notify_owner_consumed()
		queue_free()
		return
	# Bateu em parede/piso → planta
	if not _planted:
		_planted = true
		_elapsed = 0.0
		_set_planted_visual()


func teleport_owner() -> Vector2:
	if not is_active:
		return Vector2.ZERO
	is_active = false
	var pos := global_position
	_notify_owner_consumed()
	queue_free()
	return pos


func _set_planted_visual() -> void:
	if is_instance_valid(visual):
		visual.scale = Vector2.ONE * 1.3


func _despawn() -> void:
	if not is_active:
		return
	is_active = false
	_notify_owner_consumed()
	queue_free()


func _notify_owner_consumed() -> void:
	if is_instance_valid(owner_player) and owner_player.has_method("on_orb_consumed"):
		owner_player.on_orb_consumed(self)
