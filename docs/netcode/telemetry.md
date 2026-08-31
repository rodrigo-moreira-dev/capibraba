# Telemetria e Medição de Latência — Capibraba

> **Objetivo:** medir de fato, com dados, as métricas que validam o netcode e o
> game feel — em vez de confiar em intuição. Meta central: **ação → resposta
> < 100 ms** (tela + som + animação) nos dois modos (2D/3D).

---

## 1. O que medir (KPIs)

| Métrica | O que é | Meta |
|---|---|---|
| **RTT** | Tempo de ida e volta até o host | < 150 ms em LAN; anotar WAN |
| **Ação→Resposta** | Input do jogador → primeira resposta visível/sonora | **< 100 ms** |
| **Jitter** | Variação do RTT entre pacotes | < 20 ms |
| **Taxa de perda** | Pacotes perdidos | < 2% |
| **Tempo de convergência** | Tempo até 2 peers terem o mesmo estado após um evento | < 200 ms |
| **Spawn de projétil** | Input → projétil visível | < 100 ms |

---

## 2. Como instrumentar

### 2.1 Medir RTT e jitter (rede)
No `network_manager.gd` (ou autoload), registre o `RTT` que o ENet expõe e
acumule estatísticas:

```gdscript
# network_manager.gd — acompanhar RTT/jitter
var _rtt_history: Array[float] = []
var _max_history := 512

func _process(_delta: float) -> void:
	# ENet expoe "packet loss" e RTT; use o peer atual se multiplayer_peer != null
	# (APIs variam por versao — usar apenas como referencia de medicao)
	pass
```

> Ideia: guardar amostras de RTT em um buffer e computar média/p95 no HUD de
> diagnóstico (tecla para ligar/desligar).

### 2.2 Medir "Ação→Resposta" (game feel)
Instrumente o **loop de ação** (`input → antecipação → ação → impacto →
feedback`):

1. No `_input`/`_unhandled_input`, registre um timestamp no início da ação
   (ex.: ao pressionar punch/fire).
2. No `create_tween()` de feedback (squash, flash, partícula) ou no primeiro
   frame do som, marque o fim.
3. `delta_ms = fim - inicio`; registre no histórico.

```gdscript
# Exemplo conceitual (no script do jogador)
var _action_start := 0.0
func _on_fire_input() -> void:
	_action_start = Time.get_ticks_msec() / 1000.0

func _on_fire_feedback() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var response_ms := (now - _action_start) * 1000.0
	TelemetryStats.record(response_ms)
```

### 2.3 Medir convergência de estado
No servidor, após um evento crítico (morte/troca/parry), compare o hash de
estado entre peers (ver `docs/netcode/test-plan.md`, cenário #12). Registre o
tempo até a convergência.

---

## 3. Onde expor os dados

- **HUD de diagnóstico (in-game):** um painel opcional (tecla) mostrando RTT,
  jitter, perda, e a distribuição do tempo de resposta.
- **Saída de log estruturada:** para CI/automação, escreva linhas JSON
  (`{"metric":"rtt","ms":120}`) legíveis por script.

---

## 4. Como validar a meta < 100 ms

**Método:**
1. Rode o emulador de rede (`docs/netcode/test-plan.md`, §2.1) com RTT 0.
2. Meça o tempo de resposta de uma ação simples (punch) **média/p95**.
3. Aumente RTT para 50/150 ms e repita.
4. A meta está atendida se **p95 < 100 ms** com RTT 0, e se o tempo de resposta
   **não degrada linearmente** com o RTT (porque feedback é local, só o estado
   crítico espera o servidor).

> Regra prática: feedback local (squash, shake, partícula, som) deve **nunca**
> esperar o servidor. Só o resultado autoritativo (morte/knockback) pode
> chegar depois. Se a resposta do feedback depende de RTT, há um problema de
> design de rede.

---

## 5. Automação da coleta

1. Emita logs JSON de telemetria em um modo `--telemetry` (ou autoload que só
   liga em teste).
2. No CI, rode a simulação headless e parseie os logs.
3. Gate: falha se p95 de "ação→resposta" > 100 ms OU convergência > 200 ms.

---

## 6. Referências

- `docs/netcode/test-plan.md` — cenários de rede (RTT/jitter/perda) e convergência.
- `docs/design_invariants.md` — G5 (priorização), G1 (hit-stop), timing < 100 ms.
- `scripts/network/network_manager.gd` — ENet, peer, RTT.
- `docs/gamefeel/00_overview.md` — loop de ação e tempos.
