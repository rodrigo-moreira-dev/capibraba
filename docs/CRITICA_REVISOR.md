# Crítica do Revisor — Relatório Técnico do Capibraba

> **Documento de origem:** [`docs/RELATORIO_TECNICO.md`](./RELATORIO_TECNICO.md)
> **Função:** Crítica independente ao trabalho da sessão, com respostas ao
> questionário, avaliação geral e recomendações.

---

## Avaliação Geral

O trabalho é **sólido e bem fundamentado**. A arquitetura está coerente, os
padrões de rede são consistentes, e o Game Feel foi tratado como cidadão de
primeira classe (o que é raro em protótipos). A documentação é excepcional
para um projeto neste estágio — a bíblia de Game Feel e a organização dos
agentes demonstram maturidade de design.

**Nota qualitativa:** 8/10. Os pontos perdidos estão em decisões de rede
que funcionam para party game mas não escalam, e algumas escolhas de
implementação corrigíveis (hit-stop global, ausência de áudio).

---

## Respostas ao Questionário

### 1. Modelo de autoridade — coerência e escala

**Coerência:** ✅ Excelente para o gênero. A separação "movimento = cliente,
estado = servidor" é o padrão de jogos competitivos (CS, Valorant, etc.)
adaptado para party game. O servidor arbitra apenas o que importa (vidas,
troca, vitória), evitando o custo de validar física frame a frame.

**Escala:** Em 8+ jogadores com host ruim, o calcanhar de Aquiles é o **host
ser também cliente**. Três problemas:
- O host tem vantagem de latência zero (seu input chega "antes" ao servidor).
- Se o host sai/trava, a partida morre (sem migração).
- O bandwidth do host escala com o número de peers (cada peer manda posição
  pro host, que replica).

**Recomendação:** para staging atual (≤4, LAN), está ótimo. Para produção:
implementar servidor dedicado opcional (modo `--headless`), ou ao menos
adicionar **migração de host** (eleger novo peer 1 quando o atual sai).

---

### 2. Troca de posições — latência e justiça

A troca é o **ponto mais frágil** do multijogador. O problema:

```
t=0ms:   Shooter vê Target em (10,0).  Target se vê em (10,0).
t=50ms:  Target se move para (12,0).   Shooter ainda vê (10,0) por latência.
t=55ms:  Orbe acerta Target na tela do Shooter → request_swap.
         Servidor autoriza. Shooter vai para (12,0)??? Não — vai para a
         posição que o Shooter VIA (10,0). Target vai para a posição do
         Shooter. Ambas as posições são "passadas" em um dos lados.
```

O resultado: o Target pode ser "puxado de volta" 2 unidades que ele já havia
andado (rubber-banding). Em 50 ms de latência é ~1 quadro de dessincronia —
aceitável. Em 200 ms é frustrante.

**Mitigações sugeridas (em ordem de custo/benefício):**
1. **Animação de troca** (0,15–0,3 s de interpolacão visual) — mascara o
   "salto" e o jogador perdoa a dessincronia porque *viu* a transição.
   ✅ Baixíssimo custo, alto ganho de percepção.
2. **Servidor interpola posições** — o servidor mantém um buffer circular das
   últimas N posições de cada jogador e, na troca, usa a posição interpolada
   no timestamp do hit (requer timestamps nos pacotes de posição).
   ⚠️ Médio custo.
3. **Janela de invencibilidade pós-swap** (0,2 s) — evita que o jogador
   teletransportado caia imediatamente na lava "sem culpa".
   ✅ Baixo custo.

---

### 3. RPCs `any_peer` — riscos de segurança

| Risco | Gravidade | Mitigação mínima |
|---|---|---|
| `attacker_id` forjado em `_broadcast_charge` | Média (só afeta crédito de abate) | Validar `attacker_id == sender_id` no RPC (hoje não valida — o remetente pode passar ID de outro jogador como `attacker_id`) |
| Spam de `request_swap` | Baixa (só afeta orbes que acertam) | Rate limit por peer no servidor (máx. 2 swaps/s) |
| `_broadcast_punch` com `attacker_id` falso | Média | Idem: validar `attacker_id == sender` |

> **Nota:** para um jogo entre amigos em LAN, o custo de implementar
> validação extra é discutível. Mas as validações sugeridas são triviais
> (1 linha em cada RPC: `if attacker_id != multiplayer.get_remote_sender_id(): return`).

**Recomendação imediata:** adicionar a validação de remetente em todos os
RPCs `any_peer` que recebem `attacker_id`.

---

### 4. Hit-stop `Engine.time_scale` — impacto por peer

**Problema mais grave do que parece à primeira vista.**

`Engine.time_scale` é **global por processo** — desacelera *tudo*: física,
timers, _process. Quando o Shooter atinge um rival próximo e ativa hit-stop
(50 ms), no cliente do Shooter:
- O Shooter congela (queremos).
- O rival **também congela** (indesejado — o rival está em outro peer, onde
  o tempo corre normal).
- O movimento de entrada do Shooter também congela (é a Engine inteira).

No cliente do **rival**, o tempo corre normal — ele NÃO sente o hit-stop. O
resultado é uma **assimetria de percepção**: o Shooter sente o peso do
impacto, o rival não. Pior: se dois jogadores se atingem mutuamente em
frames próximos, as chamadas a `Engine.time_scale` e `await` concorrem.

**Recomendação:** substituir hit-stop global por **hit-stop visual**:
- Em vez de `Engine.time_scale`, usar `get_tree().paused = true` (pausa só a
  cena, não a engine) por 50 ms com um `Timer` `process_always` para
  restaurar. Ou melhor:
- Congelar *apenas a câmera e a animação do afetado* com um tween de
  `time_scale` no próprio `AnimationPlayer` ou via `Engine.get_singleton("Time")`?
  Godot não tem time dilation por nó nativamente. Alternativa prática:
  manter o `Engine.time_scale` **somente se o jogador local for o afetado**
  (vítima, não atirador) — isso dá feedback de dano a quem recebeu, que é
  onde o hit-stop faz mais diferença psicológica.

---

### 5. Projéteis locais vs. replicados

**Custo/benefício de replicar o orbe:**

| Abordagem | Vantagem | Desvantagem |
|---|---|---|
| Local (atual) | Zero tráfego, zero latência de spawn | Rivais não veem o orbe; troca parece "mágica" |
| Replicado (spawner) | Rivais podem reagir (esquivar/guard) ao ver o orbe | ~1 nó por orbe ativo, tráfego de posição a cada frame |

**Veredito:** para o **orbe do Teleport Gun**, a visibilidade para os rivais
**melhora significativamente o gameplay** — poder ver o orbe vindo e
esquivar/guardar transforma o Teleport Gun de "mágica de troca" em
"ferramenta de zona". O custo de replicar 1 orbe por jogador (máx. 4) é
ínfimo. O padrão do `PowerupManager` (spawn com `net_id` + `request_despawn`)
pode ser adaptado.

Para o projétil do Charge Gun, a visibilidade é menos crítica — o efeito
explosivo já comunica o impacto. Manter local por enquanto.

**Recomendação:** transformar o orbe em nó replicado. Começar com o fluxo
simples: spawnar no servidor, replicar posição, despawn quando consumido.

---

### 6. Godot 4.7.1 sem `Label2D`

**Diagnóstico:** o build está em `workspace/radical/tools/` — nome de pasta
atípico ("radical"), sugerindo fork ou build customizado. Possíveis causas da
ausência de `Label2D`:
- Compilado sem o módulo 2D (pouco provável — `Polygon2D`, `Area2D` etc.
  funcionam).
- Build "headless" ou "server" que não inclui certas classes de UI (mais
  provável).
- Renomeação em fork.

**Recomendação imediata:** o `name_label_2d.gd` é um workaround funcional e
elegante. Para confirmar se outras classes 2D estão ausentes, rodar um script
que testa `CharacterBody2D`, `CollisionShape2D`, `Sprite2D`, `AnimatedSprite2D`,
`TileMap`, `ColorRect` — se alguma dessas falhar, há um problema sistêmico
no build e afeta decisões de arquitetura.

---

### 7. Unificação dos managers

**Sim, unificar.** A lógica de partida (vidas, lava, troca, sync, vitória) é
≈95% idêntica entre 3D, Plataforma e Topdown. O que muda:
- Tipo do jogador e da arena (Node3D vs Node2D).
- Conexão da lava (Area3D vs grupo "lava_area").

**Proposta de arquitetura unificada:**
```
HellballManagerBase (Node, classe abstrata)
├── HellballManager3D (Node3D players, Area3D lava)
└── HellballManager2D (Node2D players, grupo "lava_area")
```
A base conteria toda a lógica de vidas/troca/vitória, com métodos virtuais:
- `_get_players_node() -> Node`
- `_connect_lava()`
- `_perform_swap_positions(a, b)`

**Ganhos:** redução de ~200 linhas duplicadas, correções aplicadas uma só
vez, consistência entre modos.

---

### 8. MatchSettings por `call_local` e late join

**Problema confirmado:** se um peer entra DEPOIS do `_start_game.rpc()`, ele
**não recebe o preset** — fica com o padrão (`last_standing`/`classic`), não
com o que foi escolhido no lobby.

**Solução:** no `NetworkManager._sync_players` (que é broadcast em
`_register`), incluir o estado atual da partida. Opções:
1. O servidor, ao receber `_register`, envia de volta `_sync_match_settings`
   com o preset atual (se a partida já começou).
2. `MatchSettings` vira um nó sincronizado (synced via
   `MultiplayerSynchronizer` no Manager em vez de ser autoload).

**Recomendação:** (1) é mais simples e resolve imediatamente. Adicionar
`_sync_match_settings.rpc_id(new_peer_id, current_preset)` na callback
`_register`.

---

### 9. Game Feel — o que está enxuto demais

O sistema é bom. O que falta para um jogo de festa "polido":

1. **Recompensa de abate:** quando o jogador elimina alguém (kill confirm),
   não há fanfarra. Uma notificação central com o nome do eliminado, efeito
   de confete na cor do abatedor e um som de "ding" transformam a sensação.
2. **Momentos entre ações:** idle, respawn, espera no lobby — esses momentos
   estão "secos". Pequenos idle animations (respiração, piscada), música
   ambiente, e um efeito de respawn (descendo do céu com glow) dariam vida.
3. **Screen shake está só nos impactos grandes.** Shake sutil em todo dash,
   punch e aterrissagem (magnitude menor) aumentaria a percepção de peso sem
   cansar.
4. **Vibração de controle** (`Input.start_joypad_vibration`) — mencionada na
   doc mas não implementada. É um dos canais de feedback mais imersivos.

---

### 10. Priorização da dívida técnica

Ordem sugerida (impacto ÷ esforço):

| # | Item | Por quê |
|---|---|---|
| 1 | **Áudio** | Maior ganho de imersão com menor esforço; até placeholder procedural (`AudioStreamGenerator`) já transforma a sensação |
| 2 | **Validação de RPC** (`attacker_id == sender`) | Trivial (1 linha por RPC), fecha vetor de abuso |
| 3 | **Hit-stop visual (não global)** | Corrige assimetria e race condition; melhora o feel para todos |
| 4 | **Animação de troca (lerp)** | Mascara latência da troca com custo baixíssimo |
| 5 | **Mira de gamepad no Topdown** | Bloqueia jogabilidade para quem usa controle; right-stick → aim |
| 6 | **Orbe replicado** | Visibilidade para rivais → gameplay mais tático |
| 7 | **Late-join sync de preset** | Corrige bug para partidas com entrada tardia |
| 8 | **Unificação dos managers** | Reduz dívida de manutenção |
| 9 | **Itens futuros** | Expansão de conteúdo; depende dos anteriores para base sólida |

---

## Pontos fortes (além do óbvio)

- **Documentação → agentes → código:** a cadeia é completa — princípios
  viram specs, specs viram agentes, agentes guiam implementação. Raro.
- **Procedural 2D (sem assets):** os personagens e arenas são construídos
  exclusivamente com `Polygon2D` e `CPUParticles2D` — zero texturas. Isso
  elimina dependência de assets e acelera iteração.
- **Reuso engenhoso:** o grupo `"last_standing_manager"` para reporte de
  lava, o HUD CanvasLayer para 2D/3D, o gerente 2D configurável.
- **Validação headless:** o pipeline `--headless --editor --quit` garante
  que todo commit futuro passa por checagem de script (lição aprendida com
  os erros de parse).

---

## Pontos fracos (oportunidades de melhoria)

- **Assimetria de hit-stop** entre peers (crítico, seção 4).
- **Invisibilidade do orbe** para rivais reduz profundidade tática (seção 5).
- **`Engine.time_scale` global** pode causar race conditions (seção 4).
- **Falta de late-join sync** deixa peers novos com estado inconsistente.
- **Código duplicado entre managers** (≈200 linhas).
- **Sem servidor dedicado / migração de host** — partida morre se host sair.
- **Áudio inexistente** em runtime (maior lacuna de imersão).

---

## Bugs potenciais não listados no relatório

1. **Orbe não verifica se o owner ainda existe:** se o dono do orbe for
   eliminado enquanto o orbe está em voo, `owner_player` vira referência
   inválida → crash ou no-op na notificação. `is_instance_valid` mitiga, mas
   a referência pode ficar pendurada.
2. **Swap com jogador eliminado:** se `request_swap` chega ao servidor mas o
   target já foi eliminado (morto entre o hit local e o RPC), o servidor
   deve rejeitar. Hoje valida `NetworkManager.players.has(target_id)` — o
   jogador pode estar em `players` mas sem nó (eliminado mas não
   desconectado). Verificar `_lives.has(target_id)` seria mais preciso.
3. **`flash_hurt` concorrente:** dois danos em sequência rápida → o segundo
   `await` pode restaurar a cor antes do primeiro ter acabado, deixando o
   mesh "colorido" ou "apagado". Usar um contador de referência ou cancelar
   o tween anterior resolveria.
4. **Dash durante guarda:** o código não impede dash enquanto guarda — o
   jogador pode dashi-guardar (0,5× speed + dash speed), resultado ambíguo.

---

## Recomendações para o próximo ciclo

1. **Implementar áudio** (prioridade #1 — qualquer placeholder procedural já
   transforma a demo).
2. **Corrigir hit-stop** para ser visual por nó, não global.
3. **Replicar o orbe** do Teleport Gun.
4. **Adicionar animação de troca** (lerp de posição com tween).
5. **Validar `attacker_id == sender`** em todos os RPCs.
6. **Unificar managers** antes de adicionar mais modos.
7. **Adicionar migração de host** (ou ao menos servidor headless) ao
   planejamento de longo prazo.
