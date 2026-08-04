extends Area2D

## ElectroProjectile2D - Projétil eletromagnético do minigame Ímãs (2D topdown)
## Carrega o polo de quem disparou. Ao acertar um rival: puxa/empurra conforme
## os polos. Se o alvo estiver com escudo magnético (guarding), o projétil é
## REFLETIDO de volta ao atirador com o polo invertido (fica útil contra ele).
## O projétil é LOCAL a quem disparou; o efeito é transmitido por RPC (padrão).

const SPEED    := 340.0
const LIFETIME := 1.6

var direction    := Vector2.RIGHT
var pole         := 1
var owner_id     := 1
var owner_player: Node2D = null
var _elapsed     := 0.0
var _active      := false

var _visual: Node2D
var _core: Polygon2D
var _glow: Polygon2D


func _ready() -> void:
	monitoring = false
	_build_visual()
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	monitoring = true
	_active    = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(func(_a: Area2D) -> void: _despawn())


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= LIFETIME:
		_despawn()
		return
	global_position += direction * SPEED * delta


func _build_visual() -> void:
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_glow = Polygon2D.new()
	_glow.polygon = _circle_polygon(0.5)
	_glow.color = Color(0.4, 0.8, 1.0, 0.30)
	_visual.add_child(_glow)
	_core = Polygon2D.new()
	_core.polygon = _circle_polygon(0.28)
	_core.color = _pole_color()
	_visual.add_child(_core)


func _pole_color() -> Color:
	return Color(0.35, 0.65, 1.0) if pole == 1 else Color(1.0, 0.30, 0.25)


func _circle_polygon(radius: float, segments := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if body.is_in_group("player"):
		var pid: int = body.get_multiplayer_authority()
		if pid == owner_id:
			return  # ignora o dono (ou o novo dono após refletir)
		_on_hit(body)
		return
	# Bateu em parede/piso → desliga
	_despawn()


func _on_hit(target: Node2D) -> void:
	_active = false
	if target.get("guarding"):
		_reflect(target)
		return
	_apply_hit()
	queue_free()


## Escudo magnético: reflete o projétil (inverte o polo) de volta ao atirador.
func _reflect(target: Node2D) -> void:
	pole      = -pole
	owner_id  = target.get_multiplayer_authority()
	direction = -direction
	_elapsed  = 0.0
	_active   = true
	_apply_pole_visual()
	_spawn_burst(target.global_position, Color(1, 1, 1, 0.9), 10, 0.25, 90.0)
	SfxBus.play("guard_block")


func _apply_pole_visual() -> void:
	if is_instance_valid(_core):
		_core.color = _pole_color()


func _apply_hit() -> void:
	if is_instance_valid(owner_player) and owner_player.has_method("_broadcast_electro"):
		owner_player._broadcast_electro.rpc(global_position, pole, owner_id)


func _despawn() -> void:
	if not _active:
		return
	_active = false
	queue_free()


func _spawn_burst(pos: Vector2, color: Color, amount: int, life: float, vel: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.position = pos
	get_tree().current_scene.add_child(p)
	p.emitting = true
