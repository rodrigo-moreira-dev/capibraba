# Pixel Art 2D — Plataforma (estado da arte)

> Padrões atuais para side-view em pixel art, aplicáveis à arena Hellball
> Plataforma do Capibraba.

## Física e arco de pulo
- **Gravidade + arco de pulo legível**: a silhueta do salto comunica o alcance.
- Evite pulos que cortam o arco visual (juggle) — o jogador precisa prever onde
  vai cair.
- **Coyote time + jump buffer**: falta de frame = frustração; os dois resolvem.

## Plataformas
- **Plataformas 1-way** (atravessar por baixo) são o padrão em side-view:
  colisor só de cima, visual de topo com sombra. Evita becos e permite torres.
- Tileset com **transição de topo/borda** (solo, grama, pedra): a plataforma
  precisa parecer contínua, não um mosaico. **1px de bleed** contra costuras.

## Contraste e profundidade
- **Contraste vertical**: fundo mais escuro que as plataformas; personagem com
  outline + cor de destaque.
- **Parallax sutil** para profundidade, sem roubar a leitura da arena.

## Game feel (essencial no side-view)
- **Squash & stretch** no pulo e na aterrissagem (já implementado no
  `hellball_platform_player.gd`).
- **Hit-stop** em impacto; **screen shake** proporcional.
- Resposta de ação < 100 ms.

## Godot
- **Camera2D** com limites (`limit_left/right/top/bottom`) para não expor o
  vazio; manter a câmera alinhada a pixel.
- Tile platform como `TileMapLayer` (uma camada) com física própria.

> Aplicação no Capibraba: `scenes/levels/hellball_platform.tscn` já usa
> gravidade, pulo duplo, dash horizontal, câmera com zoom e tiles página
> placeholder; o personagem é sprite PICO-8.
