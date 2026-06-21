extends Node

## PowerupManager - Gerencia spawn e coleta de power-ups
## Deve ser adicionado como filho do nível (nó do tipo Node)

const POWERUP_SCENES := {
	"shield": preload("res://scenes/powerups/powerup_shield.tscn"),
	"superspeed": preload("res://scenes/powerups/powerup_superspeed.tscn"),
	"triple_jump": preload("res://scenes/powerups/powerup_triple_jump.tscn"),
	"homing_projectile": preload("res://scenes/powerups/powerup_homing_projectile.tscn"),
	"mine": preload("res://scenes/powerups/powerup_mine.tscn"),
	"magnet": preload("res://scenes/powerups/powerup_magnet.tscn"),
	"zero_gravity": preload("res://scenes/powerups/powerup_zero_gravity.tscn"),
}

const SPAWN_HEIGHT := 2.0
const MAX_ACTIVE_POWERUPS := 5

var _active_powerups: Array[Node3D] = []
var _next_net_id: int = 1
var _spawn_timer: float = 0.0
var _spawn_points: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("powerup_manager")
	_rng.randomize()

	# Coletar pontos de spawn da arena (SpawnPoints é filho da raiz do nível,
	# portanto irmão deste nó — buscar via owner ou caminho relativo)
	var spawn_node: Node = null
	if owner:
		spawn_node = owner.get_node_or_null("SpawnPoints")
	if not spawn_node:
		spawn_node = get_node_or_null("../SpawnPoints")
	if spawn_node:
		for child in spawn_node.get_children():
			_spawn_points.append(child.global_position)

	# Se não houver pontos, criar alguns padrão
	if _spawn_points.is_empty():
		for i in range(5):
			_spawn_points.append(Vector3(
				_rng.randf_range(-8, 8),
				SPAWN_HEIGHT,
				_rng.randf_range(-8, 8)
			))


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if not MatchSettings.powerups_enabled:
		return
	
	_spawn_timer += delta
	
	if _spawn_timer >= MatchSettings.powerup_spawn_interval:
		_spawn_timer = 0.0
		_try_spawn_powerup()


func _try_spawn_powerup() -> void:
	# Limpar power-ups já coletados
	_active_powerups = _active_powerups.filter(func(p: Node3D) -> bool: return is_instance_valid(p))
	
	if _active_powerups.size() >= MAX_ACTIVE_POWERUPS:
		return
	
	var available_types := MatchSettings.get_enabled_powerups()
	if available_type s.is_empty():
		return
	
	var type: String = available_types[_rng.randi() % available_types.size()]
	var scene: PackedScene = POWERUP_SCENES.get(type)
	if not scene:
		return

	var nid: int = _next_net_id
	_next_net_id += 1

	var powerup := scene.instantiate()
	powerup.set_meta("powerup_type", type)
	powerup.set_meta("net_id", nid)

	# Posição aleatória
	var spawn_pos: Vector3 = _spawn_points[_rng.randi() % _spawn_points.size()]
	powerup.global_position = spawn_pos + Vector3(0, SPAWN_HEIGHT, 0)

	get_tree().current_scene.add_child(powerup, true)
	_active_powerups.append(powerup)

	# Sincronizar com clientes (mesmo net_id p/ despawn coordenado)
	_spawn_powerup_rpc.rpc(powerup.global_position, type, nid)


@rpc("authority", "call_local", "reliable")
func _spawn_powerup_rpc(pos: Vector3, type: String, nid: int) -> void:
	if multiplayer.is_server():
		return  # Já spawnou no servidor

	var scene: PackedScene = POWERUP_SCENES.get(type)
	if not scene:
		return

	var powerup := scene.instantiate()
	powerup.set_meta("powerup_type", type)
	powerup.set_meta("net_id", nid)
	powerup.global_position = pos
	get_tree().current_scene.add_child(powerup, true)


# ── Coleta: o peer que pegou pede ao servidor para remover de todos ────────────

@rpc("any_peer", "call_remote", "reliable")
func request_despawn(nid: int) -> void:
	# Remover do registro ativo do servidor
	for i in range(_active_powerups.size()):
		var p: Node3D = _active_powerups[i]
		if is_instance_valid(p) and int(p.get_meta("net_id", -1)) == nid:
			_active_powerups.remove_at(i)
			break
	despawn.rpc(nid)


@rpc("authority", "call_local", "reliable")
func despawn(nid: int) -> void:
	for p: Node3D in get_tree().get_nodes_in_group("powerup"):
		if is_instance_valid(p) and int(p.get_meta("net_id", -1)) == nid:
			p.queue_free()
