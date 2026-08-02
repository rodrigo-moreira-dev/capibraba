# Partículas — Padrões

> Biblioteca de padrões de partículas. Cada efeito é uma combinação de
> **burst** (uma rajada) + **stream** (rastro) + **ring** (anel) + **shake**.

## Vocabulário de Partículas

| Padrão | Quando | Configuração típica (GPUParticles3D / CPUParticles2D) |
|---|---|---|
| **Burst** | Impacto, explosão, dano | one_shot=true, explosiveness=1, amount 20–40, initial_velocity 2–10 |
| **Stream** | Rastro de orbe/projétil/dash | looping, gravity=0, scale pequeno, vida 0.2–0.4 s |
| **Ring/Anel** | Onda de choque (swap, explosão, landing) | emissão em anel (sphere/ring radius), expande, fade rápido |
| **Billow/Fumaça** | Pós-explosão, lava | cores escuras, escala cresce, alpha cai |
| **Sparks/Faísca** | Punch, guard block, impacto em metal | initial_velocity alto, gravity forte, vida curta, cor clara |
| **Dust/Poeira** | Correr, aterrissar, dash parar | cor neutra, escala pequena, vida 0.3–0.5 s, alpha baixo |
| **Confetti/Glow** | Vitória, pickup | cores da paleta, explosiveness=1, voo longo |

## Diretrizes

1. **Cor = função** (ver `05_color_palette.md`): nunca use branco genérico
   para perigo nem laranja para feedback positivo.
2. **3 escalas**: partículas de impacto são grandes (leitura a distância),
   rastros médios, poeira pequena.
3. **Tempo de vida curto**: 0.2–0.6 s para ação, 0.8–1.5 s para ambiente.
4. **Variação** (não determinístico): `initial_velocity_min/max`,
   `scale_min/max`, `color_ramp` — evita o "visual de jogo de 2005".
5. **Reciclar**: um `one_shot` + `queue_free` depois; não vazar nós.
6. **Prioridade visual**: em explosão, primeiro o **flash** (0.05 s), depois
   o **anel**, depois a **fumaça** — nessa ordem de tempo de vida.

## Padrões do Hellball

### Explosão do Charge Gun
1. Flash branco/laranja (burst 12, vida 0.08 s, emissão alta).
2. Anel de choque laranja expandindo (ring, 0.25 s).
3. Fumaça escura ascendente (billow, 0.8 s).
4. Sparks em direção ao alvo empurrado.
5. Screen shake 0.2 s + hit-stop 50 ms.

### Troca do Teleport Gun
1. Anel ciano nos dois pontos de troca (0.3 s).
2. Burst de "portal" ciano (30 partículas).
3. Flash ciano por 120 ms no destino do orbe.
4. Sparks laranja no jogador que foi "puxado" (opcional, divertido).

### Teleporte do dono (2ª pressão)
1. Espiral ciano subindo (stream em círculo, 0.35 s).
2. Flash ciano no destino.
3. Poeira no ponto de partida.

### Lava (contato)
1. Burst laranja/vermelho na base do personagem (20, vida 0.4 s).
2. Fumaça escura.
3. Sparks para cima (rebote).

### Punch / Guard / Dash
- Punch: sparks pequenos + linha de arco (slash) no impacto.
- Guard block: sparks azuis no ponto de bloqueio.
- Dash: stream horizontal da cor do jogador (8–14 partículas).

## Implementação (Godot)
- 3D: `GPUParticles3D` + `ParticleProcessMaterial`; se já há muitos
  emissivos, usar `CPUParticles3D` para simplicidade/estabilidade.
- 2D: `CPUParticles2D` (mais estável e barato que GPU em 2D).
- Criar helper compartilhado `spawn_burst(pos, color, amount, life, vel)`
  para padronizar (ver código dos jogadores).
- Nunca criar efeitos no `_process` de forma contínua sem limite;
  agrupar em um `EffectsBus` (nó autoload opcional) se a cena ficar poluída.
