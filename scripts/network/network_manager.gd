extends Node

signal players_updated
signal connected_to_server
signal connection_failed
signal server_disconnected

const DEFAULT_PORT := 7350
const MAX_PEERS    := 4

# {peer_id: {name}} — synced on all peers
var players: Dictionary = {}
var my_data: Dictionary = {name = "Capivara"}


func host(port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_PEERS) != OK:
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	players[1] = my_data.duplicate()
	players_updated.emit()


func join(ip: String, port: int = DEFAULT_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disc)


func disconnect_game() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()


# ── Server ────────────────────────────────────────────────────────────────────

func _peer_connected(_id: int) -> void:
	pass  # Waits for client to call _register


func _peer_disconnected(id: int) -> void:
	players.erase(id)
	_sync_players.rpc(players)


# ── Client ────────────────────────────────────────────────────────────────────

func _connected_ok() -> void:
	connected_to_server.emit()
	_register.rpc_id(1, my_data)


func _connected_fail() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _server_disc() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()


# ── RPCs ──────────────────────────────────────────────────────────────────────

# Client → Server: "here's my data"
@rpc("any_peer", "call_remote", "reliable")
func _register(data: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	players[id] = data
	_sync_players.rpc(players)  # Broadcast updated list to everyone


# Server → All: full player list
@rpc("authority", "call_local", "reliable")
func _sync_players(all_players: Dictionary) -> void:
	players = all_players
	players_updated.emit()
