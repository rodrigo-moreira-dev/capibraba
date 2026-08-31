extends Node

## TelemetryStats - Medição de latência de resposta (meta: ação → resposta < 100 ms).
## Autoload global. Mede o intervalo entre o INPUT do jogador e o primeiro
## FEEDBACK (som/visual) de uma ação do Hellball.
##
## Uso:
##   - Antes de disparar a ação, chame `begin(action_id)`.
##   - No primeiro feedback (SfxBus.play / tween de feedback), chame `mark(action_id)`.
##   - A diferença é a resposta de ação em ms.
##
## Mantém um buffer por ação (média e p95) exposto via `summary()`. Desligado
## por padrão? Não: é barato (só mede quando `begin` foi chamado) e fornece o
## dado que `docs/netcode/telemetry.md` exige para validar a meta < 100 ms.

const MAX_SAMPLES := 256

var _samples: Dictionary = {}   # action_id -> Array[float] (ms)
var _pending:  Dictionary = {}  # action_id -> tempo de inicio (ms)
var diagnostics_enabled := false  # liga o HUD de diagnostico (tecla F3)


func _unhandled_input(event: InputEvent) -> void:
	if not diagnostics_enabled:
		return
	if event.is_action_pressed("dash") and event.is_echo() == false:
		pass


## Marca o início de uma ação de jogador (chamado no input).
func begin(action_id: String) -> void:
	_pending[action_id] = Time.get_ticks_msec()


## Marca o primeiro feedback da ação. Se houve `begin`, registra a diferença.
func mark(action_id: String) -> void:
	if not _pending.has(action_id):
		return
	var start_ms: int = _pending[action_id]
	_pending.erase(action_id)
	var elapsed_ms := float(Time.get_ticks_msec() - start_ms)
	if not _samples.has(action_id):
		_samples[action_id] = []
	var arr: Array = _samples[action_id]
	arr.append(elapsed_ms)
	if arr.size() > MAX_SAMPLES:
		arr.pop_front()


## Devolve {action, count, avg_ms, p95_ms} para cada ação medida.
func summary() -> Dictionary:
	var result := {}
	for action: String in _samples:
		var arr: Array = _samples[action]
		if arr.is_empty():
			continue
		var sorted := arr.duplicate()
		sorted.sort()
		var total := 0.0
		for v in sorted:
			total += float(v)
		var count := sorted.size()
		var idx := int(ceil(count * 0.95)) - 1
		idx = clampi(idx, 0, count - 1)
		result[action] = {
			"count": count,
			"avg_ms": total / float(count),
			"p95_ms": float(sorted[idx]),
		}
	return result


## Metrica agregada: a pior resposta p95 entre as acoes. Para o gate < 100 ms.
func worst_p95_ms() -> float:
	var worst := 0.0
	for action in _samples:
		var arr: Array = _samples[action]
		if arr.is_empty():
			continue
		var sorted := arr.duplicate()
		sorted.sort()
		var count := sorted.size()
		var idx := clampi(int(ceil(count * 0.95)) - 1, 0, count - 1)
		var v := float(sorted[idx])
		if v > worst:
			worst = v
	return worst


func reset() -> void:
	_samples.clear()
	_pending.clear()


func meets_target(target_ms := 100.0) -> bool:
	## True se o pior p95 das acoes medidas esta abaixo do alvo (default 100 ms).
	if _samples.is_empty():
		return false
	return worst_p95_ms() < target_ms
