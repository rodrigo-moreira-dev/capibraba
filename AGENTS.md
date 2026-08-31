# Capibraba — Contexto do Jogo

> Instruções de workspace auto-carregadas (somente informação relevante ao
> jogo). Para profundidade, consulte os docs listados no fim.

## 1. Visão geral

Jogo multiplayer de arena em 3D (capybara battle royale). **Godot 4.7,
GDScript, ENet, Jolt Physics.** Servidor é autoritativo para todo estado de
jogo. Comentários e textos de UI em **português do Brasil**.

## 2. Comandos e execução

- **Rodar**: abrir no editor Godot 4.7 e apertar Play (cena principal:
  `scenes/ui/main_menu.tscn`).
- **Exportar**: usar o sistema de exportação nativo do Godot.

## 3. Estrutura de diretórios

```
scenes/          # .tscn (levels/, player/, powerups/, ui/)
scripts/         # .gd (game/, player/, powerups/, network/, ui/, arena/)
docs/            # Documentos de design
```

## 4. Arquivos-chave

| Arquivo | Função |
|---|---|
| `scripts/game/last_standing_manager.gd` | Modo principal: vidas, mortes, abates, eliminação, rounds |
| `scripts/player/player.gd` | Controller base CharacterBody3D |
| `scripts/player/player_extended.gd` | Jogador estendido com habilidades |
| `scripts/player/player_abilities.gd` | Máquina de estados de power-up |
| `scripts/network/network_manager.gd` | Singleton ENet multiplayer |
| `scripts/game/match_settings.gd` | Parâmetros configuráveis de partida |
| `scripts/game/match_presets.gd` | 7 configs predefinidas de partida |
| `scripts/game/powerup_manager.gd` | Spawn autoritativo de power-ups |
| `scripts/game/arena_event_manager.gd` | Eventos aleatórios de arena |
| `scripts/game/hellball_manager.gd` | Hellball 3D (lava, Charge/Teleport Gun, trocas) |
| `scripts/game/hellball_manager_2d.gd` | Hellball 2D (Plataforma/Topdown) |
| `scripts/player/hellball_player.gd` | Hellball 3D: Charge Gun + Teleport Gun + punch/guard |
| `scripts/player/hellball_player_2d_base.gd` | Base 2D compartilhada (itens + punch/guard + game feel) |
| `scripts/player/hellball_platform_player.gd` | Hellball 2D side-view (gravidade, pulo duplo) |
| `scripts/player/hellball_topdown_player.gd` | Hellball 2D top-down (8 direções, mira no mouse) |
| `scenes/levels/hellball_arena.tscn` | Arena Hellball 3D de lava |
| `scenes/levels/hellball_platform.tscn` | Arena Hellball 2D side-view |
| `scenes/levels/hellball_topdown.tscn` | Arena Hellball 2D top-down |

## 5. Convenções

- Servidor autoritativo para todo estado de jogo.
- Power-ups estendem `powerup_base.gd`.
- Telas de UI têm par `.tscn` + `.gd` na própria pasta.
- Seguir os padrões existentes; ler arquivos vizinhos antes de adicionar.
- Game Feel / VFX / Animação / Áudio: ver `.github/agents/` e `docs/gamefeel/`.

## 6. Game Feel — princípios

> Base: Schell, Swink, *The Illusion of Life* (12 princípios) e "Juice it or
> lose it".

**Loop de cada ação:** `input → antecipação (wind-up) → ação → impacto →
feedback → recuperação → retorno ao fluxo`. Todas as etapas precisam de
feedback.

**Regras de ouro:**
1. Toda ação relevante tem **2+ canais de feedback** (visual + sonoro; se
   possível, háptico via `Input.start_joypad_vibration`).
2. **Hit-stop** de 40–80 ms em impactos importantes.
3. **Screen shake** proporcional à intensidade; nunca contínuo.
4. **Squash & stretch** em tudo que pula, cai, dispara ou é atingido.
5. **Cores são linguagem** (ver seção 9).
6. **Tempos**: impacto < 0,1 s; movimento secundário 0,2–0,4 s; anúncios 2–4 s.
7. **Priorização**: nunca sobrepor 3+ sons/efeitos grandes; o mais importante vence.

**Specs por ação (3D/2D):**
- **Pular**: squash y×0.9 (60 ms) → ar stretch y×1.12 → aterrissagem squash
  y×0.82 (120 ms) com spring back; poeira 6–10 partículas.
- **Dano**: hit-stop 50 ms; flash branco 80 ms (3D emissão / 2D modulate);
  squash direcional 100 ms; anel de choque; shake 0.15 s.
- **Atirar (Charge Gun)**: carga = orbe cresce 0.8→1.8 + emissão sobe + shake
  leve; disparo = flash de cano, recuo (recoil 0.1 s), rastro emissivo.
- **Teleport Gun**: whoosh + rastro ciano; teleporte = espiral ciano + flash;
  troca = anel duplo (ciano do orbe + laranja do impactado) + flash 120 ms.
- **Punch**: wind-up 80 ms → hit-stop 40 ms → follow-through 120 ms; slash.
- **Guard**: escudo/bolha azul; ao bloquear sparks azuis + "clank".
- **Dash**: stretch direcional + rastro 8–14 partículas; slow-out 0.12 s.

**Implementação:** usar `create_tween()` com `TRANS_BACK`/`TRANS_ELASTIC`
para o spring — nunca setar escala por frame. 2D: animar `scale` do visual;
3D: animar `mesh_pivot.scale` (não a CharacterBody3D). Transições < 0,25 s.

## 7. Ações básicas (desarmado, sempre disponíveis)

- **Punch**: melee ~1,2 m (2D ~40 px), arco visual; knockback 20–30; hit-stop
  40 ms; cooldown 0,4 s. Não empurra o usuário.
- **Guard**: segurar = escudo/bolha azul; reduz knockback recebido em 80%;
  movimento 50% mais lento; não ataca/dispara enquanto guarda; pode cancelar.
- **Dash**: impulso 0,16 s, cooldown 0,65 s; invencível a knockback durante;
  rastro de partículas.
- **Restrições por modo**: Topdown → dash 8 direções, punch como empurrão em
  área; Plataforma → dash só horizontal, punch pode dar micro-hop aéreo.
  Se um minigame tiver 3 itens, uma ação básica pode ser limitada (ex.: sem
  dash) — sempre documentado.

## 8. Itens (sistema conceitual)

- Personagem carrega no máximo **1 item equipado**; média de 2 itens por
  minigame (2 slots quando o minigame pede, ou itens que combinam 2 funções).
  Alternativa: `slots = {1,2,3}` configurável em `MatchSettings.item_slots`.
- Cada item tem uso **primário** (botão esquerdo/disparo) e **secundário**
  (botão direito/habilidade) quando fizer sentido.
- Ações básicas nunca somem por causa de item; no máximo ficam restritas por
  decisão de design do minigame.

**Itens atuais (Hellball):** `charge_gun` + `teleport_gun`.
- **Charge Gun**: carrega e dispara projétil que **empurra** (explosão).
- **Teleport Gun**: lança orbe; 2ª pressão teleporta o dono; toque no rival
  faz **troca** de posição.

**Itens futuros (design):**
- **Ímã de Dois Polos**: clique alterna polo (Norte atrai / Sul repele);
  segurar intensifica 1→3×; força radial; recuo próprio.
- **Katana do Hattori Hanzo**: corte com hit-stop forte, pode refletir
  projéteis; dash-corte (segurar+clique) com i-frame 0,15 s.
- **Capa de Teleporte**: teleporte blink (~8 m); passo fantasma (ao ser
  empurrado, blink automático para trás, cooldown 6 s).
- **Explosão**: empurra inimigos E propulsiona o usuário (risco de cair na
  lava). Segurar aumenta raio e auto-impulso.

**Configuração futura (`MatchSettings`):**
```gdscript
var item_slots: int = 2
var items_pool: Array[String] = ["charge_gun", "teleport_gun"]
var punch_enabled := true
var guard_enabled := true
var dash_enabled := true
```

## 9. Paleta de cores (linguagem obrigatória)

Cores funcionais — **não negociável** (nunca inventar significado novo sem
atualizar `docs/gamefeel/05_color_palette.md`):

| Significado | Cor | Onde |
|---|---|---|
| Dano / Perigo | Vermelho `#E63A2E` | flash de dano, lava alta, vida perdida |
| Teleporte / Info | Ciano `#4DC9FF` | orbe do teleporte, swap, dicas |
| Charge / Poder | Laranja `#FF8C1A` | Charge Gun, carga acumulada |
| Defesa | Azul `#3FA9F5` | guard, escudo |
| Sucesso / Cura | Verde `#4CD964` | pickup, vida ganha, abate |
| Aviso | Amarelo `#FFD23F` | cooldown quase pronto, aviso de evento |
| Neutro | Cinza `#B8B8B8` | texto secundário |

Tema Hellball (fogo/capivara): fundo escuro `#140A08`; lava `#F56100`
(emissão `#FF4D00`); plataforma `#38302A`/`#29241F`; destaque quente
`#FFB03A`; acentos `#5C3A28`.

**Cores dos jogadores (manter):** `0.72,0.56,0.28` areia · `0.40,0.24,0.12`
marrom · `0.75,0.30,0.15` terracota · `0.60,0.60,0.60` cinza ·
`0.90,0.55,0.08` laranja · `0.50,0.25,0.78` roxo. **Nenhum jogador usa cor
de função pura** (sem vermelho/ciano/verde puros).

**Acessibilidade:** texto ≥ 4,5:1 com contorno escuro (outline_size 6+);
flash de tela nunca 100% opaco (40–60% + blend ADD); significado nunca depende
só de cor — parear com forma/ícone/texto (daltonismo).

## 10. Áudio (padrões, sem assets ainda)

- **Sonificação**: cada ação/item tem 1 som "assinatura" + variação.
- **Variação**: `pitch_scale = randf_range(0.9, 1.1)` em todo toque.
- **Camadas**: mundo / jogador / UI, volumes relativos fixos.
- **Priorização**: nunca tocar 3+ sons críticos juntos; o mais importante vence
  (ex.: morte > tiro > passos).
- **Range dinâmico**: impacto alto (boom), utilitário médio (whoosh), ambiente
  baixo (sizzle/lava).
- **Implementação**: 3D `AudioStreamPlayer3D` (max_distance 30); 2D
  `AudioStreamPlayer2D` (attenuation 3.0); lava ambiente como
  `AudioStreamPlayer` (não 3D). Centralizar em um autoload `SfxBus` com
  `sfx(name)` e `tone(freq, dur, wave)` usando `AudioStreamGenerator`
  (procedural) até haver SFX.

## 11. Hellball (3 modos)

**Elementos comuns (todas as versões):**
1. Itens: Charge Gun + Teleport Gun.
2. Ações básicas desarmadas: Punch, Guard, Dash — sempre disponíveis.
3. **Lava**: 1 vida por contato, rebote alto (3D 28 m/s / 2D 18–22 m/s),
   cooldown 2 s, atribui abate ao `last_attacker_id`.
4. Servidor autoritativo (vidas/mortes/troca pelo gerente).
5. Paleta: lava laranja, teleporte ciano, charge laranja, guard azul, dano
   vermelho.
6. HUD compartilhado: `scenes/ui/hud.tscn` (CanvasLayer, 2D/3D).

**Mapa por modo:**

| Feedback | 3D | 2D Plataforma | 2D Topdown |
|---|---|---|---|
| Squash & stretch | mesh_pivot | sprite/polígono | idem |
| Hit-stop | `get_tree().paused`/timer | `Engine.time_scale = 0.05` | idem |
| Screen shake | Camera3D offset | Camera2D offset | idem |
| Flash de dano | emissão material | modulate pisca | idem |
| Anel / rastro / poeira | GPUParticles3D | CPUParticles2D | idem |
| Lava | Area3D + emissão | Area2D base | Area2D zona |

- **3D** (`hellball_player.gd` / `hellball_arena.tscn`): CharacterBody3D,
  já implementado; refinar squash & stretch, hit-stop, flash, guard, punch,
  shake em `player_camera.gd`.
- **2D Plataforma** (`hellball_platform_player.gd`): CharacterBody2D com
  gravidade, pulo duplo, dash horizontal; orbe aponta na direção do
  movimento; lava na base; câmera estática.
- **2D Topdown** (`hellball_topdown_player.gd`): 8 direções, sem gravidade,
  mira no mouse (desktop) ou direção de movimento (gamepad); lava como zona
  nas bordas.

**Itens por minigame (média 2):** Hellball 3D / Plataforma / Topdown →
Charge + Teleport. Futuros: Arena Ímã (ímã + Charge), Katana (Katana + Teleport),
Capa+Explosão.

## 12. Tempos de feedback (referência rápida)

| Feedback | Tempo |
|---|---|
| Hit-stop | 40–80 ms |
| Flash de dano | 80 ms |
| Screen shake | 0,15–0,25 s |
| Anel de choque | 0,25–0,35 s |
| Fumaça | 0,8 s |
| Anúncio de evento | 2–4 s |
| Squash & stretch recover | 0,12–0,18 s |

## 13. Referências (para profundidade)

- `docs/gamefeel/00_overview.md` — visão geral do sistema.
- `docs/gamefeel/01_animation_principles.md` — 12 princípios aplicados.
- `docs/gamefeel/02_lighting.md` — padrões de iluminação 3D/2D.
- `docs/gamefeel/03_particles.md` — biblioteca de partículas.
- `docs/gamefeel/04_feedback_specs.md` — specs de feedback por ação.
- `docs/gamefeel/05_color_palette.md` — paleta e regras de contraste.
- `docs/gamefeel/06_audio.md` — padrões de áudio e mapa de sons.
- `docs/gamefeel/07_hellball_application.md` — game feel aplicado ao Hellball.
- `docs/items.md` — design de ações básicas e itens.
- `docs/hellball.md`, `docs/last_standing.md`, `docs/relatorio_roadmap_minigames.md`,
  `docs/feature_system_summary.md` — modos e roadmap (consulte conforme a tarefa).
