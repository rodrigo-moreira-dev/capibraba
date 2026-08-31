extends ArenaManager2DBase

## HellballManager2D - Gerenciador do modo Hellball 2D (Plataforma/Topdown)
## Servidor autoritativo para vidas/mortes/abates e valida a troca de
## posições do Teleport Gun. A cena define qual `player_scene` usar e o
## texto de dica do modo.
##
## UNIFICAÇÃO (CRÍTICA 2): agora herda `ArenaManager2DBase` (a base comum dos
## gerentes 2D topdown) em vez de duplicar vida/lava/placar/vitória. A base já
## fornece: spawn, reporte de lava, sync de vidas/stats, eliminação, vitória,
## intro e helpers (get_player_node, spawn_burst). Aqui só adicionamos o que é
## específico do Hellball 2D:
##   - Override de `_kill_player` para GENTIL (Hellball remove 1 vida, não é
##     1-hit-kill como Espadas/Ímãs) — a base chama `_kill_player` ao zerar.
##   - Troca de posições do Teleport Gun (request_swap → _perform_swap).
##   - Efeito de troca (CPUParticles2D ciano).

func _ready() -> void:
	add_to_group("hellball_manager_2d")
	# Preserva o anúncio de abertura que o gerente original mostrava.
	if intro_text.is_empty():
		intro_text = "⚡ HELLBALL — Empurre os rivais para a lava!"
	# A base já entra em "last_standing_manager" e conecta lava/players.
	# (mode_hint vem do pai ArenaManager2DBase; se a cena não setou, usa o padrão.)
	if mode_hint.is_empty():
		mode_hint = "Charge Gun: segure e solte o Clique Esquerdo  ·  Teleport Gun: Clique Direito (2x = teleportar)"
	super._ready()


# ═══════════════════════════════════════════════════════════════════════════════
# LAVA / VIDA (override do comportamento da base)
# ═══════════════════════════════════════════════════════════════════════════════
# A base `on_player_lava_touch` decrementa 1 vida e, ao zerar, chama
# `_kill_player`. No Hellball as vidas são múltiplas e o abate é atribuído ao
# último atacante (last_attacker_id), já tratado pela base. Mantemos o
# comportamento padrão da base (que é exatamente o do Hellball 2D original);
# se um minigame 2D precisar de 1-hit-kill, ele sobrescreve `_kill_player`.
func _kill_player(player_id: int, attacker_id: int = -1) -> void:
	# Comportamento Hellball: usado quando a vida zera. A base já removeu a
	# vida; aqui só damos o crédito de abate e eliminamos.
	super._kill_player(player_id, attacker_id)


# ── Teleport Gun - troca de posições (servidor valida) ──────────────────────

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


@rpc("authority", "call_local", "reliable")
func _perform_swap(a_id: int, b_id: int) -> void:
	var a: CharacterBody2D = null
	var b: CharacterBody2D = null
	for p: CharacterBody2D in get_tree().get_nodes_in_group("player"):
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
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO

	_spawn_swap_effect(a_pos)
	_spawn_swap_effect(b_pos)
	SfxBus.play("swap")
	if a.has_method("play_swap_flash"):
		a.play_swap_flash()
	if b.has_method("play_swap_flash"):
		b.play_swap_flash()


func _spawn_swap_effect(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 18
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 16.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.30, 0.80, 1.0, 0.9)
	p.position = pos
	get_tree().current_scene.add_child(p)
	p.emitting = true
