extends ArenaTopdownPlayerBase
class_name SwordTopdownPlayer

## SwordTopdownPlayer - Minigame Espadas (2D topdown)
## Item 1 - Espada 1-hit-kill (Clique Esq / X):
##   - Wind-up telegrafado (lâmina erguida) → janela ativa (golpe) → recovery.
##   - Acertar um rival = ELIMINAÇÃO (1 hit). Resolvido no SERVIDOR (nunca pelo
##     cliente). Espada x Espada com janelas ativas e de frente = PARRY (nenhum
##     morre; ambos recuam).
## Item 2 - Bota de Dash Garantido (Shift / L3):
##   - Dash sem cooldown, mais rápido e com i-frames (dashing) - substitui o
##     dash básico deste minigame.

## Espada
const SWORD_WINDUP   := 0.08
const SWORD_ACTIVE   := 0.12
const SWORD_RECOVERY := 0.30
const SWORD_RANGE    := 12.0
const SWORD_ARC_DEG  := 100.0
const SWORD_CD       := 0.5

## Bota de Dash (ajusta os parâmetros da base)
const BOOT_DASH_SPEED := 340.0
const BOOT_DASH_TIME  := 0.18
const BOOT_DASH_CD    := 0.15
const BOOT_IFRAMES    := 0.20

enum SwingState { IDLE, WINDUP, ACTIVE, RECOVERY }

var swinging := false          # replicado: janela ativa visível a todos
var swing_dir := Vector2.RIGHT # replicado: direção do golpe (visual/parry)
var _swing_state := SwingState.IDLE
var _swing_timer := 0.0
var _swing_cd    := 0.0

var _blade:     Polygon2D
var _blade_glow: Polygon2D


func _ready() -> void:
	# Bota de Dash: garante dash rápido, sem cooldown e com i-frames
	dash_speed       = BOOT_DASH_SPEED
	dash_time        = BOOT_DASH_TIME
	dash_cd_time     = BOOT_DASH_CD
	dash_iframe_time = BOOT_IFRAMES
	super._ready()
	_build_sword_visual()


# ═══════════════════════════════════════════════════════════════════════════════
# REPLICAÇÃO DE ESTADO (CRÍTICA 3): todos os peers veem a janela ativa do golpe
# ═══════════════════════════════════════════════════════════════════════════════

func _replicated_state() -> Dictionary:
	var st := super._replicated_state()
	st.swinging = swinging
	return st


func _apply_replicated_extras(_pol: int, swg: bool) -> void:
	swinging = swg


# ═══════════════════════════════════════════════════════════════════════════════
# ITEM - ESPADA
# ═══════════════════════════════════════════════════════════════════════════════

func _on_item_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot") and _swing_state == SwingState.IDLE and _swing_cd <= 0.0:
		_start_swing()


func _update_item(delta: float) -> void:
	_swing_cd = maxf(_swing_cd - delta, 0.0)
	match _swing_state:
		SwingState.IDLE:
			pass
		SwingState.WINDUP:
			_swing_timer -= delta
			if _swing_timer <= 0.0:
				_enter_active()
		SwingState.ACTIVE:
			_swing_timer -= delta
			if _swing_timer <= 0.0:
				_exit_active()
		SwingState.RECOVERY:
			_swing_timer -= delta
			if _swing_timer <= 0.0:
				_swing_state = SwingState.IDLE
				_swing_cd    = SWORD_CD


func _move(delta: float) -> void:
	# Trava o movimento durante o golpe (wind-up + janela ativa): legibilidade
	if _swing_state == SwingState.WINDUP or _swing_state == SwingState.ACTIVE:
		velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
		return
	super._move(delta)


func _start_swing() -> void:
	_swing_state = SwingState.WINDUP
	_swing_timer = SWORD_WINDUP
	swing_dir    = _aim_direction()
	SfxBus.play("punch")  # levantar a espada (slash vem na janela ativa)


func _enter_active() -> void:
	_swing_state = SwingState.ACTIVE
	_swing_timer = SWORD_ACTIVE
	swinging     = true
	SfxBus.play("punch_hit")
	_spawn_burst_2d(global_position + swing_dir * SWORD_RANGE * 0.6, Color(0.9, 0.95, 1.0, 0.8), 8, 0.2, 80.0)
	# Avisa o servidor para resolver golpe/parry
	var mgr := get_tree().get_first_node_in_group("sword_manager_2d")
	if mgr == null or not mgr.has_method("swing_start"):
		return
	if multiplayer.has_multiplayer_peer():
		mgr.swing_start.rpc_id(1, get_multiplayer_authority(), swing_dir)
	else:
		mgr.swing_start(get_multiplayer_authority(), swing_dir)


func _exit_active() -> void:
	_swing_state = SwingState.RECOVERY
	_swing_timer = SWORD_RECOVERY
	swinging     = false


# ═══════════════════════════════════════════════════════════════════════════════
# GAME FEEL (chamados pelo gerente via RPC)
# ═══════════════════════════════════════════════════════════════════════════════

func play_parry_flash() -> void:
	_squash(1.30, 0.70, 0.18)
	_hit_stop(0.08)
	_shake_2d(0.5, 0.2)


func play_death_flash() -> void:
	_squash(1.45, 0.55, 0.2)
	_spawn_burst_2d(global_position, Color(1.0, 0.95, 0.9, 0.9), 18, 0.4, 130.0)


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL - LÂMINA
# ═══════════════════════════════════════════════════════════════════════════════

func _build_sword_visual() -> void:
	_blade = Polygon2D.new()
	_blade.polygon = PackedVector2Array([
		Vector2(0.0, -0.09), Vector2(4.8, -0.09),
		Vector2(4.8, 0.09), Vector2(0.0, 0.09),
	])
	_blade.color = Color(0.85, 0.92, 1.0)
	_blade.visible = false
	_visual.add_child(_blade)

	_blade_glow = Polygon2D.new()
	_blade_glow.polygon = PackedVector2Array([
		Vector2(-0.10, -0.18), Vector2(5.0, -0.18),
		Vector2(5.0, 0.18), Vector2(-0.10, 0.18),
	])
	_blade_glow.color = Color(0.60, 0.90, 1.0, 0.25)
	_blade_glow.visible = false
	_visual.add_child(_blade_glow)


func _update_visual(delta: float) -> void:
	super._update_visual(delta)
	if not is_instance_valid(_blade):
		return
	# A lâmina aponta para a direção do golpe (não importa se o corpo girou)
	_blade.rotation     = swing_dir.angle() - rotation
	_blade_glow.rotation = _blade.rotation
	if not is_multiplayer_authority():
		# Peers: mostram a lâmina enquanto a janela estiver ativa (swinging)
		_blade.visible     = swinging
		_blade_glow.visible = swinging
		_blade.scale       = Vector2.ONE
		_blade_glow.scale  = Vector2.ONE
		return
	match _swing_state:
		SwingState.WINDUP:
			_blade.visible     = true
			_blade_glow.visible = true
			var p := lerpf(0.3, 1.0, 1.0 - _swing_timer / maxf(SWORD_WINDUP, 0.001))
			_blade.scale       = Vector2.ONE * p
			_blade_glow.scale  = Vector2.ONE * p
		SwingState.ACTIVE:
			_blade.visible     = true
			_blade_glow.visible = true
			_blade.scale       = Vector2.ONE
			_blade_glow.scale  = Vector2.ONE
		_:
			_blade.visible     = false
			_blade_glow.visible = false
