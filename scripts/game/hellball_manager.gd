extends Node

## HellballManager - Gerenciador do modo Hellball
## Arena de lava onde cada jogador possui um Charge Gun (empurra rivais para a
## lava) e um Teleport Gun (teleporte curto ou troca de lugar com um rival).
## O servidor é autoritativo para vidas/mortes/abates e valida a troca de
## posições do Teleport Gun.

const PLAYER_SCENE := preload("res://scenes/player/hellball_player.tscn")

var _lives:                Dictionary = {}
var _deaths:               Dictionary = {}
var _kills:                Dictionary = {}
var _initial_player_count: int        = 1

@onready var _players_node: Node3D             = $"../Players"
@onready var _spawner:      MultiplayerSpawner = $"../MultiplayerSpawner"


func _ready() -> void:
	add_to_group("hellball_manager")
	# Também entra no grupo usado por player.gd para reportar toque na lava
	add_to_group("last_standing_manager")
	_spawner.add_spawnable_scene("res://scenes/player/hellball_player.tscn")

	var lava_area: Area3D = get_node_or_null("../LavaArea")
	if lava_area:
		lava_area.body_entered.connect(_on_lava_body_entered)

	NetworkManager.players_updated.connect(_on_players_updated)

	if not multiplayer.is_server():
		return

	if NetworkManager.players.is_empty():
		# Teste offline (sem lobby)
		_initial_player_count = 1
		_init_player(1)
		_spawn_player(1)
		_broadcast_intro()
		return

	_initial_player_count = NetworkManager.players.size()
	for id: int in NetworkManager.players:
		_init_player(id)
		_spawn_player(id)

	_sync_lives.rpc(_lives)
	_sync_stats.rpc(_deaths, _kills)
	_broadcast_intro()


func _init_player(id: int) -> void:
	_lives[id]  = MatchSettings.lives_per_player
	_deaths[id] = 0
	_kills[id]  = 0


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


# ── Lava ─────────────────────────────────────────────────────────────────────

func _on_lava_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		SfxBus.play("lava")
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

	if _lives[player_id] <= 0:
		_lives.erase(player_id)
		if attacker_id != -1 and attacker_id != player_id and _kills.has(attacker_id):
			_kills[attacker_id] += 1
		_eliminate.rpc(player_id)

	_sync_lives.rpc(_lives)
	_sync_stats.rpc(_deaths, _kills)
	_check_win()


# ── Teleport Gun - troca de posições (servidor valida) ──────────────────────

## Cliente → Servidor: orbe acertou um rival, pede a troca.
@rpc("any_peer", "call_remote", "reliable")
func request_swap(owner_id: int, target_id: int) -> void:
	if not multiplayer.is_server():
		return
	if owner_id != multiplayer.get_remote_sender_id():
		return
	if not NetworkManager.players.has(owner_id) or not NetworkManager.players.has(target_id):
		return
	if owner_id == target_id:
		return
	# Rejeita troca com jogador já eliminado (sem nó vivo)
	if not _lives.has(owner_id) or not _lives.has(target_id):
		return
	_perform_swap.rpc(owner_id, target_id)


## Servidor → Todos: aplica a troca de posições.
@rpc("authority", "call_local", "reliable")
func _perform_swap(a_id: int, b_id: int) -> void:
	var a: CharacterBody3D = null
	var b: CharacterBody3D = null
	for p: CharacterBody3D in get_tree().get_nodes_in_group("player"):
		var pid: int = p.get_multiplayer_authority()
		if pid == a_id:
			a = p
		elif pid == b_id:
			b = p
	if a == null or b == null:
		return

	var a_pos := a.global_position
	var b_pos := b.global_position
	a.global_position = b_pos
	b.global_position = a_pos
	a.velocity = Vector3.ZERO
	b.velocity = Vector3.ZERO

	_spawn_swap_effect(a_pos)
	_spawn_swap_effect(b_pos)
	SfxBus.play("swap")
	if a.has_method("play_swap_flash"):
		a.play_swap_flash()
	if b.has_method("play_swap_flash"):
		b.play_swap_flash()


func _spawn_swap_effect(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.amount        = 24
	particles.lifetime      = 0.4
	particles.one_shot      = true
	particles.explosiveness = 1.0
	particles.global_position = pos + Vector3(0, 1, 0)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3.ZERO
	pm.color = Color(0.30, 0.80, 1.0, 0.9)
	particles.process_material = pm

	get_tree().current_scene.add_child(particles)
	particles.emitting = true


# ── Sync / HUD ───────────────────────────────────────────────────────────────

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


func _broadcast_intro() -> void:
	if multiplayer.has_multiplayer_peer():
		_show_intro.rpc()
	else:
		_show_intro()


@rpc("authority", "call_local", "reliable")
func _show_intro() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if hud.has_method("show_mode_hint"):
		hud.show_mode_hint("Charge Gun: segure e solte o Clique Esquerdo  ·  Teleport Gun: Clique Direito (2x = teleportar)")
	if hud.has_method("show_event_announcement"):
		hud.show_event_announcement("⚡ HELLBALL — Empurre os rivais para a lava!", 4.0)
