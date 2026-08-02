# Animação — 12 Princípios Aplicados a Jogos

Base: *The Illusion of Life* (Thomas & Johnston). Aplicação direta aos
personagens do Capibraba (3D e 2D). Todos os números são diretrizes;
ajuste por modo.

## Princípios → Ações

| Princípio | Aplicação Hellball | Parâmetros sugeridos |
|---|---|---|
| **Squash & Stretch** | Pular, aterrissar, dash, disparar, tomar dano | jump: stretch y×1.12 / squash x×0.88 · land: squash y×0.82 · recover 0.12–0.18 s |
| **Antecipação** | Wind-up do punch, carga do Charge Gun, salto | punch wind-up 0.10 s (recuo), charge 1.2 s com crescimento |
| **Follow-through / Overlap** | Recuo do corpo após punch/dash; capa/orelhas continuam | 0.15–0.25 s após fim da ação |
| **Slow-in / Slow-out** | Dash e projéteis | acelerar 0.08 s, desacelerar 0.12 s |
| **Arcos** | Projéteis e corpos arremessados | trajetória parabólica; orbe do teleporte em linha + leve arco |
| **Ação secundária** | Poeira ao correr/aterrissar, partículas do orbe, fumaça pós-impacto | 1 ação secundária por ação principal |
| **Timing** | Comprimento das animações | punch 0.22 s, guard 0.15 s, dash 0.16 s, dano 0.10 s |
| **Exagero** | Empurrão do Charge Gun, troca do Teleport Gun | corpos voam 2–3× o necessário; efeitos 1.5× |
| **Encenação (staging)** | Ação legível: flash, anel de choque, contorno | sempre separar ator do fundo (luminosidade/contorno) |
| **Apelo (appeal)** | Silhueta do capivara lida, formas arredondadas | cápsula arredondada, orelhas, cauda |
| **Pose a pose** | Estados: idle, run, jump, charge, punch, guard, hurt | transições em < 0.1 s |
| **Desenho sólido** | Volume consistente (não achatar demais) | squash nunca < 70% do volume |

## Specs por Ação (3D e 2D)

### Pular / Pular duplo
- Antecipação: squash y×0.9 por 60 ms.
- No ar: stretch y×1.12, squash horizontal ×0.9 (2D escala X, 3D escala no mesh).
- Aterrissar: squash y×0.82 por 120 ms → spring back 1.0 (elástico, curva ease-out).
- Poeira de aterrissagem: 6–10 partículas na base.

### Dano (ser empurrado/atingido)
- **Hit-stop** 50 ms no impacto do projétil.
- Flash branco no mesh do atingido por 80 ms (3D: material emissão; 2D: `modulate` pisca).
- Squash direcional: achatar na direção oposta ao empurrão por 100 ms.
- Anel de choque 2D/3D na origem + linha de impacto.
- Screen shake 0.15 s, intensidade proporcional à força.

### Atirar (Charge Gun)
- Antecipação = **carga** (crescimento do orbe + escala 0.8→1.8).
- Disparo: flash de cano, recuo do corpo (recoil 0.1 s), quem dispara sente
  leve impulso para trás.
- Projétil: rastro (trail) emissivo.

### Teleport Gun (orbe)
- Disparo: whoosh + rastro ciano.
- Teleporte do dono: partículas ciano em espiral no destino + flash.
- **Troca**: anel de choque duplo (nos dois pontos) + flash de 2 cores
  (ciano do orbe, laranja do impactado) — leitura clara do que aconteceu.

### Punch (básico)
- Wind-up 80 ms (recuo) → impacto (hit-stop 40 ms) → follow-through 120 ms.
- Linha de arco (slashes) ou anel pequeno no ponto de impacto.

### Guard (básico)
- Escudo translúcido na frente (2D) / bolha ao redor (3D), emissão azul.
- Ao bloquear: faíscas azuis + "clank" + knockback reduzido.
- Enquanto guarda: animação de pose fixa (sem movimento de ataque).

### Dash (básico)
- Stretch na direção (y×0.9, x×1.25 no 2D), rastro de 8–14 partículas.
- Slow-out no final (0.12 s) + poeira de parada.

## Implementação

- Usar `create_tween()` com `set_trans(Tween.TRANS_BACK)`/`TRANS_ELASTIC`
  para o "spring" (squash & stretch) — nunca setar escala direto por frame
  se puder usar tween (mais suave e barato).
- 2D: animar `scale` do visual (não do corpo físico).
- 3D: animar `mesh_pivot.scale` (não a CharacterBody3D).
- Manter `Time` de transições curtas: < 0.25 s para manter responsividade.
