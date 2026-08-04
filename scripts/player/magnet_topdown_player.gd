extends ArenaTopdownPlayerBase
class_name MagnetTopdownPlayer

## MagnetTopdownPlayer - Minigame Ímãs (2D topdown)
## Item 1 - Ímã de Dois Polos:
##   - Clique Esq (shoot): alterna o polo (Norte azul / Sul vermelho).
##   - Segurar Clique Dir (teleport_gun): carrega o campo magnético; enquanto
##     segura, aplica força radial nos jogadores: polo OPOSTO atrai, polo
##     IGUAL repele. Soltar dispara um projétil eletromagnético com o polo atual.
## Item 2 - Escudo Magnético (substitui o Guard neste minigame):
##   - Segurar Ctrl/LB: ergue o escudo; anula forças magnéticas sobre você e
##     REFLETE projéteis eletromagnéticos (invertendo o polo de volta ao atirador).

const ELECTRO_SCENE := preload("res://scenes/player/electro_projectile_2d.tscn")

## Ímã
const FIELD_RADIUS   := 150.0
const CHARGE_TIME    := 1.0
## Força do campo por frame (aplicada em cada physics frame na vítima; o
## movimento dela "consome" ~20/frame, então ~26/frame vira um arrasto suave).
const FIELD_STRENGTH := 26.0
const POLE_CD        := 0.25
const FIELD_CD       := 0.4
const PROJECTILE_SPEED := 340.0
const HIT_RADIUS     := 130.0
const HIT_FORCE      := 420.0

## Escudo magnético
const SHIELD_RADIUS_UP := 1.05   # escala do visual do escudo ao erguer

var pole := 1  # 1 = Norte (azul), -1 = Sul (vermelho)  [replicado]
var _pole_cd   := 0.0
var _charging  := false
var _charge    := 0.0
var _field_cd  := 0.0

# Visuais extras
var _pole_ring:  Polygon2D
var _field_ring: Polygon2D


func _ready() -> void:
	super._ready()
	_build_magnet_visual()


# ═══════════════════════════════════════════════════════════════════════════════
# ITEM - ÍMÃ
# ═══════════════════════════════════════════════════════════════════════════════

func _on_item_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot") and _pole_cd <= 0.0:
		_toggle_pole()


func _update_item(delta: float) -> void:
	_pole_cd  = maxf(_pole_cd  - delta, 0.0)
	_field_cd = maxf(_field_cd - delta, 0.0)

	if Input.is_action_pressed("teleport_gun"):
		if not _charging and _field_cd <= 0.0:
			_charging = true
			_charge   = 0.0
		if _charging:
			_charge = minf(_charge + delta / CHARGE_TIME, 1.0)
			_apply_field()
	elif _charging:
		_fire_projectile()


func _toggle_pole() -> void:
	pole = -pole
	_pole_cd = POLE_CD
	SfxBus.play("teleport")
	_spawn_burst_2d(global_position, _pole_color(0.8), 8, 0.25, 60.0)


func _apply_field() -> void:
	_broadcast_field.rpc(global_position, pole, _charge, get_multiplayer_authority())
	# Recuo leve no próprio ímã (permite micro-manobras)
	velocity += -_aim_direction() * 4.0 * _charge


@rpc("any_peer", "call_local", "unreliable")
func _broadcast_field(pos: Vector2, src_pole: int, charge: float, attacker_id: int) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and attacker_id != sid:
		return
	for p: CharacterBody2D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		if p == self:
			continue
		if p.get("guarding"):
			continue  # escudo magnético anula
		var to := p.global_position - pos
		var dist := to.length()
		if dist > FIELD_RADIUS:
			continue
		var force_dir := _pole_force_dir(p, to, dist, src_pole)
		var falloff := 1.0 - dist / FIELD_RADIUS
		p.velocity += force_dir * FIELD_STRENGTH * charge * falloff
		p.last_attacker_id = attacker_id


func _fire_projectile() -> void:
	_charging = false
	_field_cd = FIELD_CD
	var dir := _aim_direction()
	var pj := ELECTRO_SCENE.instantiate()
	pj.direction    = dir
	pj.pole         = pole
	pj.owner_id     = get_multiplayer_authority()
	pj.owner_player = self
	get_tree().current_scene.add_child(pj)
	pj.global_position = global_position + dir * 1.5
	SfxBus.play("charge_shoot")


## Direção da força sobre o alvo: polo IGUAL repele (para longe), OPOSTO atrai.
func _pole_force_dir(target: Node2D, to: Vector2, dist: float, src_pole: int) -> Vector2:
	var tpole: int = target.pole if target is MagnetTopdownPlayer else 1
	var dir := to / maxf(dist, 1.0)
	return dir if tpole == src_pole else -dir


## Aplicado pelo projétil eletromagnético ao acertar (força de um golpe só).
@rpc("any_peer", "call_local", "reliable")
func _broadcast_electro(pos: Vector2, src_pole: int, attacker_id: int) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and attacker_id != sid:
		return
	var hit := false
	for p: CharacterBody2D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		if p == self:
			continue
		if p.get("guarding"):
			continue
		var to := p.global_position - pos
		var dist := to.length()
		if dist > HIT_RADIUS:
			continue
		var force_dir := _pole_force_dir(p, to, dist, src_pole)
		var falloff := 1.0 - dist / HIT_RADIUS
		p.velocity += force_dir * HIT_FORCE * falloff
		p.last_attacker_id = attacker_id
		hit = true
		if p.has_method("play_hurt_feedback_2d"):
			p.play_hurt_feedback_2d(force_dir)
	if hit:
		SfxBus.play("explosion")
		_spawn_burst_2d(pos, Color(0.40, 0.70, 1.0, 0.9), 16, 0.35, 120.0)


# ═══════════════════════════════════════════════════════════════════════════════
# ESCUDO MAGNÉTICO (substitui o Guard)
# ═══════════════════════════════════════════════════════════════════════════════

func _update_guard(_delta: float) -> void:
	if not is_multiplayer_authority():
		if is_instance_valid(_shield):
			_shield.visible = guarding
			_shield.color   = _shield_color()
			_shield.scale   = Vector2.ONE * (SHIELD_RADIUS_UP if guarding else 0.85)
		return
	guarding = Input.is_action_pressed("guard")
	if is_instance_valid(_shield):
		_shield.visible = guarding
		_shield.color   = _shield_color()
		_shield.scale   = Vector2.ONE * (SHIELD_RADIUS_UP if guarding else 0.85)


func _shield_color() -> Color:
	return Color(0.35, 0.85, 1.0, 0.30) if guarding else Color(0.25, 0.66, 0.96, 0.22)


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL
# ═══════════════════════════════════════════════════════════════════════════════

func _build_magnet_visual() -> void:
	# Anel indicador do polo (atrás do corpo)
	_pole_ring = Polygon2D.new()
	_pole_ring.polygon = _circle_polygon(0.95)
	_pole_ring.color   = _pole_color()
	_visual.add_child(_pole_ring)

	# Anel do campo (visível ao carregar; escala = carga)
	_field_ring = Polygon2D.new()
	_field_ring.polygon = _circle_polygon(1.0)
	_field_ring.color   = Color(1.0, 1.0, 1.0, 0.18)
	_field_ring.visible = false
	_visual.add_child(_field_ring)


func _pole_color(alpha: float = 0.55) -> Color:
	return Color(0.30, 0.60, 1.0, alpha) if pole == 1 else Color(1.0, 0.30, 0.25, alpha)


func _update_visual(delta: float) -> void:
	super._update_visual(delta)
	if is_instance_valid(_pole_ring):
		_pole_ring.color = _pole_color()
	if not is_multiplayer_authority():
		return
	if is_instance_valid(_field_ring):
		_field_ring.visible = _charging
		_field_ring.scale   = Vector2.ONE * (0.5 + _charge * 1.8)
		_field_ring.color   = _pole_color(0.20)
