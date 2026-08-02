# Game Feel aplicado ao Hellball

> Como o sistema de Game Feel se aplica às **três versões** de Hellball
> (3D, 2D Plataforma, 2D Topdown). Mapa único de implementação.

## Mapa por Modo

| Feedback | Hellball 3D | 2D Plataforma | 2D Topdown |
|---|---|---|---|
| Squash & stretch | mesh_pivot (scale) | sprite/polígono scale | idem |
| Hit-stop | `get_tree().paused` curto OU timer | `Engine.time_scale = 0.05` 50 ms | idem |
| Screen shake | `Camera3D` offset | `Camera2D` offset | idem |
| Flash de dano | emissão do material | `modulate` pisca | idem |
| Anel de choque | GPUParticles3D ring | CPUParticles2D ring | idem |
| Rastro de dash | GPUParticles3D | CPUParticles2D | idem |
| Poeira aterrissar | GPUParticles3D base | CPUParticles2D base | n/a (topdown) |
| Lava | Area3D + emissão | Area2D na base | Area2D zona |
| Anúncios | HUD `show_event_announcement` | idem | idem |
| Placar/vidas | HUD (compartilhado) | idem | idem |

## Elementos Comuns (todas as versões)

1. **Items**: Charge Gun (empurra) + Teleport Gun (orbe: teleporte ou troca).
2. **Ações básicas desarmadas**: Punch, Guard, Dash — sempre disponíveis.
3. **Lava**: 1 vida por contato, rebote alto, cooldown 2 s, atribui abate
   ao `last_attacker_id`.
4. **Servidor autoritativo**: vidas/mortes/troca validada pelo gerente.
5. **Paleta**: `05_color_palette.md` (lava laranja, teleporte ciano,
   charge laranja, guard azul, dano vermelho).
6. **HUD**: reutiliza `scenes/ui/hud.tscn` (CanvasLayer — funciona em 2D/3D).

## Implementação por Versão

### 3D (`hellball_player.gd` / `hellball_arena.tscn`)
- Já implementado. Agora: squash & stretch no `mesh_pivot`, hit-stop na
  explosão, flash de dano, guard (bolha azul), punch (slash + sparks),
  shake de câmera no `player_camera.gd`.

### 2D Plataforma (`hellball_platform_player.gd` / `hellball_platform.tscn`)
- Lado: CharacterBody2D com gravidade, pulo duplo, dash horizontal.
- Lava na base; câmera estática enquadrando a arena.
- Orbe/disparo apontam para a direção do movimento (esquerda/direita).
- Mesmas mecânicas de item + punch/guard/dash.

### 2D Topdown (`hellball_topdown_player.gd` / `hellball_topdown.tscn`)
- Cima: CharacterBody2D 8 direções, sem gravidade, dash em 8 direções.
- Mira no mouse (desktop) ou direção de movimento (gamepad).
- Lava como zona ao redor da plataforma (borda) — entrar = perder vida +
  rebote para o centro.
- Mesmas mecânicas de item + punch/guard/dash.

## Itens por Minigame (regra da média)

> Regra: **em média 2 itens por minigame**; haverá minigames com 1 ou 3.
> Ações básicas (punch/guard/dash) estão sempre disponíveis.

| Minigame | Itens |
|---|---|
| Hellball 3D | Charge Gun + Teleport Gun (2) |
| Hellball 2D Plataforma | Charge Gun + Teleport Gun (2) |
| Hellball 2D Topdown | Charge Gun + Teleport Gun (2) |
| (futuro) Arena ímã | ímã 2 polos + Charge Gun (2) |
| (futuro) Katana | Katana Hattori Hanzo + Teleport Gun (2) |
| (futuro) Capa+Explosão | Capa de Teleporte + Explosão (2) |

## Medidas de Sucesso (checklist do diretor)
- [ ] Ação → resposta < 100 ms (tela + som + animação).
- [ ] Todos os jogadores se identificam instantaneamente (cor + nome).
- [ ] Empurrão do Charge sempre "dói" (feedback de dano claro).
- [ ] Troca do Teleporte é sempre legível (anel duplo + flash).
- [ ] Nenhuma tela fica "sem juice" por mais de 2 interações.
