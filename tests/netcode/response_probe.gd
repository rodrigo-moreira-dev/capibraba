extends Node

## response_probe - Mede a latência REAL do caminho input → primeiro feedback
## do Hellball 2D, rodando como CENA (autoloads reais do projeto carregam).
## Instancia um jogador topdown (autoridade), dispara as ações pelo caminho
## real de código (_try_punch / _on_teleport_pressed) e mede via TelemetryStats.
## Como begin() e mark() são síncronos (sem await entre input e primeira
## resposta), o valor medido é o custo do caminho de código + 1 frame.
##
## Meta: resposta < 100 ms. Rodar com:
##   godot --headless --path <projeto> --scene res://tests/netcode/response_probe.tscn

const TOPDOWN_SCENE := preload("res://scenes/player/hellball_topdown_player.tscn")


func _ready() -> void:
	NetworkManager.players = { 1: { "name": "Testador", "color_index": 0 } }

	var player := TOPDOWN_SCENE.instantiate()
	player.name = "1"
	player.set_multiplayer_authority(1)
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	if not player.is_multiplayer_authority():
		print("RESPONSE: FAIL (player nao e autoridade)")
		get_tree().quit(1)
		return

	# Punch: caminho real (input → som + squash imediatos). Não podemos simular o
	# input de teclado em headless, então chamamos o handler, que é a mesma coisa.
	player._try_punch()
	await get_tree().process_frame

	# Teleport (lançamento): caminho real. `_on_teleport_pressed` dispara o orbe
	# e mede "teleport_throw" sincronamente.
	player._on_teleport_pressed()
	await get_tree().process_frame

	var s: Dictionary = TelemetryStats.summary()
	print("RESPONSE summary=" + str(s))
	var worst := 0.0
	var missing := ""
	for action in ["punch_action", "teleport_throw"]:
		if s.has(action):
			worst = maxf(worst, float(s[action].p95_ms))
		else:
			missing += action + " "
	print("RESPONSE: worst p95 (punch/teleport) = %.1f ms (meta <100ms)  missing=%s" % [worst, missing])
	if worst < 100.0 and missing.is_empty():
		print("RESPONSE: OK (<100ms para punch e teleporte)")
		get_tree().quit(0)
	else:
		print("RESPONSE: FAIL (worst=%.1f, missing=%s)" % [worst, missing])
		get_tree().quit(1)
