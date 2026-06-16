extends CharacterBody3D

const PALETTE := [
	Color(0.72, 0.56, 0.28),  # marrom natural
	Color(0.40, 0.24, 0.12),  # marrom escuro
	Color(0.75, 0.30, 0.15),  # vermelho
	Color(0.60, 0.60, 0.60),  # cinza
	Color(0.90, 0.55, 0.08),  # laranja
	Color(0.50, 0.25, 0.78),  # roxo
]
const KILL_PLANE_Y  := -15.0
const RESPAWN_POINT := Vector3(0.0, 2.0, 0.0)

# ── Movement ──────────────────────────────────────────────────────────────────
@export_group("Movement")
@export var speed            := 8.0
@export var acceleration     := 22.0
@export var air_acceleration := 8.0

# ── Jump ──────────────────────────────────────────────────────────────────────
@export_group("Jump")
@export var jump_velocity        := 12.0
@export var double_jump_velocity := 10.0
@export var gravity              := 30.0
@export var fall_multiplier      := 1.5
@export var coyote_time          := 0.12
@export var jump_buffer_time     := 0.14

# ── Dash ──────────────────────────────────────────────────────────────────────
@export_group("Dash")
@export var dash_speed    := 26.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.65

# ── Wall Jump ─────────────────────────────────────────────────────────────────
@export_group("Wall Jump")
@export var wall_jump_velocity      := 11.0
@export var wall_jump_push          := 7.0
@export var wall_slide_gravity_mult := 0.18

const MAX_JUMPS := 2

var _jump_count        := 0
var _coyote_timer      := 0.0
var _jump_buffer_timer := 0.0
var _was_on_floor      := false
var _is_dashing        := false
var _dash_timer        := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir          := Vector3.ZERO

@onready var camera_rig: Node3D          = $CameraRig
@onready var mesh_pivot: Node3D          = $MeshPivot
@onready var body_mesh:  MeshInstance3D  = $MeshPivot/BodyMesh
@onready var name_label: Label3D         = $NameLabel


func _ready() -> void:
	var id   := get_multiplayer_authority()
	var data := NetworkManager.players.get(id, {}) as Dictionary
	name_label.text    = data.get("name", "Capivara")
	name_label.visible = not is_multiplayer_authority()
	var cidx: int = data.get("color_index", 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PALETTE[cidx % PALETTE.size()]
	mat.roughness    = 0.8
	body_mesh.set_surface_override_material(0, mat)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_tick_timers(delta)
	_apply_gravity(delta)
	_process_dash(delta)
	if not _is_dashing:
		_apply_movement(delta)
	_process_jump()
	_face_movement(delta)
	move_and_slide()
	_post_move()


func _tick_timers(delta: float) -> void:
	if _was_on_floor and not is_on_floor():
		_coyote_timer = coyote_time
	_coyote_timer        = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer   = maxf(_jump_buffer_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if _is_dashing or is_on_floor():
		return
	var g := gravity
	if is_on_wall_only() and velocity.y < 0.0:
		g *= wall_slide_gravity_mult
	elif velocity.y < 0.0:
		g *= fall_multiplier
	velocity.y -= g * delta


func _apply_movement(delta: float) -> void:
	var dir  := _input_dir_world()
	var accel := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)


func _process_dash(delta: float) -> void:
	if _is_dashing:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
		velocity.y = 0.0
		if _dash_timer <= 0.0:
			_is_dashing = false
		return
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		var dir := _input_dir_world()
		_dash_dir = dir if dir.length_squared() > 0.01 else -mesh_pivot.global_transform.basis.z
		_dash_dir.y = 0.0
		_dash_dir    = _dash_dir.normalized()
		_is_dashing  = true
		_dash_timer  = dash_duration
		_dash_cooldown_timer = dash_cooldown


func _process_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return
	if is_on_floor() or _coyote_timer > 0.0:
		velocity.y         = jump_velocity
		_jump_count        = 1
		_jump_buffer_timer = 0.0
		_coyote_timer      = 0.0
	elif is_on_wall_only():
		var n := get_wall_normal()
		velocity.x         = n.x * wall_jump_push
		velocity.z         = n.z * wall_jump_push
		velocity.y         = wall_jump_velocity
		_jump_count        = 1
		_jump_buffer_timer = 0.0
	elif _jump_count < MAX_JUMPS:
		velocity.y         = double_jump_velocity
		_jump_count       += 1
		_jump_buffer_timer = 0.0


func _face_movement(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() > 0.5:
		var target := atan2(flat.x, flat.z)
		mesh_pivot.rotation.y = lerp_angle(mesh_pivot.rotation.y, target, 14.0 * delta)


func _input_dir_world() -> Vector3:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if raw.length_squared() < 0.01:
		return Vector3.ZERO
	var basis   := camera_rig.global_transform.basis
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
	var right   := Vector3( basis.x.x, 0.0,  basis.x.z).normalized()
	return (forward * -raw.y + right * raw.x).normalized() * raw.length()


func _post_move() -> void:
	if is_on_floor():
		_jump_count = 0
	_was_on_floor = is_on_floor()
	if global_position.y < KILL_PLANE_Y:
		global_position = RESPAWN_POINT
		velocity        = Vector3.ZERO
