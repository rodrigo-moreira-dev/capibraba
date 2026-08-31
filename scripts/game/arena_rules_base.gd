extends Node
class_name ArenaRulesBase

## ArenaRulesBase - regras comuns a TODOS os gerentes de minigame (2D e 3D).
## Encapsula o que se repete entre hellball_manager.gd (3D), hellball_manager_2d
## e arena_manager_2d_base: vida/abate/eliminação/vitória e reporte de lava.
## É AGNÓSTICO de dimensão: não referencia Node2D/Node3D, Vector2/Vector3 nem
## partículas — apenas Dictionaries e RPCs de estado. Cada gerente concreto
## implementa `_spawn_player(id)` e `_eliminate_player(player_id)` com o tipo
## adequado (2D ou 3D). Isso resolve a CRÍTICA 2 (unificação dos managers).
##
## ⚠️ Subclasses DEVEM chamar `super._ready()` e implementar os hooks abaixo.

var _lives:                Dictionary = {}
var _deaths:               Dictionary = {}
var _kills:                Dictionary = {}
var _initial_player_count: int        = 1

# Hooks obrigatórios, a implementar em cada gerente concreto (2D ou 3D).
# @export var player_scene (na subclasse, para tipar com o PackedScene certo).


func _ready() -> void:
	add_to_group("last_standing_manager")
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
		if not _has_player_node(id):
			if not _lives.has(id):
				_init_player(id)
			_spawn_player(id)
	for child in _all_player_nodes():
		var cid: int = child.get_multiplayer_authority()
		if not NetworkManager.players.has(cid):
			_remove_player_node(child)


# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE DIMENSÃO (implementar na subclasse 2D/3D)
# ═══════════════════════════════════════════════════════════════════════════════

## True se o nó de um jogador com esse id já existe no container de players.
func _has_player_node(id: int) -> bool:
	return false


## Retorna todos os nós de jogadores sob o container de players.
func _all_player_nodes() -> Array[Node]:
	return []


## Adiciona/spawna o nó do jogador com esse id.
func _spawn_player(id: int) -> void:
	pass


## Remove o nó de jogador passado.
func _remove_player_node(node: Node) -> void:
	node.queue_free()


## Elimina o jogador: remove o nó do container (vida já foi zerada pela base).
func _eliminate_player(player_id: int) -> void:
	for node in _all_player_nodes():
		if node.get_multiplayer_authority() == player_id:
			_remove_player_node(node)
			return


# ═══════════════════════════════════════════════════════════════════════════════
# LAVA / VIDA / ABATE (servidor autoritativo)
# ═══════════════════════════════════════════════════════════════════════════════

## Cliente → Servidor: reporta toque na lava (se não for o host).
@rpc("any_peer", "call_remote", "reliable")
func client_report_lava(player_id: int, attacker_id: int) -> void:
	on_player_lava_touch(player_id, attacker_id)


## Servidor: aplica um toque na lava (remove 1 vida, atribui abate ao atacante).
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


## Zera a vida do jogador e atribui o abate. Só servidor. A base dá o crédito e
## elimina. Subclasses com 1-hit-kill (Espadas/Ímãs) sobrescrevem para matar mais
## cedo; aqui o comportamento é o do Hellball (vida já foi zerada pela lava).
func _kill_player(player_id: int, attacker_id: int = -1) -> void:
	_lives.erase(player_id)
	if attacker_id != -1 and attacker_id != player_id and _kills.has(attacker_id):
		_kills[attacker_id] += 1
	_eliminate_player(player_id)


# ═══════════════════════════════════════════════════════════════════════════════
# SYNC / HUD / VITÓRIA
# ═══════════════════════════════════════════════════════════════════════════════

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


## Aviso de abertura do minigame. Subclasses sobrescrevem p/ mostrar dica p/ modo.
@rpc("authority", "call_local", "reliable")
func _show_intro() -> void:
	pass
