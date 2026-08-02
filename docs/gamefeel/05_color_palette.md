# Paleta de Cores — Sistema

> Cores são linguagem. Esta tabela é obrigatória para feedback, VFX, UI e
> identificação. Nunca inventar novos significados sem atualizar aqui.

## Paleta Central (Hellball)
Tema: fogo / inferno / capivara. Fundos quentes e escuros para máximo contraste com os personagens.

| Papel | Cor | Uso |
|---|---|---|
| Fundo escuro | `#140A08` | tela de fundo, painéis |
| Lava | `#F56100` (emissão `#FF4D00`) | perigo máximo, chão de lava |
| Plataforma | `#38302A` / `#29241F` | cenário |
| Destaque quente | `#FFB03A` | anúncios, ouro, vitória |
| Acentos | `#5C3A28` | pilares, sombras |

## Cores Funcionais (não negociável)

| Significado | Cor | Onde |
|---|---|---|
| Dano / Perigo | Vermelho `#E63A2E` | flash de dano, lava alta, vida perdida |
| Teleporte / Info | Ciano `#4DC9FF` | orbe do teleporte, swap, dicas |
| Charge / Poder | Laranja `#FF8C1A` | Charge Gun, carga acumulada |
| Defesa | Azul `#3FA9F5` | guard, escudo |
| Sucesso / Cura | Verde `#4CD964` | pickup, vida ganha, abate |
| Aviso | Amarelo `#FFD23F` | cooldown quase pronto, aviso de evento |
| Neutro | Cinza `#B8B8B8` | texto secundário |

## Cores dos Jogadores (paleta existente — manter)

```
0.72,0.56,0.28  (areia)   0.40,0.24,0.12 (marrom)
0.75,0.30,0.15  (terracota)  0.60,0.60,0.60 (cinza)
0.90,0.55,0.08  (laranja)   0.50,0.25,0.78 (roxo)
```

Regra: nenhum jogador usa uma cor de função pura (sem vermelho/ciano/verde
puros), para não confundir com feedback.

## Regras de Contraste e Acessibilidade

1. **Texto**: ≥ 4.5:1 contra o fundo; usar contorno escuro (outline_size 6+)
   em HUD sobre fundos quentes.
2. **Elementos críticos** (projéteis inimigos, lava) sempre contrastam com o
   personagem do jogador — teste visual em todas as cores de jogador.
3. **Flash de tela**: nunca 100% branco/opaco; usar 40–60% com blend ADD.
4. **Daltonismo**: o significado nunca depende só da cor — parear com forma
   (anel de choque, ícone, texto). Ex.: dano = vermelho + ícone de coração,
   teleporte = ciano + ícone de orbe.

## Gradientes e Curvas

- **Carga**: laranja claro → laranja intenso → quase branco no máximo.
- **Vida**: cheio = verde; 1 vida = vermelho pulsante.
- **Anúncios**: amarelo/dourado (`#FFD23F` → `#FFB03A`) com contorno escuro.
- **Lava pulsante**: emissão oscila 1.6→2.2 (4 Hz) para "viva".

## Uso por Modo
| Modo | Variação |
|---|---|
| Hellball 3D | fundo quente, glow da lava, emissivos de itens |
| Hellball Plataforma (2D) | céu degrade quente→escuro, lava na base emitindo |
| Hellball Topdown (2D) | fundo escuro, zona de lava pulsante nas bordas, luz central suave |
