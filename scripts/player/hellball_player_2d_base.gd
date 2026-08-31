extends CharacterBody2D
class_name HellballPlayer2DBase

## HellballPlayer2DBase - Base dos jogadores Hellball 2D (Plataforma/Topdown)
## Compartilha as duas armas (Charge Gun + Teleport Gun), as ações básicas
## (Punch, Guard, Dash) e todo o Game Feel (squash & stretch, hit-stop,
## shake, partículas). Subclasses implementam `_move()` e `_aim_direction()`.

const CHARGE_ORB_SCENE := preload("res://scenes/player/charge_orb_2d.tscn")
const TELEPORT_ORB_SCENE := preload("res://scenes/player/teleport_orb_2d.tscn")
const NAME_LABEL_SCRIPT := preload("res://scripts/ui/name_label_2d.gd")
const PICO8_CAPYBARA := preload("res://scripts/player/pico8_capybara.gd")

const PALETTE: Array[Color] = [
	Color(0.72, 0.56, 0.28),
	Color(0.40, 0.24, 0.12),
	Color(0.75, 0.30, 0.15),
	Color(0.60, 0.60, 0.60),
	Color(0.90, 0.55, 0.08),
	Color(0.50, 0.25, 0.78),
]

## Charge Gun (unidades de pixel 2D)
const CHARGE_MAX_TIME := 1.2
const CHARGE_MIN_PUSH := 240.0
const CHARGE_MAX_PUSH := 560.0
const CHARGE_COOLDOWN := 0.5
const CHARGE_RADIUS   := 150.0

## Teleport Gun
const TELEPORT_COOLDOWN := 0.4

## Ações básicas
var punch_range     := 44.0   # var p/ permitir escala diferente (ex.: topdown novo)
var punch_force     := 280.0
const PUNCH_COOLDOWN := 0.4
const PUNCH_WINDUP   := 0.08
const GUARD_KNOCKBACK_REDUCTION := 0.2
const GUARD_SPEED_MULT := 0.55

## Lava
const LAVA_BOUNCE_COOLDOWN := 0.3
const LAVA_LIFE_COOLDOWN   := 2.0

var _charge_power    := 0.0
var _is_charging     := false
var _charge_timer    := 0.0
var _charge_cd       := 0.0
var _teleport_cd     := 0.0
var _punch_cd        := 0.0
var _teleport_orb = null
var last_attacker_id := -1
var _bounce_timer := 0.0
var _life_timer   := 0.0

var guarding := false
var facing := 1.0
var dashing := false  # replicado (usado p/ i-frames em dash); as subclasses setam
var _base_scale := Vector2.ONE
var _squash_scale := Vector2.ONE
var _was_grounded := false
var _hitstop_count := 0

var _visual: Node2D
var _body: Sprite2D
var _shield: Polygon2D
var _charge_indicator: Polygon2D
var _name_label


func _ready() -> void:
	add_to_group("player")
	_build_visual()


# ═══════════════════════════════════════════════════════════════════════════════
# ITENS GENÉRICOS (Fase 0) — consulta MatchSettings/ItemCatalog
# ═══════════════════════════════════════════════════════════════════════════════
# Os itens do minigame vêm de `MatchSettings.items_pool` limitado a
# `item_slots`. As ações básicas (Punch/Guard/Dash) são consultadas por
# `MatchSettings.get_enabled_basic_actions()`. Isso substitui o comportamento
# de "sempre ter Charge + Teleport" por um pool configurável.

func _has_item(id: String) -> bool:
	return MatchSettings.get_enabled_items().has(id)


func _has_basic(action: String) -> bool:
	var actions: Dictionary = MatchSettings.get_enabled_basic_actions()
	return actions.get(action, true)


func _item_data(id: String) -> Dictionary:
	return ItemCatalog.get_item(id)


# ═══════════════════════════════════════════════════════════════════════════════
# REPLICAÇÃO DE ESTADO (CRÍTICA 3): ataque/defesa visível para todos os peers
# ═══════════════════════════════════════════════════════════════════════════════
# `guarding`, `facing` e `dashing` são estado de "momento" que todos os peers
# precisam ver para a resolução de parry/knockback ser justa e consistente.
# Ao ler isso localmente (cliente autoritário), transmitimos via `_broadcast_state`
# para os demais, que o aplicam localmente. O servidor continua autoritativo para
# vidas/morte/troca (gerente); aqui só garantimos que TODOS veem o mesmo momento.
var _last_sync_guarding: bool = false
var _last_sync_facing: float = 1.0
var _last_sync_pole: int = 0
var _last_sync_swinging: bool = false

## Campos replicáveis. Subclasses podem sobrescrever para incluir `pole`/`swinging`.
func _replicated_state() -> Dictionary:
	return {
		"guarding": guarding,
		"facing": facing,
		"dashing": dashing,
		"pole": _last_sync_pole,
		"swinging": _last_sync_swinging,
	}


## Chamado no cliente autoritário a cada frame: se mudou, transmite o estado.
func _replicate_state() -> void:
	if not is_multiplayer_authority():
		return
	var st := _replicated_state()
	if st.guarding == _last_sync_guarding \
		and st.facing == _last_sync_facing \
		and st.pole == _last_sync_pole \
		and st.swinging == _last_sync_swinging:
		return
	_last_sync_guarding = st.guarding
	_last_sync_facing    = st.facing
	_last_sync_pole      = st.pole
	_last_sync_swinging  = st.swinging
	# Multiplayer: transmite para os demais peers. Sem rede, nada a fazer.
	if multiplayer.has_multiplayer_peer():
		_broadcast_replicated_state.rpc(st.guarding, st.facing, st.pole, st.swinging)


@rpc("any_peer", "call_local", "reliable")
func _broadcast_replicated_state(grd: bool, face: float, pol: int, swg: bool) -> void:
	# Anti-cheat (CRÍTICA 4): só aceita o estado vindo da AUTORIDADE deste
	# jogador (o dono do nó). Um peer malicioso não pode forjar o estado de outro.
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and sid != get_multiplayer_authority():
		return
	# Aplica o estado replicado nos peers NÃO-autoritários (quem vê o outro).
	if is_multiplayer_authority():
		return
	guarding = grd
	facing   = face
	dashing  = false
	_apply_replicated_extras(pol, swg)


## Subclasses registram estado extra (ex.: polo, swinging). Padrão: ignora.
func _apply_replicated_extras(_pol: int, _swg: bool) -> void:
	pass


func _physics_process(delta: float) -> void:
	_charge_cd   = maxf(_charge_cd   - delta, 0.0)
	_teleport_cd = maxf(_teleport_cd - delta, 0.0)
	_punch_cd    = maxf(_punch_cd    - delta, 0.0)
	_bounce_timer = maxf(_bounce_timer - delta, 0.0)
	_life_timer   = maxf(_life_timer   - delta, 0.0)
	_update_guard(delta)
	_update_visual(delta)
	_replicate_state()
	if not is_multiplayer_authority():
		return
	if _has_item("charge_gun"):
		_update_charge(delta)
	_move(delta)
	move_and_slide()
	_post_move_2d()


# ═══════════════════════════════════════════════════════════════════════════════
# LAVA (chamado pelo gerente 2D quando entra na área de lava)
# ═══════════════════════════════════════════════════════════════════════════════

func on_lava_contact() -> void:
	if _bounce_timer > 0.0:
		return
	_bounce_timer = LAVA_BOUNCE_COOLDOWN
	velocity = _lava_knockback()
	if _life_timer > 0.0:
		return
	_life_timer = LAVA_LIFE_COOLDOWN

	# Game Feel: burst de lava + shake + som
	_spawn_burst_2d(global_position, Color(1.0, 0.5, 0.0, 0.9), 18, 0.4, 110.0)
	_shake_2d(0.4, 0.2)
	SfxBus.play("lava")

	var managers := get_tree().get_nodes_in_group("last_standing_manager")
	if managers.is_empty():
		return
	var m: Node = managers[0]
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		m.on_player_lava_touch(get_multiplayer_authority(), last_attacker_id)
	else:
		m.client_report_lava.rpc_id(1, get_multiplayer_authority(), last_attacker_id)


func _lava_knockback() -> Vector2:
	return Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if _has_item("teleport_gun") and event.is_action_pressed("teleport_gun"):
		_on_teleport_pressed()
	if _has_basic("punch") and event.is_action_pressed("punch"):
		_try_punch()
	if event.is_action_pressed("jump"):
		_on_jump_pressed()


# ═══════════════════════════════════════════════════════════════════════════════
# VIRTUAIS (implementadas nas subclasses)
# ═══════════════════════════════════════════════════════════════════════════════

func _move(_delta: float) -> void:
	pass


func _aim_direction() -> Vector2:
	return Vector2(facing, 0)


func _on_jump_pressed() -> void:
	pass


func _update_visual(_delta: float) -> void:
	if is_instance_valid(_visual):
		_visual.scale = _base_scale * _squash_scale


# ═══════════════════════════════════════════════════════════════════════════════
# AÇÕES BÁSICAS — PUNCH / GUARD
# ═══════════════════════════════════════════════════════════════════════════════

func _try_punch() -> void:
	if _punch_cd > 0.0 or guarding:
		return
	_punch_cd = PUNCH_COOLDOWN
	TelemetryStats.begin("punch_action")
	SfxBus.play("punch")
	_squash(0.92, 1.08, 0.08)
	# A "resposta" da ação é o PRIMEIRO feedback (som + squash), que acontece já
	# aqui — antes do windup. Medir depois do windup inflacionaria a métrica com
	# a janela de antecipação, não com a latência de resposta.
	TelemetryStats.mark("punch_action")
	await get_tree().create_timer(PUNCH_WINDUP).timeout
	if not is_inside_tree():
		return
	var dir := _aim_direction()
	_broadcast_punch_2d.rpc(global_position, dir, get_multiplayer_authority(), punch_force)
	SfxBus.play("punch_hit")
	_spawn_burst_2d(global_position + dir * punch_range * 0.8, Color(1.0, 0.85, 0.4, 0.9), 10, 0.25, 90.0)
	_shake_2d(0.2, 0.1)


@rpc("any_peer", "call_local", "reliable")
func _broadcast_punch_2d(pos: Vector2, dir: Vector2, attacker_id: int, force: float) -> void:
	# Segurança: o atacante deve ser o remetente (0 = chamada local via call_local)
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and attacker_id != sid:
		return
	for p: CharacterBody2D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		if p == self:
			continue
		var to := p.global_position - pos
		var dist := to.length()
		if dist > punch_range:
			continue
		if to.normalized().dot(dir.normalized()) < 0.3:
			continue
		var push := dir * force * (1.0 - dist / punch_range)
		if p.get("guarding"):
			push *= GUARD_KNOCKBACK_REDUCTION
			SfxBus.play("guard_block")
		p.velocity += push
		p.last_attacker_id = attacker_id
		if p.has_method("play_hurt_feedback_2d"):
			p.play_hurt_feedback_2d(push.normalized())


func _update_guard(_delta: float) -> void:
	if not is_multiplayer_authority():
		if is_instance_valid(_shield):
			_shield.visible = guarding
		return
	# Guard é uma ação básica; pode ser restrita pelo minigame (sempre documentado).
	guarding = _has_basic("guard") and Input.is_action_pressed("guard")
	if is_instance_valid(_shield):
		_shield.visible = guarding


# ═══════════════════════════════════════════════════════════════════════════════
# CHARGE GUN
# ═══════════════════════════════════════════════════════════════════════════════

func _update_charge(delta: float) -> void:
	if Input.is_action_pressed("shoot"):
		if not _is_charging and _charge_cd <= 0.0:
			_is_charging  = true
			_charge_power = 0.0
			_charge_timer = 0.0
			TelemetryStats.begin("charge_action")
		elif _is_charging:
			_charge_timer += delta
			_charge_power  = clampf(_charge_timer / CHARGE_MAX_TIME, 0.0, 1.0)
	elif _is_charging:
		_fire_charge()

	if is_instance_valid(_charge_indicator):
		_charge_indicator.visible = _is_charging
		if _is_charging:
			_charge_indicator.scale = Vector2.ONE * (0.8 + _charge_power * 1.6)
			# Resposta do charge: o indicador de carga aparece ao pressionar.
			TelemetryStats.mark("charge_action")


func _fire_charge() -> void:
	_is_charging = false
	_charge_cd   = CHARGE_COOLDOWN
	var dir := _aim_direction()
	var orb := CHARGE_ORB_SCENE.instantiate()
	orb.direction = dir
	orb.force     = lerpf(CHARGE_MIN_PUSH, CHARGE_MAX_PUSH, _charge_power)
	orb.exploded.connect(_on_charge_explosion)
	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position + dir * 1.4


func _on_charge_explosion(pos: Vector2, force: float) -> void:
	_broadcast_charge_2d.rpc(pos, get_multiplayer_authority(), force)


@rpc("any_peer", "call_local", "unreliable_ordered")
func _broadcast_charge_2d(pos: Vector2, attacker_id: int, force: float) -> void:
	# Segurança: o atacante deve ser o remetente (0 = chamada local via call_local)
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and attacker_id != sid:
		return
	var local_hit := false
	for p: CharacterBody2D in get_tree().get_nodes_in_group("player"):
		if not p.is_multiplayer_authority():
			continue
		var dist := p.global_position.distance_to(pos)
		if dist > CHARGE_RADIUS:
			continue
		var push := (p.global_position - pos).normalized()
		var falloff := 1.0 - dist / CHARGE_RADIUS
		var f := force * falloff
		if p.get("guarding"):
			f *= GUARD_KNOCKBACK_REDUCTION
			SfxBus.play("guard_block")
		p.velocity += push * f
		p.last_attacker_id = attacker_id
		if p == self:
			local_hit = true
		if p.has_method("play_hurt_feedback_2d"):
			p.play_hurt_feedback_2d(push)
	if local_hit:
		SfxBus.play("explosion")
		_hit_stop(0.05)
		_spawn_burst_2d(pos, Color(1.0, 0.55, 0.1, 0.9), 22, 0.4, 130.0)


# ═══════════════════════════════════════════════════════════════════════════════
# TELEPORT GUN
# ═══════════════════════════════════════════════════════════════════════════════

func _on_teleport_pressed() -> void:
	if _teleport_cd > 0.0:
		return
	if is_instance_valid(_teleport_orb) and _teleport_orb.is_active:
		var pos: Vector2 = _teleport_orb.teleport_owner()
		if pos != Vector2.ZERO:
			global_position = pos
			velocity        = Vector2.ZERO
			_teleport_cd    = TELEPORT_COOLDOWN
			# 2ª ação (teletransporte) — resposta própria, não confundir com o lançamento.
			TelemetryStats.begin("teleport_move")
			SfxBus.play("teleport")
			TelemetryStats.mark("teleport_move")
			_spawn_burst_2d(pos, Color(0.3, 0.8, 1.0, 0.9), 18, 0.35, 90.0)
			_shake_2d(0.3, 0.15)
		return
	var dir := _aim_direction()
	var orb := TELEPORT_ORB_SCENE.instantiate()
	orb.direction    = dir
	orb.owner_id     = get_multiplayer_authority()
	orb.owner_player = self
	get_tree().current_scene.add_child(orb)
	orb.global_position = global_position + dir * 1.4
	_teleport_orb = orb
	# Resposta do lançamento: o orbe aparece/som toca imediatamente.
	TelemetryStats.begin("teleport_throw")
	SfxBus.play("teleport")
	TelemetryStats.mark("teleport_throw")


func on_orb_consumed(_orb: Node2D) -> void:
	_teleport_orb = null


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FEEL
# ═══════════════════════════════════════════════════════════════════════════════

func _post_move_2d() -> void:
	var was_grounded := _was_grounded
	_was_grounded = is_on_floor()
	if is_on_floor() and not was_grounded:
		_play_land_feedback()


func _squash(sx: float, sy: float, recover := 0.16) -> void:
	_squash_scale = Vector2(sx, sy)
	var tween := create_tween()
	tween.tween_property(self, "_squash_scale", Vector2.ONE, recover) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_jump_feedback() -> void:
	_squash(0.90, 1.14, 0.18)


func _play_land_feedback() -> void:
	_squash(1.14, 0.82, 0.16)
	_spawn_burst_2d(global_position + Vector2(0, 0.55), Color(0.5, 0.42, 0.32, 0.5), 6, 0.35, 40.0)


func _play_dash_feedback() -> void:
	_squash(1.25, 0.86, 0.18)
	_spawn_burst_2d(global_position - Vector2(facing, 0) * 0.7, Color(1, 1, 1, 0.5), 8, 0.3, 60.0)


## Chamado por RPC quando este jogador é empurrado/atingido.
func play_hurt_feedback_2d(_dir: Vector2) -> void:
	_squash(1.16, 0.84, 0.18)
	flash_hurt_2d()
	_shake_2d(0.35, 0.18)
	_spawn_burst_2d(global_position, Color(1, 1, 1, 0.9), 10, 0.25, 90.0)
	SfxBus.play("hurt")


## Animação de troca (Teleport Gun): encolhe e "estica" de volta.
func play_swap_flash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_squash_scale", Vector2(0.4, 0.4), 0.08)
	tween.tween_property(self, "_squash_scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func flash_hurt_2d() -> void:
	if not is_instance_valid(_body):
		return
	var original := _body.self_modulate
	_body.self_modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	if is_instance_valid(_body):
		_body.self_modulate = original


func _hit_stop(duration := 0.05) -> void:
	# Contador evita race condition: hit-stops sobrepostos estendem em vez de
	# restaurar cedo demais. É por-cliente (cada peer tem seu Engine.time_scale).
	_hitstop_count += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	_hitstop_count -= 1
	if _hitstop_count <= 0:
		Engine.time_scale = 1.0


func _shake_2d(strength: float, duration: float) -> void:
	var cam := get_tree().get_first_node_in_group("arena_camera")
	if cam and cam.has_method("shake"):
		cam.shake(strength, duration)


func _spawn_burst_2d(pos: Vector2, color: Color, amount: int, life: float, vel: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.position = pos
	get_tree().current_scene.add_child(p)
	p.emitting = true


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL
# ═══════════════════════════════════════════════════════════════════════════════

func _build_visual() -> void:
	var id := get_multiplayer_authority()
	var data: Dictionary = NetworkManager.players.get(id, {})
	var color: Color = PALETTE[int(data.get("color_index", 0)) % PALETTE.size()]

	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	# Personagem em pixel art PICO-8 (Sprite2D). Base da capivara; o sprite real
	# pode ser trocado depois por um asset, mantendo `Pico8Capybara.make_texture()`.
	var sprite := Sprite2D.new()
	sprite.texture = PICO8_CAPYBARA.make_texture()
	sprite.name = "Pico8Sprite"
	# O sprite é 16x16 px. Escala para o personagem ficar bem visível na arena
	# (aprox. 40 px de altura). O deslocamento vertical alinha os "pés" à base
	# do colisor.
	sprite.scale = Vector2(2.4, 2.4)
	sprite.position = Vector2(0, -16)
	# Tinge pela cor do jogador (mantém a linguagem de cores sem mudar o sprite).
	sprite.self_modulate = color
	sprite.centered = true
	_visual.add_child(sprite)
	_body = sprite

	# O sprite PICO-8 já tem corpo/orelhas/olho. O escudo e o indicador de carga
	# continuam como visuais adicionais sobrepostos.

	# Escudo de guarda
	_shield = Polygon2D.new()
	_shield.polygon = _circle_polygon(1.0)
	_shield.scale = Vector2(0.85, 0.85)
	_shield.color = Color(0.25, 0.66, 0.96, 0.22)
	_shield.visible = false
	_visual.add_child(_shield)

	# Indicador de carga
	_charge_indicator = Polygon2D.new()
	_charge_indicator.polygon = _circle_polygon(0.16)
	_charge_indicator.color = Color(1.0, 0.6, 0.1)
	_charge_indicator.position = Vector2(0.62, -0.12)
	_charge_indicator.visible = false
	_visual.add_child(_charge_indicator)

	# Nome (rótulo custom desenhado via _draw; Label2D não existe neste build)
	_name_label = NAME_LABEL_SCRIPT.new()
	_name_label.position = Vector2(0, -1.9)
	_name_label.set_name_text(data.get("name", "Capivara"))
	_name_label.visible = not is_multiplayer_authority()
	add_child(_name_label)


func _circle_polygon(radius: float, segments := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
