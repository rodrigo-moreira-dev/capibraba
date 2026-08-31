extends HellballPlayer2DBase
class_name ArenaTopdownPlayerBase

## ArenaTopdownPlayerBase - base dos minigames 2D topdown novos (Ímãs, Espadas)
## Compartilha o movimento 8 direções sem gravidade, o dash, a mira
## (mouse/gamepad), o rebote da lava para o centro e o Game Feel. O item de
## cada minigame é definido pela subclasse via hooks:
##   - _update_item(delta): lógica contínua do item (chamado só na autoridade)
##   - _on_item_input(event): entrada do item (chamado só na autoridade)
## Herda as ações básicas (Punch, Guard, Dash) da HellballPlayer2DBase.

## Escala 2D dos minigames topdown novos: o sprite PICO-8 já é grande (~40px);
## esta base não aplica mais escala extra além do squash & stretch.
const VISUAL_SCALE := 1.0

const SPEED := 130.0
const ACCEL := 1000.0
const LAVA_CENTER_PUSH := 540.0

## Dash (parâmetros configuráveis - a subclasse pode ajustar, ex.: Bota)
var dash_speed      := 280.0
var dash_time       := 0.16
var dash_cd_time    := 0.6
var dash_iframe_time := 0.0

var _is_dashing  := false
var _dash_timer  := 0.0
var _dash_cd     := 0.0
var _dash_dir    := Vector2.ZERO
# `dashing` vem da HellballPlayer2DBase (replicado p/ i-frames); não redeclarar.

var _shadow: Polygon2D


func _ready() -> void:
	# Ações básicas na escala dos minigames topdown (Punch perto do corpo)
	punch_range = 12.0
	punch_force = 240.0
	super._ready()


func _build_visual() -> void:
	super._build_visual()
	# Sombra sutil (ajuda a "aterrar" o personagem no topdown)
	_shadow = Polygon2D.new()
	_shadow.polygon = _circle_polygon(0.8)
	_shadow.color = Color(0.0, 0.0, 0.0, 0.25)
	_shadow.position = Vector2(0.25, 0.4)
	_visual.add_child(_shadow)
	_visual.move_child(_shadow, 0)
	# Nome acima da cabeça (escala maior)
	if is_instance_valid(_name_label):
		_name_label.position = Vector2(0, -4.2)


func _update_visual(delta: float) -> void:
	# Aplica a escala visual maior do topdown (além do squash & stretch)
	_base_scale = Vector2.ONE * VISUAL_SCALE
	super._update_visual(delta)


func _physics_process(delta: float) -> void:
	_punch_cd     = maxf(_punch_cd     - delta, 0.0)
	_bounce_timer = maxf(_bounce_timer - delta, 0.0)
	_life_timer   = maxf(_life_timer   - delta, 0.0)
	_update_guard(delta)
	_update_visual(delta)
	if not is_multiplayer_authority():
		return
	_update_item(delta)
	_move(delta)
	move_and_slide()
	_post_move_2d()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("punch"):
		_try_punch()
	if event.is_action_pressed("jump"):
		_on_jump_pressed()
	_on_item_input(event)


# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ITEM (implementados pelas subclasses)
# ═══════════════════════════════════════════════════════════════════════════════

func _update_item(_delta: float) -> void:
	pass


func _on_item_input(_event: InputEvent) -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# MOVIMENTO / MIRA / LAVA
# ═══════════════════════════════════════════════════════════════════════════════

func _aim_direction() -> Vector2:
	# Gamepad: mira pelo analógico direito (ações look_*)
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length_squared() > 0.05:
		return stick.normalized()
	# Desktop: mira no mouse
	var to := get_global_mouse_position() - global_position
	if to.length_squared() < 4.0:
		return Vector2(facing, 0)
	return to.normalized()


func _lava_knockback() -> Vector2:
	var to_center := Vector2.ZERO - global_position
	if to_center.length_squared() < 4.0:
		return Vector2(0, -LAVA_CENTER_PUSH)
	return to_center.normalized() * LAVA_CENTER_PUSH


func _move(delta: float) -> void:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Corpo gira para a direção da mira
	rotation = _aim_direction().angle()
	if raw.length_squared() > 0.01:
		facing = signf(raw.x) if absf(raw.x) > 0.01 else facing

	# Dash 8 direções
	if _is_dashing:
		_dash_timer -= delta
		velocity = _dash_dir * dash_speed
		if _dash_timer <= 0.0:
			_is_dashing = false
			dashing     = false
	elif Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_dash_dir = raw if raw.length_squared() > 0.01 else _aim_direction()
		_dash_dir = _dash_dir.normalized()
		_is_dashing = true
		dashing     = true
		_dash_timer = dash_time
		_dash_cd    = dash_cd_time
		_play_dash_feedback()
	_dash_cd = maxf(_dash_cd - delta, 0.0)

	var spd := SPEED * (GUARD_SPEED_MULT if guarding else 1.0)
	velocity = velocity.move_toward(raw * spd, ACCEL * delta)
