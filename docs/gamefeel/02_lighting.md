# Iluminação — Padrões

> Leitura de cena, humor e clareza do gameplay. A regra é: **o que importa
> brilha, o que é perigo emite, o que é pano de fundo escurece**.

## 3D (Hellball 3D)

### Luz principal (Key)
- Direcional quente (lava): cor `Color(1.0, 0.62, 0.32)`, energia 1.0,
  sombra ativa. Ângulo ~35° para sombras longas e legíveis.

### Fill (preenchimento)
- Ambiente quente escuro vindo do céu (`ambient_light_energy` 0.5–0.6).
- Complemento frio sutil para não perder forma nas sombras (WorldEnvironment
  `ambient_light_color` levemente azulado).

### Acabamento (rim/contorno)
- Luz de recorte nas bordas dos personagens: preferir **emissão** no material
  (borda emissiva) ou uma light secundária fria para destacar contra a lava.

### Emissivos
- **Lava**: emissão laranja `Color(1, 0.30, 0)` energia 1.8 — ponto de
  perigo máximo, deve ser o mais brilhante da cena.
- **Itens**: emissão na cor do item (orbe ciano, charge laranja) — sempre
  `emission_energy ≥ 2` para separar do cenário.
- **Fog/glow**: usar `Glow` do WorldEnvironment (2.0–3.0) para dar "peso
  mágico" aos emissivos; sem exagero (não estourar o branco).

### Regras de contraste (encenação)
| Elemento | Deve ser |
|---|---|
| Jogador (qualquer cor) | Mais claro que o fundo; contorno escuro |
| Projétil inimigo | Emissivo + contraste de cor (nunca a cor da plataforma) |
| Lava/perigo | Mais brilhante da cena |
| Pickups/sucesso | Pulsar leve (emissão oscila) |

## 2D (Plataforma e Topdown)

### Camadas de luz
1. **Fundo** (parallax/cor sólida): escuro, dessaturado.
2. **Cenário** (plataformas/paredes): meia-luz.
3. **Atores**: 100% iluminados, contorno escuro ou brilho.
4. **Efeitos**: emissivos por cima (blend ADD).

### Técnicas 2D
- **PointLight2D** sobre emissivos (lava, orbes, fogueiras) com `texture_scale`
  e `energy` 1.5–2.5; cor da luz = cor do elemento.
- **CanvasModulate** para controle de mood global (valor base 1.0; em eventos
  de perigo 0.8 avermelhado).
- **Screen flash**: ColorRect full-screen com `blend_mode = ADD` e fade
  (branco para impacto, vermelho para dano, ciano para teleporte).
- **Vignette** (gradiente radial escura nas bordas) via textura no overlay
  para focar o centro — comum em topdown.

### Exemplo Hellball 2D
- Plataforma: fundo gradiente laranja-escuro→vermelho, lava na base emitindo
  PointLight2D laranja, personagens com contorno escuro.
- Topdown: fundo escuro, zona de lava ao redor com PointLight2D pulsante
  (perigo), luz principal suave do "sol" no centro.

## Checklist
- [ ] O elemento mais brilhante da tela é sempre o alvo/perigo atual.
- [ ] Projéteis e jogadores nunca se confundem com o fundo.
- [ ] Flash de tela não passa de 150 ms e nunca é 100% opaco.
- [ ] Glow existe mas não estoura (clip de brilho).
