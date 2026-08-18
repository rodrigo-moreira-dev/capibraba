# Plano de Arquitetura Final — Capibraba

**Versão 2.0 — 18 de agosto de 2026**
**Entradas:** `plano_arquitetura.agent.final.md` (v1.0) → `revisao_arquitetura.md` → `questionario_arquitetura.md` (respondido).
**Natureza:** documento de execução. Substitui a v1.0 como referência única de arquitetura de rede.

---

## 0. Decisões aprovadas (ADRs)

As respostas do questionário fecham as decisões que a v1.0 deixava em matrizes. Cada linha abaixo é um ADR de uma página em si (o critério de saída da Fase 0).

| ADR | Decisão | Resposta aprovada | Desvio da revisão? |
|---|---|---|---|
| ADR-01 | Escopo de modos | **2D apenas; modos 3D removidos** (`hellball_arena`, `lava_*`, `player.gd`/`player_extended.gd`) | ⚠️ sim — revisão sugeria "congelar"; aprovado "remover" |
| ADR-02 | Envelope de jogadores | **2–8, esticando 12**; AOI e delta-vs-baseline fora de escopo | não |
| ADR-03 | SKUs | **Steam-first + off-Steam via EOS** | não |
| ADR-04 | Modelo de netcode | **Núcleo PREDICTED + INTERPOLATED**; ROLLBACK como caminho opcional para duelos | não |
| ADR-05 | Perfil por minijogo | Usar a tabela-base (§3.2), validar por playtest | não |
| ADR-06 | Send rate / buffer | **60 Hz default** (≤8); **buffer de interpolação adaptativo 25–120 ms** por p99 de jitter | não |
| ADR-07 | Física dos personagens | **Cinemática própria em ponto fixo** (colisão AABB/círculo à mão) | não |
| ADR-08 | Contato melee | **Favor-the-attacker com validação de plausibilidade no host** | não |
| ADR-09 | Identidade | **`player_id` estável** (SteamID64 / EOS PUID / UUID) como chave primária; `peer_id` é detalhe de transporte | não |
| ADR-10 | Transporte | **Fachada `MultiplayerPeer`**: Steam SDR no SKU Steam, EOS off-Steam, ENet em LAN/dev | não |
| ADR-11 | Export headless | **Manter** como artefato de build (CI, bots, fuga futura), sem prometer hospedagem oficial | não |
| ADR-12 | Migração de host | **Migração de sessão** (aborta rodada, preserva placar); eleição por **qualidade de rede medida + capacidade pré-validada** | não |
| ADR-13 | Rodada abortada | **Votação entre os sobreviventes** (repetir / pular) | ⚠️ sim — revisão sugeria "repetir sempre" |
| ADR-14 | Combate | **Host-autoritativo primeiro** (Etapa A) + **delay de input no host** para nivelar vantagem | não |
| ADR-15 | Segurança | **Privacidade de IP obrigatória**; EAC **adiado** pós-lançamento competitivo | não |
| ADR-16 | Multi local | **Splitscreen por slot** (input por dispositivo) + **Remote Play Together e Steam Deck** como requisitos de primeira fase | não |
| ADR-17 | Rejoin / moderação | **Rejoin por `player_id`** + **moderação de sala** (kick/ban/senha/idle/região) | não |
| ADR-18 | Achievements/stats | **Sem restrição** (conceder sem exigir confirmação autoritativa) | ⚠️ sim — ver risco R-7 |
| ADR-19 | Engine | **Godot 4.7** | não |
| ADR-20 | Higiene de números | **Recalcular banda bottom-up** + seção "hipóteses a medir na Fase 1" | não |
| ADR-21 | Bug de colisão | **Corrigir** `CapsuleShape2D` do jogador de plataforma antes do netcode | não |
| ADR-22 | Roadmap | **5 fases** (§10), 12–18 semanas | não |

**Desvios e riscos aceitos:** ADR-01 (remoção 3D — encurta o caminho, mas elimina conteúdo legado), ADR-13 (votação — adiciona um fluxo de UI na tela de migração), ADR-18 (ver R-7: achievements por predição podem gerar conquista "fantasma").

---

## 1. Produto e escopo

**Produto:** coleção de minijogos 2D pixel art (plataforma + topdown), multijogador online, salas hospedadas por jogadores, alvo Steam (não exclusivo), foco em otimização de latência.

**Escopo fechado:**
- **2D apenas.** Os modos 3D (`hellball_arena.tscn`, `lava_flat/islands/shrinking.tscn`, `player.gd`, `player_extended.gd`) são **removidos do projeto** (ADR-01). Nenhum esforço de rede será gasto neles.
- **Envelope 2–8 jogadores, esticando 12** (ADR-02). Consequência: O(n²) de broadcast é irrelevante, delta compression contra baseline por cliente não é necessária, e 60 Hz é trivialmente pagável (§7).
- **SKUs:** Steam-first com Steam Networking Sockets + Steam Lobbies; off-Steam via EOS P2P/Lobbies (ADR-03).

---

## 2. Estado atual vs. alvo (gap)

A v1.0 descrevia um jogo greenfield; o codebase é **cliente-autoritativo**. O documento final parte deste gap, que é a restrição dominante do roadmap.

### 2.1 O que existe hoje (cliente-autoritativo)

| Camada | Situação atual | Evidência |
|---|---|---|
| Movimento | Autoridade do nó do jogador no próprio par; `MultiplayerSynchronizer` replica `position` **a partir** do cliente; física roda só no dono | `arena_manager_2d_base.gd:82`, `hellball_manager_2d.gd:79`, `last_standing_manager.gd:68`, `game_manager.gd:48`, `hellball_platform_player.tscn:9-24`, `hellball_player_2d_base.gd:82`, `arena_topdown_player_base.gd:67` |
| Combate | Cliente escolhe `pos`, `dir` e **`force`**; host só confere `attacker_id` | `hellball_player_2d_base.gd:174-179` (`_broadcast_punch_2d`), `:249` (`_broadcast_charge_2d`) |
| Regras de partida | Host é autoritativo (vidas, eliminação, rodadas, spawn de powerups, eventos de arena) | `last_standing_manager.gd`, `powerup_manager.gd`, `arena_event_manager.gd` |

**Conclusão:** o host autoritativo **já existe para meta-estado**; o que falta é mover **combate** e **movimento** para o host. A afirmação "server is authoritative for all game state" no `AGENTS.md` está errada e deve ser corrigida.

### 2.2 Inventário de arquivos afetados

- Controladores: `player.gd`, `player_extended.gd` (removidos com o 3D), `hellball_player.gd`, `hellball_player_2d_base.gd` + 2 subclasses, `arena_topdown_player_base.gd` + 2 subclasses.
- Gerentes: `game_manager.gd`, `last_standing_manager.gd`, `hellball_manager_2d.gd`, `arena_manager_2d_base.gd`, `powerup_manager.gd`, `arena_event_manager.gd`.
- Rede: `network_manager.gd` (instancia `ENetMultiplayerPeer` inline; `MAX_PEERS := 4`; `players[id]` por `peer_id`).
- Cenas: todos os `.tscn` de jogador com `MultiplayerSynchronizer`.
- 13 arquivos com `@rpc`.

### 2.3 Rota incremental (não big-bang)

A migração para host-autoritativo **não é uma Fase, é uma sequência de etapas** dentro das Fases 1–3, por risco decrescente:

- **Etapa A (barata, imediata):** mover **só o combate** para o host. Cliente envia `request_punch/charge(tick, aim)`; host resolve hitbox contra o histórico que tem, aplica knockback e transmite o resultado. Fecha o buraco do `force` arbitrário **sem tocar em `_move()`**. ≈90% do valor de anti-cheat por ~10% do custo.
- **Etapa B:** fachada `NetSync` + `player_id` estável (ADR-09) + tick de rede compartilhado, ainda sobre o movimento atual.
- **Etapa C:** mover **movimento** para host-autoritativo + CSP, **um minijogo por vez** — topdown primeiro (8 direções, sem gravidade, sem coyote/jump buffer), plataforma depois.

---

## 3. Núcleo de rede

### 3.1 Núcleo multi-modelo

Um único núcleo de netcode suporta três modelos (ADR-04), e cada minijogo declara qual usa:

```gdscript
# scripts/network/net_profile.gd
class_name NetProfile extends Resource

@export var model: Model                # PREDICTED | INTERPOLATED | ROLLBACK
@export var send_rate_hz: int           # 60 | 30 | 20
@export var input_delay_frames: int     # 0..3 (rollback / fairness)
@export var interp_buffer_ms: Vector2i  # min/max do buffer adaptativo (25..120)
@export var contact_resolution: Contact # HOST_AUTHORITATIVE | FAVOR_ATTACKER
@export var max_players: int
```

**Sobre o ROLLBACK:** não é limitado a 2 jogadores — é limitado por custo (determinismo, save/restore por frame, taxa de erro de previsão). Neste produto ele é **opcional e restrito ao duelo** (Espadas), onde a fidelidade frame-perfect justifica o custo; os demais minijogos usam PREDICTED/INTERPOLATED.

### 3.2 Perfil por minijogo (ADR-05, base a validar por playtest)

| Minijogo | Modelo | Send rate | Resolução de contato | Justificativa |
|---|---|---|---|---|
| Espadas (duelo curto) | CSP + rollback local do par em contato | 60 Hz | Favor-attacker com janela de perdão | Trocas frame-perfect; alcance curto amplifica erro de interp |
| Hellball plataforma | CSP + reconciliação | 60 Hz | Host-autoritativo | Cinemática de plataforma + knockback preciso |
| Hellball topdown / Ímãs | CSP + reconciliação | 60 Hz | Host-autoritativo | Movimento contínuo, sem gravidade |
| Last Standing / King of the Hill | CSP | 30 Hz | Host-autoritativo | Ritmo médio; posicional |
| Corrida de Obstáculos | CSP, sem lag comp | 30 Hz | Sem contato relevante | Sem interação direta |
| Roubo de Comida / Capivara Bomb | Interpolação + confirmação de evento | 20–30 Hz | Host-autoritativo | Coleta/timer; latência invisível |

### 3.3 Identidade estável (ADR-09)

`player_id` estável (SteamID64 no SKU Steam; EOS Product User ID off-Steam; UUID persistido em LAN) é a chave primária de **placar, autoridade, telemetria, rejoin, moderação e achievements**. `peer_id` é rebaixado a detalhe de transporte, resolvido por um mapa `player_id ↔ peer_id` reconstruído a cada (re)conexão. Pré-requisito de migração de host e de rejoin; refatoração barata agora, caríssima depois.

### 3.4 Transporte por fachada (ADR-10, ADR-11)

Toda a camada de jogo fala com uma interface própria, nunca com `ENetMultiplayerPeer` diretamente (hoje `network_manager.gd` instancia ENet inline):

| SKU | Transporte primário | Rendezvous/lobby | Identidade | Fallback |
|---|---|---|---|---|
| Steam | SteamNetworkingSockets (SDR) | Steam Lobbies + convites + `+connect_lobby` | SteamID64 | — |
| Off-Steam (itch/Epic/standalone) | EOS P2P (relay) | EOS Lobbies/Sessions | EOS PUID | ENet direto + IP:porta manual |
| LAN / dev | ENet direto | Descoberta local | UUID local | — |

- **Steam Datagram Relay (SDR)** resolve NAT, **esconde o IP residencial do host** (ADR-15) e frequentemente **reduz** o RTT ao entrar na rede da Valve no PoP mais próximo — a maior alavanca de latência para salas com pares em regiões diferentes.
- **Export headless** é mantido como artefato de build desde a Fase 1 (bots sintéticos em CI, teste de carga), sem prometer hospedagem oficial. "Salas hospedadas por jogadores" é o modo padrão, não uma proibição de arquitetura.

---

## 4. Modelos de netcode em detalhe

### 4.1 PREDICTED (CSP + reconciliação)

Padrão para a maioria dos minijogos. Cliente simula o próprio personagem localmente (0 ms de resposta), envia inputs indexados por tick, e o host devolve por snapshot o estado autoritativo + último input processado; o cliente rebobina e re-simula em caso de divergência. A lógica de simulação é **compartilhada byte a byte** entre host e convidado (mesmo binário).

### 4.2 INTERPOLATED

Para entidades remotas: buffer de snapshots indexado por timestamp do host, renderizado **~2× intervalo de envio atrás do presente**, com **buffer adaptativo 25–120 ms** dimensionado pelo p99 de jitter em janela deslizante (ADR-06) — não o `cl_interp 0.1` fixo da v1.0.

### 4.3 Física: cinemática própria em ponto fixo (ADR-07)

`CharacterBody2D` + `move_and_slide()` exige rebobinar o mundo de física inteiro na re-simulação, e rollback com física exige Rapier/build custom. Os personagens 2D passam a usar **cinemática própria em ponto fixo com colisão AABB/círculo à mão**: determinismo bit a bit, rollback barato, feel pixel-perfect e independência de versão de engine. As formas atuais já são cápsula/círculo simples; o movimento de plataforma cabe em poucas centenas de linhas.

### 4.4 Contato melee: favor-the-attacker com validação (ADR-08)

Para melee de alcance curto (punch, Espadas), o cliente reporta o acerto e o host **valida plausibilidade** contra um histórico curto (~32 ticks): o alvo estava, no passado, dentro de `alcance × tolerância` no tick reivindicado? Mais barato e mais previsível que rewind de geometria, e a mesma lógica de validação fecha o buraco do `force` (§2.1). **Regra explícita de arbitragem de trocas simultâneas** (ambos acertam / ninguém / menor tick vence) é decisão de design obrigatória — nunca implícita.

### 4.5 Técnicas de estado da arte adotadas

1. **Nivelamento de vantagem do host (ADR-14):** delay de input local do host ≈ mediana da latência de ida dos convidados (1–4 frames). O host perde alguns ms; a sala ganha simetria.
2. **Dilatação de tempo (net time dilation):** o host devolve correção de velocidade de simulação ±1–2% para convergir a profundidade do input buffer de cada cliente — buffers mínimos auto-regulados, sem stalls.
3. **Redundância de input:** cada pacote carrega os últimos 4–8 inputs (bit-packed); o host aplica o mais novo não visto e **repete o último input conhecido** quando o do tick T não chegou (marcado como especulativo).
4. **Cosmetic-first:** no frame do input, disparar animação, hitstop, partículas, som e screen shake localmente; só o **resultado** (dano/knockback/morte) espera o host. Corolário: flag global `is_resimulating` que **suprime VFX/SFX** na re-simulação, respeitado por `SfxBus` e spawners de partícula (hoje `SfxBus.play()` é chamado dentro da lógica de gameplay).
5. **Orçamento de erro com reset explícito:** correção amortizada exponencialmente (~100 ms), limite de erro acima do qual se faz snap seco, e **flag de correção dura** para teleporte, dash e knockback — sem ela, o Teleport Gun produz exatamente o artefato que a suavização deveria esconder. Suavizar em subpixel, quantizar só na renderização.
6. **Delay de input adaptativo no rollback:** se Espadas for para rollback, 1–3 frames de delay local ajustados à latência, trocando um pouco de responsividade por menos rollbacks visíveis.

---

## 5. Sessão e migração de host

### 5.1 Máquina de estados de sessão replicada

`LOBBY → LOADING → COUNTDOWN → PLAYING → RESULTS → LOBBY`, com o **host como autoridade da transição**. Hoje o fluxo é `change_scene_to_file()` local por par (`lobby.gd:63`).

- **Barreira de ready:** o host só emite `start_round` quando todos confirmaram `scene_loaded(round_id)`, com **timeout** e política para o par lento (esperar / iniciar sem ele / kickar).
- **Idempotência de `round_id`:** todo RPC de rodada carrega o `round_id`; pacotes atrasados de rodada anterior são descartados.
- **RNG determinístico por rodada:** seed distribuído pelo host no `start_round`; `powerup_manager` e `arena_event_manager` deixam de sortear + transmitir por RPC e passam a sortear localmente da mesma seed — eventos de arena ganham predição de graça.

### 5.2 Migração de sessão (ADR-12, ADR-13)

**Não se migra a simulação; migra-se a sala.** Rodadas de party game duram 60–180 s; o custo de transferir estado de mundo, continuidade de tick, rebase de predição e re-sincronização de relógio não se justifica.

**Fluxo na queda do host:**
1. Detectada a queda (`server_disconnected`), os sobreviventes caem numa tela "o anfitrião saiu — reorganizando sala".
2. O **novo host** é o candidato **pré-eleito e pré-validado** da lista ordenada (abaixo), que já vinha recebendo o estado de meta-sessão.
3. Sobreviventes reconectam pelo rendezvous (Steam lobby / EOS); **placar acumulado** (pequeno, replicado continuamente para todos) é restaurado.
4. A rodada abortada é resolvida por **votação entre os sobreviventes** — repetir ou pular (ADR-13).
5. O jogador que caiu pode reconectar via rejoin (ADR-17).

**Custo:** ~5–10 s de interrupção + uma rodada perdida. **Benefício:** elimina os quatro itens mais caros e frágeis da migração contínua. Migração de simulação contínua, se ainda desejada, é pós-lançamento.

### 5.3 Eleição por qualidade de rede medida (ADR-12)

Não é "menor `peer_id`". Durante a partida, o host (que já tem `ENetPacketPeer.get_statistic()` de todos) mede RTT/upload de cada par e mantém, **replicada para todos**, a lista ordenada de candidatos que **minimiza o RTT máximo da sala**, filtrada por:
- capacidade de hospedar **pré-validada** (o candidato passou por um teste de NAT/alcançabilidade durante a partida);
- upload medido suficiente para a sala (§7).

Isso resolve de uma vez determinismo da eleição, alcançabilidade e qualidade do resultado. A identidade estável (ADR-09) é o que permite eleger e pontuar sem depender de `peer_id`.

---

## 6. Segurança e anti-cheat

### 6.1 Combate host-autoritativo primeiro (ADR-14)

Ordem de execução (Etapa A da §2.3): o cliente deixa de enviar `pos`/`force` e passa a enviar `request_punch/charge(tick, aim)`; o host valida plausibilidade (tolerância 1,1–1,2×, whitelist para dash/teleporte) e aplica o resultado. Cliente modificado não consegue mais knockback arbitrário.

### 6.2 Camadas

1. **Validação contínua no host** (contra convidados) — cobre ~90% do valor em 2D indie.
2. **Privacidade de IP obrigatória** (ADR-15): nenhum convidado aprende o IP residencial do host — garantido por SDR (Steam) e EOS relay (off-Steam). ENet direto fica restrito a LAN.
3. **EAC e anti-cheat de kernel adiados** (ADR-15): só se houver incentivo econômico real pós-lançamento.
4. **Limitação aceita:** o host é confiável por construção (pode ler estado e forçar resultado). É o preço do listen server; a única saída real é o dedicado, fora de escopo.

### 6.3 Achievements/stats (ADR-18 — risco aceito)

Decisão aprovada: **sem restrição** (podem ser concedidos a partir de predição). **Risco R-7:** predição + achievement pode gerar conquista "fantasma" (concedida por estado que o host depois rejeita). Mitigação barata a considerar na Fase 4: conceder achievements de resultado (fim de rodada, vitória) — que já passam por confirmação — e deixar apenas os cosméticos sem restrição.

---

## 7. Banda

### 7.1 Recálculo bottom-up (ADR-20)

A v1.0 afirmava "2–5 GB/h para 10 jogadores a 60 Hz" — **22–55× acima do próprio orçamento**, herdado de blog de vendor de hosting 3D. O número honesto, bottom-up:

- Estado por jogador, quantizado: `position` 2×16 bits (1/16 px num mundo de 4096), `rotation` 8 bits, flags 8 bits = **6 bytes** (vs. ~40–45 B em Variant).
- Payload: 7 convidados × 6 B × 8 entidades × 60 Hz ≈ **20 kB/s**.
- Cabeçalhos IP/UDP/ENet (~40–75 B/pacote) **dominam o payload** — por isso a agregação de **um pacote por tick por cliente** é a mudança de maior retorno, não porque o payload seja grande.
- Total estimado: **~100–200 MB/h para 8 jogadores** (host upload na casa de ~200–400 kbps). **Hipótese a medir na Fase 1 com Wireshark**, não constante de engenharia.

### 7.2 Interest management

**Não aplicável**: arenas de tela única exigem visibilidade total. `set_visibility_for` fica reservado a **estado privado por jogador** (inventário, cooldowns próprios) — uso legítimo que a v1.0 não mencionava.

### 7.3 Escotilha de escape

Toda replicação fica atrás da interface `NetSync` desde o dia zero. Migrar entidades quentes para serialização manual quantizada é troca de implementação, não reescrita.

---

## 8. Correções de engenharia

- **Godot 4.7** (ADR-19): todas as afirmações de compatibilidade de addon (netfox, godot-rollback-netcode, SGPhysics2D, GodotSteam) devem ser revalidadas contra 4.7 antes de entrarem em qualquer ADR de dependência.
- **Bug de colisão** (ADR-21): `hellball_platform_player.tscn:5-7` declara `CapsuleShape2D` com `radius=0.4`, `height=1.5` (metros) num espaço em pixels com velocidades de 190–430 px/s. Corrigir contra `VISUAL_SCALE` antes de qualquer netcode nessa cena.
- **`AGENTS.md`:** corrigir "Server is authoritative for all game state" para refletir o alvo (host autoritativo para movimento/combate) e a situação atual (cliente-autoritativo).
- **`MAX_PEERS := 4`** → envelope 2–8 (ADR-02).

---

## 9. Operação e produto

| Item | Decisão | Fase |
|---|---|---|
| **Versionamento de protocolo** | `PROTOCOL_VERSION` no handshake, rejeição com mensagem clara, política de branch beta na Steam | Fase 1 |
| **Rejoin** | Assento reservado por `player_id`, janela de retenção, re-sync na entrada | Fase 2 |
| **Moderação de sala** | Kick, ban por `player_id`, senha, detecção de idle, filtro de região — o host é a moderação | Fase 4 |
| **Splitscreen por slot** | Input por dispositivo (`Input.is_action_*` global → por slot); requisito de Remote Play Together | Fase 0/1 |
| **Remote Play Together + Deck** | Gamepad em todas as ações, UI legível em stream comprimido, multi local; Deck = jitter alto → reforça buffer adaptativo | Fase 0/4 |
| **Achievements** | Sem restrição (ADR-18), risco R-7 | Fase 4 |
| **Telemetria de netcode** | Métricas da §12 da v1.0 + canal (para onde vão, consentimento, alerta) | Fase 4 |
| **Hash de estado por tick** | Checksum do mundo por tick comparado entre pares; divergência aciona log/dump | Fase 1 |
| **Replay determinístico** | Stream de input gravado (inputs + seed + versão de protocolo) — depuração, killcam, evidência | Fase 1 |

---

## 10. Roadmap

Substitui o §13.1 da v1.0. Reconhece o codebase existente, sequencia por risco decrescente e paraleliza o que não colide.

**Fase 0 — Decisões e fundações (1–2 semanas).**
ADRs aprovados (§0) + remoção dos modos 3D + spike de cinemática ponto fixo (determinismo e feel em protótipo isolado). *Saída:* ADRs assinados + `NetProfile` esboçado por minijogo.

**Fase 1 — Fundação de rede sobre o que existe (2–3 semanas).** Sem mudar autoridade de movimento.
Fachada `NetSync` + fachada de transporte; `player_id` estável como chave; `PROTOCOL_VERSION`; tick de rede + clock sync; máquina de estados de sessão com barreira de ready e `round_id` idempotente; seed de RNG por rodada; hash de estado por tick + gravação de stream de input; export headless + bot sintético em CI. *Saída:* trocar de minijogo 20× seguidas (com par lento e par que cai) sem estado inconsistente; baseline de banda medida no Wireshark.

**Fase 2 — Fechar o buraco de segurança (2–3 semanas).**
Combate host-autoritativo (Etapa A): `request_punch/charge` com validação e histórico curto; remoção de `force`/`pos` do payload; arbitragem de trocas simultâneas; cosmetic-first com `is_resimulating` em `SfxBus`/VFX; rejoin por `player_id`. *Saída:* teste adversarial (cliente modificado não aplica knockback) + trocas a 150 ms percebidas como justas em playtest cego.

**Fase 3 — Predição no movimento, um minijogo por vez (4–6 semanas).**
Host-autoritativo + CSP + reconciliação (topdown → plataforma); cinemática ponto fixo (ADR-07); interpolação adaptativa; 60 Hz; suavização com reset duro; delay de input no host; dilatação de tempo. QA na matriz {50,100,200,300 ms} × {0,1,5% perda} × {0,25 ms jitter}. *Saída:* 200 ms / 2% de perda sem snaps; SLO de banda medido.

**Fase 4 — Conectividade, sala e produção (3–4 semanas).**
Steam SDR + Lobbies + convites + `+connect_lobby`; EOS off-Steam; migração de sessão com eleição por qualidade pré-validada; moderação; telemetria; teste de carga com bots contra host real. *Saída:* playtest público; sala sobrevive à saída do host perdendo no máximo a rodada corrente; nenhum IP residencial exposto.

**Fase 5 — Opcional, orientada por dados.**
Rollback para Espadas (delay de input adaptativo) se o playtest exigir; EAC se houver incentivo; migração de simulação contínua só se a interrupção de rodada provar inaceitável.

**Prazo:** 12–18 semanas para Fases 0–4 (2D, 3D removido). Equipe e prazo-alvo: **a definir** (Q29/Q30 sem resposta).

---

## 11. Riscos

| # | Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|---|
| R-1 | Cinemática ponto fixo mal calibrada (feel) | Média | Alto | Spike na Fase 0; paridade de feel antes de migrar cada minijogo (Fase 3) |
| R-2 | Upload do host insuficiente | Alta | Alto | Medir na Fase 1; limitar convidados pela banda medida; 60 Hz com estado de 6 B |
| R-3 | Migração de sessão falhar | Média | Alto | Eleição pré-distribuída + meta-sessão replicado para todos; teste dedicado na Fase 4 |
| R-4 | Host mal-intencionado | Baixa | Médio | Aceito (limitação do listen server); moderação de sala reduz dano |
| R-5 | Falsos positivos de validação (jitter) | Média | Médio | Tolerância 1,1–1,2× + whitelist de mecânicas rápidas |
| R-6 | Regressão silenciosa de banda | Alta | Médio | Wireshark no pipeline (profiler do editor subestima) |
| R-7 | Achievement fantasma por predição (ADR-18) | Média | Baixo | Conceder achievements de resultado só em confirmação (§6.3) |
| R-8 | Compatibilidade de addons com Godot 4.7 | Média | Médio | Revalidar antes de ADR de dependência; preferir implementação própria quando possível |

---

## 12. O que se preserva da v1.0

- **Tese das camadas independentes** (predição / interpolação / lag comp / rollback), cada uma com dono, orçamento e métrica — espinha do capítulo de netcode.
- **Escotilha de escape** (`NetSync`), agora ampliada para cobrir também a fachada de transporte.
- **Send rate como botão triplo** (UX / banda / upload do host) — análise correta; só as constantes estavam erradas.
- **Disciplina de confiabilidade por canal** (estado `unreliable_ordered`, eventos `reliable`, canais separados).
- **Posição lógica em subpixel, quantização só na renderização**; desligar physics interpolation nativa em nós dirigidos pela rede.
- **Matriz de QA de rede** {latência} × {perda} × {jitter} e o kit por plataforma (clumsy/NLC/netem), acrescida de hash de desync e replay determinístico.
- **Honestidade sobre retrofit de rollback** (NRS ~8 man-years vs. Skullgirls ~2 semanas) — aplicada às decisões ADR-04, 07, 09 e 12, que são de dia zero pelo mesmo motivo.
