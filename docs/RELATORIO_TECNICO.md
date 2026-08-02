# Relatório Técnico — Capibraba

> **Propósito:** documentar o trabalho realizado na sessão (modo Hellball em
> 3 versões + sistema de Game Feel), a arquitetura construída e o
> funcionamento do multijogador. Este documento é destinado a outra LLM que
> vai **observar e criticar** o trabalho — por isso inclui limitações,
> decisões e pontos frágeis de forma honesta.

- **Projeto:** Capibraba — jogo de festa multijogador online (arena party game) em Godot.
- **Engine:** Godot **4.7.1** (build local em `C:\Users\rodri\workspace\radical\tools\Godot_v4.7.1-stable_win64_console.exe`), GDScript, ENet, Jolt Physics (3D).
- **Idioma do código:** comentários e textos de UI em português brasileiro.
- **Data:** 2026-08-02.

---

## 1. Resumo do que foi feito

### 1.1 Hellball (primeiro minigame da coleção)
Jogo em arena de lava onde cada jogador tem **2 itens** e o objetivo é ser o
último com vidas (empurrar rivais para a lava).

- **Charge Gun** (Clique Esquerdo): segurar para carregar (0→1 em ~1,2 s),
  soltar dispara um projétil que explode e **empurra radialmente** os rivais
  com força proporcional à carga (3D: 16→44; 2D: 240→560 px). Cooldown curto.
- **Teleport Gun** (Clique Direito/RB): dispara um **orbe**. Apertar de novo
  teleporta o dono até o orbe; acertar um rival **troca as posições**
  instantaneamente (validado pelo servidor).

**Três versões implementadas:**
| Modo | Cena | Jogador | Gerente |
|---|---|---|---|
| Hellball 3D | `scenes/levels/hellball_arena.tscn` | `hellball_player.gd` (CharacterBody3D) | `hellball_manager.gd` |
| Hellball Plataforma (2D lado) | `scenes/levels/hellball_platform.tscn` | `hellball_platform_player.gd` | `hellball_manager_2d.gd` |
| Hellball Topdown (2D topo) | `scenes/levels/hellball_topdown.tscn` | `hellball_topdown_player.gd` | `hellball_manager_2d.gd` |

### 1.2 Ações básicas (sempre disponíveis, desarmado)
**Punch** (E/X) — melee curta com knockback; **Guard** (segurar Ctrl/LB) —
escudo que reduz knockback em 80% e velocidade; **Dash** (Shift) — impulso
curto. Novos inputs no `project.godot`: `teleport_gun`, `punch`, `guard`.

### 1.3 Game Feel (juice)
- **Bíblia de design:** `docs/gamefeel/00…07` (baseada em *The Art of Game
  Design: A Book of Lenses* — Schell, *The Illusion of Life* — Thomas &
  Johnston, *Game Feel* — Swink, e "Juice it or lose it" — GDC 2012).
- **Agentes VS Code:** `.github/agents/` — `gamefeel-director`,
  `vfx-animator`, `audio-designer`.
- **Implementado:** squash & stretch (tweens), hit-stop
  (`Engine.time_scale`), screen shake (câmeras), flash de dano, partículas
  (bursts), escudo de guarda, indicador de carga.
- **Áudio:** padrões documentados (`06_audio.md`), mas **sem assets nem
  players conectados** (pendência).

### 1.4 Itens futuros (documentados em `docs/items.md`)
Ímã de 2 polos, Katana do Hattori Hanzo, Capa de Teleporte, Explosão. Regra:
**média de 2 itens por minigame** (haverá de 1 e 3). **Não implementados.**

---

## 2. Arquitetura do projeto

### 2.1 Autoloads (singletons)
| Autoload | Arquivo | Papel |
|---|---|---|
| `NetworkManager` | `scripts/network/network_manager.gd` | Sessão ENet, lista de jogadores, sinais |
| `GameSettings` | `scripts/game/game_settings.gd` | Modo/arena/preset selecionados, volume/fullscreen |
| `MatchSettings` | `scripts/game/match_settings.gd` | Todos os parâmetros configuráveis de partida |
| `MatchPresets` | `scripts/game/match_presets.gd` | Presets predefinidos (Clássico, Caos, etc.) |

### 2.2 Fluxo de telas
```
main_menu → mode_select → (last_standing: arena_select) → lobby → arena
```
- `mode_select` expõe os modos disponíveis (`available=true`): Last Standing,
  Hellball, Hellball Plataforma, Hellball Topdown.
- `lobby` (host/cliente): nome, cor, preset; `_start_game` é um RPC
  `@rpc("authority","call_local")` que aplica o preset em **todos** os peers
  e troca de cena para a arena correspondente (`match GameSettings.selected_mode`).

### 2.3 Padrão de cena de arena (repetido nos 4 modos)
```
Arena (Node3D ou Node2D)
├── WorldEnvironment / Camera2D (arena_camera_2d.gd) / Sun
├── Lava (Area3D/Area2D + visual emissivo)          → grupo "lava_area" (2D)
├── Plataforma(s) / obstáculos (StaticBody3D/2D)
├── SpawnPoints (Marker3D/2D)
├── Players (Node3D/Node2D)                          → filhos = players por peer
├── MultiplayerSpawner (spawn_path="../Players")
├── <Mode>Manager (script do modo)
├── HUD (instance de scenes/ui/hud.tscn)             → CanvasLayer (serve 2D e 3D)
└── PauseMenu (instance de scenes/ui/pause_menu.tscn)
```
O `Manager` é o **dono do estado de partida** e o **orquestrador** do modo.

### 2.4 Padrão de cena de jogador
- `CharacterBody3D/2D` + `CollisionShape` + visual (cápsula 3D / polígonos 2D
  procedurais) + `MultiplayerSynchronizer` (replicação) + `CameraRig` (3D).
- O script define paleta de cor pelo `color_index` do `NetworkManager.players`.

---

## 3. Funcionamento do multijogador (detalhado)

### 3.1 Sessão ENet (`NetworkManager`)
- `host(port)` → `ENetMultiplayerPeer.create_server` (host = **peer 1**),
  `MAX_PEERS=4`.
- `join(ip, port)` → cliente; registro via RPC `_register(data)` → servidor
  guarda `{peer_id: {name, color_index}}` e transmite `_sync_players` (RPC
  authority) para todos → sinal `players_updated`.
- `players` (dict) é o **espelho** em todos os peers.
- Sem NAT traversal, sem criptografia/autenticação (jogo de festa local/LAN).

### 3.2 Modelo de autoridade (mistura intencional)
- **Movimento = client-autoritativo**: cada cliente controla seu próprio
  nó de jogador; a posição é replicada aos outros via `MultiplayerSynchronizer`
  (config: `position`, rotação do visual, `guarding`; 2D também `facing`/`rotation`).
- **Estado de partida = servidor-autoritativo**: vidas, mortes, abates,
  eliminação, vitória e a **validação da troca** ficam no `Manager`
  (rodando no host).
- **Efeitos = broadcast por RPC**: projéteis são **locais** a quem disparou;
  o efeito (empurrão, dano) é transmitido por RPC para todos os peers, que
  aplicam apenas no jogador sob autoridade local.

### 3.3 Spawn de jogadores
- `Manager._spawn_player(id)` no **servidor**: instancia a cena do jogador,
  `set_multiplayer_authority(id)`, posiciona em `SpawnPoints` e adiciona em
  `Players`; o `MultiplayerSpawner` replica o spawn para todos os peers.
- Reconexão/entrada tardia: `NetworkManager.players_updated` → spawn dos
  novos; despawn dos desconectados.

### 3.4 Projéteis locais + efeito por RPC (padrão)
1. Atirador cria o projétil **apenas localmente** (não é nó de rede).
2. Projétil viaja localmente; ao colidir, emite sinal `exploded(pos, force)`.
3. O jogador transmite `_broadcast_charge(pos, attacker_id, force)` —
   `@rpc("any_peer","call_local","unreliable_ordered")`.
4. Em cada peer, o loop itera o grupo `"player"` e aplica empurrão/knockback
   **somente no jogador local** (autoridade), gravando `last_attacker_id`
   para crédito de abate quando cair na lava.

### 3.5 Troca de posições (Teleport Gun) — servidor valida
```
orbe (local) acerta rival
  → request_swap.rpc_id(1, owner_id, target_id)      [cliente → servidor]
  → servidor valida: sender == owner, players existem, owner != target
  → _perform_swap.rpc(owner, target)                 [servidor → todos, call_local]
  → cada peer troca global_position dos dois nós e zera velocity + efeito
```
- As posições usadas são as **de cada peer no momento** (podem diferir por
  latência); os clientes donos re-replicam as posições finais.

### 3.6 Lava / vidas / abates
- `LavaArea.body_entered` → `player.on_lava_contact()` (rebote + cooldown de
  vida) → reporte ao `Manager` pelo grupo `"last_standing_manager"`
  (o player 3D base já usa esse grupo; os managers se registram nele para
  reutilizar o reporte). Cliente → `client_report_lava.rpc_id(1,...)`;
  offline/servidor → chamada direta.
- `on_player_lava_touch`: -1 vida, crédito de abate ao `last_attacker_id`,
  eliminação (vida 0), broadcast de vidas/placar por RPC e checagem de
  vitória (último vivo; empate se todos caírem juntos).

### 3.7 HUD compartilhado
- `scenes/ui/hud.tscn` (CanvasLayer) com: lista de jogadores/vidas,
  placar (TAB), overlay de vencedor, anúncio de evento
  (`show_event_announcement`) e dica de modo (`show_mode_hint`).
- Atualizado via RPCs dos managers (`_sync_lives`, `_sync_stats`,
  `_announce_winner`, `_show_intro`).

---

## 4. Game Feel — aplicação

- **Squash & stretch** no visual (3D `mesh_pivot.scale`, 2D `_visual.scale`)
  com `create_tween()` `TRANS_BACK`; detectado em pulo/aterrissagem/dash/dano.
- **Hit-stop**: `Engine.time_scale = 0.05` por ~50 ms com
  `create_timer(ignore_time_scale=true)` para restaurar.
- **Screen shake**: método `shake()` em `player_camera.gd` (3D) e
  `arena_camera_2d.gd` (2D, grupo `"arena_camera"`).
- **Flash de dano**: emissão do material (3D) / `modulate` do corpo (2D).
- **Partículas**: bursts em explosão, teleporte, troca, lava, landing.
- **Paleta funcional**: lava/charge laranja, teleporte ciano, guard azul,
  dano vermelho, sucesso verde (tabela em `05_color_palette.md`).
- **Áudio**: padrões documentados; **não há sons conectados** (pendência).

---

## 5. Problemas conhecidos, limitações e pontos frágeis

> (Alvo de crítica — alguns são deliberados para jogo de festa, outros são
> pendências reais.)

1. **Build do Godot sem `Label2D`**: o build 4.7.1 local **não possui a
   classe `Label2D`** (`Label3D` funciona). Contornado com `name_label_2d.gd`
   (desenho via `_draw()`). Pode indicar build customizado.
2. **Projéteis/orbes não são nós de rede**: rivais **não veem o orbe** do
   Teleport Gun nem o projétil do Charge Gun; a consistência vem dos efeitos
   broadcast. Com latência, a troca pode "sentir" levemente dessincronizada.
3. **Troca usa posições locais de cada peer**: não há snapshot autoritativo
   de posição no servidor (o movimento é client-autoritativo). Para um jogo
   de festa é aceitável; para competitivo seria um problema.
4. **Hit-stop global por cliente**: `Engine.time_scale` é local e global; se
   dois hit-stops ocorrerem sobrepostos, a restauração via `await` pode
   "fechar" cedo demais (race condition simples). Efeito puramente local.
5. **Sem anti-cheat**: `request_swap`, `_broadcast_charge` etc. são RPCs
   `any_peer`; um cliente malicioso pode forjar `attacker_id` (crédito de
   abate) ou enviar trocas. Só há validação básica no `request_swap`.
6. **Audio não implementado** (só documentado) — sem `AudioStreamPlayer` nos
   jogadores/arenas.
7. **Itens futuros não implementados** (íma, katana, capa, explosão).
8. **Topdown: mira só no mouse**; no gamepad a mira cai para `facing`
   (não há right-stick de mira no modo 2D).
9. **`MatchPresets`/`MatchSettings` aplicados localmente** via RPC
   `call_local` (não são estado replicado); depende de todos aplicarem igual.
10. **Sem NAT/hole punching, sem servidor dedicado**: host é cliente e peer
   1; sair do host encerra a partida.
11. **Cache/`class_name`**: scripts criados fora do editor exigiram
    reconstrução do cache do Godot (`.godot`) — um atrito conhecido de
    desenvolvimento com ferramentas externas.
12. **`flash_hurt` (2D/3D) com `await` mutando material/cor**: flashes
    simultâneos podem reverter antes do esperado (race simples).
13. **3D `hellball_player.gd` mantém `extends "res://..."` por caminho**
    (funciona porque `player.gd` já está cacheado); os 2D usam `class_name`
    (padrão mais robusto) — inconsistência pequena.

---

## 6. Decisões de design (justificadas)

- **Client-autoritativo p/ movimento** + **server-autoritativo p/ estado**:
  melhor resposta de input em party game, com servidor arbitrando o que
  importa (vidas/troca/vitória).
- **Projéteis locais + efeitos por RPC**: simples, evita sincronizar muitos
  nós; custo: invisibilidade do orbe para os outros.
- **Reuso do grupo `last_standing_manager`** para o reporte de lava:
  integração com o sistema de vidas pré-existente sem duplicar código.
- **HUD/pausa compartilhados (CanvasLayer)**: funcionam em 2D e 3D.
- **Gerente 2D único configurável** (`player_scene` + `mode_hint`) em vez de
  dois gerentes: reduz duplicação (Plataforma/Topdown compartilham ~95%).
- **Game Feel como sistema documentado + agentes**: princípios (Schell,
  Disney) viraram specs acionáveis e agentes de IA dedicados.

---

## 7. Questionário para o LLM revisor

1. **Modelo de autoridade:** a mistura client/Server é coerente? O que
   quebraria em escala maior (ex.: 8+ jogadores, host ruim)?
2. **Troca de posições:** sem snapshot de posição no servidor, há risco de
   "trade" injusto ou desync perceptível? Como torná-la mais robusta sem
   perder responsividade?
3. **RPCs `any_peer`:** quais os riscos reais de segurança/abuso e qual o
   mínimo de validação a adicionar (id de sessão, rate limit, estado esperado)?
4. **Hit-stop `Engine.time_scale`:** o impacto na sincronização entre peers
   é relevante? Alternativas (hit-stop local por nó)?
5. **Projéteis locais:** vale a pena transformar o orbe em nó replicado
   (ex.: `MultiplayerSpawner` com `net_id`, como os power-ups) para os rivais
   verem? Custo/benefício?
6. **Godot 4.7.1 sem `Label2D`:** como validar/diagnosticar se o build é
   customizado? Alguma classe removida pode ter sido usada sem perceber?
7. **Estrutura dos managers:** os três managers (3D, 2D) têm lógica quase
   idêntica (lava/vidas/troca/vitória). Vale unificar num `Manager` genérico?
   Risco de divergência?
8. **MatchSettings por RPC `call_local`:** é robusto? O que acontece se um
   peer entra depois do preset ser aplicado?
9. **Game Feel:** as escolhas (hit-stop 50 ms, shake proporcional, paleta
   funcional) seguem as boas práticas citadas? O que está "enxuto demais"
   para um jogo de festa?
10. **Dívida técnica:** quais itens (áudio, mira de gamepad, itens futuros,
    anti-cheat) deveriam ser priorizados e por quê?

---

## 8. Como validar

- **Importação headless (limpa scripts):**
  `& Godot_v4.7.1-stable_win64_console.exe --headless --editor --path <proj> --quit`
  (exit 0 = sem erros de script).
- **Fluxo manual:** Menu → Selecionar Modo → Hellball (3D/Plataforma/Topdown)
  → Lobby (host) → Iniciar. Testar Charge Gun, Teleport Gun (teleporte e
  troca), Punch/Guard/Dash, queda na lava e vitória.
