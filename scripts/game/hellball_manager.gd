extends ArenaRulesBase

## HellballManager - Gerenciador do modo Hellball (3D)
## Arena de lava onde cada jogador possui um Charge Gun (empurra rivais para a
## lava) e um Teleport Gun (teleporte curto ou troca de lugar com um rival).
##
## UNIFICAÇÃO (CRÍTICA 2): agora herda `ArenaRulesBase` — a camada de REGRAS
## comum aos gerentes 2D e 3D (vida/abate/eliminação/vitória/reporte de lava).
## Aqui ficam só as partes 3D: container de players (Node3D), spawn, e o efeito
## de troca de posições do Teleport Gun (GPUParticles3D ciano).

const PLAYER_SCENE := preload("res://scenes/player/hellball_player.tscn")

@onready var _players_node: Node3D             = $"../Players"
@onready var _spawner:      MultiplayerSpawner = $"../MultiplayerSpawner"


func _ready() -> void:
	add_to_group("hellball_manager")
	_spawner.add_spawnable_scene("res://scenes/player/hellball_player.tscn")

	var lava_area: Area3D = get_node_or_null("../LavaArea")
	if lava_area:
		lava_area.body_entered.connect(_on_lava_body_entered)

	super._ready()


# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS 3D (implementação de ArenaRulesBase)
# ═══════════════════════════════════════════════════════════════════════════════

func _has_player_node(id: int) -> bool:
	return _players_node.has_node(str(id))


func _all_player_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for child in _players_node.get_children():
		result.append(child)
	return result


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


# ── Lava (3D) ─────────────────────────────────────────────────────────────────

func _on_lava_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		SfxBus.play("lava")
		body.on_lava_contact()


# ── Intro / HUD (3D) ──────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _show_intro() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	if hud.has_method("show_mode_hint"):
		hud.show_mode_hint("Charge Gun: segure e solte o Clique Esquerdo  ·  Teleport Gun: Clique Direito (2x = teleportar)")
	if hud.has_method("show_event_announcement"):
		hud.show_event_announcement("⚡ HELLBALL — Empurre os rivais para a lava!", 4.0)


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
