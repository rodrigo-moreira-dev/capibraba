# Netcode — Plano de Testes (Capibraba)

> **Objetivo:** validar o netcode do Capibraba (Godot 4.7, ENet) contra latência,
> jitter e perda de pacote, garantindo que o estado crítico (vidas, mortes,
> knockback, troca de posição) permaneça **justo e consistente** entre peers.
> Meta de resposta de ação: **< 100 ms** de input → feedback.

---

## 1. Princípios que os testes devem provar

1. Todo estado crítico é **decidido no servidor** (host autoritativo), nunca por
   um cliente mandando "matei".
2. **Nunca há dessync de morte/parry/troca** que resulte em morte injusta.
3. Movimento/dash **client-predicted** + estado replicado (interpolação).
4. Eventos discretos (knockback, swap, spawn de projétil) via RPC validado com
   `get_remote_sender_id()`.
5. Projéteis/orbes podem ser locais, desde que o **efeito** seja RPC e o
   **estado de ataque** (swinging, polo, escudo) seja replicado.

> Regras e stack em `scripts/network/network_manager.gd` e nos playbooks
> (`netcode_playbook` do preset Capibraba — topics `architecture`,
> `prediction`, `interpolation`, `input`, `testing`).

---

## 2. Ambiente de teste (como reproduzir a rede ruim)

### 2.1 Emulador de rede in-game (recomendado — determinístico)
Um autoload `network_emulator.gd` que atrasa/perde pacotes **antes** de
entregá-los, para testar sem precisar de rede real:

```gdscript
# autoload: network_emulator.gd
extends Node
# Config por peer numa sessao de teste (nao commit como escape).
var rtt_ms := 0          # atraso artificial de ida e volta
var jitter_ms := 0
var loss_pct := 0.0      # 0..100

# Gancho: envelhece/despacha pacotes com atraso + perda simulada.
```

**Roteiro:**
1. Altere o RTT via `rtt_ms` (ex.: 0, 50, 150, 300 ms).
2. Aplique jitter (ex.: ±20 ms) para simular rede instável.
3. Aplique perda (ex.: 0%, 2%, 5%).
4. Repita a mesma sequência de inputs para obter comparação determinística.

### 2.2 Ferramenta externa (teste em build real)
- **Windows:** use `clumsy` (https://jagt.github.io/clumsy/) para aplicar lag
  em um build exportado, controlando latência/perda reais.

### 2.3 Topologia de teste
- 1 host + 3 clientes na mesma máquina (rápido, simulando o pior caso de
  latência do host? **não** — o host tem latência zero).
- Para medir o efeito da latência no **cliente**, emule o atraso apenas nos
  clientes, mantendo o host limpo.
- Teste também em **rede local** e **internet real** para pegar roteadores.

---

## 3. Matriz de cenários (tabela de execução)

| # | Cenário | Config (RTT / jitter / perda) | O que observar | Passa quando |
|---|---|---|---|---|
| 1 | **Morte por lava** | 0/0/0 | Host decide; todos veem o mesmo sobrevivente | Último de pé idêntico em todos os peers |
| 2 | Mesmo, com atraso | 150ms/±20/0 | Cliente lento não "morre" antes do host | Morte ocorre na mesma ordem lógica |
| 3 | Mesmo, com perda | 150ms/0/5% | Pacote de morte perdido não dessincroniza | Host re-transmite; clientes convergem |
| 4 | **Abate via last_attacker** | 150ms/±20/2% | O assassino correto recebe o credit | `last_attacker_id` consistente |
| 5 | **Knockback (Charge)** | 0/0/0 vs 150ms/±20/0 | Empurrão aplica no mesmo frame lógico | Mesmo deslocamento final em todos |
| 6 | Knockback com perda | 150ms/0/5% | Efeito por RPC não some | Todos veem o impulso; nenhum "empurrou e nada" |
| 7 | **Troca de posição (Teleport)** | 0/0/0 | `request_swap` → `_perform_swap.rpc` | Troca idêntica em todos; velocidades zeradas |
| 8 | Troca com atraso | 200ms/±30/0 | Cliente pede troca; servidor valida | Ninguém troca "sozinho"; estado converge |
| 9 | **Parry de projétil** | 0/0/0 vs 150ms/0/0 | Janela ativa no servidor | Parry/reflexão resolvido no host, nunca injusto |
| 10 | Parry com janela de input | 150ms/±20/2% | Input buffering (100–150ms) | Golpe "pressionado antes" ainda conta |
| 11 | **Polo/escudo replicado** | 150ms/±20/2% | Cor/estado visto por todos | Todos os peers veem o mesmo polo/escudo |
| 12 | **Convergência longo prazo** | 200ms/±30/5% | 60s de jogo caótico | Hash de estado (vidas/posições) igual no fim |
| 13 | **Reconexão / host migration** | — | Peer sai e volta | Estado não corrompe; jogadores restantes ok |

---

## 4. Cenário que mais importa: **Convergência de estado** (#12)

É o "teste de determinismo" que detecta dessync acumulado (float, RNG, ordem de
physics, delta time).

**Procedimento:**
1. Rode o host + N clientes headless na mesma máquina (ver 5.2).
2. Injete uma **sequência fixa de inputs** (gravada) em todos os peers.
3. Ao fim, compare um **hash do estado autoritativo** (vidas, posições,
   `last_attacker_id`, itens ativos).
4. Qualquer divergência = dessync → isolar a fonte:
   - Float não-determinístico → usar `is_equal_approx`/quantização.
   - RNG → semear por peer e usar um gerador determinístico.
   - Ordem de `_physics_process` → processar em ordem de peer_id.
   - `delta`/`Engine.time_scale` → nunca confiar em `delta` para lógica.

---

## 5. Automação (CI / headless)

### 5.1 Teste headless do host
```bash
godot --headless --script tests/netcode/simulation_test.gd
```

### 5.2 Simulação multi-peer
Execute 1 host + N clientes na mesma máquina (sem render), injete a sequência
de inputs fixa e compare o hash final. Se CI tem GPU limitada, use `--headless`.

### 5.3 Gate de CI
- Adicione um job que roda a simulação e **falha** se o hash divergir.
- Inclua ao menos o cenário #12 em cada merge.

---

## 6. Checklist de aceite (los critérios de qualidade)

- [ ] Toda morte/parry/troca é resolvida no **servidor** (nenhum cliente decide).
- [ ] `get_remote_sender_id()` validado em todo RPC de efeito novo.
- [ ] Estado de ataque (`swinging`), polo e escudo são **replicados** (todos veem).
- [ ] Morte nunca é injusta por dessync (parry sempre legível e honesto).
- [ ] **Input buffering** (100–150 ms) presente para parry/bordas.
- [ ] Ação → resposta < **100 ms** em ambos os modos (2D/3D).
- [ ] Nenhum tester "viu" um empurrão que não aconteceu para o outro (sem efeito
      fantasma).
- [ ] Simulação determinística (#12) passa em CI.

---

## 7. Referências

- `scripts/network/network_manager.gd` — ENet, MAX_PEERS, porta 7350.
- `scripts/game/hellball_manager.gd` / `hellball_manager_2d.gd` — autoridade de
  vidas/lava/troca/vitória.
- `scripts/player/teleport_orb*.gd` — projétil local + `request_swap` RPC.
- `docs/hellball.md` — arquitetura de troca (4 passos) e padrão de projéteis.
- `docs/gamefeel/` — feedback de impacto < 100 ms.
