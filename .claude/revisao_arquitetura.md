# Revisão do Plano de Arquitetura — Capibraba

**Documento revisado:** `.claude/plano_arquitetura.agent.final.md` (v1.0, 397 linhas)
**Data:** 18 de agosto de 2026

**Objetivo do produto (conforme briefing):** coleção de minijogos 2D pixel art (plataforma + topdown), multijogador online, salas hospedadas por jogadores, alvo Steam (mas não exclusivo), estado da arte em otimização de latência.

---

## 0. Veredito executivo

O plano é **forte como survey e fraco como plano**. Ele domina o cânone de netcode (Bernier/Valve, Gambetta, Fiedler, GGPO), organiza bem as camadas de compensação de latência e acerta em cheio três teses transversais (latência em camadas independentes; a fronteira HLAPI↔replicação manual como decisão crítica; send rate como botão triplo). Aproveite tudo isso.

O que impede de executá-lo como está:

| # | Bloqueador | Gravidade |
|---|---|---|
| 1 | Escrito como **greenfield**; o codebase existente é **cliente-autoritativo** — inclusive o combate, com `force` e `position` vindos do cliente. O plano não tem capítulo de gap nem rota de refatoração. | Crítico |
| 2 | Decide netcode para **um** jogo; o produto é uma **coleção de minijogos** com requisitos de fidelidade radicalmente diferentes. Falta o conceito de *perfil de netcode por minijogo sobre um núcleo comum*. | Crítico |
| 3 | A **migração de host** proposta não funciona sobre ENet como está descrita (sem canal pós-morte, sem endereços, sem alcançabilidade pré-validada, identidade atrelada a `peer_id`). | Crítico |
| 4 | **Steam é o alvo declarado e está subutilizada**: Steam Datagram Relay, privacidade de IP, lobby/convites, Remote Play Together e Deck aparecem de raspão ou não aparecem. Off-Steam, EOS (grátis, sem infra) não é mencionado como camada de conectividade. | Alto |
| 5 | **Números internamente inconsistentes** (banda por hora ~22–55× fora do próprio orçamento) e constantes de engenharia ancoradas em blogs de SEO/vendor. | Alto |
| 6 | O pedido explícito — **estado da arte** — para em ~2015. Faltam ~10 técnicas que são prática corrente 2024–2026. | Alto |
| 7 | Gasta capítulos em escala irrelevante (AOI, 17–64, MMO) e **omite** o que quebra coleções de minijogos na prática: barreira de ready entre cenas, versionamento de protocolo, rejoin, anti-grief, RNG semeado, detecção de desync. | Médio |

Resumo: **bom como referência técnica, insuficiente como plano de execução para *este* projeto.**

---

## 1. Bloqueador nº1 — o plano descreve um jogo que não é este

O plano fixa como referência "clientes enviam apenas *inputs*; o host executa a simulação completa e devolve *estado*" e conclui (cap. 11.1) que "speed hack e teleport pressupõem que o cliente envia posição — neste modelo, não há campo de pacote para adulterar".

O código faz exatamente o contrário.

**1.1 Movimento é cliente-autoritativo.** Cada gerente atribui a autoridade do nó do jogador ao próprio par:

- [arena_manager_2d_base.gd:82](scripts/game/arena_manager_2d_base.gd#L82), [hellball_manager_2d.gd:79](scripts/game/hellball_manager_2d.gd#L79), [last_standing_manager.gd:68](scripts/game/last_standing_manager.gd#L68), [game_manager.gd:48](scripts/game/game_manager.gd#L48) — todos `player.set_multiplayer_authority(id)`.

E o `MultiplayerSynchronizer` replica `position` **a partir** dessa autoridade ([hellball_platform_player.tscn:9-24](scenes/player/hellball_platform_player.tscn#L9-L24) declara `position`, `rotation`, `guarding`, `facing` como propriedades sincronizadas). O loop de física roda só no dono ([hellball_player_2d_base.gd:82](scripts/player/hellball_player_2d_base.gd#L82) e [arena_topdown_player_base.gd:67](scripts/player/arena_topdown_player_base.gd#L67): `if not is_multiplayer_authority(): return`), lendo `Input` local. **Posição é declaração, não resultado.**

**1.2 Combate é cliente-autoritativo e o cliente escolhe o dano.** [hellball_player_2d_base.gd:174-179](scripts/player/hellball_player_2d_base.gd#L174-L179):

```gdscript
@rpc("any_peer", "call_local", "reliable")
func _broadcast_punch_2d(pos: Vector2, dir: Vector2, attacker_id: int, force: float) -> void:
	var sid := multiplayer.get_remote_sender_id()
	if sid != 0 and attacker_id != sid:
		return
```

A validação confere apenas *quem diz ser o atacante*. `pos`, `dir` e **`force`** são aceitos como vindos. Idem `_broadcast_charge_2d` ([:249](scripts/player/hellball_player_2d_base.gd#L249)). Um cliente modificado hoje pode lançar qualquer jogador, de qualquer distância, com qualquer força — não é hipótese de anti-cheat futura, é a superfície atual. O host não arbitra combate; ele só *ouve*.

**1.3 `AGENTS.md` está factualmente errado** ao afirmar "Server is authoritative for all game state". O servidor é autoritativo para *regras de partida* (vidas, eliminação, rodadas, spawn de powerups, eventos de arena) — não para movimento nem para golpes. `docs/CRITICA_REVISOR.md` é honesto sobre isso ("a separação movimento = cliente, estado = servidor"); o plano de arquitetura não.

### Consequência para o plano

Migrar de cliente-autoritativo para host-autoritativo com predição **reescreve toda a camada de personagem**: 6 controladores (`player.gd`, `player_extended.gd`, `hellball_player.gd`, `hellball_player_2d_base.gd` + 2 subclasses, `arena_topdown_player_base.gd` + 2 subclasses), 4 gerentes, 13 arquivos com `@rpc` e todos os `.tscn` de jogador. A "Fase 1 — vertical slice HLAPI" do roadmap descreve construir algo que **já existe**; a Fase 2 carrega o trabalho real, e ela não é "3–6 semanas" — é a reescrita do núcleo de gameplay.

### O que o plano precisa ganhar

1. **Capítulo "Estado atual vs. alvo"** com a tabela de gap acima e inventário de arquivos afetados.
2. **Rota incremental, não big-bang:**
   - **Etapa A (barata, imediata, sem mexer em autoridade):** manter movimento cliente-autoritativo e mover **só o combate** para o host — o cliente envia `request_punch(tick, aim)`, o host resolve hitbox contra o estado que ele tem, aplica knockback e transmite o resultado. Fecha o buraco do `force` arbitrário e já introduz o padrão input-up/estado-down num sistema isolado, sem tocar em `_move()`. Cerca de 90% do valor de anti-cheat por ~10% do custo.
   - **Etapa B:** introduzir a fachada `NetSync` + identidade estável (§3.4) + tick de rede compartilhado, ainda sobre o movimento atual.
   - **Etapa C:** migrar movimento para host-autoritativo + CSP **um minijogo por vez**, começando pelo topdown (8 direções, sem gravidade, sem coyote/jump buffer) e só depois o de plataforma.
3. **Decisão de escopo explícita sobre os modos 3D.** O briefing diz "minijogos 2D em pixel art". Existem hoje `hellball_arena.tscn` (3D, Jolt), `lava_flat/islands/shrinking.tscn` (3D) e `player.gd`/`player_extended.gd` (`CharacterBody3D`). Se 2D é o alvo, o plano deve declarar os modos 3D como legado congelado ou removido — carregá-los pelo refactor de rede é dobrar o custo de todas as etapas acima. Isso não está no documento e é a maior alavanca de prazo disponível.

---

## 2. Bloqueador nº2 — o produto é uma coleção de minijogos; o plano decide como se fosse um jogo

O cap. 4 entrega uma matriz e a Fase 0 manda "escolher pela matriz: modelo A/B/C". Para este produto, essa pergunta não tem uma resposta — tem uma por minijogo. Os modos existentes e planejados ([lobby.gd:20-31](scripts/ui/lobby.gd#L20-L31)) são: Last Capivara Standing, Hellball (3D/plataforma/topdown), Ímãs, Espadas, Capivara Bomb, King of the Hill, Corrida de Obstáculos, Roubo de Comida.

Esses modos não têm o mesmo requisito de fidelidade nem de perto. Espadas é duelo de alcance curto onde 100 ms decidem a troca; Roubo de Comida é coleta posicional onde 150 ms são invisíveis. Aplicar o mesmo netcode aos dois é pagar rollback onde não precisa e entregar interpolação onde não dá.

**A arquitetura que o plano deveria propor é um núcleo único com perfis declarativos por minijogo:**

```gdscript
# scripts/network/net_profile.gd
class_name NetProfile extends Resource

@export var model: Model                # PREDICTED | INTERPOLATED | ROLLBACK
@export var send_rate_hz: int           # 30 | 60
@export var input_delay_frames: int     # 0..3 (rollback / fairness)
@export var interp_buffer_ms: Vector2i  # min/max do buffer adaptativo
@export var contact_resolution: Contact # HOST_AUTHORITATIVE | FAVOR_ATTACKER
@export var max_players: int
```

Sugestão de preenchimento (a validar por playtest, não por tabela):

| Minijogo | Modelo | Send rate | Resolução de contato | Justificativa |
|---|---|---|---|---|
| Espadas (duelo curto) | CSP + rollback local do par em contato | 60 Hz | Favor-attacker com janela de perdão | Trocas frame-perfect; alcance curto amplifica erro de interp |
| Hellball plataforma | CSP + reconciliação | 60 Hz | Host-autoritativo | Cinemática de plataforma + knockback preciso |
| Hellball topdown / Ímãs | CSP + reconciliação | 60 Hz | Host-autoritativo | Movimento contínuo, sem gravidade |
| Last Standing / King of the Hill | CSP | 30 Hz | Host-autoritativo | Ritmo médio; posicional |
| Corrida de Obstáculos | CSP, sem lag comp | 30 Hz | Sem contato relevante | Sem interação direta |
| Roubo de Comida / Capivara Bomb | Interpolação + confirmação de evento | 20–30 Hz | Host-autoritativo | Coleta/timer; latência invisível |

O que muda no plano: a Fase 0 deixa de ser "escolher um modelo" e passa a ser **"construir um núcleo que suporte PREDICTED e INTERPOLATED desde o dia zero, e ROLLBACK como caminho opcional para duelos"**. É decisão de arquitetura, não de matriz — e determina se Espadas pode existir na qualidade que merece.

### O que o plano omite e é o maior gerador de bugs em coleções de minijogos

Nada no documento fala sobre **transição de cena em rede**, a máquina de bugs nº1 do gênero. Hoje o fluxo é `get_tree().change_scene_to_file()` local ([lobby.gd:63](scripts/ui/lobby.gd#L63)) — cada par troca de cena quando quer. Falta especificar:

1. **Máquina de estados de sessão replicada** (`LOBBY → LOADING → COUNTDOWN → PLAYING → RESULTS → LOBBY`), com o host como autoridade da transição.
2. **Barreira de ready** — o host só emite `start_round` quando todos os pares confirmaram `scene_loaded(round_id)`, com **timeout** e política para o par lento (esperar / kickar / iniciar sem ele). Sem isso, o par que carrega devagar entra na rodada já morto, e o par que carrega rápido simula ticks contra um mundo vazio.
3. **Seed de RNG determinístico por rodada**, distribuído pelo host no `start_round`. Hoje `powerup_manager.gd` e `arena_event_manager.gd` sorteiam no host e transmitem por RPC — funciona, mas é caro em banda e impede replay/rollback. Com seed compartilhado, os eventos de arena tornam-se localmente previsíveis: **eliminam RPC e ganham predição de graça**.
4. **Idempotência de `round_id`** — todo RPC de rodada carrega o `round_id`; pacotes da rodada anterior chegando atrasados são descartados em vez de aplicados. Bug clássico de minijogo em sequência.

---

## 3. Bloqueador nº3 — a migração de host, como está escrita, não funciona

Este é o capítulo mais confiante do plano e o menos correto. O trecho da §10.2 é apresentado como "o protocolo recomendado". Problemas, em ordem de gravidade:

**3.1 Não existe canal de coordenação depois que o host cai.** O código faz `_on_server_disconnected()` → `get_surviving_peers()` → eleger. Sobre ENet cliente-servidor, todo tráfego entre clientes é **relayed pelo host**. Quando o host morre, o relay morre com ele: os sobreviventes conhecem os `peer_id` uns dos outros (a `MultiplayerAPI` os propaga), mas **não têm como trocar um único pacote entre si** para confirmar a eleição. A eleição precisa estar *pré-acordada e pré-distribuída enquanto o host está vivo*, não computada depois.

**3.2 Os sobreviventes não têm endereços.** `reconnect_to(survivors[0])` precisa de `IP:porta` do eleito. Ninguém tem. O plano reconhece isso numa oração subordinada ("renegociado via signaling") e segue como se fosse detalhe. Não é: **implica dependência obrigatória de um serviço externo de rendezvous** (Steam lobby / EOS / noray), o que contradiz o "custo zero de infra" vendido no cap. 2.

**3.3 Alcançabilidade do host reserva não é pré-validada.** O host original passou pelo teste de NAT — foi ele que criou a sala. O reserva pode estar atrás de NAT simétrico e ser **incapaz** de hospedar. Eleger por "menor `peer_id` sobrevivente" ignora isso: a eleição precisa acontecer sobre candidatos **cuja capacidade de hospedar já foi testada durante a partida**.

**3.4 A identidade está atrelada a `peer_id` — e `peer_id` não sobrevive à migração.** Todo o codebase indexa por `peer_id`: `NetworkManager.players[id]` ([network_manager.gd:11](scripts/network/network_manager.gd#L11)), `set_multiplayer_authority(id)`, `attacker_id` nos RPCs de combate. Quando o novo host chama `create_server()`, o ENet **atribui ids novos a todo mundo** e o ex-host era o id 1. Toda a tabela de autoridade, placar, vidas e kills se desreferencia.

> **Requisito arquitetural que o plano não tem:** uma **identidade estável de jogador** (`SteamID64` na Steam, UUID persistido fora dela) como chave primária de tudo — placar, autoridade, telemetria, rejoin, achievements — com `peer_id` rebaixado a detalhe de transporte, resolvido por um mapa `player_id ↔ peer_id` reconstruído a cada (re)conexão. É pré-requisito de migração, de rejoin e de stats na Steam, e é uma refatoração transversal barata **agora** e caríssima depois.

**3.5 O snapshot para o reserva é o desenho errado.** O plano manda `send_world_snapshot.rpc_id(backup_host_id, serialize_world())` dentro de `_process` — mundo inteiro, 60×/s (taxa de *frame*, não de tick), para **um** par. Três defeitos: (a) infla o egress do host justamente no recurso que o plano identifica como gargalo; (b) se o reserva for quem desconectar, não há reserva; (c) o estado que realmente precisa sobreviver à migração é o **estado de meta-sessão** (quem está na sala, placar acumulado, minijogo atual, seed) — centenas de bytes, que devem ser replicados **para todos os pares a cada mudança**, não 60×/s para um.

**3.6 Continuidade temporal e RPCs em trânsito não são tratados.** O novo host tem outro relógio e outro contador de tick; todos os clientes precisam re-sincronizar clock e rebasear predição. RPCs `reliable` em vôo no momento da queda estão perdidos silenciosamente.

**3.7 Vetor de abuso não considerado.** Migração transfere autoridade para um jogador arbitrário — que pode ser o trapaceiro. E "host rage-quit" passa de acidente a mecânica de grief.

### Recomendação: trocar migração de simulação por migração de sessão

Para uma **coleção de minijogos**, a solução certa é muito mais barata que a proposta e o plano não a considera. Rodadas de party game duram 60–180 s. Então:

> **Não migre a simulação. Migre a sala.**
>
> Na queda do host: aborta-se a rodada corrente, todos caem numa tela "o anfitrião saiu — reorganizando sala", o novo host (pré-eleito e pré-validado) reabre a sala, os sobreviventes reconectam pelo rendezvous, o **placar acumulado** (replicado continuamente para todos, porque é pequeno) é restaurado, e a rodada abortada é **repetida**. Custo: ~5–10 s de interrupção e uma rodada perdida. Benefício: elimina transferência de estado de mundo, continuidade de tick, rebase de predição e re-sincronização de relógio — os quatro itens mais caros e frágeis de §3.5–3.6.

Isso mantém a promessa de produto ("a partida não morre quando o host sai") a uma fração do custo, e é o comportamento que a maioria dos party games hospedados por jogador de fato entrega. Migração de simulação *contínua*, se ainda for desejada, entra como refinamento pós-lançamento — nunca como requisito de Fase 2.

E o critério de eleição deve mudar: em vez de menor `peer_id`, **eleger por qualidade de rede medida** (§7.8).

---

## 4. Steam está subutilizada — e é o alvo declarado

O plano nomeia Steam como plataforma-alvo e a trata em dois lugares: GodotSteam como uma das três rotas de NAT traversal (§10.1) e "lobbies de graça" (§10.3). Isso inverte a prioridade. Para um jogo Steam-first com salas hospedadas por jogadores, **Steam Networking Sockets deve ser o transporte padrão**, não um fallback de NAT.

**4.1 O que a Steam entrega e o plano não contabiliza:**

- **Steam Datagram Relay (SDR).** Backbone da Valve. Não só resolve NAT — frequentemente **reduz** o RTT em relação à rota BGP direta, porque o tráfego entra na rede da Valve no PoP mais próximo. Para uma sala com pares em regiões diferentes (realidade de qualquer jogo brasileiro com jogadores no BR/US/EU), essa é a **maior otimização de latência disponível para este produto** — e é configuração, não sistema a construir. Um plano cujo tema central é "estado da arte em latência" e que menciona SDR de passagem está deixando a maior alavanca na mesa.
- **Privacidade de IP e superfície de DDoS.** O plano nunca menciona e é falha de segurança real: com `ENetMultiplayerPeer` cru, **todo convidado aprende o IP residencial do host**. Em jogos com salas de jogador, isso é vetor documentado de DDoS e de assédio. O SDR resolve por construção (os pares se enxergam por `SteamID`, nunca por IP). Off-Steam, o mesmo papel cabe ao relay do EOS. Deveria estar no cap. 11 como requisito.
- **Lobby, convites e `+connect_lobby`.** Convite pelo overlay, entrada por lista de amigos, Rich Presence "entrar na partida", e o parâmetro de linha de comando que faz o jogo abrir já entrando na sala do amigo. Substitui integralmente o "código da sala" e o lobby próprio da §10.3 no SKU Steam — e elimina Nakama do escopo.
- **Auth tickets** — identidade verificada de graça, que é exatamente a `player_id` estável exigida em §3.4.
- **Steam Remote Play Together.** Para um party game de minijogos, é canal de distribuição sério: o host convida amigos que **não possuem o jogo**. Não substitui netcode, mas impõe requisitos que precisam entrar no plano agora: todas as ações jogáveis com gamepad, UI legível em stream comprimido, e suporte a múltiplos jogadores locais na mesma instância.
- **Steam Deck.** Alvo natural para pixel art 2D. Muda o QA de rede: Deck vive em Wi-Fi, com **jitter alto e variável** — o que reforça buffers adaptativos (§7.3) e derruba o buffer fixo de 100 ms como default.

**4.2 O "mas não só" é uma contradição não resolvida.** O documento decide "não queremos infraestrutura" (§2.2) *e* promete funcionar fora da Steam. Fora da Steam, NAT traversal, rendezvous e relay não existem de graça — a §10.1 aponta noray e a §10.3 aponta Nakama, ambos serviços que **alguém precisa hospedar e pagar**. O plano não fecha essa conta.

**A resposta que falta é EOS — Epic Online Services.** Grátis, multiplataforma, sem infra própria: lobbies, sessions, P2P com NAT traversal e relay, identidade e amigos. O plano cita a Epic apenas para Anti-Cheat e ignora a camada de conectividade. Arquitetura de transporte recomendada:

| SKU | Transporte primário | Rendezvous / lobby | Identidade | Fallback |
|---|---|---|---|---|
| Steam | SteamNetworkingSockets (SDR) | Steam Lobbies | SteamID64 | — |
| Off-Steam (itch, Epic, standalone) | EOS P2P (relay) | EOS Lobbies/Sessions | EOS Product User ID | ENet direto + IP:porta manual |
| LAN / dev | ENet direto | descoberta local | UUID local | — |

Requisito que isso impõe, e que o plano já quase tem certo: **toda a camada de jogo fala com uma interface `MultiplayerPeer` e nunca com `ENetMultiplayerPeer` diretamente**. Hoje `network_manager.gd` instancia `ENetMultiplayerPeer` inline ([:17](scripts/network/network_manager.gd#L17), [:28](scripts/network/network_manager.gd#L28)) — a fachada de transporte precisa entrar junto com a `NetSync`.

---

## 5. Números que não fecham e higiene de fontes

O plano acerta ao insistir "medir, não assumir", e então usa números não medidos como restrições de projeto.

**5.1 A conta de banda está inconsistente com ela mesma em ~1,5 ordem de magnitude.** A §8.1 diz "uma partida de 10 jogadores a 60 Hz gera ~2–5 GB de tráfego de saída por hora na máquina do host". Contra o próprio orçamento do plano (≤25 kbps/jogador): 9 convidados × 25 kbps = 225 kbps ≈ 28 KB/s ≈ **101 MB/hora**. Para chegar a 2–5 GB/h seriam necessários 4,4–11 Mbps sustentados, ou 550–1400 kbps por convidado — **22 a 55× o orçamento declarado**. As duas afirmações não podem ser verdadeiras ao mesmo tempo. Isso importa porque a cifra assustadora é o que sustenta a escolha de 20 Hz como default (§5.1, §8.5) — decisão de UX tomada com base num número errado, vindo de blog de vendor de hospedagem de servidor dedicado (workloads 3D AAA), não de um jogo 2D.

**5.2 O orçamento de 25 kbps/jogador é frouxo, não apertado, e está mal ancorado.** Vem de um rascunho de blog pessoal e ocupa linha de SLO na tabela do cap. 1. Faça bottom-up. Estado sincronizado hoje, por jogador: `position` (Vector2), `rotation` (float), `guarding` (bool), `facing` (int). Em Variant isso são ~40–45 bytes por atualização; quantizado (16 bits/eixo a 1/16 px num mundo de 4096 px, ângulo em 8 bits, flags em 8 bits) são **6 bytes** — ~7× menos. Some o overhead de cabeçalho IP/UDP/ENet (~40–75 B/pacote), que a essa altura **domina o payload**: é por isso que a recomendação de agregar *um pacote por tick por cliente* (§8.1) é, de longe, a mudança de banda de maior retorno para este codebase — e não porque o payload seja grande.

**5.3 Números atribuídos a fontes que não os afirmam.** "Serialização manual em `PackedByteArray` é ~2,5× menor e ~10× mais rápida" é creditado a Gaffer on Games, que não faz afirmação nenhuma sobre `Variant` do Godot. O teto de "~40 CCU" vem de blog de vendor; "profiler subestima 10–25×" idem. Nenhum desses deveria aparecer como constante de engenharia. Sugestão editorial: mover essas passagens dos caps. 8 e 10.4 para uma seção **"hipóteses a medir na Fase 1"**, com um número medido no lugar de cada citação.

**5.4 Versão do engine.** O plano fala em Godot 4.6 ao longo de todo o texto; o projeto declara `config/features=PackedStringArray("4.7", ...)`. Todas as afirmações de compatibilidade de addon (netfox, godot-rollback-netcode, SGPhysics2D, GodotSteam) precisam ser revalidadas contra 4.7 antes de entrarem em ADR.

**5.5 `MAX_PEERS := 4`** ([network_manager.gd:9](scripts/network/network_manager.gd#L9)) é o limite atual, contra capítulos do plano dedicados a 17–64 e à discussão de MMO. Ver §6.

---

## 6. Corte de escopo: o plano gasta orçamento onde não há problema

**6.1 Interest management / AOI (§8.4) é provavelmente inaplicável.** Os minijogos são arenas de tela única onde **todos precisam ver todos** — é o gênero. A §8.4 dedica um capítulo a AOI, spatial hashing e redução de 8× no tráfego, para um jogo cuja área de interesse é "a arena inteira". Substituir por uma frase: *"não aplicável: arenas de tela única exigem visibilidade total; `set_visibility_for` fica reservado a estado privado por jogador (inventário, cooldowns próprios)"* — que, aliás, é o uso legítimo e o plano não menciona.

**6.2 As faixas 17–64 e 64+ devem sair.** Fixe o envelope em **2–8 jogadores (esticando a 12)** e as consequências são grandes: O(n²) deixa de importar, delta compression contra baseline por cliente (§8.3, com acks custom sobre UDP — sistema caro) deixa de ser necessária, e **60 Hz de send rate torna-se trivialmente pagável** (7 convidados × ~6 B de estado × 8 entidades × 60 Hz ≈ 20 kB/s de payload, mais cabeçalhos). O orçamento economizado vai para fidelidade — que é o que o jogador sente.

**6.3 "Servidor dedicado descartado por decisão de produto" é uma decisão que o briefing não tomou** — e o plano se contradiz. A §12.3 exige "bots headless" para teste de carga e CI; bots headless **são** o export headless que a §2.2 descartou. O export headless do mesmo binário custa quase nada no Godot e entrega três coisas: (a) infraestrutura de teste automatizado de netcode, (b) opção futura de servidor comunitário/competitivo, (c) caminho de fuga se a migração de host provar inviável. Recomendação: **manter o export headless como artefato de build desde a Fase 1**, sem prometer hospedagem oficial. "Salas hospedadas por jogadores" é o modo padrão, não uma proibição de arquitetura.

---

## 7. Estado da arte que falta (o pedido explícito do briefing)

O plano cobre bem o cânone: CSP (Gambetta), reconciliação (Bernier), interpolação de entidades, lag compensation, rollback (GGPO), quantização (Fiedler) — o estado da arte de ~2001–2015. Faltam as técnicas que definem prática corrente. Em ordem de retorno para *este* jogo:

**7.1 Nivelamento de vantagem do host (o mais importante, e ausente).** O plano registra três vezes que "o host joga com latência zero e os convidados pagam RTT" — e nunca propõe corrigir. Num party game competitivo hospedado por jogador, isso é injustiça estrutural na mecânica central (trocas de golpe). A prática corrente é **atrasar deliberadamente o input local do host** em ~mediana da latência de ida dos convidados (tipicamente 1–4 frames), fazendo o personagem do host passar pelo mesmo input buffer dos demais. O host perde alguns ms de responsividade; a sala ganha simetria. Sem isso, "host com vantagem" vira reclamação de review na Steam.

**7.2 Dilatação de tempo / elasticidade de tick (net time dilation).** Em vez de descartar inputs atrasados ou travar a simulação, o host mede a profundidade do input buffer de cada cliente e devolve uma correção de **velocidade de simulação de ±1–2%**, empurrando cada cliente a convergir para a profundidade-alvo. Substitui buffers superdimensionados "por segurança" por buffers mínimos auto-regulados — menos latência, sem stalls. É a técnica que mais reduz latência efetiva por linha de código e não aparece no plano.

**7.3 Buffer de playout adaptativo por percentil, não fixo.** O plano fixa ~100 ms (`cl_interp 0.1`, Source 2001, 20 Hz, shooter hitscan) e trata 60 Hz como exceção "com justificativa orçada". Para 2–8 jogadores em 2D com estado de 6 bytes, isso está invertido. Recomendação: **send rate 60 Hz como default para ≤8 jogadores**, e buffer de interpolação **adaptativo dimensionado pelo p99 de jitter medido em janela deslizante** (faixa 25–120 ms), apertando em rede limpa e abrindo sob jitter — exatamente como um jitter buffer de VoIP. Ganho: interp delay de ~33 ms em vez de 100 ms nos jogadores remotos, que num brawler de contato é a diferença entre trocar golpes e adivinhar.

**7.4 Redundância de input e predição de input no host.** O plano menciona redundância entre parênteses (§5.3). Especifique: cada pacote de input carrega **os últimos 4–8 inputs** (~1 byte cada quando bit-packed) e o host aplica o mais novo que ainda não viu. A perda de pacote isolada passa a ser gratuita e o buffer de input pode encolher. Complementarmente, quando o input do tick T não chegou, o host **repete o último input conhecido** em vez de aplicar "input vazio" (que faz o personagem parar e depois teleportar), marcando o tick como especulativo para correção posterior.

**7.5 Feedback cosmético imediato ("cosmetic-first"), desacoplado da confirmação autoritativa.** A técnica que mais esconde latência num brawler não é netcode, é ordem de operações: no frame do input, disparar **animação, hitstop, partículas, som e screen shake localmente**, sem esperar nada; só o *resultado* (dano, knockback, morte) espera a confirmação do host. O plano tem uma bíblia de game feel em `docs/gamefeel/` e um capítulo de netcode, e nunca conecta os dois — é a integração mais valiosa disponível e está faltando. Corolário obrigatório: durante a re-simulação de reconciliação, **VFX/SFX devem ser suprimidos** (o plano acerta ao mencionar isso em §6.2) — o que exige um flag global `is_resimulating` respeitado por todo o `SfxBus` e pelos spawners de partícula. Isso é refatoração real no codebase atual, onde `SfxBus.play()` é chamado direto de dentro da lógica de gameplay ([hellball_player_2d_base.gd](scripts/player/hellball_player_2d_base.gd)).

**7.6 Detecção de acerto no cliente com validação no host (favor-the-attacker) como alternativa ao rewind.** O plano só apresenta lag compensation por rewind de histórico no host (§7.2). Para **melee de alcance curto** — Espadas, punch — a prática moderna é o cliente reportar o acerto e o host **validar plausibilidade** (o alvo estava, no histórico, dentro de `alcance × tolerância` no tick reivindicado?) em vez de re-resolver a geometria. Mais barato, mais previsível para quem ataca, e a lógica de validação é a mesma que fecha o buraco do `force` arbitrário da §1.2. Precisa vir com **regra explícita de arbitragem de trocas simultâneas** (ambos acertam? ninguém acerta? o de tick menor vence?) — decisão de design que o plano não pede e que gera reclamação garantida se ficar implícita.

**7.7 Orçamento de erro e suavização com reset explícito.** A §6.4 resolve correção com "lerp ao longo de alguns frames". Especifique: **erro amortizado exponencialmente** com constante de tempo ~100 ms, **limite de erro máximo** acima do qual se faz snap seco (evita o personagem "escorregando" por meio segundo depois de uma correção grande) e — crítico aqui — **flag de correção dura** que desliga a suavização em teleporte, dash e knockback. Sem esse flag, o Teleport Gun e o dash (que existem em todos os minijogos) produzem exatamente o artefato que a suavização deveria esconder. Em pixel art: suavizar em subpixel, quantizar só na renderização (o plano acerta aqui, §9.2).

**7.8 Eleição de host por qualidade de rede medida.** Substituir "menor `peer_id` sobrevivente" (§10.2) por: durante a partida, cada par mede RTT contra os demais (via host, que já tem `ENetPacketPeer.get_statistic()` de todos) e o host mantém, replicado para todos, a **lista ordenada de candidatos que minimiza o RTT máximo da sala** — filtrada por candidatos cuja capacidade de hospedar foi **pré-validada** (§3.3) e cujo upload medido suporta a sala. Resolve simultaneamente determinismo da eleição, alcançabilidade e qualidade do resultado, e é a resposta de "estado da arte" para salas hospedadas por jogador.

**7.9 Delay de input adaptativo no caminho de rollback.** Se Espadas for para rollback, a prática corrente não é rollback puro: é **delay de input dinâmico** — 1–3 frames de atraso local ajustados à latência medida, trocando um pouco de responsividade por uma queda grande na frequência de rollback (e portanto nos artefatos visuais). O plano descreve rollback como binário e não menciona o botão que o torna utilizável.

**7.10 Hash de estado por tick e replay determinístico.** Duas ferramentas de teste que são padrão em netcode moderno e estão ausentes do cap. 12:
- **Checksum do estado do mundo por tick**, comparado entre pares; divergência aciona log e dump. É a única forma de descobrir desync antes do jogador. Barato de adicionar **agora**, insubstituível se rollback/lockstep entrar.
- **Replay determinístico a partir de stream de input gravado** (inputs + seed + versão de protocolo). É a ferramenta de depuração de netcode com melhor retorno que existe: transforma "aconteceu uma vez no playtest" em "reproduzo no meu terminal". Dá de graça, ainda, killcam, replay de rodada e evidência de anti-cheat.

**7.11 Correção técnica sobre física e rollback.** A matriz do cap. 4 diz que no modelo B "qualquer física serve" e a §9.1 diz que com servidor autoritativo "o problema some". Otimista demais, e vai custar tempo. Com `CharacterBody2D` + `move_and_slide()` (o que o codebase usa), re-simular N ticks exige **rebobinar o mundo de física inteiro**, não só o corpo do jogador local — porque colisão jogador-contra-jogador é mecânica central aqui (knockback, punch, empurrão). E o `PhysicsServer2D` do Godot não é passo-a-passo trivial dentro de um único frame; a própria documentação do netfox condiciona rollback com física a addon Rapier ou build customizada. Recomendação, que a §9.1 menciona de passagem e deveria promover a decisão de primeira classe: **cinemática própria em ponto fixo com colisão AABB/círculo à mão**, sem engine de física, para os personagens 2D. As formas de colisão atuais já são cápsula e círculo simples; o movimento de plataforma cabe em poucas centenas de linhas; e isso entrega determinismo, rollback barato, controle exato de feel pixel-perfect e independência de versão de engine de uma vez.

> **Bug de porte, à margem da revisão mas relevante para o feel 2D:** [hellball_platform_player.tscn:5-7](scenes/player/hellball_platform_player.tscn#L5-L7) declara `CapsuleShape2D` com `radius = 0.4` e `height = 1.5` — unidades de metro herdadas do 3D, aplicadas a um espaço em pixels, com velocidades na casa de 190–430 px/s. A colisão do jogador de plataforma tem sub-pixel de tamanho. Vale confirmar contra `VISUAL_SCALE` antes de qualquer trabalho de netcode em cima dessa cena.

---

## 8. Lacunas de produto e operação (ausentes do plano)

Para salas hospedadas por jogadores na Steam, estes itens não são polimento — são o que quebra no lançamento:

| Lacuna | Por que é crítica | Onde entra |
|---|---|---|
| **Versionamento de protocolo** | Com salas de jogador, clientes de versões diferentes tentam se conectar em toda atualização. Sem handshake de versão, o sintoma é desync silencioso, não erro claro. Precisa de `PROTOCOL_VERSION` no handshake, rejeição com mensagem clara e política de branch beta na Steam. | Fase 1, ~1 dia |
| **Rejoin / reconexão em partida** | O plano cita "reconecta pelo lobby" uma vez, sem design. Precisa de assento reservado por `player_id` estável, janela de retenção e re-sync de estado na entrada. | Fase 2 |
| **Moderação da sala (anti-grief)** | Em sala de jogador, o host **é** a moderação: kick, ban por `player_id`, senha de sala, detecção de idle, filtro de região. Nada disso está no plano, e num party game público é o que decide se as salas são jogáveis. | Fase 3 |
| **Splitscreen / múltiplos jogadores locais** | Requisito implícito de party game e pré-requisito de Remote Play Together. Muda a arquitetura de input: `Input.is_action_*` global (usado hoje em todos os controladores) precisa virar input **por dispositivo/slot**. Barato agora, caro depois. | Decidir na Fase 0 |
| **Consistência de achievements/stats Steam** | Só conceder em confirmação autoritativa; nunca em predição. Predição + achievement = conquista fantasma. | Fase 4 |
| **Telemetria de netcode em produção** | O plano lista boas métricas (§12.3). Falta o canal: para onde vão, com que consentimento, e qual alerta dispara. | Fase 4 |

---

## 9. Roadmap revisado

Substitui o §13.1. Diferenças: reconhece o codebase existente, sequencia por risco decrescente, e paraleliza o que não colide.

**Fase 0 — Decisões e fundações (1–2 semanas).**
ADRs de uma página para: (a) escopo 2D — modos 3D congelados ou removidos; (b) envelope 2–8 (esticando 12); (c) identidade estável `player_id` desacoplada de `peer_id`; (d) transporte por SKU (Steam SDR / EOS / ENet-LAN) atrás de fachada; (e) cinemática própria em ponto fixo vs. `CharacterBody2D`; (f) migração de **sessão**, não de simulação; (g) input local por slot (splitscreen sim/não). *Saída:* ADRs aprovados + `NetProfile` esboçado por minijogo.

**Fase 1 — Fundação de rede sobre o que existe (2–3 semanas).** Sem mudar autoridade de movimento.
Fachada `NetSync` + fachada de transporte; `player_id` estável como chave em `NetworkManager`, gerentes e RPCs; `PROTOCOL_VERSION` no handshake; tick de rede compartilhado + clock sync; máquina de estados de sessão replicada com **barreira de ready** e `round_id` idempotente; seed de RNG por rodada; **hash de estado por tick** e gravação de stream de input; export headless + bot sintético em CI. *Saída:* trocar de minijogo 20× seguidas, com um par lento e um par que cai, sem nenhum estado inconsistente; baseline de banda medida no Wireshark.

**Fase 2 — Fechar o buraco de segurança e introduzir o padrão (2–3 semanas).**
Combate para o host: `request_punch/charge(tick, aim)` com validação de plausibilidade e histórico curto (~32 ticks) para lag comp; remoção de `force`/`pos` do payload do cliente; regra explícita de arbitragem de trocas simultâneas; feedback cosmético imediato desacoplado da confirmação, com flag `is_resimulating` respeitado por `SfxBus` e VFX. *Saída:* cliente modificado não consegue aplicar knockback arbitrário (teste adversarial escrito); trocas de golpe a 150 ms percebidas como justas em playtest cego.

**Fase 3 — Predição no movimento, um minijogo por vez (4–6 semanas).**
Host-autoritativo + CSP + reconciliação, começando pelo topdown, depois plataforma; interpolação de remotos com buffer adaptativo por p99 de jitter; send rate 60 Hz para ≤8; suavização de erro com amortecimento exponencial + reset duro em dash/teleporte; **delay de input no host para nivelar vantagem**; dilatação de tempo para regular profundidade de buffer. QA na matriz {50,100,200,300 ms} × {0,1,5% perda} × {0,25 ms jitter} via clumsy/netem. *Saída:* 200 ms / 2% de perda jogável sem snaps; SLO de banda medido no fio.

**Fase 4 — Conectividade, sala e produção (3–4 semanas).**
Steam Networking Sockets + SDR como transporte default; Steam Lobbies, convites e `+connect_lobby`; EOS para o SKU off-Steam; **migração de sessão** com eleição por qualidade de rede medida e candidatos pré-validados; rejoin por `player_id`; moderação de sala (kick/ban/senha/região); telemetria e teste de carga com bots contra host real. *Saída:* playtest público com SLOs monitorados; sala sobrevive à saída do host perdendo no máximo a rodada corrente; nenhum IP residencial exposto a convidado.

**Fase 5 — Opcional, orientada por dados.** Rollback para Espadas (com delay de input adaptativo) se o playtest mostrar que o duelo pede; anti-cheat de cliente só se houver incentivo econômico a trapacear; migração de simulação contínua só se a interrupção de rodada provar inaceitável.

Prazo total: **12–18 semanas** para as Fases 0–4, assumindo escopo 2D e os modos 3D fora. Com os modos 3D dentro, some ~50% nas Fases 2–3.

---

## 10. Decisões que o plano deveria fixar (e não fixa)

O documento termina entregando matrizes. Um plano de arquitetura termina entregando decisões. As oito que faltam, com a recomendação desta revisão:

| # | Decisão | Recomendação |
|---|---|---|
| 1 | Escopo de modos | 2D apenas; 3D congelado |
| 2 | Envelope de jogadores | 2–8 (esticar 12); AOI e delta-vs-baseline fora de escopo |
| 3 | Modelo de netcode | Núcleo suporta PREDICTED + INTERPOLATED; perfil por minijogo; ROLLBACK opcional só em duelo |
| 4 | Send rate | 60 Hz default (≤8 jogadores); buffer de interpolação adaptativo 25–120 ms por p99 de jitter |
| 5 | Física dos personagens | Cinemática própria em ponto fixo, colisão AABB/círculo à mão |
| 6 | Transporte | Fachada; Steam SDR no SKU Steam, EOS off-Steam, ENet em LAN/dev |
| 7 | Continuidade de sala | Migração de **sessão** (aborta rodada, preserva placar, reabre sala), eleição por qualidade de rede pré-validada |
| 8 | Identidade | `player_id` estável (SteamID/EOS PUID/UUID) como chave primária; `peer_id` é detalhe de transporte |

---

## 11. O que o plano acerta e deve ser preservado

- **A tese das camadas independentes** (predição / interpolação / lag comp / rollback, cada uma com dono, orçamento e métrica). É o melhor parágrafo do documento (§7.3) e deve virar a espinha do capítulo de netcode.
- **A "escotilha de escape"** (§8.5): isolar replicação atrás de uma interface própria antes de precisar. Correto e barato — e agora precisa carregar também a fachada de transporte (§4.2).
- **Send rate como botão triplo** (UX / banda / upload do host). Análise correta; só as constantes estão erradas (§7.3).
- **Disciplina de confiabilidade por canal** (estado em `unreliable_ordered`, eventos em `reliable`, canais ENet separados) — aplicável tal como está.
- **Posição lógica em subpixel, quantização só na renderização** (§9.2). Exatamente certo, e o alerta de desligar a physics interpolation nativa em nós dirigidos pela rede é o tipo de detalhe que economiza uma semana de depuração.
- **A matriz de QA de rede** {latência} × {perda} × {jitter} e o kit por plataforma (clumsy/NLC/netem). Aproveitável integralmente; só precisa ganhar hash de desync e replay determinístico (§7.10).
- **A honestidade sobre retrofit de rollback** (NRS ~8 man-years vs. Skullgirls ~2 semanas). O argumento está certo — e vale exatamente o mesmo para as decisões 3, 5, 7 e 8 da tabela acima, que são de dia zero pelo mesmo motivo.
