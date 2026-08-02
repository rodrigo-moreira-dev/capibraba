extends HellballPlayer2DBase

## HellballPlatformPlayer - Hellball 2D visto de lado (plataforma)
## Movimento com gravidade, pulo duplo, dash horizontal. Herda os itens
## (Charge Gun + Teleport Gun), ações básicas (Punch/Guard/Dash) e Game Feel.

const GRAVITY := 1000.0
const JUMP_VELOCITY := -430.0
const DOUBLE_JUMP_VELOCITY := -380.0
const SPEED := 190.0
const ACCEL := 1400.0
const AIR_ACCEL := 900.0
const DASH_SPEED := 430.0
const DASH_TIME := 0.16
const DASH_CD := 0.65
const LAVA_BOUNCE_Y := -520.0

var _jumps := 0
var _jump_buffer := 0.0
var _is_dashing := false
var _dash_timer := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.ZERO


func _on_jump_pressed() -> void:
	_jump_buffer = 0.12


func _aim_direction() -> Vector2:
	return Vector2(facing, 0)


func _lava_knockback() -> Vector2:
	return Vector2(velocity.x * 0.15, LAVA_BOUNCE_Y)


func _update_visual(_delta: float) -> void:
	_base_scale = Vector2(facing, 1)
	super._update_visual(_delta)


func _move(delta: float) -> void:
	# Gravidade
	if _is_dashing:
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y += GRAVITY * delta

	# Dash horizontal
	if _is_dashing:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * DASH_SPEED
		if _dash_timer <= 0.0:
			_is_dashing = false
	elif Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_dash_dir = Vector2(facing, 0)
		_is_dashing = true
		_dash_timer = DASH_TIME
		_dash_cd = DASH_CD
		_play_dash_feedback()
	_dash_cd = maxf(_dash_cd - delta, 0.0)

	# Movimento horizontal
	if not _is_dashing:
		var dir := Input.get_axis("move_left", "move_right")
		if dir != 0.0:
			facing = signf(dir)
		var accel := ACCEL if is_on_floor() else AIR_ACCEL
		var spd := SPEED * (GUARD_SPEED_MULT if guarding else 1.0)
		velocity.x = move_toward(velocity.x, dir * spd, accel * delta)

	# Pulo / pulo duplo
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if _jump_buffer > 0.0:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			_jumps = 1
			_jump_buffer = 0.0
			_play_jump_feedback()
		elif _jumps < 2:
			velocity.y = DOUBLE_JUMP_VELOCITY
			_jumps += 1
			_jump_buffer = 0.0
			_play_jump_feedback()
	if is_on_floor():
		_jumps = 0
