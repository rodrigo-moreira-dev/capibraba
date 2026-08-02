extends Camera2D

## ArenaCamera2D - Câmera fixa das arenas 2D com suporte a screen shake
## (Game Feel). Registrar-se no grupo "arena_camera" para os jogadores
## acionarem shake via RPC local.

var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0


func _ready() -> void:
	add_to_group("arena_camera")


func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_time = maxf(_shake_time, duration)
	_shake_duration = _shake_time


func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time -= delta
	var t := clampf(_shake_time / maxf(_shake_duration, 0.001), 0.0, 1.0)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength * t
	if _shake_time <= 0.0:
		offset = Vector2.ZERO
