# Hellball

## Visão Geral

**Hellball** é o primeiro minigame do Capibraba: uma arena de lava onde cada
jogador possui **duas armas** — o **Charge Gun** e o **Teleport Gun**. O
objetivo é ser o último jogador com vidas, empurrando rivais para a lava.

## Como Funciona

Cada jogador começa com as vidas configuradas em `MatchSettings.lives_per_player`
(padrão: 3). Tocar a lava custa 1 vida e arremessa o jogador de volta ao alto
(controle aéreo para retornar à plataforma). Quem perder todas as vidas é
eliminado. O último de pé vence.

## Mecânicas

### Charge Gun (Clique Esquerdo)
- **Segure** para carregar (até ~1,2 s) e **solte** para disparar.
- Dispara um projétil que explode no impacto com um **empurrão radial**.
- A força do empurrão cresce com a carga (16 → 44) e cai com a distância
  (raio de 5 m). Uma carga cheia manda rivais voando para fora da arena.
- Cooldown curto entre disparos (0,55 s). Um indicador na câmera mostra a carga.
- O jogador que empurrou recebe o abate se o rival cair na lava em seguida
  (via `last_attacker_id`).

### Teleport Gun (Clique Direito / RB)
- Dispara um **orbe** que viaja na direção da mira.
- **Aperte de novo** (enquanto o orbe estiver ativo) → você se teletransporta
  até a posição atual do orbe (funciona em pleno voo ou "plantado" na parede).
- **Acerte um rival** com o orbe → os dois **trocam de lugar instantaneamente**
  (posições e velocidades zeradas). Ótimo para derrubar alguém na lava ou
  escapar de um empurrão.
- O orbe fica ativo por 6 s (ou 4 s após plantar). Ao bater no próprio dono ele
  o ignora.

### Lava
- Mesma mecânica do Last Capivara Standing: tocar a lava causa um salto alto
  automático (28 m/s), cada contato consome 1 vida (com cooldown de 2 s), e o
  impulso horizontal é quase zerado para exigir controle aéreo.

### Arena (`hellball_arena`)
- Plataforma central (24×24) cercada por lava.
- 4 pilares de cobertura para se esconder do Charge Gun e planejar trocas.
- Anel emissivo no centro como referência visual.

## Controles

| Ação                    | Teclado/Mouse          | Controle            |
|-------------------------|------------------------|---------------------|
| Mover                   | WASD                   | Analógico Esquerdo  |
| Câmera                  | Mouse                  | Analógico Direito   |
| Pular / Pulo duplo      | Espaço                 | Botão Sul (A)       |
| Dash                    | Shift                  | L3                  |
| Charge Gun (carregar)   | Segurar Clique Esq.    | Segurar RT          |
| Charge Gun (disparar)   | Soltar Clique Esq.     | Soltar RT           |
| Teleport Gun (orbe)     | Clique Direito         | RB                  |
| Teleport Gun (pular)    | Clique Direito (2ª vez)| RB (2ª vez)         |
| Punch (básico)          | E                      | X (Norte)           |
| Guard (básico)          | Segurar Ctrl Esq.      | Segurar LB          |
| Placar                  | TAB                    | —                   |
| Pausar                  | ESC                    | —                   |

> Ações básicas (Punch, Guard, Dash) estão sempre disponíveis, mesmo com os
> dois itens equipados. Detalhes em `docs/items.md`.

## Variantes 2D

### Hellball Plataforma (`hellball_platform.tscn`)
- 2D visto de lado: gravidade, pulo duplo, dash horizontal, plataformas
  flutuantes sobre a lava.
- Mesmos itens (Charge Gun + Teleport Gun) + Punch/Guard/Dash.
- Lava na base; a câmera enquadra a arena. Gerenciado por
  `hellball_manager_2d.gd`.

### Hellball Topdown (`hellball_topdown.tscn`)
- 2D visto de cima: movimento 8 direções, mira no mouse, dash em 8 direções.
- A lava fica ao redor da plataforma; ao entrar, o jogador é empurrado de
  volta ao centro (perde 1 vida).
- Mesmos itens + Punch/Guard/Dash.

## Game Feel

- Todo o sistema de feedback (squash & stretch, hit-stop, screen shake,
  partículas, flash de dano, paleta) segue `docs/gamefeel/`.
- Agentes de Game Feel (Diretor, VFX/Animação, Áudio): `.github/agents/`.
- A aplicação por versão está em `docs/gamefeel/07_hellball_application.md`.

## Arquitetura / Rede

- **Servidor autoritativo** para vidas, mortes, abates e eliminação
  (`scripts/game/hellball_manager.gd`).
- A **troca de posições** do Teleport Gun é validada pelo servidor:
  1. O orbe (local no cliente do atirador) acerta um rival →
  2. `request_swap(owner, target)` RPC para o servidor →
  3. Servidor valida e transmite `_perform_swap` para todos →
  4. Cada peer aplica a troca; os clientes donos replicam a posição final.
- O Charge Gun segue o padrão dos projéteis existentes: o projétil é local e o
  efeito (empurrão) é transmitido por RPC para todos os peers.
- `hellball_player.gd` estende `player.gd` (sem o sistema de habilidades), com
  as duas armas. O `hellball_manager` também entra no grupo
  `last_standing_manager` para reutilizar o reporte de toque na lava.

## Arquivos

| Arquivo | Finalidade |
|---|---|
| `scripts/game/hellball_manager.gd` | Gerenciador do modo 3D (lava, vidas, troca, vitória) |
| `scripts/game/hellball_manager_2d.gd` | Gerenciador dos modos 2D (configurável por cena) |
| `scripts/player/hellball_player.gd` | Jogador 3D: Charge Gun + Teleport Gun + Punch/Guard |
| `scripts/player/hellball_player_2d_base.gd` | Base 2D: itens + Punch/Guard + Game Feel |
| `scripts/player/hellball_platform_player.gd` | Jogador 2D plataforma |
| `scripts/player/hellball_topdown_player.gd` | Jogador 2D topdown |
| `scripts/player/charge_projectile.gd` / `charge_orb_2d.gd` | Projéteis do Charge Gun (3D/2D) |
| `scripts/player/teleport_orb.gd` / `teleport_orb_2d.gd` | Orbes do Teleport Gun (3D/2D) |
| `scripts/arena/arena_camera_2d.gd` | Câmera 2D com screen shake |
| `scenes/levels/hellball_arena.tscn` | Arena de lava 3D |
| `scenes/levels/hellball_platform.tscn` | Arena 2D lado |
| `scenes/levels/hellball_topdown.tscn` | Arena 2D topo |
