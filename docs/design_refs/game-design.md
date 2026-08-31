# Game Design — Princípios rápidos

> Núcleo de design que orienta os minigames do Capibraba: clareza, decisões,
> interações entre itens e justiça em multiplayer.

## As três referências canônicas

### Theory of Fun for Game Design — Raph Koster
**Diversão = aprendizado de padrões.** O jogo ensina o cérebro a reconhecer e
dominar padrões; quando o padrão se esgota, a diversão vira tédio.

- Projete para uma **curva de aprendizado contínua**: novos padrões a cada
  camada, nunca um único padrão repetido.
- Um jogo "fácil demais" entedia; "impossível demais" frustra (ligado à Lente
  do Fluxo de Schell).
- No Capibraba: o loop de itens (parry, troca, knockback) deve oferecer padrões
  emergentes conforme o jogador domina a base.

### The Art of Game Design: A Book of Lenses — Jesse Schell (3ª ed.)
Mais de **100 lentes** para enxergar o jogo por ângulos (experiência, mecânica,
estética, jogador, equipe).

- **Lente n° 1 (a mais importante):** "Que experiência eu quero que o jogador
  tenha?". Toda decisão deriva dela.
- Outras lentes úteis aqui: *A Diversão* (surpresa + maestria + novidade),
  *O Fluxo* (desafio no alcance), *Progresso Visível* (consequência legível),
  *Recompensa* (feedback imediato/proporcional/variável).
- Use as lentes na **fase de conceito** para convergir a visão antes de codar.

### Game Maker's Toolkit (GMTK) — Mark Brown
Canal de vídeo que traduz design em linguagem prática moderna.

- **Juice**: feedback exagerado e deliberado em cada interação.
- **Telegrafia**: comunicar a intenção antes do fato (indispensável em 1-hit-kill).
- **Design de chefes / level design / economia**: vocabulário comum.
- Use o vocabulário do GMTK na hora de **comunicar juízo** (review/feedback).

**Regra prática para o Capibraba:** Schell no conceito, Koster no loop de itens,
GMTK no momento de avaliar juice/feedback.

---

## Princípios que orientam os minigames

- **Um objetivo claro em até 5 segundos** (ex.: "empurre os rivais para a lava").
  Rodada curta (1–3 min) e todos ativos.
- **Decisões > reflexo**: cada item cria uma escolha (parry ou desviar? trocar
  de lugar ou segurar?) — não um botão de dano.
- **Interações entre itens são ouro** (bola × bola = explosão; selo × projétil
  = troca). Desenhe a **tabela de interações** explicitamente.
- **Counterplay**: todo item tem resposta (guard reduz knockback; dash é
  i-frame; parry anula projétil).
- **Feedback em < 100 ms** (tela + som + animação) — a base do juice; nunca
  sobrepor 3+ efeitos grandes.
- **Fairness em multiplayer**: estado crítico replicado, morte/parry resolvidos
  no servidor, input buffering para parry justo.

> Ver também: `../gamefeel/` (sistema de game feel) e `../items.md` (design de
> itens e ações básicas).
