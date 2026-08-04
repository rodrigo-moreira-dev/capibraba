extends Node
class_name ArenaManager2DBase

## ArenaManager2DBase - base dos gerentes de minigames 2D topdown (Ímãs/Espadas)
## Servidor autoritativo para vidas/mortes/abates/vitória + lava (mesmo padrão
## do hellball_manager_2d). A cena define `player_scene`, `mode_hint` e
## `intro_text`. Subclasses adicionam a resolução específica do minigame
## (ex.: morte por espada no sword_manager_2d.gd).

@export var player_scene: PackedScene
@export var mode_hint: String = ""
@export var intro_text: String = ""

var _lives:                Dictionary = {}
var _deaths:               Dictionary = {}
var _kills:                Dictionary = {}
var _initial_player_count: int        = 1

@onready var _players_node: Node2D             = $"../Players"
@onready var _spawner:      MultiplayerSpawner = $"../MultiplayerSpawner"


func _ready() -> void:
	add_to_group("arena_manager_2d")
	# Reutiliza o reporte de toque na lava dos jogadores 2D (grupo já usado)
	add_to_group("last_standing_manager")

	if player_scene:
		_spawner.add_spawnable_scene(player_scene.resource_path)

	# Conecta a TODAS as áreas de lava (grupo "lava_area")
	for lava in get_tree().get_nodes_in_group("lava_area"):
		if lava is Area2D:
			lava.body_entered.connect(_on_lava_body_entered)

	NetworkManager.players_updated.connect(_on_players_updated)

	if not multiplayer.is_server():
		return

	if NetworkManager.players.is_empty():
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
	if player_scene == null:
		return
	var player := player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)

	var spawn_node := get_node_or_null("../SpawnPoints")
	if spawn_node:
		var pts := spawn_node.get_children()
		var idx: int = maxi(0, NetworkManager.players.keys().find(id))
		player.position = pts[idx % pts.size()].position
	else:
		player.position = Vector2(0, 2)

	_players_node.add_child(player, true)


# ── Lava ─────────────────────────────────────────────────────────────────────

func _on_lava_body_entered(body: Node2D) -> void:
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

	if _lives[player_id] <= 0:
		_kill_player(player_id, attacker_id)

	_sync_lives.rpc(_lives)
	_sync_stats.rpc(_deaths, _kills)
	_check_win()


## Elimina um jogador (1 vida/1 hit = morte) com crédito de abate. Só servidor.
func _kill_player(player_id: int, attacker_id: int = -1) -> void:
	_lives.erase(player_id)
	if attacker_id != -1 and attacker_id != player_id and _kills.has(attacker_id):
		_kills[attacker_id] += 1
	_eliminate.rpc(player_id)


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
		hud.show_mode_hint(mode_hint)
	if hud.has_method("show_event_announcement") and not intro_text.is_empty():
		hud.show_event_announcement(intro_text, 4.0)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS (usados pelos gerentes de minigame)
# ═══════════════════════════════════════════════════════════════════════════════

func get_player_node(pid: int) -> CharacterBody2D:
	for p: CharacterBody2D in _players_node.get_children():
		if p.get_multiplayer_authority() == pid:
			return p
	return null


func spawn_burst(pos: Vector2, color: Color, amount: int, life: float, vel: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.position = pos
	get_tree().current_scene.add_child(p)
	p.emitting = true
