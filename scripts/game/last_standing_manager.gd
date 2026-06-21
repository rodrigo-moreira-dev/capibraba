extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _lives:                Dictionary = {}
var _deaths:               Dictionary = {}
var _kills:                Dictionary = {}
var _kill_streaks:         Dictionary = {}  # Track kill streaks
var _initial_player_count: int        = 1
var _round_wins:           Dictionary = {}  # Track round wins
var _current_round:        int        = 1

@onready var _players_node: Node3D             = $"../Players"
@onready var _spawner:      MultiplayerSpawner = $"../MultiplayerSpawner"


func _ready() -> void:
	add_to_group("last_standing_manager")
	_spawner.add_spawnable_scene("res://scenes/player/player.tscn")

	var lava_area: Area3D = get_node_or_null("../LavaArea")
	if lava_area:
		lava_area.body_entered.connect(_on_lava_body_entered)

	NetworkManager.players_updated.connect(_on_players_updated)

	if not multiplayer.is_server():
		return

	if NetworkManager.players.is_empty():
		_initial_player_count = 1
		_init_player(1)
		_spawn_player(1)
		return

	_initial_player_count = NetworkManager.players.size()
	for id: int in NetworkManager.players:
		_init_player(id)
		_spawn_player(id)

	_sync_lives.rpc(_lives)
	_sync_stats.rpc(_deaths, _kills)


func _init_player(id: int) -> void:
	_lives[id]  = MatchSettings.lives_per_player
	_deaths[id] = 0
	_kills[id]  = 0
	_kill_streaks[id] = 0


func _on_players_updated() -> void:
	if not multiplayer.is_server():
		return
	for id: int in NetworkManager.players:
		if not _players_node.has_node(str(id)):
			if not _lives.has(id):
				_init_player(id)
			_spawn_player(id)
	for child in _players_node.get_children():
		if not NetworkManager.players.has(int(child.name)):
			child.queue_free()


func _spawn_player(id: int) -> void:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)

	var spawn_node := get_node_or_null("../SpawnPoints")
	if spawn_node:
		var pts := spawn_node.get_children()
		var idx: int = maxi(0, NetworkManager.players.keys().find(id))
		player.position = pts[idx % pts.size()].position
	else:
		player.position = Vector3(0, 3, 0)

	_players_node.add_child(player, true)


# ── Lava events ───────────────────────────────────────────────────────────────

func _on_lava_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		body.on_lava_contact()


@rpc("any_peer", "call_remote", "reliable")
func client_report_lava(player_id: int, attacker_id: int) -> void:
	on_player_lava_touch(player_id, attacker_id)


func on_player_lava_touch(player_id: int, attacker_id: int = -1) -> void:
	if not multiplayer.is_server():
		return
	if not _lives.has(player_id):
		return

	_deaths[player_id] = _deaths.get(player_id, 0) + 1
	_lives[player_id] -= 1
	
	# Reset kill streak do jogador que morreu
	_kill_streaks[player_id] = 0

	if _lives[player_id] <= 0:
		_lives.erase(player_id)
		if attacker_id != -1 and attacker_id != player_id and _kills.has(attacker_id):
			_kills[attacker_id] += 1
			# Kill streak
			_kill_streaks[attacker_id] = _kill_streaks.get(attacker_id, 0) + 1
			_check_kill_streak(attacker_id)
		_eliminate.rpc(player_id)

	_sync_lives.rpc(_lives)
	_sync_stats.rpc(_deaths, _kills)
	_check_win()


func _check_kill_streak(player_id: int) -> void:
	if not MatchSettings.kill_streak_enabled:
		return
	
	var streak: int = _kill_streaks.get(player_id, 0)
	if streak >= MatchSettings.kill_streak_bonus:
		# Bônus: ganha uma vida extra
		_lives[player_id] = _lives.get(player_id, 0) + 1
		_kill_streaks[player_id] = 0
		_announce_kill_streak.rpc(player_id, streak)


@rpc("authority", "call_local", "reliable")
func _announce_kill_streak(player_id: int, streak: int) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_kill_streak"):
		hud.show_kill_streak(player_id, streak)


# ── Sync ──────────────────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _sync_lives(data: Dictionary) -> void:
	_lives = data
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_lives"):
		hud.update_lives(_lives)


@rpc("authority", "call_local", "reliable")
func _sync_stats(deaths: Dictionary, kills: Dictionary) -> void:
	_deaths = deaths
	_kills  = kills
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_scoreboard"):
		hud.update_scoreboard(_deaths, _kills)


@rpc("authority", "call_local", "reliable")
func _eliminate(player_id: int) -> void:
	for p: Node in _players_node.get_children():
		if p.get_multiplayer_authority() == player_id:
			p.queue_free()
			break


func _check_win() -> void:
	if not multiplayer.is_server():
		return
	match _lives.size():
		0: _announce_winner.rpc(-1)
		1:
			if _initial_player_count > 1:
				_announce_winner.rpc(_lives.keys()[0])


@rpc("authority", "call_local", "reliable")
func _announce_winner(winner_id: int) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_winner"):
		hud.show_winner(winner_id)
	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
