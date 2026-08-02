# Game Feel — Visão Geral

> Sistema de referência de **Game Feel** do Capibraba. Todo agente de VFX,
> animação, áudio ou paleta deve ler este conjunto antes de implementar.

## Fontes

- **Jesse Schell — "The Art of Game Design: A Book of Lenses"**
  - *Lens #22 A Diversão*: prazer vem de surpresa + maestria + novidade.
  - *Lens #26 O Fluxo*: desafio dentro do alcance do jogador.
  - *Lens #32 Progresso Visível*: cada ação deve ter consequência legível.
  - *Lens #44 A Experiência Necessária*: escolha 1-2 sentimentos centrais.
  - *Lens #53 Recompensa*: dar feedback imediato, proporcional e variável.
  - *Lens #60 A Outra Pessoa*: empatia → reações do mundo ao jogador.
- **Steve Swink — "Game Feel"**: o *feel* é a interação entre input,
  simulação e feedback em tempo real (screen shake, hit-stop, efeitos).
- **Frank Thomas & Ollie Johnston — "The Illusion of Life"**: os 12
  princípios da animação (ver `01_animation_principles.md`).
- **Jonasson & Purho — "Juice it or lose it" (GDC 2012)**: "juice" =
  feedback em excesso deliberado em cada interação.

## O Loop de Game Feel

Cada ação do jogador segue o ciclo abaixo. **Todas as etapas precisam de
feedback**:

```
input → antecipação (wind-up) → ação → impacto → feedback (fx/som/tela)
      → recuperação (follow-through) → retorno ao fluxo
```

| Etapa | Exemplo Hellball | Feedback |
|---|---|---|
| Antecipação | carregar Charge Gun | orbe cresce, tom sobe, shake leve |
| Ação | disparar | projétil + flash + som de whoosh |
| Impacto | explodir/empurrar | hit-stop, shake, partículas, som |
| Feedback | jogador atingido | flash de dano, recuo, anel de choque |
| Recuperação | recuo/anim de retorno | squash & stretch, poeira |

## Regras de Ouro

1. **Toda ação relevante tem 2+ canais de feedback** (visual + sonoro; se
   possível também haptico via `Input.start_joypad_vibration`).
2. **Hit-stop** (congelar o jogo por 40–80 ms) em impactos importantes —
   nada comunica peso melhor.
3. **Screen shake** proporcional à intensidade; nunca contínuo.
4. **Squash & stretch** em tudo que pula, cai, dispara ou é atingido.
5. **Cores são linguagem**: vermelho = dano/perigo, ciano = teleporte,
   laranja = charge/lava, azul = defesa, verde = cura/sucesso (ver
   `05_color_palette.md`).
6. **Tempo dos números**: impacto < 0,1 s; movimento secundário 0,2–0,4 s;
   anúncios 2–4 s.
7. **Priorização de feedback**: nunca sobreponha 3+ sons/efeitos grandes;
   o mais importante vence.

## Como Usar

- Agente **VFX/Animação**: `01`, `02`, `03`, `05`.
- Agente **Áudio**: `06`, `04`.
- Agente **Diretor de Game Feel**: todos; valida consistência e "juice".
- Implementação Hellball: `07_hellball_application.md`.
