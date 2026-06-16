extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SPAWN_POINTS := [
	Vector3( 0, 2,  0),
	Vector3( 6, 2,  5),
	Vector3(-6, 2,  5),
	Vector3( 0, 2, -6),
]

@onready var players_node: Node3D = $"../Players"


func _ready() -> void:
	var spawner: MultiplayerSpawner = $"../MultiplayerSpawner"
	spawner.add_spawnable_scene("res://scenes/player/player.tscn")

	NetworkManager.players_updated.connect(_on_players_updated)

	if not multiplayer.is_server():
		return

	# Offline testing: no lobby was used
	if NetworkManager.players.is_empty():
		_spawn_player(1)
		return

	for id: int in NetworkManager.players:
		_spawn_player(id)


func _on_players_updated() -> void:
	if not multiplayer.is_server():
		return
	# Spawn newcomers
	for id: int in NetworkManager.players:
		if not players_node.has_node(str(id)):
			_spawn_player(id)
	# Despawn disconnected
	for child in players_node.get_children():
		if not NetworkManager.players.has(int(child.name)):
			child.queue_free()


func _spawn_player(id: int) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	var idx: int = maxi(0, NetworkManager.players.keys().find(id))
	player.position = SPAWN_POINTS[idx % SPAWN_POINTS.size()]
	players_node.add_child(player, true)
