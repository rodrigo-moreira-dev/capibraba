extends Node3D

@export var mouse_sensitivity := 0.003
@export var gamepad_sensitivity := 3.0
@export var pitch_min := -35.0
@export var pitch_max := 65.0
@export var follow_speed := 20.0

var _yaw := 0.0
var _pitch := deg_to_rad(-20.0)

## Screen shake (Game Feel) — usado por impactos
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var _player: Node3D = get_parent() as Node3D


## Aplica um screen shake decrescente (intensidade 0..1+).
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)
	_shake_duration = _shake_time


func _ready() -> void:
	if not get_parent().is_multiplayer_authority():
		$SpringArm3D/Camera3D.current = false
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	top_level = true
	global_position = _player.global_position + Vector3(0, 0.8, 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min), deg_to_rad(pitch_max)
		)


func _physics_process(delta: float) -> void:
	# Gamepad right stick
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_yaw -= stick.x * gamepad_sensitivity * delta
	_pitch = clampf(
		_pitch - stick.y * gamepad_sensitivity * delta,
		deg_to_rad(pitch_min), deg_to_rad(pitch_max)
	)

	var target := _player.global_position + Vector3(0, 0.8, 0)
	var base := global_position.lerp(target, follow_speed * delta)

	# Screen shake (Game Feel): decai com o tempo restante
	var shake_offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		var t := clampf(_shake_time / maxf(_shake_duration, 0.001), 0.0, 1.0)
		shake_offset = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			0.0
		) * _shake_strength * t
	global_position = base + shake_offset

	rotation.y = _yaw
	spring_arm.rotation.x = _pitch
