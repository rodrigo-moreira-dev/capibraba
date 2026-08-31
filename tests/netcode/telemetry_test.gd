extends SceneTree

## telemetry_test.gd - Testa o pipeline de medição de resposta (TelemetryStats).
## Exercita begin/mark/summary/meets_target e confirma que gera dados coerentes.
## Uso:  godot --headless --path <projeto> --script res://tests/netcode/telemetry_test.gd

func _initialize() -> void:
	# Autoloads nao sao instanciados em --script; instancia o script do autoload
	# para validar a LOGICA de begin/mark/summary/meets_target.
	var t: Node = load("res://scripts/audio/telemetry_stats.gd").new()
	root.add_child(t)

	# Sem ação pendente: mark() deve ser inofensivo.
	t.mark("nada")
	if t.summary().is_empty():
		print("TELEMETRY: OK (no-op safe)")
	else:
		print("TELEMETRY: FAIL (no-op gerou amostra)")
		quit(1)
		return

	# Simula 3 ações de punch com respostas ~50, ~61, ~120 ms.
	for ms in [50, 61, 120]:
		t.begin("punch_action")
		# adiciona um atraso artificial controlado
		await create_timer(float(ms) / 1000.0).timeout
		t.mark("punch_action")

	var s: Dictionary = t.summary()
	if not s.has("punch_action"):
		print("TELEMETRY: FAIL (punch_action nao medida)")
		quit(1)
		return

	var d: Dictionary = s.punch_action
	# Coerência: p95 >= avg (p95 é um quantil alto), contagem correta, avg > 0.
	# O timing exato do engine tem overhead de reserva, então validamos FAIXA em
	# vez de valores nominais. Logo, o objetivo é provar que o pipeline mede.
	var count_ok: bool = int(d.count) == 3
	var avg_ok: bool = float(d.avg_ms) > 0.0 and float(d.avg_ms) < 200.0
	var p95_ge_avg: bool = float(d.p95_ms) >= float(d.avg_ms)
	# Gate de meta: o p95 real é ~131ms (overhead do await no teste). Então:
	#   - meets_target(100) deve ser FALSE (p95 >= 100).
	#   - meets_target(150) deve ser TRUE (p95 < 150).
	# Isso prova que `meets_target` avalia o limiar corretamente.
	var gate_ok: bool = (t.meets_target(100.0) == false) and (t.meets_target(150.0) == true)
	if count_ok and avg_ok and p95_ge_avg and gate_ok:
		print("TELEMETRY: OK count=%d avg=%d p95=%d worst=%d meets100=%s meets150=%s" % [
			int(d.count), int(d.avg_ms), int(d.p95_ms), int(t.worst_p95_ms()),
			str(t.meets_target(100.0)), str(t.meets_target(150.0)),
		])
		quit(0)
	else:
		print("TELEMETRY: FAIL count=%d avg=%d p95=%d gate_ok=%s" % [int(d.count), int(d.avg_ms), int(d.p95_ms), str(gate_ok)])
		quit(1)
