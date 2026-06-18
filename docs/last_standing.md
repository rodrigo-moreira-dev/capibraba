# Last Capivara Standing

## Visão Geral

Last Capivara Standing é um modo de eliminação em arena onde o objetivo é ser o último jogador vivo. A arena é cercada por lava, e os jogadores usam projéteis explosivos para se empurrar para fora da plataforma.

## Como Funciona

Cada jogador começa com **3 vidas**. Ao tocar a lava, o jogador perde uma vida e é arremessado para o alto, podendo voltar para a arena com controle aéreo. Quando um jogador perde todas as vidas, ele é eliminado. O último jogador vivo vence a partida.

## Mecânicas

### Lava
- Tocar a lava causa um **salto alto automático** (velocidade vertical de 28 m/s), permitindo retornar à arena
- O impulso horizontal é quase zerado na colisão, então é preciso usar os controles aéreos para direcionar de volta à plataforma
- Cada contato com a lava consome **1 vida**
- Um cooldown de 2 segundos evita perda de vidas em contatos rápidos consecutivos

### Projéteis Explosivos
- Pressione **Clique Esquerdo** (teclado/mouse) ou **Gatilho Direito / RT** (controle) para disparar
- O projétil voa em linha reta na direção da câmera
- Ao colidir com qualquer superfície ou jogador, explode e **empurra todos os jogadores próximos** em um raio de 4,5 metros
- A força do empurrão é proporcional à proximidade — mais perto, maior o impulso
- Cooldown de 0,55 segundos entre disparos

### Controle Aéreo
- O personagem mantém aceleração no ar, permitindo manobras após ser lançado
- Pulo duplo disponível para recuperação extra

## Vitória e Placar

- O jogo termina quando **apenas um jogador** permanece com vidas
- Se todos os jogadores perderem suas vidas ao mesmo tempo, é declarado **empate**
- Pressione **TAB** a qualquer momento para ver o placar em tempo real:
  - **Mortes**: quantas vezes o jogador tocou a lava
  - **Abates**: quantos jogadores o jogador eliminou

## Variantes de Arena

### Plataforma Central (`lava_flat`)
Uma plataforma plana e ampla cercada por lava. Layout simples e direto — ideal para aprender as mecânicas. Os confrontos tendem a ser abertos, sem onde se esconder.

### Ilhas de Lava (`lava_islands`)
Uma ilha central cercada por quatro ilhas menores nas diagonais. Jogadores começam nas ilhas externas e precisam atravessar lava (ou ser lançados) para alcançar o centro. Favorece jogadores que controlam bem o voo.

### Plataforma Maldita (`lava_shrinking`)
Uma grade de 5×5 tiles que desaparece progressivamente — o servidor remove um tile aleatório a cada 15 segundos, até restar apenas 5 tiles. O espaço se torna cada vez menor, forçando confrontos inevitáveis.

## Controles

| Ação         | Teclado/Mouse         | Controle         |
|--------------|-----------------------|------------------|
| Mover        | WASD                  | Analógico Esquerdo |
| Câmera       | Mouse                 | Analógico Direito  |
| Pular        | Espaço                | Botão Sul (A/Cross) |
| Pulo Duplo   | Espaço (no ar)        | Botão Sul (no ar)  |
| Dash         | Shift                 | L3 (pressionar analógico) |
| Disparar     | Clique Esquerdo       | RT / Gatilho Direito |
| Placar       | TAB                   | —                |
| Pausar       | ESC                   | —                |
