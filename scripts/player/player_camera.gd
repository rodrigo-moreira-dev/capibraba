extends Node3D

@export var mouse_sensitivity := 0.003
@export var gamepad_sensitivity := 3.0
@export var pitch_min := -35.0
@export var pitch_max := 65.0
@export var follow_speed := 20.0

var _yaw := 0.0
var _pitch := deg_to_rad(-20.0)

@onready var spring_arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	top_level = true
	global_position = get_parent().global_position + Vector3(0, 0.8, 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(
			_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min), deg_to_rad(pitch_max)
		)
	if event.is_action_pressed("ui_cancel"):
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Gamepad right stick
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_yaw -= stick.x * gamepad_sensitivity * delta
	_pitch = clampf(
		_pitch - stick.y * gamepad_sensitivity * delta,
		deg_to_rad(pitch_min), deg_to_rad(pitch_max)
	)

	var target := get_parent().global_position + Vector3(0, 0.8, 0)
	global_position = global_position.lerp(target, follow_speed * delta)

	rotation.y = _yaw
	spring_arm.rotation.x = _pitch
