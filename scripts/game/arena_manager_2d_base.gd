extends ArenaRulesBase
class_name ArenaManager2DBase

## ArenaManager2DBase - base dos gerentes de minigames 2D topdown (Ímãs/Espadas)
## Servidor autoritativo para vidas/mortes/abates/vitória + lava (mesmo padrão
## do hellball). Agora herda `ArenaRulesBase` (a camada de REGRAS agnóstica de
## dimensão): a vida/abate/eliminação/vitória/reporte de lava vivem lá. Aqui
## ficam só as partes 2D: o container de players (Node2D), o spawn e os efeitos.
##
## A cena define `player_scene`, `mode_hint` e `intro_text`. Subclasses adicionam
## a resolução específica do minigame (ex.: morte por espada no sword_manager_2d).

@export var player_scene: PackedScene
@export var mode_hint: String = ""
@export var intro_text: String = ""

@onready var _players_node: Node2D             = $"../Players"
@onready var _spawner:      MultiplayerSpawner = $"../MultiplayerSpawner"


func _ready() -> void:
	add_to_group("arena_manager_2d")
	if player_scene:
		_spawner.add_spawnable_scene(player_scene.resource_path)

	# Conecta a TODAS as áreas de lava (grupo "lava_area")
	for lava in get_tree().get_nodes_in_group("lava_area"):
		if lava is Area2D:
			lava.body_entered.connect(_on_lava_body_entered)

	super._ready()


# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS 2D (implementação de ArenaRulesBase)
# ═══════════════════════════════════════════════════════════════════════════════

func _has_player_node(id: int) -> bool:
	return _players_node.has_node(str(id))


func _all_player_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for child in _players_node.get_children():
		result.append(child)
	return result


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


# ── Lava (2D) ─────────────────────────────────────────────────────────────────

func _on_lava_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		body.on_lava_contact()


# ── Intro / HUD (2D) ──────────────────────────────────────────────────────────

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
