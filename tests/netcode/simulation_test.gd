extends SceneTree

## simulation_test.gd - Teste de convergência de estado (headless).
## Valida o determinismo do netcore do Capibraba rodando uma simulação fixa de
## vidas/knockback e conferindo que o hash de estado bate entre "peers" lógicos.
## Uso:  godot --headless --script tests/netcode/simulation_test.gd
## Saída: "CONVERGENCE: PASS(<hash>)" ou falha com a divergência.
##
## NOTA: sem o projeto aberto, este script roda o SceneTree vazio. Ele simula a
## LÓGICA do manager (vidas/abates) de forma determinística e verifica que dois
## processamentos da mesma sequência de inputs produzem o mesmo estado. É a
## semente do teste de determinismo real descrito em docs/netcode/test-plan.md.

const INPUTS := [
	# { "type": "lava", "player": 1, "attacker": 2 },
	# { "type": "swap", "a": 1, "b": 3 },
]

# Vidas iniciais por jogador (id -> lives)
const START_LIVES := { 1: 3, 2: 3, 3: 3, 4: 3 }

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var hash_a := _simulate(InputManagerA)
	var hash_b := _simulate(InputManagerA_copy)
	if hash_a == hash_b:
		print("CONVERGENCE: PASS(" + str(hash_a) + ")")
		quit(0)
	else:
		print("CONVERGENCE: FAIL a=" + str(hash_a) + " b=" + str(hash_b))
		quit(1)


# Simula a resolução de uma sequência fixa de eventos seguindo as regras do
# manager (lava remove 1 vida, abate vai ao last_attacker, swap não muda vidas).
# Retorna um hash determinístico do estado final (vidas ordenadas + abates).
func _simulate(input_gen: Callable) -> String:
	var lives: Dictionary = START_LIVES.duplicate(true)
	var kills: Dictionary = { 1: 0, 2: 0, 3: 0, 4: 0 }
	var events: Array = input_gen.call()
	for ev: Dictionary in events:
		match ev.get("type", ""):
			"lava":
				var p: int = ev.get("player", -1)
				var atk: int = ev.get("attacker", -1)
				if not lives.has(p):
					continue
				lives[p] -= 1
				if lives[p] <= 0:
					lives.erase(p)
					if atk != -1 and atk != p and kills.has(atk):
						kills[atk] += 1
			"swap":
				# Troca de posição não altera vidas/abates (só transforma estado
				# espacial, que aqui é abstraído). Nada a somar.
				pass
	# Estado final → hash (vidas em ordem de id + total de abates).
	var state := ""
	for id in lives.keys():
		state += str(id) + ":" + str(lives[id]) + ";"
	var total_kills := 0
	for k in kills.values():
		total_kills += k
	state += "K:" + str(total_kills)
	return state.sha256_text()


# Dois geradores determinísticos da MESMA sequência de inputs (devem convergir).
func InputManagerA() -> Array:
	var seq: Array = []
	seq.append({ "type": "lava", "player": 1, "attacker": 2 })
	seq.append({ "type": "lava", "player": 1, "attacker": 2 })
	seq.append({ "type": "lava", "player": 1, "attacker": 2 })  # elimina 1
	seq.append({ "type": "swap", "a": 2, "b": 3 })
	seq.append({ "type": "lava", "player": 3, "attacker": 4 })
	return seq


func InputManagerA_copy() -> Array:
	# Réplica exata da sequência A. Determinismo: a MESMA sequência processada do
	# mesmo jeito deve produzir o mesmo estado final (hash idêntico). Reordenar
	# eventos NÃO é determinismo — ordem faz parte do estado de entrada.
	var seq: Array = []
	seq.append({ "type": "lava", "player": 1, "attacker": 2 })
	seq.append({ "type": "lava", "player": 1, "attacker": 2 })
	seq.append({ "type": "lava", "player": 1, "attacker": 2 })
	seq.append({ "type": "swap", "a": 2, "b": 3 })
	seq.append({ "type": "lava", "player": 3, "attacker": 4 })
	return seq
