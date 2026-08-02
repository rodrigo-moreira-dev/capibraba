extends Area2D

## ChargeOrb2D - Projétil 2D do Charge Gun (Hellball Plataforma/Topdown)
## Viaja na direção do alvo e explode, empurrando jogadores com força
## proporcional à carga.

signal exploded(position: Vector2, force: float)

const SPEED    := 320.0
const LIFETIME := 2.0

var direction := Vector2.RIGHT
var force     := 240.0
var _elapsed  := 0.0
var _active   := false

@onready var visual: Node2D = $Visual
@onready var collision: CollisionShape2D = $Collision


func _ready() -> void:
	monitoring = false
	_build_visual()
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	monitoring = true
	_active    = true
	body_entered.connect(func(_b: Node2D) -> void: _explode())
	area_entered.connect(func(_a: Area2D)  -> void: _explode())


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= LIFETIME:
		_explode()
		return
	global_position += direction * SPEED * delta


func _build_visual() -> void:
	visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)
	var poly := Polygon2D.new()
	poly.polygon = _circle_polygon(0.32)
	poly.color = Color(1.0, 0.55, 0.10)
	# brilho: segundo polígono maior translúcido
	var glow := Polygon2D.new()
	glow.polygon = _circle_polygon(0.5)
	glow.color = Color(1.0, 0.45, 0.0, 0.30)
	visual.add_child(glow)
	visual.add_child(poly)
	# escala conforme a carga
	var s := 1.0 + clampf((force - 140.0) / 500.0, 0.0, 0.8)
	visual.scale = Vector2.ONE * s


func _circle_polygon(radius: float, segments := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _explode() -> void:
	if not _active:
		return
	_active = false
	exploded.emit(global_position, force)
	queue_free()
