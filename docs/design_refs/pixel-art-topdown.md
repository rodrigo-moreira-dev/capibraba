# Pixel Art 2D — Topdown (estado da arte)

> Padrões atuais para jogos topdown em pixel art, aplicáveis às arenas do
> Capibraba (Hellball Topdown e os minigames Ímãs/Espadas).

## Resolução e escala
- **Resolução base** 480×270 ou 640×360, com **escala inteira** (2x/3x).
- Todo arte em resolução nativa; nada de "desenhar grande e reduzir".
- **Godot**: stretch mode `canvas_items`, aspect `keep`; import filter
  `Nearest`; ative `snap_2d_transforms_to_pixel` e `snap_2d_vertices_to_pixel`.

## Tileset
- Tile base **16×16 ou 32×32**, com **1px de bleed** além da borda (contra
  costuras no atlas).
- Use **TileMapLayer** (uma por camada): chão sólido, decoração (sem colisão),
  zona de dano (lava).
- Bordas/cantos desenhados para a transição parecer contínua, não um mosaico.

## Paleta e valor
- **Paleta limitada** (16–64 cores) e **estrutura de valor** primeiro;
  cor depois.
- Contraste do jogador por **hue + valor**, nunca só por detalhe.

## Legibilidade (arena com 4+ jogadores)
- **Silhueta > interior**: o personagem precisa ser lido de relance.
- **1px de outline escuro** (não preto puro) em personagens e projéteis —
  nunca em fundo.
- Projéteis sempre outlined/emissivos e com tamanho mínimo visível.
- Impacto < 100 ms (knockback + flash + partícula).

## Animação
- **8 direções**: idle 2–4 frames, run 4–6; poses fortes vencem mais frames.
- **Squash & stretch** por mudança de *bounding box*.
- **Hit-stop + shake** substituem frames de impacto.

## Mira (topdown)
- **Mouse** com retículo visível (desktop); **analógico direito** (gamepad).
- O corpo gira para a mira (padrão já usado no `hellball_topdown_player.gd`).
- Direção determinística para projéteis/selo (CRÍTICA 7 do roadmap).

> Aplicação no Capibraba: `scenes/levels/hellball_topdown.tscn` já usa câmera
> com zoom e lava ao redor; os minigames Ímãs/Espadas seguem o mesmo padrão.
