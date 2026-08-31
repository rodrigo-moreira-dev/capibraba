extends HellballPlayer2DBase

## HellballTopdownPlayer - Hellball 2D visto de cima (topdown)
## Movimento 8 direções sem gravidade, mira no mouse, dash em 8 direções.
## A lava fica ao redor da plataforma: ao entrar, é empurrado de volta ao
## centro. Herda itens, ações básicas e Game Feel.

const SPEED := 175.0
const ACCEL := 1200.0
const DASH_SPEED := 430.0
const DASH_TIME := 0.16
const DASH_CD := 0.6
const LAVA_CENTER_PUSH := 540.0

var _is_dashing := false
var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.ZERO


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

	# Corpo gira para a direção da mira (mouse)
	rotation = _aim_direction().angle()
	if raw.length_squared() > 0.01:
		facing = signf(raw.x) if absf(raw.x) > 0.01 else facing

	# Dash 8 direções
	if _is_dashing:
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
		if _dash_timer <= 0.0:
			_is_dashing = false
	elif Input.is_action_just_pressed("dash") and _dash_cd <= 0.0 and _has_basic("dash"):
		_dash_dir = raw if raw.length_squared() > 0.01 else _aim_direction()
		_dash_dir = _dash_dir.normalized()
		_is_dashing = true
		_dash_timer = DASH_TIME
		_dash_cd = DASH_CD
		_play_dash_feedback()
	_dash_cd = maxf(_dash_cd - delta, 0.0)

	var spd := SPEED * (GUARD_SPEED_MULT if guarding else 1.0)
	velocity = velocity.move_toward(raw * spd, ACCEL * delta)
