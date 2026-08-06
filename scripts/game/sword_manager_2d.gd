extends ArenaManager2DBase
class_name SwordManager2D

## SwordManager2D - Gerente do minigame Espadas (2D topdown)
## Servidor autoritativo para a resolução da espada: golpe 1-hit-kill e PARRY.
## Os jogadores avisam swing_start quando a janela ativa do golpe começa; o
## servidor verifica:
##   1) PARRY: outra janela ativa, com os dois de frente → ninguém morre.
##   2) ACERTO: alvo no alcance/arco (e não em dash) → eliminação.
## A morte é decidida no fim da janela ativa para dar tempo ao parry simultâneo.

const SWORD_ACTIVE  := 0.12   # precisa bater com SwordTopdownPlayer.SWORD_ACTIVE
const SWORD_RANGE   := 12.0
const SWORD_ARC_DEG := 100.0
const PARRY_PUSH    := 260.0

var _swing_data: Dictionary = {}  # player_id -> {"dir": Vector2, "until": float}


func _ready() -> void:
	add_to_group("sword_manager_2d")
	super._ready()


# ── Resolução da espada (servidor) ───────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func swing_start(attacker_id: int, dir: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and attacker_id != sid:
		return
	if not NetworkManager.players.has(attacker_id):
		return
	if _swing_data.has(attacker_id):
		return

	_swing_data[attacker_id] = {
		"dir": dir,
		"until": Time.get_ticks_msec() / 1000.0 + SWORD_ACTIVE,
	}

	# PARRY imediato contra uma janela já ativa
	if _try_parry(attacker_id, dir):
		return

	# ACERTO resolvido no fim da janela (dá tempo para parry simultâneo)
	await get_tree().create_timer(SWORD_ACTIVE).timeout
	if not is_inside_tree():
		return
	if not _swing_data.has(attacker_id):
		return
	if _try_parry(attacker_id, dir):
		return
	_swing_data.erase(attacker_id)

	var victim := _find_sword_target(attacker_id, dir)
	if victim != -1:
		_show_kill_effect.rpc(victim)
		_kill_player(victim, attacker_id)


## Procura outra janela ativa de frente → PARRY (nenhuma morte). True se parry.
func _try_parry(attacker_id: int, dir: Vector2) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	for qid: int in _swing_data.keys():
		if qid == attacker_id:
			continue
		var q: Dictionary = _swing_data[qid]
		if q.until < now:
			_swing_data.erase(qid)
			continue
		if _facing_each_other(attacker_id, qid, dir, q.dir):
			_swing_data.erase(attacker_id)
			_swing_data.erase(qid)
			_perform_parry.rpc(attacker_id, qid)
			return true
	return false


## Dois jogadores de frente um para o outro (cones de ~120°).
func _facing_each_other(a_id: int, b_id: int, adir: Vector2, bdir: Vector2) -> bool:
	var a := get_player_node(a_id)
	var b := get_player_node(b_id)
	if a == null or b == null:
		return false
	var to_b := (b.global_position - a.global_position).normalized()
	var to_a := -to_b
	return to_b.dot(adir.normalized()) > 0.5 and to_a.dot(bdir.normalized()) > 0.5


## Alvo mais próximo dentro do alcance e do arco do golpe.
func _find_sword_target(attacker_id: int, dir: Vector2) -> int:
	var a := get_player_node(attacker_id)
	if a == null:
		return -1
	var best     := -1
	var best_dist := INF
	for p: CharacterBody2D in _players_node.get_children():
		if not p is CharacterBody2D:
			continue
		var pid: int = p.get_multiplayer_authority()
		if pid == attacker_id:
			continue
		if not _lives.has(pid):
			continue
		if p.get("dashing"):
			continue  # bota de dash = i-frames durante o dash
		var to := p.global_position - a.global_position
		var dist := to.length()
		if dist > SWORD_RANGE:
			continue
		if to.normalized().dot(dir.normalized()) < cos(deg_to_rad(SWORD_ARC_DEG) * 0.5):
			continue
		if dist < best_dist:
			best_dist = dist
			best      = pid
	return best


# ── Efeitos (broadcast para todos) ───────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func _perform_parry(a_id: int, b_id: int) -> void:
	var a := get_player_node(a_id)
	var b := get_player_node(b_id)
	if a == null or b == null:
		return
	var away := a.global_position - b.global_position
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT
	away = away.normalized()
	a.velocity += away * PARRY_PUSH
	b.velocity += -away * PARRY_PUSH
	SfxBus.play("guard_block")
	spawn_burst(a.global_position, Color(0.95, 0.95, 1.0, 0.9), 20, 0.35, 140.0)
	spawn_burst(b.global_position, Color(0.95, 0.95, 1.0, 0.9), 20, 0.35, 140.0)
	if a.has_method("play_parry_flash"):
		a.play_parry_flash()
	if b.has_method("play_parry_flash"):
		b.play_parry_flash()


@rpc("authority", "call_local", "reliable")
func _show_kill_effect(victim_id: int) -> void:
	var v := get_player_node(victim_id)
	if v == null:
		return
	SfxBus.play("explosion")
	spawn_burst(v.global_position, Color(1.0, 0.95, 0.9, 0.95), 24, 0.45, 150.0)
	if v.has_method("play_death_flash"):
		v.play_death_flash()
	var cam := get_tree().get_first_node_in_group("arena_camera")
	if cam and cam.has_method("shake"):
		cam.shake(0.6, 0.22)
